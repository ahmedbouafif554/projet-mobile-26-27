import '../../models/delivery.dart';
import '../base/crud_repository.dart';

/// Livraisons (Module 4).
abstract interface class DeliveryRepository
    implements CrudRepository<Delivery> {
  Future<List<Delivery>> forCourier(String courierId);

  /// Courses en attente d'un livreur (« commandes à accepter »).
  Future<List<Delivery>> available();

  /// Assigne un livreur (back office) ou accepte une course (livreur).
  Future<Delivery> assign(String id, String courierId);

  Future<Delivery> updateStatus(String id, DeliveryStatus status);
}
