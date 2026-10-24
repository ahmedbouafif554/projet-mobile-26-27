import '../../models/courier.dart';
import '../base/api_crud_repository.dart';
import 'courier_repository.dart';

class ApiCourierRepository extends ApiCrudRepository<Courier>
    implements CourierRepository {
  ApiCourierRepository(super.dio) : super(path: '/couriers');

  @override
  Courier fromJson(Map<String, dynamic> json) => Courier.fromJson(json);

  @override
  Map<String, dynamic> toJson(Courier item) => item.toJson();

  @override
  String idOf(Courier item) => item.id;

  @override
  Future<Courier?> findByUser(String userId) async {
    final couriers = await getList(path, query: {'userId': userId});
    return couriers.isEmpty ? null : couriers.first;
  }

  @override
  Future<Courier> setStatus(String id, CourierStatus status) =>
      patch(id, 'status', {'status': status.name});

  @override
  Future<Courier> reviewDocuments(String id, DocumentStatus status) =>
      patch(id, 'documents', {'status': status.name});
}
