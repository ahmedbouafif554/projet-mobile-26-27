import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../router/back_routes.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'catalog_controllers.dart';
import 'restaurant_form.dart';

/// Change le statut d'un restaurant (confirmation pour refuser / suspendre).
Future<void> changeRestaurantStatus(
  BuildContext context,
  WidgetRef ref,
  Restaurant restaurant,
  RestaurantStatus status,
) async {
  if (status == RestaurantStatus.rejected ||
      status == RestaurantStatus.suspended) {
    final reject = status == RestaurantStatus.rejected;
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: reject
          ? 'Refuser ${restaurant.name} ?'
          : 'Suspendre ${restaurant.name} ?',
      message: reject
          ? 'La demande sera refusée et le restaurateur ne pourra pas se connecter.'
          : 'Le restaurant disparaîtra de l’application jusqu’à sa réactivation.',
      confirmLabel: reject ? 'Refuser' : 'Suspendre',
      icon: reject ? Icons.block_rounded : Icons.pause_circle_outline_rounded,
    );
    if (!confirmed) return;
  }
  try {
    await ref
        .read(restaurantsControllerProvider.notifier)
        .setStatus(restaurant, status);
    if (!context.mounted) return;
    AppSnackbar.success(context, switch (status) {
      RestaurantStatus.approved => '${restaurant.name} est validé et visible',
      RestaurantStatus.rejected => 'Demande de ${restaurant.name} refusée',
      RestaurantStatus.suspended => '${restaurant.name} est suspendu',
      RestaurantStatus.pending => '${restaurant.name} repasse en attente',
    });
  } catch (error) {
    if (context.mounted) AppSnackbar.error(context, error);
  }
}

/// Module 2 (admin) : restaurants, validation des inscriptions, CRUD.
class RestaurantsPage extends ConsumerStatefulWidget {
  const RestaurantsPage({super.key});

  @override
  ConsumerState<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends ConsumerState<RestaurantsPage> {
  RestaurantStatus? _quick;

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsControllerProvider);
    final all = restaurants.value ?? const <Restaurant>[];
    final pending = all
        .where((r) => r.status == RestaurantStatus.pending)
        .toList();
    final visible = _quick == null
        ? restaurants.value
        : all.where((r) => r.status == _quick).toList();

    Widget pill(String label, RestaurantStatus? status, Color color) =>
        SummaryPill(
          label: label,
          value: status == null
              ? all.length
              : all.where((r) => r.status == status).length,
          color: color,
          selected: _quick == status,
          onTap: () => setState(() => _quick = status),
        );

    return BoPage(
      title: 'Restaurants',
      subtitle: 'Partenaires de la plateforme et demandes d’inscription.',
      onAdd: () => openRestaurantForm(context),
      addLabel: 'Nouveau restaurant',
      addIcon: Icons.add_business_rounded,
      children: [
        if (pending.isNotEmpty) ...[
          _PendingRequests(restaurants: pending),
          boGap,
        ],
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            pill('Tous', null, AppColors.primary),
            pill('Validés', RestaurantStatus.approved, AppColors.success),
            pill('En attente', RestaurantStatus.pending, AppColors.warning),
            pill('Suspendus', RestaurantStatus.suspended, AppColors.secondary),
            pill('Refusés', RestaurantStatus.rejected, AppColors.error),
          ],
        ),
        boGap,
        AppDataTable<Restaurant>(
          items: visible,
          isLoading: restaurants.isLoading,
          error: restaurants.error,
          onRetry: () => ref.invalidate(restaurantsControllerProvider),
          searchHint: 'Nom, cuisine, adresse…',
          searchText: (r) => '${r.name} ${r.cuisine} ${r.address}',
          initialSortColumn: 2,
          initialSortAscending: false,
          filters: [
            AppTableFilter(
              label: 'Ouverture',
              icon: Icons.door_front_door_outlined,
              options: const {'open': 'Ouverts', 'closed': 'Fermés'},
              test: (r, v) => r.isOpen == (v == 'open'),
            ),
          ],
          columns: [
            AppTableColumn(
              label: 'Restaurant',
              primary: true,
              flex: 4,
              sortValue: (r) => r.name,
              cell: (context, r) => RestaurantCell(restaurant: r),
            ),
            AppTableColumn(
              label: 'Adresse',
              flex: 3,
              cell: (context, r) => Text(
                r.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ),
            AppTableColumn(
              label: 'Note',
              sortValue: (r) => r.rating,
              cell: (context, r) => r.reviewCount == 0
                  ? Text('Nouveau', style: context.text.bodySmall)
                  : Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${Formatters.rating(r.rating)} (${r.reviewCount})',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
            ),
            AppTableColumn(
              label: 'Livraison',
              sortValue: (r) => r.deliveryMinutes,
              cell: (context, r) => Text(
                '${r.deliveryTimeLabel}\n${r.deliveryFee == 0 ? 'Offerte' : Formatters.price(r.deliveryFee)}',
                style: context.text.bodySmall,
              ),
            ),
            AppTableColumn(
              label: 'Statut',
              sortValue: (r) => r.status.index,
              cell: (_, r) => restaurantStatusChip(r.status),
            ),
          ],
          onView: (r) => context.go(BackRoutes.restaurant(r.id)),
          onEdit: (r) => openRestaurantForm(context, restaurant: r),
          onDelete: (r) =>
              ref.read(restaurantsControllerProvider.notifier).remove(r.id),
          deleteMessage: (r) =>
              '${r.name} sera retiré de la plateforme avec son menu.',
          actions: [
            AppTableAction(
              label: 'Valider',
              icon: Icons.verified_rounded,
              isVisible: (r) =>
                  r.status == RestaurantStatus.pending ||
                  r.status == RestaurantStatus.rejected,
              onSelected: (r) => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.approved,
              ),
            ),
            AppTableAction(
              label: 'Refuser',
              icon: Icons.block_rounded,
              isDestructive: true,
              isVisible: (r) => r.status == RestaurantStatus.pending,
              onSelected: (r) => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.rejected,
              ),
            ),
            AppTableAction(
              label: 'Suspendre',
              icon: Icons.pause_circle_outline_rounded,
              isDestructive: true,
              isVisible: (r) => r.status == RestaurantStatus.approved,
              onSelected: (r) => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.suspended,
              ),
            ),
            AppTableAction(
              label: 'Réactiver',
              icon: Icons.play_circle_outline_rounded,
              isVisible: (r) => r.status == RestaurantStatus.suspended,
              onSelected: (r) => changeRestaurantStatus(
                context,
                ref,
                r,
                RestaurantStatus.approved,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Demandes d'inscription en attente : cartes avec « Valider » / « Refuser ».
class _PendingRequests extends ConsumerWidget {
  const _PendingRequests({required this.restaurants});

  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: "Demandes d'inscription",
      subtitle:
          '${restaurants.length} restaurant${restaurants.length > 1 ? 's attendent' : ' attend'} votre validation',
      icon: Icons.pending_actions_rounded,
      child: ResponsiveGrid(
        minItemWidth: 300,
        maxColumns: 3,
        children: [
          for (final r in restaurants)
            AppCard(
              color: context.palette.surfaceMuted,
              padding: const EdgeInsets.all(AppSizes.md),
              onTap: () => context.go(BackRoutes.restaurant(r.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RestaurantCell(restaurant: r),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    '${r.address}\nDemande ${Formatters.relative(r.createdAt).toLowerCase()}',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => changeRestaurantStatus(
                            context,
                            ref,
                            r,
                            RestaurantStatus.rejected,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('Refuser'),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => changeRestaurantStatus(
                            context,
                            ref,
                            r,
                            RestaurantStatus.approved,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Valider'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }
}

/// Image, nom et cuisine d'un restaurant (cellule de tableau).
class RestaurantCell extends StatelessWidget {
  const RestaurantCell({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AppNetworkImage(restaurant.imageUrl, width: 44, height: 44),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (!restaurant.isOpen) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.nightlight_round,
                      size: 14,
                      color: context.palette.textSecondary,
                    ),
                  ],
                ],
              ),
              Text(
                restaurant.cuisine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
