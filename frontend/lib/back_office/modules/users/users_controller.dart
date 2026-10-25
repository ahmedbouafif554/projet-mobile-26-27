import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../../shared/repositories/users/user_repository.dart';
import '../../shared/entity_list_controller.dart';

/// Utilisateurs (Module 1, admin) : CRUD, blocage et rôles.
final usersControllerProvider =
    AsyncNotifierProvider<UsersController, List<User>>(UsersController.new);

class UsersController extends EntityListController<User> {
  @override
  UserRepository get repository => ref.read(userRepositoryProvider);

  Future<void> setStatus(User user, UserStatus status) =>
      run(() => repository.setStatus(user.id, status));

  Future<void> setRole(User user, UserRole role) =>
      run(() => repository.setRole(user.id, role));
}
