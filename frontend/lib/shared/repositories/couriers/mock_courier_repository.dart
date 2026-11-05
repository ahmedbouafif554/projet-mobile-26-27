import '../../models/courier.dart';
import '../base/mock_crud_repository.dart';
import 'courier_repository.dart';

class MockCourierRepository extends MockCrudRepository<Courier>
    implements CourierRepository {
  MockCourierRepository(super.seed) : super(idPrefix: 'c');

  @override
  String idOf(Courier item) => item.id;

  @override
  Courier withId(Courier item, String id) => item.copyWith(id: id);

  @override
  Future<Courier?> findByUser(String userId) async {
    final found = await where((c) => c.userId == userId);
    return found.isEmpty ? null : found.first;
  }

  @override
  Future<Courier> setStatus(String id, CourierStatus status) =>
      mutate(id, (c) => c.copyWith(status: status));

  @override
  Future<CourierIdentityScan> identityScan(String id) async {
    final courier = await getById(id);
    return CourierIdentityScan(
      courierId: courier.id,
      firstName: courier.firstName,
      lastName: courier.lastName,
      email: '',
      phone: courier.phone,
      documents: [
        for (final doc in courier.documents)
          ScannedDocument(
            type: doc.type,
            label: doc.type.label,
            received: doc.imageData != null && doc.imageData!.length > 32,
            bytes: doc.imageData?.length ?? 0,
            status: doc.status,
            uploadedAt: doc.uploadedAt,
            imageData: doc.imageData,
          ),
      ],
    );
  }

  @override
  Future<Courier> reviewDocuments(String id, DocumentStatus status) => mutate(
    id,
    (c) => c.copyWith(
      documents: [for (final d in c.documents) d.copyWith(status: status)],
    ),
  );
}
