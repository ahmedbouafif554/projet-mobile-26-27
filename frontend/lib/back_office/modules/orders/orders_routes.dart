import 'package:go_router/go_router.dart';

import '../../router/back_routes.dart';
import '../../router/bo_route.dart';
import 'kitchen_page.dart';
import 'order_detail_page.dart';
import 'orders_page.dart';

/// Routes du Module 3 (commandes).
List<RouteBase> ordersRoutes() => [
  boRoute(
    BackRoutes.orders,
    (_, _) => const OrdersPage(),
    routes: [
      boRoute(
        ':id',
        (_, state) => OrderDetailPage(orderId: state.pathParameters['id']!),
      ),
    ],
  ),
  boRoute(BackRoutes.kitchen, (_, _) => const KitchenPage()),
];
