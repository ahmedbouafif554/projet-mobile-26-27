import 'package:go_router/go_router.dart';

import '../../router/back_routes.dart';
import '../../router/bo_route.dart';
import 'categories_page.dart';
import 'my_restaurant_page.dart';
import 'products_page.dart';
import 'restaurant_detail_page.dart';
import 'restaurants_page.dart';

/// Routes du Module 2 (catalogue).
List<RouteBase> catalogRoutes() => [
  boRoute(
    BackRoutes.restaurants,
    (_, _) => const RestaurantsPage(),
    routes: [
      boRoute(
        ':id',
        (_, state) =>
            RestaurantDetailPage(restaurantId: state.pathParameters['id']!),
      ),
    ],
  ),
  boRoute(BackRoutes.categories, (_, _) => const CategoriesPage()),
  boRoute(BackRoutes.products, (_, _) => const ProductsPage()),
  boRoute(BackRoutes.myRestaurant, (_, _) => const MyRestaurantPage()),
];
