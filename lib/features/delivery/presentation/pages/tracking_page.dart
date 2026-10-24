import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../communication/communication_routes.dart';
import '../../../orders/models/order.dart';
import '../../../orders/presentation/controllers/cart_controller.dart';
import '../../../orders/presentation/controllers/orders_controller.dart';
import '../../../orders/presentation/widgets/order_status_chip.dart';
import '../../data/delivery_mock_data.dart';
import '../widgets/courier_card.dart';
import '../widgets/fake_map.dart';
import '../widgets/tracking_timeline.dart';

/// Suivi de commande en temps réel (simulé) :
/// les étapes avancent automatiquement et le livreur se déplace sur la carte.
class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with TickerProviderStateMixin {
  /// Durée du trajet du livreur dans la simulation.
  static const _rideDuration = Duration(seconds: 14);

  /// Durée des étapes « confirmée » et « en préparation ».
  static const _stepDuration = Duration(seconds: 6);

  late final Order? _order = OrdersController.instance.byId(widget.orderId);
  late OrderStatus _status = _order?.status ?? OrderStatus.delivered;

  late final AnimationController _ride = AnimationController(
    vsync: this,
    duration: _rideDuration,
    value: switch (_status) {
      OrderStatus.delivered => 1.0,
      OrderStatus.onTheWay => 0.1,
      _ => 0.0,
    },
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_order != null && _status.isActive) _scheduleNextStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ride.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _scheduleNextStep() {
    if (_status == OrderStatus.onTheWay) {
      // Le livreur roule : l'étape suivante arrive à la fin du trajet.
      _ride.forward().whenCompleteOrCancel(() {
        if (mounted && _status == OrderStatus.onTheWay) _advance();
      });
    } else {
      _timer = Timer(_stepDuration, _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final next = _status.next;
    setState(() => _status = next);
    OrdersController.instance.updateStatus(widget.orderId, next);
    HapticFeedback.lightImpact();

    if (next == OrderStatus.delivered) {
      _ride.value = 1;
      final order = _order;
      final router = GoRouter.of(context);
      AppSnackbar.success(
        context,
        'Commande livrée. Bon appétit ! 🎉',
        actionLabel: order?.restaurantId == null ? null : 'Noter',
        onAction: () => router.push(
          CommunicationRoutes.writeReview(
            restaurantId: order!.restaurantId!,
            orderId: order.id,
          ),
        ),
      );
    } else {
      _scheduleNextStep();
    }
  }

  /// Minutes restantes estimées selon l'étape et la position du livreur.
  int get _minutesLeft => switch (_status) {
    OrderStatus.confirmed => _order!.etaMinutes,
    OrderStatus.preparing => (_order!.etaMinutes * 0.7).round(),
    OrderStatus.onTheWay => (1 + (1 - _ride.value) * 12).round(),
    _ => 0,
  };

  void _showDetails(BuildContext context) {
    final order = _order!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            0,
            AppSizes.pagePadding,
            AppSizes.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande ${order.displayNumber}',
                style: context.text.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.dateTime(order.createdAt),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSizes.md),
              if (order.items.isEmpty)
                Text(order.summary, style: context.text.bodyMedium)
              else
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${item.quantity}×  ',
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(child: Text(item.product.name)),
                        Text(
                          Formatters.price(item.totalPrice),
                          style: context.text.labelLarge,
                        ),
                      ],
                    ),
                  ),
              const Divider(height: 28),
              _DetailRow(icon: Icons.place_outlined, label: order.address),
              _DetailRow(
                icon: Icons.credit_card_rounded,
                label: order.paymentLabel,
              ),
              _DetailRow(
                icon: Icons.receipt_long_rounded,
                label: 'Total payé : ${Formatters.price(order.total)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: 68,
          leading: const Center(
            child: AppBackButton(fallbackRoute: AppRoutes.orders),
          ),
        ),
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Commande introuvable',
          message: 'Cette commande n\'existe pas ou a été supprimée.',
          actionLabel: 'Mes commandes',
          onAction: () => context.go(AppRoutes.orders),
        ),
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FakeMap(
              progress: _ride,
              pulse: _pulse,
              originIcon: order.type == OrderType.parcel
                  ? Icons.inventory_2_rounded
                  : Icons.storefront_rounded,
            ),
          ),
          // Barre du haut
          Positioned(
            top: topPadding + AppSizes.sm,
            left: AppSizes.md,
            right: AppSizes.md,
            child: Row(
              children: [
                const AppBackButton(
                  elevated: true,
                  fallbackRoute: AppRoutes.orders,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    boxShadow: context.palette.softShadow,
                  ),
                  child: Text(
                    order.displayNumber,
                    style: context.text.titleSmall,
                  ),
                ),
                const Spacer(),
                CircleIconButton(
                  icon: Icons.receipt_long_rounded,
                  elevated: true,
                  tooltip: 'Détails de la commande',
                  onTap: () => _showDetails(context),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.5, end: 0),
          ),
          // Panneau d'informations déplaçable
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusXl + 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  12,
                  AppSizes.pagePadding,
                  AppSizes.xl,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _EtaHeader(
                    status: _status,
                    ride: _ride,
                    minutesLeft: () => _minutesLeft,
                  ),
                  const SizedBox(height: AppSizes.md),
                  _ProgressSegments(status: _status),
                  const SizedBox(height: AppSizes.lg),
                  if (_status == OrderStatus.cancelled)
                    const _CancelledBanner()
                  else ...[
                    CourierCard(courier: DeliveryMockData.courier),
                    const SizedBox(height: AppSizes.lg),
                    TrackingTimeline(status: _status),
                  ],
                  const SizedBox(height: AppSizes.lg),
                  _DetailRow(icon: Icons.place_outlined, label: order.address),
                  _DetailRow(
                    icon: Icons.shopping_bag_outlined,
                    label: order.summary,
                  ),
                  _DetailRow(
                    icon: Icons.receipt_long_rounded,
                    label:
                        'Total : ${Formatters.price(order.total)} • ${order.paymentLabel}',
                  ),
                  if (_status == OrderStatus.delivered &&
                      order.restaurantId != null) ...[
                    const SizedBox(height: AppSizes.lg),
                    PrimaryButton(
                      label: 'Noter la commande',
                      icon: Icons.star_rounded,
                      onPressed: () => context.push(
                        CommunicationRoutes.writeReview(
                          restaurantId: order.restaurantId!,
                          orderId: order.id,
                        ),
                      ),
                    ),
                  ],
                  if (!_status.isActive && order.type == OrderType.food) ...[
                    const SizedBox(height: AppSizes.md),
                    PrimaryButton(
                      label: 'Re-commander',
                      icon: Icons.replay_rounded,
                      onPressed: () {
                        OrdersController.instance.reorder(
                          order,
                          CartController.instance,
                        );
                        context.push(AppRoutes.cart);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre principal : temps restant ou commande livrée.
class _EtaHeader extends StatelessWidget {
  const _EtaHeader({
    required this.status,
    required this.ride,
    required this.minutesLeft,
  });

  final OrderStatus status;
  final Animation<double> ride;
  final int Function() minutesLeft;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ride,
      builder: (context, _) {
        final String title;
        final String subtitle;
        switch (status) {
          case OrderStatus.delivered:
            title = 'Commande livrée 🎉';
            subtitle = 'Merci d\'avoir commandé avec SuperFaster';
          case OrderStatus.cancelled:
            title = 'Commande annulée';
            subtitle = 'Vous avez été intégralement remboursé';
          default:
            final minutes = minutesLeft();
            title = 'Arrivée dans ~$minutes min';
            subtitle =
                'Prévue vers ${Formatters.time(DateTime.now().add(Duration(minutes: minutes)))}';
        }

        return Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.medium,
                child: Column(
                  key: ValueKey(title),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.headlineSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
            OrderStatusChip(status: status),
          ],
        );
      },
    );
  }
}

/// Barre de progression en 4 segments animés.
class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final reached = status == OrderStatus.cancelled
        ? -1
        : OrderStatus.values.indexOf(status);
    return Row(
      children: List.generate(4, (i) {
        final filled = i <= reached;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: AppDurations.slow,
              curve: Curves.easeOutCubic,
              widthFactor: filled ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: status == OrderStatus.delivered
                      ? AppColors.success
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cette commande a été annulée par le restaurant. Le montant a été remboursé.',
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
