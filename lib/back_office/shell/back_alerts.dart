import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/user.dart';
import '../router/back_routes.dart';
import 'back_badges.dart';

/// Alerte du tableau de bord et de la cloche de la topbar.
class BoAlert {
  const BoAlert({
    required this.icon,
    required this.color,
    required this.title,
    required this.route,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String route;
  final int count;
}

/// « 2 demandes », « 4 avis » (mot déjà au pluriel inchangé).
String _plural(int n, String word) =>
    '$n $word${n > 1 && !word.endsWith('s') ? 's' : ''}';

/// Alertes du rôle (seules celles qui ont au moins un élément).
List<BoAlert> watchAlerts(WidgetRef ref, UserRole role) {
  final alerts = role == UserRole.admin
      ? [
          BoAlert(
            icon: Icons.storefront_rounded,
            color: AppColors.warning,
            title: "demande d'inscription",
            route: BackRoutes.restaurants,
            count: pendingRestaurantsBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.star_half_rounded,
            color: AppColors.info,
            title: 'avis à modérer',
            route: BackRoutes.reviews,
            count: reviewsBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.badge_rounded,
            color: AppColors.primary,
            title: 'livreur à vérifier',
            route: BackRoutes.couriers,
            count: documentsToReviewBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.route_rounded,
            color: AppColors.success,
            title: 'livraison à assigner',
            route: BackRoutes.deliveries,
            count: unassignedDeliveriesBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.flag_rounded,
            color: AppColors.error,
            title: 'conversation signalée',
            route: BackRoutes.chats,
            count: chatsBadge(ref, role),
          ),
        ]
      : [
          BoAlert(
            icon: Icons.notifications_active_rounded,
            color: AppColors.primary,
            title: 'nouvelle commande',
            route: BackRoutes.kitchen,
            count: newOrdersBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.rate_review_rounded,
            color: AppColors.info,
            title: 'avis sans réponse',
            route: BackRoutes.reviews,
            count: reviewsBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.inventory_2_rounded,
            color: AppColors.warning,
            title: 'produit en rupture',
            route: BackRoutes.products,
            count: outOfStockBadge(ref, role),
          ),
          BoAlert(
            icon: Icons.mark_chat_unread_rounded,
            color: AppColors.success,
            title: 'message non lu',
            route: BackRoutes.chats,
            count: chatsBadge(ref, role),
          ),
        ];
  return alerts.where((a) => a.count > 0).toList();
}

/// « 2 demandes d'inscription »
String alertLabel(BoAlert alert) {
  final words = alert.title.split(' ');
  return '${_plural(alert.count, words.first)}'
      '${words.length > 1 ? ' ${words.skip(1).join(' ')}' : ''}';
}
