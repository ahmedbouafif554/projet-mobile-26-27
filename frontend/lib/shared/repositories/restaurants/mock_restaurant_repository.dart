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
}
