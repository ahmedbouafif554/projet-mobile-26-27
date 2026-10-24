import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../models/category.dart';
import '../base/api_crud_repository.dart';
import 'category_repository.dart';

class ApiCategoryRepository extends ApiCrudRepository<Category>
    implements CategoryRepository {
  ApiCategoryRepository(super.dio) : super(path: '/categories');

  @override
  Category fromJson(Map<String, dynamic> json) => Category.fromJson(json);

  @override
  Map<String, dynamic> toJson(Category item) => item.toJson();

  @override
  String idOf(Category item) => item.id;

  @override
  Future<List<Category>> reorder(List<String> orderedIds) => runApi(() async {
    final response = await dio.put('$path/order', data: {'ids': orderedIds});
    return jsonList(response.data).map(Category.fromJson).toList();
  });
}
