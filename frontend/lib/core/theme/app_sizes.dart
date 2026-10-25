/// Espacements, rayons et durées utilisés partout dans l'application.
/// Garder ces valeurs centralisées assure un rendu cohérent.
class AppSizes {
  AppSizes._();

  // Espacements
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Marge horizontale standard des pages.
  static const double pagePadding = 20;

  // Rayons des coins arrondis (16 à 24 px selon la charte)
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  /// Hauteur standard des boutons principaux.
  static const double buttonHeight = 56;

  /// Largeur maximale du contenu des pages du back office.
  static const double maxContentWidth = 1400;
}

/// Points de rupture de la mise en page responsive (largeur en px logiques).
class Breakpoints {
  Breakpoints._();

  /// En dessous : téléphone (une colonne, menu en Drawer).
  static const double compact = 600;

  /// À partir de : grand écran (sidebar dépliée, tableaux complets).
  static const double expanded = 1024;
}

/// Durées d'animation standard.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);

  /// Compteurs et graphiques animés.
  static const Duration counter = Duration(milliseconds: 1200);
}
