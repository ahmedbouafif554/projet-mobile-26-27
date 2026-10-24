import '../../models/courier.dart';
import '../base/crud_repository.dart';

/// Livreurs partenaires (Module 4).
abstract interface class CourierRepository implements CrudRepository<Courier> {
  /// Profil livreur d'un compte utilisateur, ou null.
  Future<Courier?> findByUser(String userId);

  /// Disponible / hors ligne / en livraison.
  Future<Courier> setStatus(String id, CourierStatus status);

  /// Valide ou refuse tous les justificatifs du livreur.
  Future<Courier> reviewDocuments(String id, DocumentStatus status);
}
