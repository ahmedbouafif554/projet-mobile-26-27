import 'package:flutter/painting.dart';

/// Contenu d'une slide d'onboarding.
class OnboardingItem {
  const OnboardingItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.accent,
    required this.badges,
  });

  final String title;
  final String description;
  final String imageUrl;

  /// Couleur des cercles décoratifs derrière l'illustration.
  final Color accent;

  /// Petites étiquettes flottantes : (emoji, texte).
  final List<(String, String)> badges;
}
