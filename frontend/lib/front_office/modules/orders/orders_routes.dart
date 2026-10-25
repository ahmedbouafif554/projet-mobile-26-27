import 'package:go_router/go_router.dart';

import '../../../core/routing/page_transitions.dart';
import '../communication/presentation/pages/write_review_page.dart';
import 'presentation/pages/checkout_page.dart';
import 'presentation/pages/order_confirmation_page.dart';
import 'presentation/pages/order_detail_page.dart';
import 'presentation/pages/order_tracking_page.dart';

/// Module 3 — sous-écrans de l'onglet Panier.
List<RouteBase> cartRoutes() => [
  transitionRoute(
    'checkout',
    (_, _) => const CheckoutPage(),
    type: PageTransitionType.slideUp,
  ),
];

/// Module 3 — sous-écrans de l'onglet Commandes : détail, suivi, avis.
List<RouteBase> orderRoutes() => [
  transitionRoute(
    ':id',
    (_, state) => OrderDetailPage(orderId: state.pathParameters['id']!),
    routes: [
      transitionRoute(
        'track',
        (_, state) => OrderTrackingPage(orderId: state.pathParameters['id']!),
        type: PageTransitionType.slideUp,
      ),
      transitionRoute(
        'review',
        (_, state) => WriteReviewPage(orderId: state.pathParameters['id']!),
        type: PageTransitionType.slideUp,
      ),
    ],
  ),
];

/// Module 3 — confirmation après paiement (plein écran).
List<RouteBase> orderFullScreenRoutes() => [
  transitionRoute(
    '/order-confirmed/:id',
    (_, state) => OrderConfirmationPage(orderId: state.pathParameters['id']!),
    type: PageTransitionType.scale,
  ),
];
