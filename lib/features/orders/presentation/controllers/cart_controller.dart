import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../catalog/data/catalog_mock_data.dart';
import '../../data/orders_mock_data.dart';
import '../../models/cart_item.dart';
import '../../models/promo_code.dart';

/// État du panier (en mémoire).
///
/// Les widgets l'écoutent via `ListenableBuilder(listenable: CartController.instance)`.
class CartController extends ChangeNotifier {
  CartController();

  /// Instance partagée par toute l'application.
  static final CartController instance = CartController();

  final List<CartItem> _items = [];
  PromoCode? _promo;

  List<CartItem> get items => List.unmodifiable(_items);
  PromoCode? get promo => _promo;
  bool get isEmpty => _items.isEmpty;

  /// Nombre total d'articles (quantités cumulées) pour le badge.
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0, (sum, i) => sum + i.totalPrice);

  /// Frais de livraison du (premier) restaurant du panier.
  double get deliveryFee {
    if (isEmpty || _promo?.type == PromoType.freeDelivery) return 0;
    return CatalogMockData.restaurantById(
      _items.first.product.restaurantId,
    ).deliveryFee;
  }

  double get serviceFee => isEmpty ? 0 : OrdersMockData.serviceFee;

  double get discount => _promo?.discountOn(subtotal) ?? 0;

  double get total =>
      math.max(0, subtotal + deliveryFee + serviceFee - discount);

  /// Ajoute un article ; fusionne avec une ligne identique si elle existe.
  void add(CartItem item) {
    final index = _items.indexWhere((i) => i.key == item.key);
    if (index >= 0) {
      final existing = _items[index];
      _items[index] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void updateQuantity(String key, int quantity) {
    final index = _items.indexWhere((i) => i.key == key);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  /// Supprime une ligne et retourne sa position (pour « Annuler »).
  int remove(String key) {
    final index = _items.indexWhere((i) => i.key == key);
    if (index >= 0) {
      _items.removeAt(index);
      if (_items.isEmpty) _promo = null;
      notifyListeners();
    }
    return index;
  }

  /// Réinsère une ligne supprimée à sa position d'origine.
  void restore(CartItem item, int index) {
    _items.insert(index.clamp(0, _items.length), item);
    notifyListeners();
  }

  /// Applique un code promo. Retourne `false` si le code est inconnu.
  bool applyPromo(String code) {
    final promo = OrdersMockData.findPromo(code);
    if (promo == null) return false;
    _promo = promo;
    notifyListeners();
    return true;
  }

  void removePromo() {
    _promo = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _promo = null;
    notifyListeners();
  }
}
