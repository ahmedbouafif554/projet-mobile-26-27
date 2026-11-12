import 'package:latlong2/latlong.dart';

import '../../models/restaurant.dart';
import '../base/crud_repository.dart';

/// Restaurants et commerces (Module 2).
abstract interface class RestaurantRepository
    implements CrudRepository<Restaurant> {
  /// Valider / refuser une demande d'inscription, suspendre un restaurant.
  Future<Restaurant> setStatus(String id, RestaurantStatus status);

  /// Tous les restaurants, avec la distance réelle et le délai estimé depuis
  /// [position] (client), du plus proche au plus loin. Ceux dont l'adresse
  /// n'est pas localisée suivent, sans distance calculée.
  Future<List<Restaurant>> getAllNear(LatLng position);

  /// Fiche d'un restaurant avec sa distance depuis [position].
  Future<Restaurant> getByIdNear(String id, LatLng position);

  /// Relocalise l'adresse sur la carte (OpenStreetMap).
  Future<Restaurant> relocate(String id);
}
