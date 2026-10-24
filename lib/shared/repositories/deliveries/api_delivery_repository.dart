import '../../models/delivery.dart';
import '../base/api_crud_repository.dart';
import 'delivery_repository.dart';

class ApiDeliveryRepository extends ApiCrudRepository<Delivery>
    implements DeliveryRepository {
  ApiDeliveryRepository(super.dio) : super(path: '/deliveries');

  @override
  Delivery fromJson(Map<String, dynamic> json) => Delivery.fromJson(json);

  @override
  Map<String, dynamic> toJson(Delivery item) => item.toJson();

  @override
  String idOf(Delivery item) => item.id;

  @override
  Future<List<Delivery>> forCourier(String courierId) =>
      getList(path, query: {'courierId': courierId});

  @override
  Future<List<Delivery>> available() =>
      getList(path, query: {'status': DeliveryStatus.waiting.name});

  @override
  Future<Delivery> assign(String id, String courierId) =>
      patch(id, 'assign', {'courierId': courierId});

  @override
  Future<Delivery> updateStatus(String id, DeliveryStatus status) =>
      patch(id, 'status', {'status': status.name});
}
