import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/repositories/repository_providers.dart';

// =============================================================================
// Module 2 (front office) : catalogue vu par le client — catégories,
// restaurants validés, menus, favoris, filtres et recherche.
// =============================================================================

/// Catégories visibles, dans l'ordre choisi dans le back office.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final all = await ref.watch(categoryRepositoryProvider).getAll();
  return all.where((c) => c.isActive).toList();
});

/// Restaurants validés (les demandes en attente ne sont pas visibles).
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final all = await ref.watch(restaurantRepositoryProvider).getAll();
  return all.where((r) => r.isVisible).toList();
});

final restaurantProvider = FutureProvider.family<Restaurant, String>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).getById(id),
);

/// Menu d'un restaurant.
final restaurantProductsProvider = FutureProvider.family<List<Product>, String>(
  (ref, restaurantId) =>
      ref.watch(productRepositoryProvider).forRestaurant(restaurantId),
);

final productProvider = FutureProvider.family<Product, String>(
  (ref, id) => ref.watch(productRepositoryProvider).getById(id),
);

/// Restaurants favoris de l'utilisateur (identifiants), avec ajout /
/// retrait optimiste.
final favoritesProvider = AsyncNotifierProvider<FavoritesController, Set<String>>(
  FavoritesController.new,
);

class FavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    if (userId == null) return const {};
    return ref.watch(favoriteRepositoryProvider).getRestaurantIds(userId);
  }

  /// Ajoute ou retire un favori ; renvoie le nouvel état.
  Future<bool> toggle(String restaurantId) async {
    final userId = ref.read(authServiceProvider).user!.id;
    final current = {...?state.value};
    final add = !current.contains(restaurantId);
    add ? current.add(restaurantId) : current.remove(restaurantId);
    state = AsyncData(current);
    final repository = ref.read(favoriteRepositoryProvider);
    add
        ? await repository.add(userId, restaurantId)
        : await repository.remove(userId, restaurantId);
    return add;
  }
}

/// Tri de la liste des restaurants.
enum RestaurantSort {
  recommended('Recommandés'),
  rating('Mieux notés'),
  fastest('Plus rapides'),
  cheapest('Livraison la moins chère');

  const RestaurantSort(this.label);
  final String label;
}

/// Filtres de la liste des restaurants.
class RestaurantFilter {
  const RestaurantFilter({
    this.categoryId,
    this.sort = RestaurantSort.recommended,
    this.freeDelivery = false,
    this.topRated = false,
    this.withPromo = false,
    this.openOnly = false,
  });

  final String? categoryId;
  final RestaurantSort sort;
  final bool freeDelivery;
  final bool topRated;
  final bool withPromo;
  final bool openOnly;

  int get activeCount =>
      [freeDelivery, topRated, withPromo, openOnly].where((b) => b).length +
      (sort == RestaurantSort.recommended ? 0 : 1);

  RestaurantFilter copyWith({
    Object? categoryId = _keep,
    RestaurantSort? sort,
    bool? freeDelivery,
    bool? topRated,
    bool? withPromo,
    bool? openOnly,
  }) => RestaurantFilter(
    categoryId: categoryId == _keep ? this.categoryId : categoryId as String?,
    sort: sort ?? this.sort,
    freeDelivery: freeDelivery ?? this.freeDelivery,
    topRated: topRated ?? this.topRated,
    withPromo: withPromo ?? this.withPromo,
    openOnly: openOnly ?? this.openOnly,
  );

  /// Applique les filtres et le tri.
  List<Restaurant> apply(List<Restaurant> restaurants) {
    final list = restaurants.where((r) {
      if (categoryId != null && !r.categoryIds.contains(categoryId)) {
        return false;
      }
      if (freeDelivery && r.deliveryFee > 0) return false;
      if (topRated && r.rating < 4.5) return false;
      if (withPromo && r.promo == null) return false;
      if (openOnly && !r.isOpen) return false;
      return true;
    }).toList();
    switch (sort) {
      case RestaurantSort.recommended:
        list.sort((a, b) {
          if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
          if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
          return b.rating.compareTo(a.rating);
        });
      case RestaurantSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case RestaurantSort.fastest:
        list.sort((a, b) => a.deliveryMinutes.compareTo(b.deliveryMinutes));
      case RestaurantSort.cheapest:
        list.sort((a, b) => a.deliveryFee.compareTo(b.deliveryFee));
    }
    return list;
  }
}

const _keep = Object();

final restaurantFilterProvider =
    NotifierProvider<RestaurantFilterNotifier, RestaurantFilter>(
      RestaurantFilterNotifier.new,
    );

class RestaurantFilterNotifier extends Notifier<RestaurantFilter> {
  @override
  RestaurantFilter build() => const RestaurantFilter();

  void update(RestaurantFilter filter) => state = filter;

  void reset() => state = const RestaurantFilter();
}

/// Résultat de la recherche : restaurants et plats correspondants.
class SearchResults {
  const SearchResults({required this.restaurants, required this.products});

  final List<Restaurant> restaurants;

  /// Plats avec leur restaurant.
  final List<(Product, Restaurant)> products;

  bool get isEmpty => restaurants.isEmpty && products.isEmpty;
}

/// Recherche (sans accents ni majuscules) dans les restaurants validés et
/// leurs plats disponibles.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>((ref, query) async {
      final q = normalize(query.trim());
      if (q.isEmpty) {
        return const SearchResults(restaurants: [], products: []);
      }
      final (restaurants, products) = await (
        ref.watch(restaurantsProvider.future),
        ref.watch(productRepositoryProvider).getAll(),
      ).wait;
      final byId = {for (final r in restaurants) r.id: r};
      return SearchResults(
        restaurants: [
          for (final r in restaurants)
            if (normalize('${r.name} ${r.cuisine} ${r.description}').contains(q))
              r,
        ],
        products: [
          for (final p in products)
            if (byId.containsKey(p.restaurantId) &&
                normalize('${p.name} ${p.description}').contains(q))
              (p, byId[p.restaurantId]!),
        ],
      );
    });

/// Minuscules sans accents (« Crêpe » → « crepe »).
String normalize(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString();
}

/// Recherches récentes (session).
final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const ['Burger', 'Sushi', 'Pizza'];

  void add(String query) {
    final q = query.trim();
    if (q.length < 2) return;
    state = [q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())]
        .take(6)
        .toList();
  }

  void remove(String query) =>
      state = state.where((s) => s != query).toList();

  void clear() => state = const [];
}
