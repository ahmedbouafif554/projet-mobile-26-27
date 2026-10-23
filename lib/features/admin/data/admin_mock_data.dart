import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/admin_stat.dart';

/// Fausses statistiques du tableau de bord administrateur.
class AdminMockData {
  AdminMockData._();

  static const List<AdminStat> stats = [
    AdminStat(
      label: 'Commandes du jour',
      value: '128',
      trend: 12.4,
      icon: Icons.receipt_long_rounded,
      color: AppColors.primary,
    ),
    AdminStat(
      label: "Chiffre d'affaires",
      value: '3 245 €',
      trend: 8.1,
      icon: Icons.euro_rounded,
      color: AppColors.success,
    ),
    AdminStat(
      label: 'Livreurs actifs',
      value: '24',
      trend: -3.2,
      icon: Icons.delivery_dining_rounded,
      color: AppColors.info,
    ),
    AdminStat(
      label: 'Note moyenne',
      value: '4,8',
      trend: 1.5,
      icon: Icons.star_rounded,
      color: AppColors.warning,
    ),
  ];

  /// Commandes par jour sur la semaine (lundi -> dimanche).
  static const List<int> weeklyOrders = [86, 102, 94, 120, 138, 171, 128];
  static const List<String> weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
}
