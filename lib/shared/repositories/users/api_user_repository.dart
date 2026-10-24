import '../../../core/network/api_exception.dart';
import '../../models/user.dart';
import '../base/api_crud_repository.dart';
import 'user_repository.dart';

class ApiUserRepository extends ApiCrudRepository<User>
    implements UserRepository {
  ApiUserRepository(super.dio) : super(path: '/users');

  @override
  User fromJson(Map<String, dynamic> json) => User.fromJson(json);

  @override
  Map<String, dynamic> toJson(User item) => item.toJson();

  @override
  String idOf(User item) => item.id;

  @override
  Future<User?> findByEmail(String email) async {
    try {
      final users = await getList(path, query: {'email': email});
      return users.isEmpty ? null : users.first;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<User> setStatus(String id, UserStatus status) =>
      patch(id, 'status', {'status': status.name});

  @override
  Future<User> setRole(String id, UserRole role) =>
      patch(id, 'role', {'role': role.name});
}
