import 'package:go_router/go_router.dart';

import '../../../core/routing/page_transitions.dart';
import '../../router/front_routes.dart';
import 'presentation/pages/courier_documents_page.dart';
import 'presentation/pages/delivery_detail_page.dart';

/// Module 4 — détail d'une course (onglet Livraisons du livreur).
List<RouteBase> courierDeliveryRoutes() => [
  transitionRoute(
    ':id',
    (_, state) => DeliveryDetailPage(deliveryId: state.pathParameters['id']!),
  ),
];

/// Module 4 — documents et véhicule (plein écran, depuis le profil).
List<RouteBase> courierAccountRoutes() => [
  transitionRoute(FrontRoutes.documents, (_, _) => const CourierDocumentsPage()),
];
