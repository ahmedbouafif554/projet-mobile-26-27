import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/avatar.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'delivery_actions.dart';
import 'delivery_controllers.dart';

enum _DeliveryGroup {
  all('Toutes', AppColors.primary),
  waiting('À assigner', AppColors.warning),
  active('En cours', AppColors.info),
  delivered('Livrées', AppColors.success),
  cancelled('Annulées', AppColors.error);

  const _DeliveryGroup(this.label, this.color);
  final String label;
  final Color color;

  bool test(Delivery d) => switch (this) {
    all => true,
    waiting => d.status == DeliveryStatus.waiting,
    active => d.status.isActive,
    delivered => d.status == DeliveryStatus.delivered,
    cancelled => d.status == DeliveryStatus.cancelled,
  };
}

/// Module 4 (admin) : courses, assignation des livreurs et suivi.
class DeliveriesPage extends ConsumerStatefulWidget {
  const DeliveriesPage({super.key});

  @override
  ConsumerState<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends ConsumerState<DeliveriesPage> {
  _DeliveryGroup _group = _DeliveryGroup.all;

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveriesControllerProvider);
    final couriers = ref.watch(couriersControllerProvider).value ?? [];
    final all = deliveries.value ?? const <Delivery>[];
    final visible = _group == _DeliveryGroup.all
        ? deliveries.value
        : all.where(_group.test).toList();
    Courier? courierOf(Delivery d) =>
        couriers.where((c) => c.id == d.courierId).firstOrNull;

    return BoPage(
      title: 'Livraisons',
      subtitle: 'Assignez les courses et suivez-les jusqu’au client.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.go(BackRoutes.map),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.map_rounded),
          label: const Text('Carte en direct'),
        ),
      ],
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final g in _DeliveryGroup.values)
              SummaryPill(
                label: g.label,
                value: all.where(g.test).length,
                color: g.color,
                selected: _group == g,
                onTap: () => setState(() => _group = g),
              ),
          ],
        ),
        boGap,
        AppDataTable<Delivery>(
          items: visible,
          isLoading: deliveries.isLoading,
          error: deliveries.error,
          onRetry: () => ref.invalidate(deliveriesControllerProvider),
          searchHint: 'Commande, restaurant, client…',
          searchText: (d) =>
              '${d.orderReference} ${d.pickupName} ${d.customerName} ${courierOf(d)?.fullName ?? ''}',
          initialSortColumn: 0,
          initialSortAscending: false,
          columns: [
            AppTableColumn(
              label: 'Course',
              primary: true,
              flex: 3,
              sortValue: (d) => d.createdAt,
              cell: (context, d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${d.orderReference}', style: context.text.titleSmall),
                  Text(
                    Formatters.dateTime(d.createdAt),
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Trajet',
              flex: 5,
              cell: (context, d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stop(
                    icon: Icons.storefront_rounded,
                    color: AppColors.primary,
                    text: d.pickupName,
                  ),
                  _Stop(
                    icon: Icons.place_rounded,
                    color: AppColors.success,
                    text: '${d.customerName} • ${d.dropoffAddress}',
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Livreur',
              flex: 3,
              sortValue: (d) => courierOf(d)?.fullName ?? '',
              cell: (context, d) {
                final courier = courierOf(d);
                if (courier == null) {
                  return d.status == DeliveryStatus.waiting
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () => assignCourier(context, ref, d),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: AppColors.primary,
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_rounded,
                              size: 18,
                            ),
                            label: const Text('Assigner'),
                          ),
                        )
                      : Text('—', style: context.text.bodySmall);
                }
                return Row(
                  children: [
                    Avatar(
                      name: courier.fullName,
                      imageUrl: courier.avatarUrl,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        courier.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
            AppTableColumn(
              label: 'Distance',
              sortValue: (d) => d.distanceKm,
              cell: (context, d) => Text(
                '${Formatters.distance(d.distanceKm)}\n~${d.estimatedMinutes} min',
                style: context.text.bodySmall,
              ),
            ),
            AppTableColumn(
              label: 'Gain',
              numeric: true,
              sortValue: (d) => d.earnings,
              cell: (context, d) => Text(
                Formatters.price(d.earnings),
                style: context.text.titleSmall,
              ),
            ),
            AppTableColumn(
              label: 'Statut',
              flex: 2,
              sortValue: (d) => d.status.index,
              cell: (_, d) => deliveryStatusChip(d.status),
            ),
          ],
          onView: (d) => context.go(BackRoutes.order(d.orderId)),
          actions: [
            AppTableAction(
              label: 'Assigner un livreur',
              icon: Icons.person_add_alt_rounded,
              isVisible: (d) => d.status == DeliveryStatus.waiting,
              onSelected: (d) => assignCourier(context, ref, d),
            ),
            for (final step in [
              DeliveryStatus.pickedUp,
              DeliveryStatus.inTransit,
              DeliveryStatus.delivered,
            ])
              AppTableAction(
                label: deliveryStepAction(step),
                icon: switch (step) {
                  DeliveryStatus.pickedUp => Icons.shopping_bag_outlined,
                  DeliveryStatus.inTransit => Icons.route_rounded,
                  _ => Icons.task_alt_rounded,
                },
                isVisible: (d) => nextDeliveryStatus(d.status) == step,
                onSelected: (d) => updateDeliveryStatus(context, ref, d, step),
              ),
            AppTableAction(
              label: 'Annuler la course',
              icon: Icons.cancel_outlined,
              isDestructive: true,
              isVisible: (d) =>
                  d.status == DeliveryStatus.waiting || d.status.isActive,
              onSelected: (d) => updateDeliveryStatus(
                context,
                ref,
                d,
                DeliveryStatus.cancelled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
