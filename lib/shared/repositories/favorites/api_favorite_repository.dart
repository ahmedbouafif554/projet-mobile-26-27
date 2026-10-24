import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'favorite_repository.dart';

class ApiFavoriteRepository implements FavoriteRepository {
  ApiFavoriteRepository(this._dio);

  final Dio _dio;

  @override
  Future<Set<String>> getRestaurantIds(String userId) => runApi(() async {
    final response = await _dio.get('/users/$userId/favorites');
    return {for (final id in unwrapData(response.data) as List) id as String};
  });

  @override
  Future<void> add(String userId, String restaurantId) =>
      runApi(() => _dio.put<void>('/users/$userId/favorites/$restaurantId'));

  @override
  Future<void> remove(String userId, String restaurantId) =>
      runApi(() => _dio.delete<void>('/users/$userId/favorites/$restaurantId'));
}
