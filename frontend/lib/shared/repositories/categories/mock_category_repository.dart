import '../../models/category.dart';
import '../base/mock_crud_repository.dart';
import 'category_repository.dart';

class MockCategoryRepository extends MockCrudRepository<Category>
    implements CategoryRepository {
  MockCategoryRepository(super.seed) : super(idPrefix: 'cat');

  @override
  String idOf(Category item) => item.id;

  /// Une nouvelle catégorie se place en dernier.
  @override
  Category withId(Category item, String id) =>
      item.copyWith(id: id, position: items.length);

  @override
  Future<List<Category>> getAll() async =>
      (await super.getAll())..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<List<Category>> reorder(List<String> orderedIds) async {
    await latency();
    final byId = {for (final c in items) c.id: c};
    replaceAll([
      for (final (i, id) in orderedIds.indexed)
        if (byId[id] != null) byId[id]!.copyWith(position: i),
    ]);
    return items;
  }
}
