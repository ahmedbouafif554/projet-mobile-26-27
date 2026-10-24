import '../../core/routes/module_routes.dart';
import '../../core/routes/page_transitions.dart';
import '../delivery/presentation/pages/tracking_page.dart';
import '../profile/presentation/pages/payment_methods_page.dart';
import 'presentation/controllers/cart_controller.dart';
import 'presentation/controllers/orders_controller.dart';
import 'presentation/pages/cart_page.dart';
import 'presentation/pages/checkout_page.dart';
import 'presentation/pages/order_confirmation_page.dart';
import 'presentation/pages/orders_page.dart';

/// Commande de démo (carte du module, sans identifiant) : la commande en
/// cours, sinon la plus récente.
String get _demoOrderId {
  final orders = OrdersController.instance;
  return (orders.activeOrders.firstOrNull ?? orders.pastOrders.first).id;
}

/// Routes du Module 3 — Panier et commandes (`/orders/...`).
///
/// Identifiant d'écran (modules_config.dart) → vraie page.
/// Les écrans prévus absents de cette table affichent un placeholder.
final ModuleRoutes ordersRoutes = ModuleRoutes(
  moduleNumber: 3,
  screens: {
    'cart': (_, _) => const CartPage(),
    'checkout': (_, _) => const CheckoutPage(),
    'payment': (_, _) => const PaymentMethodsPage(),
    'confirmation': (_, _) => OrderConfirmationPage(orderId: _demoOrderId),
    'history': (_, _) => const OrdersPage(),
    'tracking': (_, _) => TrackingPage(orderId: _demoOrderId),
  },
  transitions: {
    'cart': PageTransitionType.slideUp,
    'confirmation': PageTransitionType.scale,
    'tracking': PageTransitionType.slideUp,
  },
  extraRoutes: [
    ModuleRoutes.route(
      'confirmation/:id',
      (_, state) => OrderConfirmationPage(orderId: state.pathParameters['id']!),
      fullScreen: true,
      transition: PageTransitionType.scale,
    ),
    ModuleRoutes.route(
      'tracking/:id',
      (_, state) => TrackingPage(orderId: state.pathParameters['id']!),
      fullScreen: true,
      transition: PageTransitionType.slideUp,
    ),
  ],
  // Badge de l'onglet : nombre d'articles dans le panier.
  badge: TabBadge(
    listenable: CartController.instance,
    count: () => CartController.instance.itemCount,
  ),
);
