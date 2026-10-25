import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_charts.dart';
import '../../shared/models/models.dart';
import '../modules/communication/communication_controllers.dart';
import '../modules/delivery/delivery_controllers.dart';
import '../modules/orders/orders_controller.dart';
import '../modules/users/users_controller.dart';
import '../router/back_routes.dart';

/// Indicateur clé (carte de statistique du tableau de bord).
class Kpi {
  const Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.format = Formatters.count,
    this.color = AppColors.primary,
    this.trend,
    this.caption,
    this.route,
  });

  final String label;
  final num value;
  final IconData icon;
  final String Function(num value) format;
  final Color color;
  final double? trend;
  final String? caption;
  final String? route;
}

/// Données du tableau de bord : globales pour l'admin, limitées à son
/// restaurant pour un restaurateur.
class DashboardData {
  const DashboardData({
    required this.kpis,
    required this.sales,
    required this.days,
    required this.statusSlices,
    required this.barsTitle,
    required this.barsSubtitle,
    required this.bars,
    required this.barsFormat,
    required this.latestOrders,
  });

  final List<Kpi> kpis;

  /// Chiffre d'affaires des 7 derniers jours (le plus ancien à gauche).
  final List<double> sales;
  final List<String> days;
  final List<ChartSlice> statusSlices;
  final String barsTitle;
  final String barsSubtitle;
  final List<ChartBar> bars;
  final String Function(num value) barsFormat;
  final List<Order> latestOrders;
}

/// Évolution en % (null si la période précédente est vide).
double? trendOf(num current, num previous) =>
    previous == 0 ? null : (current - previous) / previous * 100;

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _counts(Order o) =>
    o.status != OrderStatus.cancelled && o.status != OrderStatus.refunded;

/// Se recalcule quand une commande, un utilisateur ou un livreur change
/// (il lit les mêmes contrôleurs que les pages de gestion).
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final user = ref.watch(authServiceProvider).user;
  final isAdmin = user?.role == UserRole.admin;
  final orders = await ref.watch(ordersControllerProvider.future);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final paid = orders.where(_counts).toList();

  double revenueOn(DateTime day) => paid
      .where((o) => _sameDay(o.createdAt, day))
      .fold(0, (sum, o) => sum + o.total);
  int ordersOn(DateTime day) =>
      orders.where((o) => _sameDay(o.createdAt, day)).length;

  final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
  final sales = [for (final day in days) revenueOn(day)];

  int countWhere(bool Function(OrderStatus s) test) =>
      orders.where((o) => test(o.status)).length;
  final statusSlices = [
    ChartSlice(
      label: 'Nouvelles',
      value: countWhere((s) => s == OrderStatus.pending).toDouble(),
      color: AppColors.info,
    ),
    ChartSlice(
      label: 'En cours',
      value: countWhere(
        (s) => s.isActive && s != OrderStatus.pending,
      ).toDouble(),
      color: AppColors.primary,
    ),
    ChartSlice(
      label: 'Livrées',
      value: countWhere((s) => s == OrderStatus.delivered).toDouble(),
      color: AppColors.success,
    ),
    ChartSlice(
      label: 'Annulées / remb.',
      value: countWhere(
        (s) => s == OrderStatus.cancelled || s == OrderStatus.refunded,
      ).toDouble(),
      color: AppColors.error,
    ),
  ];

  final commonKpis = [
    Kpi(
      label: 'Commandes du jour',
      value: ordersOn(today),
      icon: Icons.receipt_long_rounded,
      trend: trendOf(ordersOn(today), ordersOn(yesterday)),
      caption: 'vs hier',
      route: BackRoutes.orders,
    ),
    Kpi(
      label: "Chiffre d'affaires du jour",
      value: revenueOn(today),
      format: Formatters.priceShort,
      icon: Icons.euro_rounded,
      color: AppColors.success,
      trend: trendOf(revenueOn(today), revenueOn(yesterday)),
      caption: 'vs hier',
      route: BackRoutes.orders,
    ),
  ];

  final latest = orders.take(6).toList();

  if (isAdmin) {
    final (users, couriers) = await (
      ref.watch(usersControllerProvider.future),
      ref.watch(couriersControllerProvider.future),
    ).wait;
    final weekAgo = today.subtract(const Duration(days: 7));
    final twoWeeksAgo = today.subtract(const Duration(days: 14));
    final newThisWeek = users.where((u) => u.createdAt.isAfter(weekAgo)).length;
    final newLastWeek = users
        .where(
          (u) =>
              u.createdAt.isAfter(twoWeeksAgo) && !u.createdAt.isAfter(weekAgo),
        )
        .length;
    final online = couriers.where((c) => c.status.isOnline).length;

    // Top 5 des restaurants par chiffre d'affaires.
    final byRestaurant = <String, double>{};
    for (final o in paid) {
      byRestaurant.update(
        o.restaurantName,
        (v) => v + o.total,
        ifAbsent: () => o.total,
      );
    }
    final top = byRestaurant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardData(
      kpis: [
        ...commonKpis,
        Kpi(
          label: 'Utilisateurs',
          value: users.length,
          icon: Icons.groups_rounded,
          color: AppColors.info,
          trend: trendOf(newThisWeek, newLastWeek),
          caption: '+$newThisWeek cette semaine',
          route: BackRoutes.users,
        ),
        Kpi(
          label: 'Livreurs en ligne',
          value: online,
          icon: Icons.delivery_dining_rounded,
          color: AppColors.warning,
          caption: 'sur ${couriers.length} livreurs',
          route: BackRoutes.couriers,
        ),
      ],
      sales: sales,
      days: [for (final d in days) Formatters.weekday(d)],
      statusSlices: statusSlices,
      barsTitle: 'Top restaurants',
      barsSubtitle: "Chiffre d'affaires total",
      bars: [
        for (final e in top.take(5))
          ChartBar(label: e.key, value: e.value),
      ],
      barsFormat: Formatters.priceShort,
      latestOrders: latest,
    );
  }

  // Restaurateur : panier moyen, note et produits les plus vendus.
  final reviews = await ref.watch(reviewsControllerProvider.future);
  final published = reviews.where((r) => r.status == ReviewStatus.approved);
  final rating = published.isEmpty
      ? 0.0
      : published.fold<int>(0, (s, r) => s + r.rating) / published.length;
  final weekAgo = today.subtract(const Duration(days: 6));
  final prevWeek = weekAgo.subtract(const Duration(days: 7));
  double average(Iterable<Order> list) => list.isEmpty
      ? 0
      : list.fold<double>(0, (s, o) => s + o.total) / list.length;
  final thisWeek = paid.where((o) => !o.createdAt.isBefore(weekAgo));
  final lastWeek = paid.where(
    (o) => !o.createdAt.isBefore(prevWeek) && o.createdAt.isBefore(weekAgo),
  );

  final quantities = <String, int>{};
  for (final order in paid) {
    for (final item in order.items) {
      quantities.update(
        item.product.name,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
  }
  final topProducts = quantities.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return DashboardData(
    kpis: [
      ...commonKpis,
      Kpi(
        label: 'Panier moyen',
        value: average(thisWeek),
        format: Formatters.price,
        icon: Icons.shopping_bag_rounded,
        color: AppColors.info,
        trend: trendOf(average(thisWeek), average(lastWeek)),
        caption: '7 derniers jours',
      ),
      Kpi(
        label: 'Note moyenne',
        value: rating,
        format: Formatters.rating,
        icon: Icons.star_rounded,
        color: AppColors.warning,
        caption: '${published.length} avis publiés',
        route: BackRoutes.reviews,
      ),
    ],
    sales: sales,
    days: [for (final d in days) Formatters.weekday(d)],
    statusSlices: statusSlices,
    barsTitle: 'Produits les plus vendus',
    barsSubtitle: 'Quantités commandées',
    bars: [
      for (final e in topProducts.take(5))
        ChartBar(label: e.key, value: e.value.toDouble()),
    ],
    barsFormat: Formatters.count,
    latestOrders: latest,
  );
});
