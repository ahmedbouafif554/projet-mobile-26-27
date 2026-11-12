import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/location/road_route.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/realtime.dart';
import '../../../../../core/utils/launcher.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/mock/mock_users.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/repositories/repository_providers.dart';
import '../../../../router/front_routes.dart';
import '../../../auth/presentation/widgets/address_map_field.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/orders_providers.dart';

/// Livreur assigné à une commande (nom, téléphone, véhicule, note).
class TrackedCourier {
  const TrackedCourier({
    required this.name,
    this.phone,
    this.vehicle,
    this.rating,
  });

  final String name;
  final String? phone;
  final String? vehicle;
  final double? rating;

  String get vehicleLabel => switch (vehicle) {
    'bike' => 'Vélo',
    'car' => 'Voiture',
    _ => 'Scooter',
  };
}

/// Données de suivi d'une commande (`GET /orders/:id/tracking`) : positions
/// réelles du restaurant, du client et du livreur, temps restant.
class TrackingData {
  const TrackingData({
    this.pickup,
    this.dropoff,
    this.courierPosition,
    this.courier,
    this.remainingMinutes,
    this.remainingKm,
    this.estimatedArrivalAt,
    this.phase,
    this.toRestaurantKm,
  });

  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? courierPosition;
  final TrackedCourier? courier;
  final int? remainingMinutes;
  final double? remainingKm;

  /// Heure d'arrivée estimée par le serveur (préparation restante, trajet du
  /// livreur jusqu'au restaurant puis jusqu'au client).
  final DateTime? estimatedArrivalAt;

  /// searchingCourier | toRestaurant | toCustomer
  final String? phase;

  /// Distance du livreur au restaurant (avant le retrait).
  final double? toRestaurantKm;

  /// Minutes restantes à l'instant présent.
  int? get minutesLeft {
    final arrival = estimatedArrivalAt;
    if (arrival == null) return remainingMinutes;
    final seconds = arrival.difference(DateTime.now()).inSeconds;
    return seconds <= 60 ? 1 : (seconds / 60).ceil();
  }

  /// Précision affichée sous le statut (« Votre livreur est à 1,2 km… »).
  String? get detail => switch (phase) {
    'searchingCourier' => 'Recherche d’un livreur à proximité…',
    'toRestaurant' when toRestaurantKm != null =>
      'Votre livreur est à ${Formatters.distance(toRestaurantKm!)} du restaurant.',
    'toRestaurant' => 'Votre livreur se rend au restaurant.',
    'toCustomer' when remainingKm != null =>
      'Votre livreur est à ${Formatters.distance(remainingKm!)} de chez vous.',
    _ => null,
  };
}

LatLng? _point(dynamic raw) {
  if (raw is! Map) return null;
  final lat = (raw['latitude'] as num?)?.toDouble();
  final lng = (raw['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
  return LatLng(lat, lng);
}

/// Suivi relu à chaque changement côté serveur (statut, livreur assigné) et
/// à chaque nouvelle position GPS du livreur (Socket.IO).
final orderTrackingProvider = FutureProvider.autoDispose
    .family<TrackingData, String>((ref, orderId) async {
      watchLogistics(ref);
      ref.watch(realtimeRevisionProvider(RealtimeTopic.location(orderId)));
      // Estimation recalculée régulièrement (la préparation avance même
      // quand personne ne bouge).
      final refresh = Timer(const Duration(seconds: 30), ref.invalidateSelf);
      ref.onDispose(refresh.cancel);
      if (AppConfig.useMockData && !AppConfig.useApiOrders) {
        final demo = MockUsers.byId('u-courier-1');
        return TrackingData(
          courier: TrackedCourier(
            name: demo.firstName,
            phone: demo.phone,
            rating: 4.9,
          ),
        );
      }
      try {
        final response = await ref
            .read(dioProvider)
            .get('/orders/$orderId/tracking');
        final data = response.data as Map;
        final positions = data['positions'];
        final courier = data['courier'];
        return TrackingData(
          pickup: positions is Map ? _point(positions['pickup']) : null,
          dropoff: positions is Map ? _point(positions['dropoff']) : null,
          courierPosition: positions is Map
              ? _point(positions['courier'])
              : null,
          courier: courier is Map
              ? TrackedCourier(
                  name: '${courier['name'] ?? 'Votre livreur'}',
                  phone: courier['phone'] as String?,
                  vehicle: courier['vehicle'] as String?,
                  rating: (courier['rating'] as num?)?.toDouble(),
                )
              : null,
          remainingMinutes: (data['remainingMinutes'] as num?)?.round(),
          remainingKm: (data['remainingDistanceKm'] as num?)?.toDouble(),
          estimatedArrivalAt: DateTime.tryParse(
            '${data['estimatedArrivalAt'] ?? ''}',
          )?.toLocal(),
          phase: (data['eta'] as Map?)?['phase'] as String?,
          toRestaurantKm: ((data['eta'] as Map?)?['toRestaurantKm'] as num?)
              ?.toDouble(),
        );
      } catch (_) {
        return const TrackingData();
      }
    });

/// Livreur de la commande (panneau du bas).
final trackedCourierProvider = Provider.autoDispose
    .family<AsyncValue<TrackedCourier?>, String>(
      (ref, orderId) =>
          ref.watch(orderTrackingProvider(orderId)).whenData((t) => t.courier),
    );

/// Suivi en temps réel : vraie carte (OpenStreetMap) avec le restaurant, le
/// domicile et la position GPS du livreur, mise à jour en direct par
/// Socket.IO. L'étape et le livreur changent dès que le restaurant ou le
/// livreur font avancer la commande.
class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      body: AsyncValueView(
        value: order,
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (o) => _TrackingView(order: o),
      ),
    );
  }
}

class _TrackingView extends ConsumerStatefulWidget {
  const _TrackingView({required this.order});

  final Order order;

  @override
  ConsumerState<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<_TrackingView> {
  final _map = MapController();

  /// Démonstration hors ligne seulement : la commande avance toute seule.
  Timer? _progression;

  /// La caméra suit le livreur tant que le client ne déplace pas la carte.
  bool _follow = true;
  bool _fitted = false;

  static bool get _offlineDemo =>
      AppConfig.useMockData && !AppConfig.useApiOrders;

  @override
  void initState() {
    super.initState();
    if (_offlineDemo && !widget.order.status.isFinal) {
      _progression = Timer.periodic(const Duration(seconds: 6), (_) => _step());
    }
  }

  @override
  void didUpdateWidget(covariant _TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order.status.isFinal) _progression?.cancel();
  }

  Future<void> _step() async {
    if (!mounted) return;
    final next = await advanceOrderDemo(
      ref.read(orderRepositoryProvider),
      widget.order.id,
    );
    if (!mounted) return;
    if (next == null || next == OrderStatus.delivered) _progression?.cancel();
    ref.invalidate(myOrdersProvider);
  }

  @override
  void dispose() {
    _progression?.cancel();
    _map.dispose();
    super.dispose();
  }

  /// Cadre la carte sur les points connus (au premier affichage).
  void _fit(List<LatLng> points, double bottomInset) {
    if (_fitted || points.isEmpty) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (points.length == 1) {
          _map.move(points.first, 15);
        } else {
          _map.fitCamera(
            CameraFit.coordinates(
              coordinates: points,
              padding: EdgeInsets.fromLTRB(60, 120, 60, bottomInset + 40),
              maxZoom: 17,
            ),
          );
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final tracking = ref.watch(orderTrackingProvider(o.id)).value;
    final live = ref.watch(liveCourierPositionProvider(o.id));
    final showCourier =
        o.status == OrderStatus.delivering ||
        o.status == OrderStatus.ready ||
        o.status == OrderStatus.preparing ||
        o.status == OrderStatus.accepted;

    final pickup = tracking?.pickup;
    final dropoff = tracking?.dropoff;
    final courier = live != null
        ? LatLng(live.lat, live.lng)
        : tracking?.courierPosition;

    final remaining = tracking?.minutesLeft;
    // Estimation du serveur (préparation + trajets) ; valeurs indicatives
    // seulement en mode démo hors ligne.
    final minutesLeft = switch (o.status) {
      _ when remaining != null && o.status.isActive => remaining,
      OrderStatus.delivering when remaining != null => remaining,
      OrderStatus.pending || OrderStatus.accepted => 30,
      OrderStatus.preparing => 22,
      OrderStatus.ready => remaining != null ? remaining + 5 : 15,
      OrderStatus.delivering => 8,
      _ => 0,
    };

    final route = pickup != null && dropoff != null
        ? ref.watch(roadRouteProvider((pickup, dropoff))).value
        : null;

    final size = MediaQuery.sizeOf(context);
    final bottomInset = size.height * 0.42;
    final points = [?pickup, ?dropoff, if (showCourier) ?courier];
    _fit(points, bottomInset);

    // Suit le livreur pendant la livraison.
    if (_follow &&
        _fitted &&
        courier != null &&
        o.status == OrderStatus.delivering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(courier, _map.camera.zoom);
        } catch (_) {}
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter:
                  courier ??
                  dropoff ??
                  pickup ??
                  AddressMapField.fallbackCenter,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.superfaster.app',
              ),
              if (route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 5,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (pickup != null)
                    Marker(
                      point: pickup,
                      width: 44,
                      height: 44,
                      child: _marker(
                        Icons.storefront_rounded,
                        AppColors.primary,
                      ),
                    ),
                  if (dropoff != null)
                    Marker(
                      point: dropoff,
                      width: 44,
                      height: 44,
                      child: _marker(Icons.home_rounded, AppColors.success),
                    ),
                  if (showCourier && courier != null)
                    Marker(
                      point: courier,
                      width: 52,
                      height: 52,
                      child: _courierMarker(),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© les contributeurs d’OpenStreetMap'),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  elevated: true,
                  tooltip: 'Retour',
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(FrontRoutes.orders),
                ),
                const Spacer(),
                if (!_follow && courier != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleIconButton(
                      icon: Icons.my_location_rounded,
                      elevated: true,
                      tooltip: 'Suivre le livreur',
                      onTap: () {
                        setState(() => _follow = true);
                        _map.move(courier, 16);
                      },
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Text(
                    '#${o.reference}',
                    style: context.text.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomPanel(order: o, minutesLeft: minutesLeft),
        ),
      ],
    );
  }

  Widget _marker(IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );

  Widget _courierMarker() =>
      Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 0.92, end: 1.06, duration: 900.ms);
}

class _BottomPanel extends ConsumerWidget {
  const _BottomPanel({required this.order, required this.minutesLeft});

  final Order order;
  final int minutesLeft;

  static const _labels = {
    OrderStatus.pending: (
      'Commande envoyée',
      'Le restaurant va confirmer votre commande.',
    ),
    OrderStatus.accepted: (
      'Commande acceptée',
      'Le restaurant s’apprête à cuisiner.',
    ),
    OrderStatus.preparing: (
      'En préparation 👨‍🍳',
      'Votre repas est en cuisine.',
    ),
    OrderStatus.ready: ('Commande prête', 'Un livreur arrive au restaurant.'),
    OrderStatus.delivering: ('En route 🛵', 'Votre livreur arrive bientôt.'),
    OrderStatus.delivered: ('Livrée ✅', 'Bon appétit !'),
    OrderStatus.cancelled: ('Commande annulée', 'Vous ne serez pas débité.'),
    OrderStatus.refunded: (
      'Commande remboursée',
      'Le remboursement est en cours.',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, defaultSubtitle) = _labels[order.status]!;
    final detail = order.status.isActive
        ? ref.watch(orderTrackingProvider(order.id)).value?.detail
        : null;
    final subtitle = detail ?? defaultSubtitle;
    final step = order.status.index.clamp(0, OrderStatus.delivered.index);
    final courier = ref.watch(trackedCourierProvider(order.id)).value;
    final showCourier = courier != null && order.status.isActive;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDurations.medium,
                    child: Column(
                      key: ValueKey(order.status),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleLarge),
                        Text(
                          subtitle,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.status.isActive)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$minutesLeft min',
                        style: context.text.headlineSmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'vers ${Formatters.time(DateTime.now().add(Duration(minutes: minutesLeft)))}',
                        style: context.text.labelSmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                for (var i = 0; i <= OrderStatus.delivered.index; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: i <= step ? 1 : 0),
                      duration: AppDurations.slow,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          color: AppColors.primary,
                          backgroundColor: context.palette.surfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (showCourier) ...[
              const SizedBox(height: AppSizes.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    Avatar(name: courier.name, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(courier.name, style: context.text.titleSmall),
                          Text(
                            courier.rating == null
                                ? courier.vehicleLabel
                                : '${courier.vehicleLabel} • ★ ${courier.rating!.toStringAsFixed(1).replaceAll('.', ',')}',
                            style: context.text.bodySmall?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.call_rounded,
                      tooltip: 'Appeler',
                      onTap: () => Launcher.call(context, courier.phone),
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.chat_bubble_rounded,
                      tooltip: 'Message',
                      backgroundColor: AppColors.primary,
                      iconColor: Colors.white,
                      onTap: () async {
                        try {
                          final chat = await ref
                              .read(myChatsProvider.notifier)
                              .chatWithCourier(order);
                          if (context.mounted) {
                            context.push(FrontRoutes.chat(chat.id));
                          }
                        } catch (error) {
                          if (context.mounted) {
                            AppSnackbar.error(context, error);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.3, end: 0),
            ],
            if (order.status == OrderStatus.delivered) ...[
              const SizedBox(height: AppSizes.md),
              PrimaryButton(
                label: 'Noter ma commande',
                icon: Icons.star_rounded,
                onPressed: () => context.go(FrontRoutes.writeReview(order.id)),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            TextButton(
              onPressed: () => context.push(FrontRoutes.order(order.id)),
              child: const Text('Détail de la commande'),
            ),
          ],
        ),
      ),
    );
  }
}
