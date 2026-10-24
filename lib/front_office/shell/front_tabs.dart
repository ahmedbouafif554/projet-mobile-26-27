import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modules/auth/presentation/pages/profile_page.dart';
import '../modules/catalog/catalog_routes.dart';
import '../modules/catalog/presentation/pages/home_page.dart';
import '../modules/catalog/presentation/pages/search_page.dart';
import '../modules/communication/communication_routes.dart';
import '../modules/communication/presentation/pages/chats_list_page.dart';
import '../modules/courier/courier_routes.dart';
import '../modules/courier/presentation/pages/courier_dashboard_page.dart';
import '../modules/courier/presentation/pages/courier_deliveries_page.dart';
import '../modules/courier/presentation/pages/courier_earnings_page.dart';
import '../modules/orders/orders_routes.dart';
import '../modules/orders/presentation/pages/cart_page.dart';
import '../modules/orders/presentation/pages/orders_page.dart';
import '../router/front_routes.dart';
import 'tab_badges.dart';

/// Onglet de la barre de navigation du front office.
class FrontTab {
  const FrontTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
    required this.builder,
    this.routes = const [],
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Route de l'onglet (écran principal).
  final String path;
  final Widget Function() builder;

  /// Sous-écrans ouverts dans l'onglet (fournis par les modules).
  final List<RouteBase> routes;

  /// Compteur affiché sur l'onglet (absent ou 0 = pas de pastille).
  final TabBadge? badge;
}

/// Onglets du client : Explorer, Recherche, Panier, Commandes, Profil.
final List<FrontTab> clientTabs = [
  FrontTab(
    label: 'Explorer',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
    path: FrontRoutes.explore,
    builder: () => const HomePage(),
    routes: exploreRoutes(),
  ),
  FrontTab(
    label: 'Recherche',
    icon: Icons.search_rounded,
    selectedIcon: Icons.manage_search_rounded,
    path: FrontRoutes.search,
    builder: () => const SearchPage(),
    routes: searchRoutes(),
  ),
  FrontTab(
    label: 'Panier',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
    path: FrontRoutes.cart,
    badge: cartCountBadge,
    builder: () => const CartPage(),
    routes: cartRoutes(),
  ),
  FrontTab(
    label: 'Commandes',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    path: FrontRoutes.orders,
    badge: activeOrdersBadge,
    builder: () => const OrdersPage(),
    routes: orderRoutes(),
  ),
  FrontTab(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    path: FrontRoutes.profile,
    builder: () => const ProfilePage(),
  ),
];

/// Onglets du livreur : Dashboard, Livraisons, Gains, Messages, Profil.
final List<FrontTab> courierTabs = [
  FrontTab(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    path: FrontRoutes.courierDashboard,
    builder: () => const CourierDashboardPage(),
  ),
  FrontTab(
    label: 'Livraisons',
    icon: Icons.delivery_dining_outlined,
    selectedIcon: Icons.delivery_dining_rounded,
    path: FrontRoutes.courierDeliveries,
    badge: availableDeliveriesBadge,
    builder: () => const CourierDeliveriesPage(),
    routes: courierDeliveryRoutes(),
  ),
  FrontTab(
    label: 'Gains',
    icon: Icons.payments_outlined,
    selectedIcon: Icons.payments_rounded,
    path: FrontRoutes.courierEarnings,
    builder: () => const CourierEarningsPage(),
  ),
  FrontTab(
    label: 'Messages',
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum_rounded,
    path: FrontRoutes.courierMessages,
    badge: unreadMessagesBadge,
    builder: () => const ChatsListPage(),
    routes: chatRoutes(),
  ),
  FrontTab(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    path: FrontRoutes.courierProfile,
    builder: () => const ProfilePage(),
  ),
];
