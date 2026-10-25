import '../../models/restaurant.dart';
import '../base/crud_repository.dart';

/// Restaurants et commerces (Module 2).
abstract interface class RestaurantRepository
    implements CrudRepository<Restaurant> {
  /// Valider / refuser une demande d'inscription, suspendre un restaurant.
  Future<Restaurant> setStatus(String id, RestaurantStatus status);
}
