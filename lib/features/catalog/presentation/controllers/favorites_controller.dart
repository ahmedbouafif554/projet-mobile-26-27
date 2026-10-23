import 'package:flutter/foundation.dart';

/// Restaurants favoris de l'utilisateur (en mémoire uniquement).
class FavoritesController extends ChangeNotifier {
  FavoritesController._();
  static final FavoritesController instance = FavoritesController._();

  // Quelques favoris par défaut pour la démo.
  final Set<String> _ids = {'r3', 'r4', 'r7'};

  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  bool isFavorite(String restaurantId) => _ids.contains(restaurantId);

  /// Ajoute ou retire un favori. Retourne le nouvel état.
  bool toggle(String restaurantId) {
    final added = _ids.add(restaurantId);
    if (!added) _ids.remove(restaurantId);
    notifyListeners();
    return added;
  }
}
