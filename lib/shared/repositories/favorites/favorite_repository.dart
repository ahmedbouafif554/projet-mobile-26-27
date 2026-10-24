/// Restaurants favoris d'un utilisateur (Module 2).
abstract interface class FavoriteRepository {
  Future<Set<String>> getRestaurantIds(String userId);

  Future<void> add(String userId, String restaurantId);

  Future<void> remove(String userId, String restaurantId);
}
