import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../models/restaurant.dart';
import '../base/api_crud_repository.dart';
import 'restaurant_repository.dart';

class ApiRestaurantRepository extends ApiCrudRepository<Restaurant>
    implements RestaurantRepository {
  ApiRestaurantRepository(super.dio) : super(path: '/restaurants');

  @override
  Restaurant fromJson(Map<String, dynamic> json) => Restaurant.fromJson(json);

  @override
  Map<String, dynamic> toJson(Restaurant item) => item.toJson();

  @override
  String idOf(Restaurant item) => item.id;

  @override
  Future<Restaurant> setStatus(String id, RestaurantStatus status) =>
      patch(id, 'status', {'status': status.name});

  /// `?latitude=&longitude=` : le serveur calcule distance et délai.
  static Map<String, dynamic> _near(LatLng position) => {
    'latitude': position.latitude,
    'longitude': position.longitude,
  };

  @override
  Future<List<Restaurant>> getAllNear(LatLng position) =>
      getList(path, query: _near(position));

  @override
  Future<Restaurant> getByIdNear(String id, LatLng position) =>
      runApi(() async {
        final response = await dio.get(
          '$path/$id',
          queryParameters: _near(position),
        );
        return fromJson(jsonMap(response.data));
      });

  @override
  Future<Restaurant> relocate(String id) => runApi(() async {
    final response = await dio.post('$path/$id/geocode');
    return fromJson(jsonMap(response.data));
  });
}
