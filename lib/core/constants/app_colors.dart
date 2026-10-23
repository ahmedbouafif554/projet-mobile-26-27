import 'package:flutter/material.dart';

/// Palette de couleurs centrale de SuperFaster.
/// Toutes les couleurs « brutes » de l'application sont définies ici.
class AppColors {
  AppColors._();

  // Couleurs de marque
  static const Color primary = Color(0xFFFF5A1F);
  static const Color primaryLight = Color(0xFFFF8A5B);
  static const Color primaryDark = Color(0xFFE04410);
  static const Color secondary = Color(0xFF1B1B1F);

  // Statuts
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color favorite = Color(0xFFFF3B5C);

  // Mode clair
  static const Color background = Color(0xFFF8F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F1F5);
  static const Color textPrimary = Color(0xFF1B1B1F);
  static const Color textSecondary = Color(0xFF6B6B76);
  static const Color border = Color(0xFFEAEAF0);

  // Mode sombre
  static const Color darkBackground = Color(0xFF111114);
  static const Color darkSurface = Color(0xFF1B1B1F);
  static const Color darkSurfaceMuted = Color(0xFF26262C);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF2E2E36);

  /// Dégradé utilisé sur les boutons principaux et les bannières.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF7A45), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
