import 'json_utils.dart';
import 'product.dart';

/// Ligne du panier (et ligne d'une commande) : produit, options et quantité.
class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.options = const [],
    this.note,
  });

  final String id;

  /// Copie du produit au moment de l'ajout (prix figé dans la commande).
  final Product product;
  final int quantity;
  final List<ProductOption> options;
  final String? note;

  /// Deux lignes identiques (même produit, mêmes options, même note)
  /// sont fusionnées dans le panier.
  String get mergeKey {
    final ids = [for (final o in options) o.id]..sort();
    return '${product.id}|${ids.join(',')}|${note ?? ''}';
  }

  double get unitPrice =>
      product.price + options.fold<double>(0, (sum, o) => sum + o.price);

  double get totalPrice => unitPrice * quantity;

  /// « Grand, Bacon croustillant »
  String get optionsLabel => [for (final o in options) o.name].join(', ');

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'] as String,
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: parseInt(json['quantity'], 1),
    options: parseList(json['options'], ProductOption.fromJson),
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'product': product.toJson(),
    'quantity': quantity,
    'options': [for (final o in options) o.toJson()],
    'note': note,
  };

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    List<ProductOption>? options,
    Object? note = keep,
  }) => CartItem(
    id: id ?? this.id,
    product: product ?? this.product,
    quantity: quantity ?? this.quantity,
    options: options ?? this.options,
    note: note == keep ? this.note : note as String?,
  );
}
