import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import '../delivery/delivery_controllers.dart';
import 'order_flow.dart';
import 'orders_controller.dart';

/// Fiche d'une commande : progression, articles, client, paiement,
/// livraison et historique, avec les actions de statut.
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authServiceProvider).role;
    final orders = ref.watch(ordersControllerProvider);
    final parent = BreadcrumbItem(
      role == UserRole.admin ? 'Commandes' : 'Commandes reçues',
      onTap: () => context.go(BackRoutes.orders),
    );
    final order = orders.value?.where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      return BoPage(
        title: orders.isLoading ? 'Chargement…' : 'Commande introuvable',
        parent: parent,
        children: [
          if (orders.isLoading)
            const ShimmerScope(
              child: SkeletonBox(height: 260, radius: AppSizes.radiusLg),
            )
          else
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.receipt_long_rounded,
                title: 'Commande introuvable',
                message: 'Cette commande a peut-être été supprimée.',
                actionLabel: 'Retour aux commandes',
                onAction: () => context.go(BackRoutes.orders),
              ),
            ),
        ],
      );
    }

    final next = nextOrderStatus(order.status, role);
    return BoPage(
      title: 'Commande #${order.reference}',
      subtitle:
          '${Formatters.dateTime(order.createdAt)} • ${order.restaurantName}',
      parent: parent,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              AppSnackbar.info(context, 'Ticket envoyé à l’imprimante (démo).'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Imprimer'),
        ),
        if (canCancel(order))
          OutlinedButton.icon(
            onPressed: () => cancelOrder(context, ref, order),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.error,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler'),
          ),
        if (canRefund(order, role))
          OutlinedButton.icon(
            onPressed: () => refundOrder(context, ref, order),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.error,
            ),
            icon: const Icon(Icons.currency_exchange_rounded),
            label: const Text('Rembourser'),
          ),
        if (next != null)
          FilledButton.icon(
            onPressed: () => advanceOrder(context, ref, order),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: Icon(nextStatusIcon(next)),
            label: Text(nextStatusAction(next)),
          ),
      ],
      children: [
        _Progress(order: order),
        boGap,
        SplitRow(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ItemsCard(order: order),
              boGap,
              _HistoryCard(order: order),
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CustomerCard(order: order),
              boGap,
              _PaymentCard(order: order),
              if (role == UserRole.admin) ...[
                boGap,
                _DeliveryCard(order: order),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Barre de progression des étapes (ou bandeau d'annulation).
class _Progress extends StatelessWidget {
  const _Progress({required this.order});

  final Order order;

  static const _steps = [
    (OrderStatus.pending, Icons.receipt_rounded),
    (OrderStatus.accepted, Icons.check_rounded),
    (OrderStatus.preparing, Icons.soup_kitchen_rounded),
    (OrderStatus.ready, Icons.room_service_rounded),
    (OrderStatus.delivering, Icons.delivery_dining_rounded),
    (OrderStatus.delivered, Icons.task_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.refunded) {
      final cancelled = order.status == OrderStatus.cancelled;
      return Container(
        padding: const EdgeInsets.all(AppSizes.md + 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              cancelled
                  ? Icons.cancel_rounded
                  : Icons.currency_exchange_rounded,
              color: AppColors.error,
              size: 32,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cancelled ? 'Commande annulée' : 'Commande remboursée',
                    style: context.text.titleMedium,
                  ),
                  if (order.cancelReason != null)
                    Text(
                      'Motif : ${order.cancelReason}',
                      style: context.text.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().shakeX(hz: 3, amount: 3);
    }

    final current = order.status.index;
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabels = constraints.maxWidth > 560;
          return Row(
            children: [
              for (final (i, (status, icon)) in _steps.indexed) ...[
                if (i > 0)
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: status.index <= current ? 1 : 0,
                      ),
                      duration: AppDurations.slow,
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: t,
                          minHeight: 4,
                          backgroundColor: context.palette.border,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                _StepDot(
                  icon: icon,
                  label: showLabels ? status.label : null,
                  done: status.index < current,
                  active: status.index == current,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.icon,
    required this.done,
    required this.active,
    this.label,
  });

  final IconData icon;
  final String? label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reached = done || active;
    final dot = AnimatedContainer(
      duration: AppDurations.medium,
      width: active ? 44 : 36,
      height: active ? 44 : 36,
      decoration: BoxDecoration(
        color: reached ? AppColors.primary : context.palette.surfaceMuted,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: active ? 22 : 18,
        color: reached ? Colors.white : context.palette.textSecondary,
      ),
    );
    final animated = active
        ? dot
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.08, duration: 900.ms)
        : dot;
    if (label == null) return animated;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 48, child: Center(child: animated)),
          const SizedBox(height: 6),
          Text(
            label!,
            style: context.text.labelSmall?.copyWith(
              color: reached
                  ? context.colors.onSurface
                  : context.palette.textSecondary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    Widget line(String label, double value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? context.text.titleMedium : context.text.bodyMedium,
            ),
          ),
          Text(
            Formatters.price(value),
            style: bold ? context.text.titleMedium : context.text.bodyMedium,
          ),
        ],
      ),
    );

    return SectionCard(
      title: 'Articles',
      icon: Icons.shopping_bag_outlined,
      subtitle: '${order.itemCount} article${order.itemCount > 1 ? 's' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppNetworkImage(
                      item.product.imageUrl,
                      width: 52,
                      height: 52,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity} × ${item.product.name}',
                          style: context.text.titleSmall,
                        ),
                        if (item.options.isNotEmpty)
                          Text(item.optionsLabel, style: muted),
                        if (item.note != null)
                          Text('« ${item.note} »', style: muted),
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
          if (order.note != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(order.note!)),
                ],
              ),
            ),
          ],
          const Divider(height: 28),
          line('Sous-total', order.subtotal),
          line('Livraison', order.deliveryFee),
          line('Frais de service', order.serviceFee),
          if (order.discount > 0)
            line(
              'Réduction${order.promoCode == null ? '' : ' (${order.promoCode})'}',
              -order.discount,
            ),
          const SizedBox(height: 4),
          line('Total', order.total, bold: true),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final a = order.deliveryAddress;
    final registered = order.userId != 'guest';
    return SectionCard(
      title: 'Client',
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar(name: order.customerName, size: 44),
            title: Text(order.customerName),
            subtitle: Text(registered ? 'Client SuperFaster' : 'Commande téléphonique'),
          ),
          infoText(Icons.place_outlined, 'Adresse de livraison', a.fullAddress),
          if (a.instructions != null)
            infoText(Icons.info_outline_rounded, 'Instructions', a.instructions!),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Paiement',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          infoText(
            switch (order.paymentMethod) {
              PaymentMethod.card => Icons.credit_card_rounded,
              PaymentMethod.applePay => Icons.phone_iphone_rounded,
              PaymentMethod.cash => Icons.euro_rounded,
            },
            'Moyen de paiement',
            order.paymentMethod.label,
          ),
          InfoRow(
            icon: Icons.verified_outlined,
            label: 'Statut',
            value: Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                label: order.paymentStatus.label,
                tone: switch (order.paymentStatus) {
                  PaymentStatus.paid => StatusTone.success,
                  PaymentStatus.pending => StatusTone.warning,
                  PaymentStatus.refunded => StatusTone.neutral,
                },
              ),
            ),
          ),
          infoText(
            Icons.receipt_rounded,
            'Montant',
            Formatters.price(order.total),
          ),
        ],
      ),
    );
  }
}

/// Livraison (admin) : course liée et livreur assigné.
class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = (ref.watch(deliveriesControllerProvider).value ?? [])
        .where((d) => d.orderId == order.id)
        .firstOrNull;
    final courierId = delivery?.courierId ?? order.courierId;
    final courier = (ref.watch(couriersControllerProvider).value ?? [])
        .where((c) => c.id == courierId)
        .firstOrNull;
    final muted = context.text.bodyMedium?.copyWith(
      color: context.palette.textSecondary,
    );
    return SectionCard(
      title: 'Livraison',
      icon: Icons.delivery_dining_outlined,
      trailing: delivery == null
          ? null
          : deliveryStatusChip(delivery.status),
      child: delivery == null
          ? Text(
              'La course sera créée quand la commande sera prête.',
              style: muted,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (courier == null)
                  Text('Aucun livreur assigné pour le moment.', style: muted)
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(
                      name: courier.fullName,
                      imageUrl: courier.avatarUrl,
                      size: 44,
                    ),
                    title: Text(courier.fullName),
                    subtitle: Text(
                      '${courier.vehicle.label} • ${courier.phone}',
                    ),
                    onTap: () => context.go(BackRoutes.courier(courier.id)),
                  ),
                infoText(
                  Icons.route_outlined,
                  'Distance',
                  '${Formatters.distance(delivery.distanceKm)} • ~${delivery.estimatedMinutes} min',
                ),
                const SizedBox(height: AppSizes.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go(BackRoutes.deliveries),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Gérer la livraison'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Historique des statuts (frise verticale).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final events = order.history.reversed.toList();
    return SectionCard(
      title: 'Historique',
      icon: Icons.history_rounded,
      child: events.isEmpty
          ? Text(
              'Aucun événement.',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            )
          : Column(
              children: [
                for (final (i, e) in events.indexed)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? AppColors.primary
                                    : context.palette.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (i < events.length - 1)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: context.palette.border,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    orderStatusChip(e.status, dense: true),
                                    const Spacer(),
                                    Text(
                                      Formatters.dateTime(e.at),
                                      style: context.text.bodySmall?.copyWith(
                                        color: context.palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (e.note != null) ...[
                                  const SizedBox(height: 4),
                                  Text(e.note!, style: context.text.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
