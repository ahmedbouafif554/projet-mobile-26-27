import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../shared/models/models.dart';
import '../../router/back_routes.dart';
import '../../shell/bo_page.dart';
import 'order_flow.dart';
import 'orders_controller.dart';

/// Colonne du Kanban : statuts affichés et statut donné par un dépôt.
enum _Lane {
  incoming('Nouvelles', AppColors.info, Icons.notifications_active_rounded),
  cooking('En cuisine', AppColors.warning, Icons.soup_kitchen_rounded),
  ready('Prêtes', AppColors.success, Icons.room_service_rounded);

  const _Lane(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  bool contains(OrderStatus s) => switch (this) {
    incoming => s == OrderStatus.pending,
    cooking => s == OrderStatus.accepted || s == OrderStatus.preparing,
    ready => s == OrderStatus.ready,
  };

  /// Statut d'une commande déposée dans la colonne.
  OrderStatus get dropStatus => switch (this) {
    incoming => OrderStatus.pending,
    cooking => OrderStatus.accepted,
    ready => OrderStatus.ready,
  };

  /// On ne peut avancer que vers la droite.
  bool accepts(Order order) =>
      !contains(order.status) && dropStatus.index > order.status.index;
}

/// Cuisine (restaurateur) : Kanban des commandes du jour. Glissez une carte
/// vers la droite ou utilisez ses boutons pour faire avancer la commande.
class KitchenPage extends ConsumerWidget {
  const KitchenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersControllerProvider);
    return BoPage(
      title: 'Cuisine',
      subtitle: 'Glissez les commandes de gauche à droite au fil du service.',
      scrollable: false,
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(ordersControllerProvider),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Actualiser'),
        ),
      ],
      children: [
        Expanded(
          child: AsyncValueView(
            value: orders,
            onRetry: () => ref.invalidate(ordersControllerProvider),
            loading: const ShimmerScope(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SkeletonBox(radius: AppSizes.radiusLg)),
                  SizedBox(width: AppSizes.md),
                  Expanded(child: SkeletonBox(radius: AppSizes.radiusLg)),
                  SizedBox(width: AppSizes.md),
                  Expanded(child: SkeletonBox(radius: AppSizes.radiusLg)),
                ],
              ),
            ),
            data: (list) => LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final lanes = [
                  for (final lane in _Lane.values)
                    _LaneColumn(
                      lane: lane,
                      orders: list
                          .where((o) => lane.contains(o.status))
                          .toList()
                        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
                    ),
                ];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, lane) in lanes.indexed) ...[
                        if (i > 0) const SizedBox(width: AppSizes.md),
                        Expanded(child: lane),
                      ],
                    ],
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: lanes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSizes.md),
                  itemBuilder: (_, i) => SizedBox(
                    width: (constraints.maxWidth * 0.86).clamp(260, 340),
                    child: lanes[i],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LaneColumn extends ConsumerWidget {
  const _LaneColumn({required this.lane, required this.orders});

  final _Lane lane;
  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<Order>(
      onWillAcceptWithDetails: (details) => lane.accepts(details.data),
      onAcceptWithDetails: (details) =>
          advanceOrder(context, ref, details.data, to: lane.dropStatus),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(
            color: hovering
                ? lane.color.withValues(alpha: 0.12)
                : context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: hovering ? lane.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(lane.icon, color: lane.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(lane.label, style: context.text.titleMedium),
                    ),
                    AnimatedSwitcher(
                      duration: AppDurations.fast,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Container(
                        key: ValueKey(orders.length),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: lane.color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${orders.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hovering
                                    ? Icons.move_down_rounded
                                    : Icons.inbox_outlined,
                                size: 40,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hovering
                                    ? 'Déposez ici'
                                    : 'Aucune commande',
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: orders.length,
                        itemBuilder: (context, i) => _DraggableTicket(
                          key: ValueKey(orders[i].id),
                          order: orders[i],
                          lane: lane,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableTicket extends StatelessWidget {
  const _DraggableTicket({super.key, required this.order, required this.lane});

  final Order order;
  final _Lane lane;

  @override
  Widget build(BuildContext context) {
    final ticket = _Ticket(order: order, lane: lane);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Draggable<Order>(
        data: order,
        maxSimultaneousDrags: lane == _Lane.ready ? 0 : 1,
        feedback: SizedBox(
          width: 300,
          child: Transform.rotate(
            angle: 0.03,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: _Ticket(order: order, lane: lane, compact: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: ticket),
        child: MouseRegion(
          cursor: lane == _Lane.ready
              ? SystemMouseCursors.basic
              : SystemMouseCursors.grab,
          child: ticket,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15, end: 0);
  }
}

/// Ticket de cuisine : numéro, temps écoulé, articles et action suivante.
class _Ticket extends ConsumerWidget {
  const _Ticket({
    required this.order,
    required this.lane,
    this.compact = false,
  });

  final Order order;
  final _Lane lane;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = nextOrderStatus(order.status, UserRole.restaurant);
    final muted = context.text.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: compact ? null : () => context.go(BackRoutes.order(order.id)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border(left: BorderSide(color: lane.color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('#${order.reference}', style: context.text.titleMedium),
                  const SizedBox(width: 8),
                  if (order.status == OrderStatus.preparing)
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  const Spacer(),
                  _Elapsed(since: order.createdAt),
                ],
              ),
              Text(order.customerName, style: muted),
              const SizedBox(height: 10),
              for (final item in order.items.take(compact ? 2 : 6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${item.quantity}× ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: item.product.name),
                        if (item.options.isNotEmpty)
                          TextSpan(text: ' (${item.optionsLabel})', style: muted),
                      ],
                    ),
                    style: context.text.bodyMedium,
                  ),
                ),
              if (order.note != null && !compact) ...[
                const SizedBox(height: 6),
                Text(
                  '📝 ${order.note}',
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!compact) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      Formatters.price(order.total),
                      style: context.text.titleSmall,
                    ),
                    const Spacer(),
                    if (lane == _Lane.incoming)
                      IconButton(
                        tooltip: 'Refuser',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => cancelOrder(context, ref, order),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    if (next != null)
                      FilledButton.icon(
                        onPressed: () => advanceOrder(context, ref, order),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: lane.color,
                        ),
                        icon: Icon(nextStatusIcon(next), size: 18),
                        label: Text(switch (next) {
                          OrderStatus.accepted => 'Accepter',
                          OrderStatus.preparing => 'Démarrer',
                          _ => 'Prête',
                        }),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delivery_dining_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text('Attente livreur', style: muted),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Temps écoulé depuis la commande, rafraîchi toutes les 30 secondes
/// (orange après 15 min, rouge après 30 min).
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since});

  final DateTime since;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(widget.since).inMinutes;
    final color = minutes >= 30
        ? AppColors.error
        : minutes >= 15
        ? AppColors.warning
        : context.palette.textSecondary;
    final label = minutes < 60
        ? '$minutes min'
        : minutes < 24 * 60
        ? '${minutes ~/ 60} h ${minutes % 60}'
        : Formatters.dayMonth(widget.since);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
