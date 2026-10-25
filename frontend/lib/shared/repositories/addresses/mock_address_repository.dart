import '../../models/address.dart';
import '../base/mock_crud_repository.dart';
import 'address_repository.dart';

class MockAddressRepository extends MockCrudRepository<Address>
    implements AddressRepository {
  MockAddressRepository(super.seed) : super(idPrefix: 'a');

  @override
  String idOf(Address item) => item.id;

  @override
  Address withId(Address item, String id) => item.copyWith(id: id);

  @override
  Future<List<Address>> forUser(String userId) =>
      where((a) => a.userId == userId);

  @override
  Future<List<Address>> setDefault(String userId, String addressId) async {
    await latency();
    replaceAll([
      for (final a in items)
        a.userId == userId ? a.copyWith(isDefault: a.id == addressId) : a,
    ]);
    return items.where((a) => a.userId == userId).toList();
  }
}
