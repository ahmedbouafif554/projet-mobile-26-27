import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../../shared/widgets/status_chips.dart';
import '../../../../router/front_routes.dart';
import '../../../communication/providers/communication_providers.dart';
import '../../providers/cart_controller.dart';
import '../../providers/orders_providers.dart';
import '../widgets/order_widgets.dart';
import 'orders_page.dart';

/// Détail d'une commande du client : étapes, articles, montants, adresse,
/// paiement et actions (suivre, annuler, contacter, noter, recommander).
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Order order) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Annuler la commande ?',
      message: 'Le restaurant n’a pas encore commencé : vous serez remboursé.',
      confirmLabel: 'Annuler la commande',
      icon: Icons.cancel_outlined,
    );
    if (!confirmed) return;
    try {
      await ref.read(myOrdersProvider.notifier).cancel(order);
      if (context.mounted) AppSnackbar.success(context, 'Commande annulée');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  Future<void> _contact(BuildContext context, WidgetRef ref, Order order) async {
    try {
      final chat = await ref.read(myChatsProvider.notifier).chatForOrder(order);
      if (context.mounted) context.push(FrontRoutes.chat(chat.id));
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView(
          value: order,
          onRetry: () => ref.invalidate(orderProvider(orderId)),
          loading: const ShimmerScope(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.pagePadding),
              child: SkeletonBox(height: 400, radius: AppSizes.radiusLg),
            ),
          ),
          data: (o) {
            final reviewed =
                ref
                    .watch(myReviewsProvider)
                    .value
                    ?.any((r) => r.orderId == o.id) ??
                false;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xl,
              ),
              children:
                  [
                        const PageTitle('Ma commande'),
                        const SizedBox(height: AppSizes.md),
                        SurfaceCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.restaurantName,
                                      style: context.text.titleMedium,
                                    ),
                                    Text(
                                      '#${o.reference} • ${Formatters.dateTime(o.createdAt)}',
                                      style: context.text.bodySmall?.copyWith(
                                        color: context.palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              orderStatusChip(o.status),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        if (o.status.isActive)
                          PrimaryButton(
                            label: 'Suivre en temps réel',
                            icon: Icons.map_rounded,
                            onPressed: () =>
                                context.push(FrontRoutes.orderTracking(o.id)),
                          ),
                        if (o.status == OrderStatus.cancelled &&
                            o.cancelReason != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                            ),
                            child: Text('Motif : ${o.cancelReason}'),
                          ),
                        const SizedBox(height: AppSizes.lg),
                        TitledBlock(
                          title: 'Suivi',
                          child: SurfaceCard(child: OrderTimeline(order: o)),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        TitledBlock(
                          title: 'Articles',
                          child: SurfaceCard(
                            child: Column(
                              children: [
                                for (final item in o.items)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AppNetworkImage(
                                            item.product.imageUrl,
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item.quantity} × ${item.product.name}',
                                                style: context.text.titleSmall,
                                              ),
                                              if (item.options.isNotEmpty)
                                                Text(
                                                  item.optionsLabel,
                                                  style: context.text.bodySmall
                                                      ?.copyWith(
                                                        color: context
                                                            .palette
                                                            .textSecondary,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          Formatters.price(item.totalPrice),
                                          style: context.text.titleSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        TotalsCard(
                          totals: CartTotals(
                            subtotal: o.subtotal,
                            deliveryFee: o.deliveryFee,
                            serviceFee: o.serviceFee,
                            discount: o.discount,
                          ),
                          promoCode: o.promoCode,
                        ),
                        const SizedBox(height: AppSizes.lg),
                        TitledBlock(
                          title: 'Livraison et paiement',
                          child: SurfaceCard(
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(o.deliveryAddress.label),
                                  subtitle: Text(o.deliveryAddress.fullAddress),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.credit_card_rounded,
                                    color: AppColors.primary,
                                  ),
                                  title: Text(o.paymentMethod.label),
                                  subtitle: Text(o.paymentStatus.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        Wrap(
                          spacing: AppSizes.sm,
                          runSpacing: AppSizes.sm,
                          alignment: WrapAlignment.center,
                          children: [
                            _Action(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Contacter le restaurant',
                              onTap: () => _contact(context, ref, o),
                            ),
                            if (o.status == OrderStatus.delivered && !reviewed)
                              _Action(
                                icon: Icons.star_outline_rounded,
                                label: 'Laisser un avis',
                                onTap: () =>
                                    context.push(FrontRoutes.writeReview(o.id)),
                              ),
                            if (!o.status.isActive)
                              _Action(
                                icon: Icons.replay_rounded,
                                label: 'Recommander',
                                onTap: () => reorder(context, ref, o),
                              ),
                            if (o.status == OrderStatus.pending)
                              _Action(
                                icon: Icons.cancel_outlined,
                                label: 'Annuler',
                                destructive: true,
                                onTap: () => _cancel(context, ref, o),
                              ),
                          ],
                        ),
                      ]
                      .animate(interval: 40.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05, end: 0),
            );
          },
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: destructive ? AppColors.error : null,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Étapes de la commande (frise verticale animée).
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final Order order;

  static const _steps = [
    (OrderStatus.pending, 'Commande envoyée', Icons.receipt_rounded),
    (OrderStatus.accepted, 'Acceptée par le restaurant', Icons.thumb_up_alt_rounded),
    (OrderStatus.preparing, 'En préparation', Icons.soup_kitchen_rounded),
    (OrderStatus.ready, 'Prête, en attente du livreur', Icons.room_service_rounded),
    (OrderStatus.delivering, 'En route vers vous', Icons.delivery_dining_rounded),
    (OrderStatus.delivered, 'Livrée, bon appétit !', Icons.task_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final cancelled =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.refunded;
    final current = order.status.index;
    DateTime? timeOf(OrderStatus s) =>
        order.history.where((e) => e.status == s).firstOrNull?.at;

    return Column(
      children: [
        for (final (i, (status, label, icon)) in _steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: AppDurations.medium,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: !cancelled && status.index <= current
                            ? AppColors.primary
                            : context.palette.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        !cancelled && status.index < current
                            ? Icons.check_rounded
                            : icon,
                        size: 17,
                        color: !cancelled && status.index <= current
                            ? Colors.white
                            : context.palette.textSecondary,
                      ),
                    ),
                    if (i < _steps.length - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: AppDurations.medium,
                          width: 2,
                          color: !cancelled && status.index < current
                              ? AppColors.primary
                              : context.palette.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: context.text.bodyMedium?.copyWith(
                              fontWeight: status.index == current && !cancelled
                                  ? FontWeight.w700
                                  : null,
                              color: !cancelled && status.index <= current
                                  ? null
                                  : context.palette.textSecondary,
                            ),
                          ),
                        ),
                        if (timeOf(status) != null)
                          Text(
                            Formatters.time(timeOf(status)!),
                            style: context.text.labelSmall?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (cancelled)
          Text(
            order.status == OrderStatus.refunded
                ? 'Commande remboursée'
                : 'Commande annulée',
            style: context.text.titleSmall?.copyWith(color: AppColors.error),
          ),
      ],
    );
  }
}
