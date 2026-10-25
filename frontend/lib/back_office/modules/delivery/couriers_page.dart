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
import 'courier_form.dart';
import 'delivery_actions.dart';
import 'delivery_controllers.dart';

/// Filtres rapides des livreurs.
enum _CourierGroup {
  all('Tous', AppColors.primary),
  available('Disponibles', AppColors.success),
  busy('En livraison', AppColors.warning),
  offline('Hors ligne', AppColors.secondary),
  documents('À vérifier', AppColors.error);

  const _CourierGroup(this.label, this.color);
  final String label;
  final Color color;

  bool test(Courier c) => switch (this) {
    all => true,
    available => c.status == CourierStatus.available,
    busy => c.status == CourierStatus.busy,
    offline => c.status == CourierStatus.offline,
    documents => c.documentStatus == DocumentStatus.pending,
  };
}

/// Module 4 (admin) : livreurs, justificatifs et statut en ligne.
class CouriersPage extends ConsumerStatefulWidget {
  const CouriersPage({super.key});

  @override
  ConsumerState<CouriersPage> createState() => _CouriersPageState();
}

class _CouriersPageState extends ConsumerState<CouriersPage> {
  _CourierGroup _group = _CourierGroup.all;

  @override
  Widget build(BuildContext context) {
    final couriers = ref.watch(couriersControllerProvider);
    final all = couriers.value ?? const <Courier>[];
    final visible = _group == _CourierGroup.all
        ? couriers.value
        : all.where(_group.test).toList();

    return BoPage(
      title: 'Livreurs',
      subtitle: 'Partenaires de livraison, justificatifs et disponibilité.',
      onAdd: () => openCourierForm(context),
      addLabel: 'Nouveau livreur',
      addIcon: Icons.person_add_alt_1_rounded,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.go(BackRoutes.map),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.map_rounded),
          label: const Text('Voir la carte'),
        ),
      ],
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final g in _CourierGroup.values)
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
        AppDataTable<Courier>(
          items: visible,
          isLoading: couriers.isLoading,
          error: couriers.error,
          onRetry: () => ref.invalidate(couriersControllerProvider),
          searchHint: 'Nom, téléphone, zone…',
          searchText: (c) => '${c.fullName} ${c.phone} ${c.zone}',
          filters: [
            AppTableFilter(
              label: 'Véhicule',
              icon: Icons.two_wheeler_rounded,
              options: {for (final v in VehicleType.values) v.name: v.label},
              test: (c, v) => c.vehicle.name == v,
            ),
          ],
          columns: [
            AppTableColumn(
              label: 'Livreur',
              primary: true,
              flex: 4,
              sortValue: (c) => c.fullName,
              cell: (context, c) => Row(
                children: [
                  Avatar(name: c.fullName, imageUrl: c.avatarUrl, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          c.phone,
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Véhicule',
              flex: 3,
              sortValue: (c) => c.vehicle.index,
              cell: (context, c) => Row(
                children: [
                  Icon(
                    vehicleIcon(c.vehicle),
                    size: 18,
                    color: context.palette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.plateNumber == null
                          ? c.vehicle.label
                          : '${c.vehicle.label} • ${c.plateNumber}',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Note',
              sortValue: (c) => c.rating,
              cell: (context, c) => Text(
                '★ ${Formatters.rating(c.rating)} • ${c.completedDeliveries}',
                style: context.text.bodySmall,
              ),
            ),
            AppTableColumn(
              label: 'Gains',
              numeric: true,
              sortValue: (c) => c.totalEarnings,
              cell: (context, c) => Text(
                Formatters.priceShort(c.totalEarnings),
                style: context.text.titleSmall,
              ),
            ),
            AppTableColumn(
              label: 'Statut',
              sortValue: (c) => c.status.index,
              cell: (_, c) => courierStatusChip(c.status),
            ),
            AppTableColumn(
              label: 'Justificatifs',
              sortValue: (c) => c.documentStatus.index,
              cell: (_, c) => documentStatusChip(c.documentStatus),
            ),
          ],
          onView: (c) => context.go(BackRoutes.courier(c.id)),
          onEdit: (c) => openCourierForm(context, courier: c),
          onDelete: (c) =>
              ref.read(couriersControllerProvider.notifier).remove(c.id),
          deleteMessage: (c) =>
              '${c.fullName} ne pourra plus recevoir de courses.',
          actions: [
            AppTableAction(
              label: 'Valider les justificatifs',
              icon: Icons.verified_user_outlined,
              isVisible: (c) => c.documentStatus != DocumentStatus.approved,
              onSelected: (c) => reviewCourierDocuments(
                context,
                ref,
                c,
                DocumentStatus.approved,
              ),
            ),
            AppTableAction(
              label: 'Refuser les justificatifs',
              icon: Icons.gpp_bad_outlined,
              isDestructive: true,
              isVisible: (c) => c.documentStatus == DocumentStatus.pending,
              onSelected: (c) => reviewCourierDocuments(
                context,
                ref,
                c,
                DocumentStatus.rejected,
              ),
            ),
            AppTableAction(
              label: 'Mettre hors ligne',
              icon: Icons.power_settings_new_rounded,
              isVisible: (c) => c.status == CourierStatus.available,
              onSelected: (c) =>
                  setCourierStatus(context, ref, c, CourierStatus.offline),
            ),
          ],
        ),
      ],
    );
  }
}
