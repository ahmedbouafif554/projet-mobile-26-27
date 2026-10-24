import '../../../core/config/app_config.dart';
import 'favorite_repository.dart';

class MockFavoriteRepository implements FavoriteRepository {
  MockFavoriteRepository(Map<String, Set<String>> seed)
    : _byUser = {
        for (final e in seed.entries) e.key: {...e.value},
      };

  final Map<String, Set<String>> _byUser;

  Future<void> _latency() => Future.delayed(AppConfig.mockLatencyMin);

  @override
  Future<Set<String>> getRestaurantIds(String userId) async {
    await _latency();
    return {...?_byUser[userId]};
  }

  @override
  Future<void> add(String userId, String restaurantId) async {
    await _latency();
    _byUser.putIfAbsent(userId, () => {}).add(restaurantId);
  }

  @override
  Future<void> remove(String userId, String restaurantId) async {
    await _latency();
    _byUser[userId]?.remove(restaurantId);
  }
}
