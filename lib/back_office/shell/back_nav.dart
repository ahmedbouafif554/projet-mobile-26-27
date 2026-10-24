import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../shared/models/user.dart';
import '../router/back_routes.dart';
import 'back_badges.dart';

/// Entrée du menu latéral. La même définition sert au menu (filtré selon le
/// rôle) et aux règles d'accès du routeur.
class BackNavItem {
  const BackNavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.anyOf,
    this.onlyFor,
    this.restaurantLabel,
    this.badge,
  });

  final String label;
  final IconData icon;
  final String path;

  /// Au moins une de ces permissions est nécessaire.
  final Set<Permission> anyOf;

  /// Réservé à certains rôles (ex. la cuisine : restaurants uniquement).
  final Set<UserRole>? onlyFor;

  /// Libellé affiché à un restaurant (« Mon menu » au lieu de « Produits »).
  final String? restaurantLabel;

  /// Compteur affiché à droite de l'entrée (0 = rien).
  final int Function(WidgetRef ref, UserRole role)? badge;

  bool isVisibleFor(UserRole role) =>
      (onlyFor == null || onlyFor!.contains(role)) &&
      anyOf.any((p) => Permissions.can(role, p));

  String labelFor(UserRole role) =>
      role == UserRole.restaurant ? restaurantLabel ?? label : label;
}

/// Groupe du menu : un module de l'application.
class BackNavGroup {
  const BackNavGroup({this.title, required this.items});

  /// Nom du module (null : entrée hors module, ex. le tableau de bord).
  final String? title;
  final List<BackNavItem> items;
}

final List<BackNavGroup> backNavGroups = [
  const BackNavGroup(
    items: [
      BackNavItem(
        label: 'Tableau de bord',
        icon: Icons.space_dashboard_rounded,
        path: BackRoutes.dashboard,
        anyOf: {Permission.viewGlobalDashboard, Permission.viewOwnStats},
      ),
    ],
  ),
  const BackNavGroup(
    title: 'Utilisateurs',
    items: [
      BackNavItem(
        label: 'Utilisateurs',
        icon: Icons.groups_rounded,
        path: BackRoutes.users,
        anyOf: {Permission.manageUsers},
      ),
    ],
  ),
  BackNavGroup(
    title: 'Catalogue',
    items: [
      BackNavItem(
        label: 'Restaurants',
        icon: Icons.storefront_rounded,
        path: BackRoutes.restaurants,
        anyOf: const {Permission.manageRestaurants},
        badge: pendingRestaurantsBadge,
      ),
      const BackNavItem(
        label: 'Catégories',
        icon: Icons.category_rounded,
        path: BackRoutes.categories,
        anyOf: {Permission.manageCategories},
      ),
      BackNavItem(
        label: 'Produits',
        restaurantLabel: 'Mon menu',
        icon: Icons.fastfood_rounded,
        path: BackRoutes.products,
        anyOf: const {Permission.manageOwnMenu},
        badge: outOfStockBadge,
      ),
      const BackNavItem(
        label: 'Mon restaurant',
        icon: Icons.store_mall_directory_rounded,
        path: BackRoutes.myRestaurant,
        anyOf: {Permission.manageOwnMenu},
        onlyFor: {UserRole.restaurant},
      ),
    ],
  ),
  BackNavGroup(
    title: 'Commandes',
    items: [
      BackNavItem(
        label: 'Commandes',
        restaurantLabel: 'Commandes reçues',
        icon: Icons.receipt_long_rounded,
        path: BackRoutes.orders,
        anyOf: const {Permission.viewAllOrders, Permission.manageOwnOrders},
        badge: newOrdersBadge,
      ),
      const BackNavItem(
        label: 'Cuisine',
        icon: Icons.view_kanban_rounded,
        path: BackRoutes.kitchen,
        anyOf: {Permission.manageOwnOrders},
        onlyFor: {UserRole.restaurant},
      ),
    ],
  ),
  BackNavGroup(
    title: 'Livraison',
    items: [
      BackNavItem(
        label: 'Livreurs',
        icon: Icons.delivery_dining_rounded,
        path: BackRoutes.couriers,
        anyOf: const {Permission.manageCouriers},
        badge: documentsToReviewBadge,
      ),
      BackNavItem(
        label: 'Livraisons',
        icon: Icons.route_rounded,
        path: BackRoutes.deliveries,
        anyOf: const {Permission.manageDeliveries},
        badge: unassignedDeliveriesBadge,
      ),
      const BackNavItem(
        label: 'Carte',
        icon: Icons.map_rounded,
        path: BackRoutes.map,
        anyOf: {Permission.manageDeliveries},
      ),
    ],
  ),
  BackNavGroup(
    title: 'Communication',
    items: [
      BackNavItem(
        label: 'Avis',
        icon: Icons.star_rounded,
        path: BackRoutes.reviews,
        anyOf: const {Permission.moderateReviews, Permission.replyToReviews},
        badge: reviewsBadge,
      ),
      const BackNavItem(
        label: 'Campagnes',
        icon: Icons.campaign_rounded,
        path: BackRoutes.campaigns,
        anyOf: {Permission.sendCampaigns},
      ),
      BackNavItem(
        label: 'Conversations',
        icon: Icons.forum_rounded,
        path: BackRoutes.chats,
        anyOf: const {Permission.superviseChats, Permission.chatWithCustomers},
        badge: chatsBadge,
      ),
    ],
  ),
];

/// Menu du rôle : entrées autorisées, groupes vides retirés.
List<BackNavGroup> navFor(UserRole role) => [
  for (final group in backNavGroups)
    if (group.items.any((i) => i.isVisibleFor(role)))
      BackNavGroup(
        title: group.title,
        items: [
          for (final item in group.items)
            if (item.isVisibleFor(role)) item,
        ],
      ),
];

/// Entrée du menu qui correspond à un chemin (préfixe le plus long).
BackNavItem? navItemFor(String path) {
  BackNavItem? best;
  for (final group in backNavGroups) {
    for (final item in group.items) {
      final matches = path == item.path || path.startsWith('${item.path}/');
      if (matches && (best == null || item.path.length > best.path.length)) {
        best = item;
      }
    }
  }
  return best;
}

/// Groupe (module) d'un chemin, pour le fil d'Ariane.
String? navGroupTitleFor(String path) {
  final item = navItemFor(path);
  for (final group in backNavGroups) {
    if (group.items.contains(item)) return group.title;
  }
  return null;
}
