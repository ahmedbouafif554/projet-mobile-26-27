import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/catalog_mock_data.dart';
import '../controllers/favorites_controller.dart';
import '../widgets/restaurant_tile.dart';

/// Liste des restaurants favoris.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = FavoritesController.instance;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Mes favoris'),
      ),
      body: ListenableBuilder(
        listenable: favorites,
        builder: (context, _) {
          final restaurants = CatalogMockData.restaurants
              .where((r) => favorites.isFavorite(r.id))
              .toList();

          return AnimatedSwitcher(
            duration: AppDurations.medium,
            child: restaurants.isEmpty
                ? EmptyState(
                    key: const ValueKey('empty'),
                    icon: Icons.favorite_border_rounded,
                    title: 'Aucun favori',
                    message:
                        'Touchez le cœur d\'un restaurant pour le retrouver ici en un clin d\'œil.',
                    actionLabel: 'Explorer les restaurants',
                    onAction: () => context.push(AppRoutes.restaurants),
                  )
                : ListView.separated(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.all(AppSizes.pagePadding),
                    itemCount: restaurants.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.md),
                    itemBuilder: (context, i) =>
                        RestaurantTile(
                              key: ValueKey(restaurants[i].id),
                              restaurant: restaurants[i],
                              heroOrigin: 'fav',
                            )
                            .animate(delay: (70 * i).ms)
                            .fadeIn(duration: 400.ms)
                            .slideX(
                              begin: 0.15,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),
                  ),
          );
        },
      ),
    );
  }
}
