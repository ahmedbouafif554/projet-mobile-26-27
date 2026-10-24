import '../../core/routes/module_routes.dart';
import '../../core/routes/page_transitions.dart';
import 'data/catalog_mock_data.dart';
import 'presentation/pages/favorites_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/product_page.dart';
import 'presentation/pages/restaurant_page.dart';
import 'presentation/pages/restaurants_page.dart';
import 'presentation/pages/search_page.dart';

/// Routes du Module 2 — Restaurants et catalogue (`/explore/...`).
///
/// Identifiant d'écran (modules_config.dart) → vraie page.
/// Les écrans prévus absents de cette table affichent un placeholder.
final ModuleRoutes catalogRoutes = ModuleRoutes(
  moduleNumber: 2,
  screens: {
    'home': (_, _) => const HomePage(),
    'restaurants': (_, state) => RestaurantsPage(
      categoryId: state.uri.queryParameters['category'],
      filter: state.uri.queryParameters['filter'],
    ),
    'search': (_, _) => const SearchPage(),
    // Sans identifiant (carte du module) : restaurant et plat de démo.
    'restaurant': (_, _) => RestaurantPage(
      restaurantId: CatalogMockData.restaurants.first.id,
      heroOrigin: 'module',
    ),
    'product': (_, _) => ProductPage(
      productId: CatalogMockData.products.first.id,
      heroOrigin: 'module',
    ),
    'favorites': (_, _) => const FavoritesPage(),
  },
  transitions: {'restaurant': PageTransitionType.fade},
  extraRoutes: [
    ModuleRoutes.route(
      'restaurant/:id',
      (_, state) => RestaurantPage(
        restaurantId: state.pathParameters['id']!,
        heroOrigin: state.uri.queryParameters['hero'] ?? 'list',
      ),
      transition: PageTransitionType.fade,
    ),
    ModuleRoutes.route(
      'product/:id',
      (_, state) => ProductPage(
        productId: state.pathParameters['id']!,
        heroOrigin: state.uri.queryParameters['hero'] ?? 'menu',
      ),
      fullScreen: true,
    ),
  ],
);
