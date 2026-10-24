import 'package:go_router/go_router.dart';

import '../../router/back_routes.dart';
import '../../router/bo_route.dart';
import 'courier_detail_page.dart';
import 'couriers_page.dart';
import 'deliveries_page.dart';
import 'map_page.dart';

/// Routes du Module 4 (livraison).
List<RouteBase> deliveryRoutes() => [
  boRoute(
    BackRoutes.couriers,
    (_, _) => const CouriersPage(),
    routes: [
      boRoute(
        ':id',
        (_, state) => CourierDetailPage(courierId: state.pathParameters['id']!),
      ),
    ],
  ),
  boRoute(BackRoutes.deliveries, (_, _) => const DeliveriesPage()),
  boRoute(BackRoutes.map, (_, _) => const MapPage()),
];
