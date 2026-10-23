import 'package:flutter/painting.dart';

/// Bannière promotionnelle du carrousel de l'accueil.
class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.colors,
    this.code,
    this.restaurantId,
    this.categoryId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;

  /// Couleurs du dégradé de fond.
  final List<Color> colors;

  /// Code promo à saisir dans le panier.
  final String? code;

  /// Cible au clic : un restaurant ou une catégorie.
  final String? restaurantId;
  final String? categoryId;
}
