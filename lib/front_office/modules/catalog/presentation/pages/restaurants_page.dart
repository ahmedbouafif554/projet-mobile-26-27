import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/async_value_view.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/selectable_chip.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../providers/catalog_providers.dart';

/// Tous les restaurants avec filtres (catégorie, tri, livraison offerte,
/// mieux notés, promos, ouverts).
class RestaurantsPage extends ConsumerWidget {
  const RestaurantsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(restaurantFilterProvider);
    final notifier = ref.read(restaurantFilterProvider.notifier);
    final restaurants = ref.watch(restaurantsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.sm,
              ),
              child: Row(
                children: [
                  const Expanded(child: PageTitle('Restaurants')),
                  Badge(
                    isLabelVisible: filter.activeCount > 0,
                    backgroundColor: AppColors.primary,
                    label: Text('${filter.activeCount}'),
                    child: IconButton.filledTonal(
                      tooltip: 'Trier et filtrer',
                      onPressed: () => _openFilters(context),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding - 6,
                ),
                children: [
                  for (final c in categories)
                    CategoryBubble(
                      category: c,
                      selected: filter.categoryId == c.id,
                      onTap: () => notifier.update(
                        filter.copyWith(
                          categoryId: filter.categoryId == c.id ? null : c.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                  vertical: 4,
                ),
                children: [
                  for (final (label, icon, selected, onTap) in [
                    (
                      'Livraison offerte',
                      Icons.delivery_dining_rounded,
                      filter.freeDelivery,
                      () => notifier.update(
                        filter.copyWith(freeDelivery: !filter.freeDelivery),
                      ),
                    ),
                    (
                      '4,5 ★ et plus',
                      Icons.star_rounded,
                      filter.topRated,
                      () => notifier.update(
                        filter.copyWith(topRated: !filter.topRated),
                      ),
                    ),
                    (
                      'Promos',
                      Icons.local_offer_rounded,
                      filter.withPromo,
                      () => notifier.update(
                        filter.copyWith(withPromo: !filter.withPromo),
                      ),
                    ),
                    (
                      'Ouverts',
                      Icons.door_front_door_rounded,
                      filter.openOnly,
                      () => notifier.update(
                        filter.copyWith(openOnly: !filter.openOnly),
                      ),
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: SelectableChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                        onTap: onTap,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView(
                value: restaurants,
                onRetry: () => ref.invalidate(restaurantsProvider),
                loading: ShimmerScope(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSizes.pagePadding),
                    children: [
                      for (var i = 0; i < 3; i++)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSizes.md),
                          child: SkeletonBox(
                            height: 230,
                            radius: AppSizes.radiusLg,
                          ),
                        ),
                    ],
                  ),
                ),
                data: (all) {
                  final list = filter.apply(all);
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun restaurant',
                      message: 'Aucun restaurant ne correspond à ces filtres.',
                      actionLabel: 'Réinitialiser',
                      onAction: notifier.reset,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.sm,
                      AppSizes.pagePadding,
                      AppSizes.xl,
                    ),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.md),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Text(
                          '${list.length} restaurant${list.length > 1 ? 's' : ''} • ${filter.sort.label}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        );
                      }
                      final r = list[i - 1];
                      return RestaurantCard(
                        key: ValueKey(r.id),
                        restaurant: r,
                        onTap: () => context.push(FrontRoutes.restaurant(r.id)),
                      ).animate(delay: (40 * (i % 6)).ms).fadeIn().slideY(
                        begin: 0.06,
                        end: 0,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _SortSheet(),
  );
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(restaurantFilterProvider);
    final notifier = ref.read(restaurantFilterProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trier par', style: context.text.titleLarge),
            const SizedBox(height: AppSizes.sm),
            for (final sort in RestaurantSort.values)
              RadioListTile<RestaurantSort>(
                value: sort,
                groupValue: filter.sort,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                title: Text(sort.label),
                onChanged: (s) => notifier.update(filter.copyWith(sort: s)),
              ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      notifier.reset();
                      Navigator.pop(context);
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
