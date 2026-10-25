import '../../models/address.dart';
import '../base/crud_repository.dart';

/// Adresses de livraison des utilisateurs (Module 1).
abstract interface class AddressRepository implements CrudRepository<Address> {
  Future<List<Address>> forUser(String userId);

  /// Définit l'adresse par défaut et renvoie les adresses de l'utilisateur.
  Future<List<Address>> setDefault(String userId, String addressId);
}
