import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../router/front_routes.dart';
import '../../../../shared/catalog_widgets.dart';
import '../../providers/catalog_providers.dart';

/// Mes restaurants favoris (balayer pour retirer, avec annulation).
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final restaurants = ref.watch(restaurantsProvider);
    final loading = favorites.isLoading || restaurants.isLoading;
    final list = [
      for (final r in restaurants.value ?? const [])
        if (favorites.value?.contains(r.id) ?? false) r,
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.md,
              ),
              child: PageTitle('Mes favoris'),
            ),
            Expanded(
              child: loading && list.isEmpty
                  ? ShimmerScope(
                      child: ListView(
                        padding: const EdgeInsets.all(AppSizes.pagePadding),
                        children: [
                          for (var i = 0; i < 3; i++)
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSizes.md),
                              child: SkeletonBox(height: 96),
                            ),
                        ],
                      ),
                    )
                  : list.isEmpty
                  ? EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Aucun favori',
                      message:
                          'Touchez le cœur d’un restaurant pour le retrouver ici.',
                      actionLabel: 'Explorer les restaurants',
                      onAction: () => context.go(FrontRoutes.explore),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.pagePadding,
                        0,
                        AppSizes.pagePadding,
                        AppSizes.xl,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.sm + 4),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return Dismissible(
                          key: ValueKey(r.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: AppColors.favorite,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: const Icon(
                              Icons.heart_broken_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) async {
                            final notifier = ref.read(favoritesProvider.notifier);
                            await notifier.toggle(r.id);
                            if (!context.mounted) return;
                            AppSnackbar.show(
                              context,
                              '${r.name} retiré des favoris',
                              icon: Icons.heart_broken_rounded,
                              iconColor: AppColors.favorite,
                              actionLabel: 'Annuler',
                              onAction: () => notifier.toggle(r.id),
                            );
                          },
                          child: RestaurantTile(
                            restaurant: r,
                            onTap: () =>
                                context.push(FrontRoutes.restaurant(r.id)),
                          ),
                        ).animate(delay: (50 * i).ms).fadeIn().slideX(
                          begin: 0.05,
                          end: 0,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
