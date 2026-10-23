import 'package:flutter/widgets.dart';

/// Indicateur clé affiché sur le tableau de bord admin.
class AdminStat {
  const AdminStat({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;

  /// Évolution en % par rapport à la veille (négatif = baisse).
  final double trend;
  final IconData icon;
  final Color color;
}
