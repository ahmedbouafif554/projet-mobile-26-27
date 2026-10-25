import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/base/crud_repository.dart';

/// Contrôleur générique des pages de gestion (tableaux CRUD) : charge la
/// liste depuis le dépôt et la recharge après chaque modification.
///
/// ```dart
/// class UsersController extends EntityListController<User> {
///   @override
///   CrudRepository<User> get repository => ref.read(userRepositoryProvider);
/// }
/// ```
abstract class EntityListController<T> extends AsyncNotifier<List<T>> {
  CrudRepository<T> get repository;

  /// Chargement (à redéfinir pour filtrer, ex. le menu d'un restaurant).
  Future<List<T>> load() => repository.getAll();

  @override
  Future<List<T>> build() => load();

  /// Recharge la liste (sans vider l'affichage pendant le chargement).
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// Crée ([isNew]) ou modifie un élément.
  Future<T> save(T item, {required bool isNew}) async {
    final saved = isNew
        ? await repository.create(item)
        : await repository.update(item);
    await reload();
    return saved;
  }

  Future<void> remove(String id) async {
    await repository.delete(id);
    await reload();
  }

  /// Exécute une action du dépôt (bloquer, valider…) puis recharge.
  Future<R> run<R>(Future<R> Function() action) async {
    final result = await action();
    await reload();
    return result;
  }
}
