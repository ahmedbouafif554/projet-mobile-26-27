import 'package:go_router/go_router.dart';

import '../../../core/routing/page_transitions.dart';
import '../../router/front_routes.dart';
import '../communication/presentation/pages/restaurant_reviews_page.dart';
import 'presentation/pages/favorites_page.dart';
import 'presentation/pages/restaurant_page.dart';
import 'presentation/pages/restaurants_map_page.dart';
import 'presentation/pages/restaurants_page.dart';

/// Carte des restaurants (sous la liste de l'onglet Explorer).
const restaurantsMapPath = '${FrontRoutes.restaurants}/map';

/// Fiche d'un restaurant et ses avis (dans l'onglet qui l'ouvre).
GoRoute _restaurantRoute() => transitionRoute(
  'restaurant/:id',
  (_, state) => RestaurantPage(restaurantId: state.pathParameters['id']!),
  routes: [
    transitionRoute(
      'reviews',
      (_, state) =>
          RestaurantReviewsPage(restaurantId: state.pathParameters['id']!),
    ),
  ],
);

/// Module 2 — sous-écrans de l'onglet Explorer.
List<RouteBase> exploreRoutes() => [
  transitionRoute(
    'restaurants',
    (_, _) => const RestaurantsPage(),
    routes: [transitionRoute('map', (_, _) => const RestaurantsMapPage())],
  ),
  _restaurantRoute(),
];

/// Module 2 — sous-écrans de l'onglet Recherche.
List<RouteBase> searchRoutes() => [_restaurantRoute()];

/// Module 2 — favoris (plein écran, depuis le profil).
List<RouteBase> catalogAccountRoutes() => [
  transitionRoute(FrontRoutes.favorites, (_, _) => const FavoritesPage()),
];
