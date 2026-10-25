import 'json_utils.dart';

/// Catégorie de cuisine (Burgers, Sushi…), réordonnable dans le back office.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    this.colorValue = 0xFFFFE8D9,
    this.position = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String emoji;

  /// Couleur de fond de la pastille (ARGB), ex. `0xFFFFE8D9`.
  final int colorValue;

  /// Ordre d'affichage (0 = premier).
  final int position;
  final bool isActive;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '🍽️',
    colorValue: parseInt(json['colorValue'], 0xFFFFE8D9),
    position: parseInt(json['position']),
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'colorValue': colorValue,
    'position': position,
    'isActive': isActive,
  };

  Category copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    int? position,
    bool? isActive,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    colorValue: colorValue ?? this.colorValue,
    position: position ?? this.position,
    isActive: isActive ?? this.isActive,
  );
}
