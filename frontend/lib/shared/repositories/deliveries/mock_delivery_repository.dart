import '../../models/delivery.dart';
import '../base/mock_crud_repository.dart';
import 'delivery_repository.dart';

class MockDeliveryRepository extends MockCrudRepository<Delivery>
    implements DeliveryRepository {
  MockDeliveryRepository(super.seed) : super(idPrefix: 'd');

  @override
  String idOf(Delivery item) => item.id;

  @override
  Delivery withId(Delivery item, String id) => item.copyWith(id: id);

  @override
  Future<List<Delivery>> forCourier(String courierId) async =>
      (await where((d) => d.courierId == courierId))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Delivery>> available() =>
      where((d) => d.status == DeliveryStatus.waiting && d.courierId == null);

  @override
  Future<Delivery> assign(String id, String courierId) => mutate(
    id,
    (d) => d.copyWith(
      courierId: courierId,
      status: DeliveryStatus.assigned,
      assignedAt: DateTime.now(),
    ),
  );

  /// Horodate les étapes de la course.
  @override
  Future<Delivery> updateStatus(String id, DeliveryStatus status) {
    final now = DateTime.now();
    return mutate(
      id,
      (d) => d.copyWith(
        status: status,
        pickedUpAt: status == DeliveryStatus.pickedUp ? now : d.pickedUpAt,
        deliveredAt: status == DeliveryStatus.delivered ? now : d.deliveredAt,
      ),
    );
  }
}
