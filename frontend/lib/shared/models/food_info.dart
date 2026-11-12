import 'json_utils.dart';

/// Nutri-Score d'un produit alimentaire (A = meilleure qualité nutritionnelle).
enum NutriScore {
  a(0xFF038141),
  b(0xFF85BB2F),
  c(0xFFFECB02),
  d(0xFFEE8100),
  e(0xFFE63E11);

  const NutriScore(this.colorValue);

  /// Couleur officielle de la lettre (ARGB), comme `Category.colorValue`.
  final int colorValue;

  /// « A », « B »…
  String get letter => name.toUpperCase();

  /// `null` si la valeur est absente ou inconnue.
  static NutriScore? fromCode(Object? code) =>
      code is String ? values.asNameMap()[code.toLowerCase()] : null;
}

/// Les 14 allergènes à déclaration obligatoire (règlement UE n° 1169/2011),
/// avec les identifiants d'Open Food Facts (les mêmes que le backend).
abstract final class Allergens {
  static const Map<String, String> labels = {
    'gluten': 'Gluten',
    'crustaceans': 'Crustacés',
    'eggs': 'Œufs',
    'fish': 'Poisson',
    'peanuts': 'Arachides',
    'soybeans': 'Soja',
    'milk': 'Lait',
    'nuts': 'Fruits à coque',
    'celery': 'Céleri',
    'mustard': 'Moutarde',
    'sesame-seeds': 'Sésame',
    'sulphur-dioxide-and-sulphites': 'Sulfites',
    'lupin': 'Lupin',
    'molluscs': 'Mollusques',
  };

  static String label(String code) => labels[code] ?? code;
}

/// Code-barres GS1 valide : 8, 12, 13 ou 14 chiffres et clé de contrôle
/// correcte (somme pondérée 3-1-3… depuis la droite, modulo 10). Espaces et
/// tirets sont ignorés, comme côté serveur.
bool isValidBarcode(String value) {
  final code = value.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d+$').hasMatch(code) ||
      !const [8, 12, 13, 14].contains(code.length)) {
    return false;
  }
  final digits = code.split('').map(int.parse).toList();
  final check = digits.removeLast();
  var sum = 0;
  for (final (i, digit) in digits.reversed.indexed) {
    sum += digit * (i.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == check;
}

/// Fiche pré-remplie par Open Food Facts à partir d'un code-barres
/// (`GET /products/lookup/:barcode`). Rien n'est encore enregistré.
class BarcodeProduct {
  const BarcodeProduct({
    required this.barcode,
    this.name = '',
    this.description = '',
    this.imageUrl = '',
    this.calories,
    this.caloriesPer100g = false,
    this.allergens = const [],
    this.nutriScore,
  });

  final String barcode;
  final String name;

  /// « Ferrero · 400 g »
  final String description;
  final String imageUrl;
  final int? calories;

  /// `true` : [calories] pour 100 g (Open Food Facts n'a pas la portion).
  final bool caloriesPer100g;
  final List<String> allergens;
  final NutriScore? nutriScore;

  factory BarcodeProduct.fromJson(Map<String, dynamic> json) => BarcodeProduct(
    barcode: json['barcode'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    calories: (json['calories'] as num?)?.toInt(),
    caloriesPer100g: json['caloriesBasis'] == '100g',
    allergens: parseStrings(json['allergens']),
    nutriScore: NutriScore.fromCode(json['nutriScore']),
  );
}
