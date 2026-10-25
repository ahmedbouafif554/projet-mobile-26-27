import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Raccourcis pratiques pour accéder au thème depuis un [BuildContext].
/// Exemple : `context.colors.primary`, `context.text.titleLarge`.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Taille de l'écran (pour adapter les mises en page).
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Vrai sur les petits téléphones (iPhone SE, etc.).
  bool get isSmallScreen => MediaQuery.sizeOf(this).width < 360;
}
