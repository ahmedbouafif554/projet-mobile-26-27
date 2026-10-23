/// Une option sélectionnable (taille, supplément...).
class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    this.extraPrice = 0,
  });

  final String id;
  final String name;

  /// Surcoût ajouté au prix de base.
  final double extraPrice;
}

/// Groupe d'options : « Taille » (choix unique) ou « Suppléments » (multiple).
class ProductOptionGroup {
  const ProductOptionGroup({
    required this.id,
    required this.title,
    required this.options,
    this.allowMultiple = false,
    this.isRequired = false,
  });

  final String id;
  final String title;
  final List<ProductOption> options;
  final bool allowMultiple;
  final bool isRequired;
}

/// Article de menu.
class Product {
  const Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.section,
    this.isPopular = false,
    this.calories,
    this.optionGroups = const [],
  });

  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final String imageUrl;
  final double price;

  /// Onglet du menu dans lequel l'article est rangé.
  final String section;
  final bool isPopular;
  final int? calories;
  final List<ProductOptionGroup> optionGroups;
}
