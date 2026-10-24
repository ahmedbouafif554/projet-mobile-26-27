import '../../models/category.dart';
import '../base/crud_repository.dart';

/// Catégories de cuisine (Module 2). [getAll] les renvoie dans l'ordre
/// d'affichage.
abstract interface class CategoryRepository
    implements CrudRepository<Category> {
  /// Nouvel ordre d'affichage (glisser-déposer du back office).
  Future<List<Category>> reorder(List<String> orderedIds);
}
