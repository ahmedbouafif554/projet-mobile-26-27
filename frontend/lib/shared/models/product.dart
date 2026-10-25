import 'json_utils.dart';

/// Choix possible dans un groupe d'options (« Grand », « Bacon »…).
class ProductOption {
  const ProductOption({required this.id, required this.name, this.price = 0});

  final String id;
  final String name;

  /// Supplément ajouté au prix du produit.
  final double price;

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
    id: json['id'] as String,
    name: json['name'] as String,
    price: parseDouble(json['price']),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  ProductOption copyWith({String? id, String? name, double? price}) =>
      ProductOption(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
      );
}

/// Groupe d'options d'un produit : choix unique (taille) ou multiple
/// (suppléments).
class ProductOptionGroup {
  const ProductOptionGroup({
    required this.id,
    required this.name,
    this.isRequired = false,
    this.maxChoices = 1,
    required this.options,
  });

  final String id;
  final String name;
  final bool isRequired;

  /// 1 = choix unique, plus = choix multiples.
  final int maxChoices;
  final List<ProductOption> options;

  bool get isMultiple => maxChoices > 1;

  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) =>
      ProductOptionGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        isRequired: json['isRequired'] as bool? ?? false,
        maxChoices: parseInt(json['maxChoices'], 1),
        options: parseList(json['options'], ProductOption.fromJson),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isRequired': isRequired,
    'maxChoices': maxChoices,
    'options': [for (final o in options) o.toJson()],
  };

  ProductOptionGroup copyWith({
    String? id,
    String? name,
    bool? isRequired,
    int? maxChoices,
    List<ProductOption>? options,
  }) => ProductOptionGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    isRequired: isRequired ?? this.isRequired,
    maxChoices: maxChoices ?? this.maxChoices,
    options: options ?? this.options,
  );
}

/// Plat ou article proposé par un restaurant.
class Product {
  const Product({
    required this.id,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.section,
    this.optionGroups = const [],
    this.isAvailable = true,
    this.isPopular = false,
    this.calories,
  });

  final String id;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  /// Onglet du menu (« Burgers », « Boissons »…).
  final String section;
  final List<ProductOptionGroup> optionGroups;

  /// `false` : en rupture (interrupteur du back office).
  final bool isAvailable;
  final bool isPopular;
  final int? calories;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    restaurantId: json['restaurantId'] as String,
    categoryId: json['categoryId'] as String? ?? '',
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    price: parseDouble(json['price']),
    imageUrl: json['imageUrl'] as String? ?? '',
    section: json['section'] as String? ?? '',
    optionGroups: parseList(json['optionGroups'], ProductOptionGroup.fromJson),
    isAvailable: json['isAvailable'] as bool? ?? true,
    isPopular: json['isPopular'] as bool? ?? false,
    calories: (json['calories'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurantId': restaurantId,
    'categoryId': categoryId,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'section': section,
    'optionGroups': [for (final g in optionGroups) g.toJson()],
    'isAvailable': isAvailable,
    'isPopular': isPopular,
    'calories': calories,
  };

  Product copyWith({
    String? id,
    String? restaurantId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? section,
    List<ProductOptionGroup>? optionGroups,
    bool? isAvailable,
    bool? isPopular,
    Object? calories = keep,
  }) => Product(
    id: id ?? this.id,
    restaurantId: restaurantId ?? this.restaurantId,
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    imageUrl: imageUrl ?? this.imageUrl,
    section: section ?? this.section,
    optionGroups: optionGroups ?? this.optionGroups,
    isAvailable: isAvailable ?? this.isAvailable,
    isPopular: isPopular ?? this.isPopular,
    calories: calories == keep ? this.calories : calories as int?,
  );
}
