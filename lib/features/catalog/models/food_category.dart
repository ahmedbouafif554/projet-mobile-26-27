import 'package:flutter/painting.dart';

/// Catégorie de commerce (burger, pizza, courses...).
/// Nommée FoodCategory pour ne pas entrer en conflit avec
/// l'annotation `Category` de Flutter.
class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;

  /// Couleur de fond de la pastille de catégorie.
  final Color color;
}
