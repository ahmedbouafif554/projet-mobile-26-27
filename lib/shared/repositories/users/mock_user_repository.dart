import '../../models/user.dart';
import '../base/mock_crud_repository.dart';
import 'user_repository.dart';

class MockUserRepository extends MockCrudRepository<User>
    implements UserRepository {
  MockUserRepository(super.seed) : super(idPrefix: 'u');

  @override
  String idOf(User item) => item.id;

  @override
  User withId(User item, String id) => item.copyWith(id: id);

  @override
  Future<User?> findByEmail(String email) async {
    await latency();
    final wanted = email.trim().toLowerCase();
    for (final user in items) {
      if (user.email.toLowerCase() == wanted) return user;
    }
    return null;
  }

  @override
  Future<User> setStatus(String id, UserStatus status) =>
      mutate(id, (u) => u.copyWith(status: status));

  @override
  Future<User> setRole(String id, UserRole role) =>
      mutate(id, (u) => u.copyWith(role: role));
}
