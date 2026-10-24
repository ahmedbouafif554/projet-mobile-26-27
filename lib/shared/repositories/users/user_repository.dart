import '../../models/user.dart';
import '../base/crud_repository.dart';

/// Utilisateurs de la plateforme (Module 1).
abstract interface class UserRepository implements CrudRepository<User> {
  /// Compte associé à un e-mail (connexion), ou null.
  Future<User?> findByEmail(String email);

  /// Bloquer / débloquer un compte.
  Future<User> setStatus(String id, UserStatus status);

  /// Gestion des rôles (back office).
  Future<User> setRole(String id, UserRole role);
}
