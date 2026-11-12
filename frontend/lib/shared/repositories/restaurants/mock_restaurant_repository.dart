import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../models/restaurant.dart';
import '../base/mock_crud_repository.dart';
import 'restaurant_repository.dart';

class MockRestaurantRepository extends MockCrudRepository<Restaurant>
    implements RestaurantRepository {
  MockRestaurantRepository(super.seed) : super(idPrefix: 'r');

  @override
  String idOf(Restaurant item) => item.id;

  @override
  Restaurant withId(Restaurant item, String id) => item.copyWith(id: id);

  @override
  Future<Restaurant> setStatus(String id, RestaurantStatus status) =>
      mutate(id, (r) => r.copyWith(status: status));

  @override
  Future<List<Restaurant>> getAllNear(LatLng position) async {
    final all = await getAll();
    final located = [
      for (final r in all)
        if (r.hasLocation) (_distanceKm(position, r), r),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final (km, r) in located) _withDistance(r, km),
      for (final r in all)
        if (!r.hasLocation) r,
    ];
  }

  @override
  Future<Restaurant> getByIdNear(String id, LatLng position) async {
    final r = await getById(id);
    return r.hasLocation ? _withDistance(r, _distanceKm(position, r)) : r;
  }

  /// Démo : les adresses sont déjà localisées, rien à redemander.
  @override
  Future<Restaurant> relocate(String id) => getById(id);

  // Même règle que le serveur (module restaurant_catalogue, geo.utils.js).

  static const _includedKm = 2;
  static const _minutesPerKm = 3;

  static double _distanceKm(LatLng from, Restaurant to) {
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(to.latitude! - from.latitude);
    final dLng = rad(to.longitude! - from.longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(from.latitude)) *
            math.cos(rad(to.latitude!)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * 6371 * math.asin(math.min(1, math.sqrt(a)));
  }

  static double _round(double km) => (km * 10).round() / 10;

  static Restaurant _withDistance(Restaurant r, double km) {
    final extraKm = math.max(0.0, _round(km) - _includedKm);
    return r.copyWith(
      distanceKm: _round(km),
      estimatedMinutes:
          r.deliveryMinutes + _round(extraKm * _minutesPerKm).ceil(),
    );
  }
}
