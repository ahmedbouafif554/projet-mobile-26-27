import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../models/address.dart';
import '../base/api_crud_repository.dart';
import 'address_repository.dart';

class ApiAddressRepository extends ApiCrudRepository<Address>
    implements AddressRepository {
  ApiAddressRepository(super.dio) : super(path: '/addresses');

  @override
  Address fromJson(Map<String, dynamic> json) => Address.fromJson(json);

  @override
  Map<String, dynamic> toJson(Address item) => item.toJson();

  @override
  String idOf(Address item) => item.id;

  @override
  Future<List<Address>> forUser(String userId) =>
      getList('/users/$userId/addresses');

  @override
  Future<List<Address>> setDefault(String userId, String addressId) =>
      runApi(() async {
        final response = await dio.patch('$path/$addressId/default');
        return jsonList(response.data).map(Address.fromJson).toList();
      });
}
