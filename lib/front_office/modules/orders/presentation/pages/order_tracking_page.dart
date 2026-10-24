import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/avatar.dart';
import '../../../../../core/widgets/circle_icon_button.dart';
import '../../../../../core/widgets/city_map.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/mock/mock_users.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/repositories/repository_providers.dart';
import '../../../../router/front_routes.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/orders_providers.dart';

/// Suivi en temps réel : plan animé (restaurant → domicile), étape en
/// cours, heure d'arrivée et livreur. La commande avance toute seule (démo).
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

class _TrackingViewState extends ConsumerState<_TrackingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  /// Simulation : la commande avance d'une étape toutes les 6 secondes tant
  /// que la page est ouverte.
  Timer? _progression;

  @override
  void initState() {
    super.initState();
    _progression = Timer.periodic(const Duration(seconds: 6), (_) => _step());
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

  // Positions relatives du restaurant et du domicile sur le plan.
  static const _restaurant = Offset(0.24, 0.32);
  static const _home = Offset(0.74, 0.68);

  @override
  void dispose() {
    _progression?.cancel();
    _motion.dispose();
    super.dispose();
  }

  /// Avancement du livreur sur le trajet (0 = restaurant, 1 = domicile).
  double _progress(double t) => switch (widget.order.status) {
    OrderStatus.delivering => 0.15 + 0.75 * t,
    OrderStatus.delivered => 1,
    _ => 0,
  };

  Offset _along(double p) {
    // Trajet en L arrondi : vers l'est puis vers le sud.
    final corner = Offset(_home.dx, _restaurant.dy);
    if (p < 0.5) return Offset.lerp(_restaurant, corner, p * 2)!;
    return Offset.lerp(corner, _home, (p - 0.5) * 2)!;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final delivering = o.status == OrderStatus.delivering;
    final delivered = o.status == OrderStatus.delivered;
    final minutesLeft = switch (o.status) {
      OrderStatus.pending || OrderStatus.accepted => 30,
      OrderStatus.preparing => 22,
      OrderStatus.ready => 15,
      OrderStatus.delivering => 8,
      _ => 0,
    };

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              // Le panneau du bas recouvre le plan : les repères restent
              // dans la partie visible.
              final mapHeight = size.height;
              final visible = size.height * 0.6;
              Offset px(Offset rel) =>
                  Offset(rel.dx * size.width, rel.dy * visible);
              return AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final courier = px(_along(_progress(_motion.value)));
                  return Stack(
                    children: [
                      SizedBox(
                        height: mapHeight,
                        width: size.width,
                        child: CustomPaint(
                          painter: CityMapPainter(
                            dark: context.isDark,
                            routes: [
                              (px(_restaurant), px(Offset(_home.dx, _restaurant.dy))),
                              (px(Offset(_home.dx, _restaurant.dy)), px(_home)),
                            ],
                            dash: _motion.value,
                          ),
                        ),
                      ),
                      _marker(
                        px(_restaurant),
                        Icons.storefront_rounded,
                        AppColors.primary,
                      ),
                      _marker(px(_home), Icons.home_rounded, AppColors.success),
                      if (delivering || delivered)
                        Positioned(
                          left: courier.dx - 24,
                          top: courier.dy - 24,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 2 + 3 * math.sin(_motion.value * 2 * math.pi).abs(),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
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
          child: _BottomPanel(
            order: o,
            minutesLeft: minutesLeft,
          ),
        ),
      ],
    );
  }

  Widget _marker(Offset at, IconData icon, Color color) => Positioned(
    left: at.dx - 20,
    top: at.dy - 20,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

class _BottomPanel extends ConsumerWidget {
  const _BottomPanel({required this.order, required this.minutesLeft});

  final Order order;
  final int minutesLeft;

  static const _labels = {
    OrderStatus.pending: ('Commande envoyée', 'Le restaurant va confirmer votre commande.'),
    OrderStatus.accepted: ('Commande acceptée', 'Le restaurant s’apprête à cuisiner.'),
    OrderStatus.preparing: ('En préparation 👨‍🍳', 'Votre repas est en cuisine.'),
    OrderStatus.ready: ('Commande prête', 'Un livreur arrive au restaurant.'),
    OrderStatus.delivering: ('En route 🛵', 'Votre livreur arrive bientôt.'),
    OrderStatus.delivered: ('Livrée ✅', 'Bon appétit !'),
    OrderStatus.cancelled: ('Commande annulée', 'Vous ne serez pas débité.'),
    OrderStatus.refunded: ('Commande remboursée', 'Le remboursement est en cours.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, subtitle) = _labels[order.status]!;
    final step = order.status.index.clamp(0, OrderStatus.delivered.index);
    final courier = MockUsers.byId('u-courier-1');
    final showCourier =
        order.status == OrderStatus.delivering ||
        order.status == OrderStatus.ready;

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
                    Avatar(
                      name: courier.fullName,
                      imageUrl: courier.avatarUrl,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(courier.firstName, style: context.text.titleSmall),
                          Text(
                            'Scooter • ★ 4,9',
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
                      onTap: () => AppSnackbar.info(
                        context,
                        'Appel de ${courier.firstName} (démo).',
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.chat_bubble_rounded,
                      tooltip: 'Message',
                      backgroundColor: AppColors.primary,
                      iconColor: Colors.white,
                      onTap: () async {
                        final chats = await ref.read(myChatsProvider.future);
                        final chat = chats
                            .where((c) => c.type == ChatType.courier)
                            .firstOrNull;
                        if (!context.mounted) return;
                        chat == null
                            ? AppSnackbar.info(context, 'Messagerie bientôt disponible.')
                            : context.push(FrontRoutes.chat(chat.id));
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
