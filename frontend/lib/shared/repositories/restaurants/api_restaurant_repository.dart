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
}
