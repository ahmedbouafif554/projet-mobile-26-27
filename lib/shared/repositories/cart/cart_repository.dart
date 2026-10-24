import '../../models/cart_item.dart';
import '../base/crud_repository.dart';

/// Panier de l'utilisateur connecté (Module 3).
abstract interface class CartRepository implements CrudRepository<CartItem> {
  /// Vide le panier (après la commande).
  Future<void> clear();
}
