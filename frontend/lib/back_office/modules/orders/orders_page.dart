import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
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
import 'order_flow.dart';
import 'order_form.dart';
import 'orders_controller.dart';

/// Regroupement des statuts pour les pastilles de synthèse.
enum _OrderGroup {
  all('Toutes', AppColors.primary),
  fresh('Nouvelles', AppColors.info),
  active('En cours', AppColors.warning),
  delivered('Livrées', AppColors.success),
  closed('Annulées', AppColors.error);

  const _OrderGroup(this.label, this.color);
  final String label;
  final Color color;

  bool test(Order o) => switch (this) {
    all => true,
    fresh => o.status == OrderStatus.pending,
    active => o.status.isActive && o.status != OrderStatus.pending,
    delivered => o.status == OrderStatus.delivered,
    closed =>
      o.status == OrderStatus.cancelled || o.status == OrderStatus.refunded,
  };
}

/// Module 3 : toutes les commandes (admin) ou les commandes reçues
/// (restaurateur). Création manuelle, changement de statut, annulation,
/// remboursement.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  _OrderGroup _group = _OrderGroup.all;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authServiceProvider).role;
    final isAdmin = role == UserRole.admin;
    final orders = ref.watch(ordersControllerProvider);
    final all = orders.value ?? const <Order>[];
    final visible = _group == _OrderGroup.all
        ? orders.value
        : all.where(_group.test).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return BoPage(
      title: isAdmin ? 'Commandes' : 'Commandes reçues',
      subtitle: isAdmin
          ? 'Suivi de toutes les commandes de la plateforme.'
          : 'Acceptez, préparez et suivez vos commandes.',
      onAdd: () => openOrderForm(context),
      addLabel: 'Commande manuelle',
      addIcon: Icons.add_call,
      actions: [
        if (!isAdmin)
          OutlinedButton.icon(
            onPressed: () => context.go(BackRoutes.kitchen),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.view_kanban_rounded),
            label: const Text('Vue cuisine'),
          ),
      ],
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final g in _OrderGroup.values)
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
        AppDataTable<Order>(
          items: visible,
          isLoading: orders.isLoading,
          error: orders.error,
          onRetry: () => ref.invalidate(ordersControllerProvider),
          searchHint: 'Numéro, client, restaurant…',
          searchText: (o) =>
              '${o.reference} ${o.customerName} ${o.restaurantName}',
          initialSortColumn: 0,
          initialSortAscending: false,
          filters: [
            AppTableFilter(
              label: 'Période',
              icon: Icons.date_range_rounded,
              options: const {
                'today': "Aujourd'hui",
                '7': '7 derniers jours',
                '30': '30 derniers jours',
              },
              test: (o, v) => v == 'today'
                  ? !o.createdAt.isBefore(today)
                  : o.createdAt.isAfter(
                      today.subtract(Duration(days: int.parse(v))),
                    ),
            ),
            AppTableFilter(
              label: 'Paiement',
              icon: Icons.payments_outlined,
              options: {for (final m in PaymentMethod.values) m.name: m.label},
              test: (o, v) => o.paymentMethod.name == v,
            ),
          ],
          columns: [
            AppTableColumn(
              label: 'Commande',
              primary: true,
              flex: 3,
              sortValue: (o) => o.createdAt,
              cell: (context, o) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${o.reference}', style: context.text.titleSmall),
                  Text(
                    Formatters.dateTime(o.createdAt),
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Client',
              flex: 3,
              sortValue: (o) => o.customerName,
              cell: (context, o) => Row(
                children: [
                  Avatar(name: o.customerName, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      o.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              AppTableColumn(
                label: 'Restaurant',
                flex: 3,
                sortValue: (o) => o.restaurantName,
                cell: (context, o) =>
                    Text(o.restaurantName, style: context.text.bodySmall),
              ),
            AppTableColumn(
              label: 'Articles',
              sortValue: (o) => o.itemCount,
              cell: (context, o) => Tooltip(
                message: o.summary,
                child: Text(
                  '${o.itemCount} article${o.itemCount > 1 ? 's' : ''}',
                  style: context.text.bodySmall,
                ),
              ),
            ),
            AppTableColumn(
              label: 'Total',
              numeric: true,
              sortValue: (o) => o.total,
              cell: (context, o) => Text(
                Formatters.price(o.total),
                style: context.text.titleSmall,
              ),
            ),
            AppTableColumn(
              label: 'Statut',
              flex: 2,
              sortValue: (o) => o.status.index,
              cell: (_, o) => orderStatusChip(o.status),
            ),
          ],
          onView: (o) => context.go(BackRoutes.order(o.id)),
          onDelete: isAdmin
              ? (o) => ref.read(ordersControllerProvider.notifier).remove(o.id)
              : null,
          deleteMessage: (o) =>
              'La commande #${o.reference} sera supprimée de l’historique.',
          actions: [
            for (final status in [
              OrderStatus.accepted,
              OrderStatus.preparing,
              OrderStatus.ready,
              OrderStatus.delivering,
              OrderStatus.delivered,
            ])
              AppTableAction(
                label: nextStatusAction(status),
                icon: nextStatusIcon(status),
                isVisible: (o) => nextOrderStatus(o.status, role) == status,
                onSelected: (o) => advanceOrder(context, ref, o, to: status),
              ),
            AppTableAction(
              label: 'Annuler',
              icon: Icons.cancel_outlined,
              isDestructive: true,
              isVisible: canCancel,
              onSelected: (o) => cancelOrder(context, ref, o),
            ),
            AppTableAction(
              label: 'Rembourser',
              icon: Icons.currency_exchange_rounded,
              isDestructive: true,
              isVisible: (o) => canRefund(o, role),
              onSelected: (o) => refundOrder(context, ref, o),
            ),
          ],
        ),
      ],
    );
  }
}
