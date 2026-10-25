import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/categories/category_repository.dart';
import '../../../shared/repositories/products/product_repository.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../../shared/repositories/restaurants/restaurant_repository.dart';
import '../../shared/entity_list_controller.dart';
import '../users/users_controller.dart';

/// Restaurants (Module 2, admin) : CRUD et validation des inscriptions.
final restaurantsControllerProvider =
    AsyncNotifierProvider<RestaurantsController, List<Restaurant>>(
      RestaurantsController.new,
    );

class RestaurantsController extends EntityListController<Restaurant> {
  @override
  RestaurantRepository get repository => ref.read(restaurantRepositoryProvider);

  /// Valide, refuse ou suspend un restaurant. Le compte du restaurateur suit :
  /// actif une fois validé, bloqué s'il est refusé ou suspendu.
  Future<void> setStatus(Restaurant restaurant, RestaurantStatus status) =>
      run(() async {
        await repository.setStatus(restaurant.id, status);
        final ownerId = restaurant.ownerId;
        if (ownerId == null) return;
        final users = ref.read(userRepositoryProvider);
        try {
          await users.setStatus(ownerId, switch (status) {
            RestaurantStatus.approved => UserStatus.active,
            RestaurantStatus.pending => UserStatus.pending,
            RestaurantStatus.rejected ||
            RestaurantStatus.suspended => UserStatus.blocked,
          });
        } on ApiException {
          // Compte supprimé entre-temps : rien à synchroniser.
        }
        ref.invalidate(usersControllerProvider);
      });
}

/// Catégories (Module 2, admin) : CRUD et ordre d'affichage.
final categoriesControllerProvider =
    AsyncNotifierProvider<CategoriesController, List<Category>>(
      CategoriesController.new,
    );

class CategoriesController extends EntityListController<Category> {
  @override
  CategoryRepository get repository => ref.read(categoryRepositoryProvider);

  /// Déplace une catégorie (glisser-déposer) et enregistre le nouvel ordre.
  Future<void> move(int oldIndex, int newIndex) async {
    final list = [...?state.value];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    // Affichage immédiat, puis enregistrement.
    state = AsyncData([
      for (final (i, c) in list.indexed) c.copyWith(position: i),
    ]);
    await repository.reorder([for (final c in list) c.id]);
  }
}

/// Produits (Module 2) : tous pour l'admin, ceux de son restaurant pour un
/// restaurateur.
final productsControllerProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
      ProductsController.new,
    );

class ProductsController extends EntityListController<Product> {
  @override
  ProductRepository get repository => ref.read(productRepositoryProvider);

  /// Restaurant du restaurateur connecté (null pour l'admin).
  String? get scope {
    final user = ref.read(authServiceProvider).user;
    return user?.role == UserRole.restaurant ? user?.restaurantId : null;
  }

  @override
  Future<List<Product>> build() {
    ref.watch(authServiceProvider.select((a) => a.user?.id));
    return load();
  }

  @override
  Future<List<Product>> load() {
    final restaurantId = scope;
    return restaurantId == null
        ? repository.getAll()
        : repository.forRestaurant(restaurantId);
  }

  Future<void> setAvailability(Product product, bool isAvailable) async {
    // Mise à jour optimiste de l'interrupteur.
    state = AsyncData([
      for (final p in state.value ?? const <Product>[])
        p.id == product.id ? p.copyWith(isAvailable: isAvailable) : p,
    ]);
    await repository.setAvailability(product.id, isAvailable);
  }
}
