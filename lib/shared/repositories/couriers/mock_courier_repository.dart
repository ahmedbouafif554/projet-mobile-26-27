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
  Future<Courier> reviewDocuments(String id, DocumentStatus status) => mutate(
    id,
    (c) => c.copyWith(
      documents: [for (final d in c.documents) d.copyWith(status: status)],
    ),
  );
}
