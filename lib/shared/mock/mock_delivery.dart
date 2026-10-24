import '../models/courier.dart';
import '../models/delivery.dart';
import '../models/order.dart';
import 'mock_catalog.dart';
import 'mock_orders.dart';
import 'mock_users.dart';

/// 6 livreurs et les livraisons associées aux commandes mock.
class MockDelivery {
  MockDelivery._();

  static final DateTime _now = DateTime.now();

  static List<CourierDocument> _documents(DocumentStatus status, int daysAgo) =>
      [
        for (final type in DocumentType.values)
          CourierDocument(
            type: type,
            status: status,
            uploadedAt: _now.subtract(Duration(days: daysAgo)),
          ),
      ];

  static final List<Delivery> deliveries = _generate();

  static final List<Courier> couriers = [
    _courier(
      'c-1',
      'u-courier-1',
      'Karim',
      'Benali',
      11,
      VehicleType.scooter,
      'GH-482-PK',
      CourierStatus.busy,
      DocumentStatus.approved,
      4.9,
      280,
      lat: 48.8662,
      lng: 2.3501,
    ),
    _courier(
      'c-2',
      'u-courier-2',
      'Inès',
      'Haddad',
      26,
      VehicleType.bike,
      null,
      CourierStatus.busy,
      DocumentStatus.approved,
      4.8,
      190,
      lat: 48.8575,
      lng: 2.3622,
    ),
    _courier(
      'c-3',
      'u-courier-3',
      'Lucas',
      'Bernard',
      3,
      VehicleType.scooter,
      'FT-219-ZD',
      CourierStatus.available,
      DocumentStatus.approved,
      4.7,
      150,
      lat: 48.8701,
      lng: 2.3399,
    ),
    _courier(
      'c-4',
      'u-courier-4',
      'Yanis',
      'Mansouri',
      7,
      VehicleType.car,
      'EK-903-LM',
      CourierStatus.offline,
      DocumentStatus.approved,
      4.6,
      90,
      lat: 48.8530,
      lng: 2.3455,
    ),
    _courier(
      'c-5',
      'u-courier-5',
      'Chloé',
      'Fontaine',
      29,
      VehicleType.bike,
      null,
      CourierStatus.offline,
      DocumentStatus.rejected,
      4.5,
      40,
      lat: 48.8619,
      lng: 2.3730,
    ),
    _courier(
      'c-6',
      'u-courier-6',
      'Mehdi',
      'Ziani',
      8,
      VehicleType.scooter,
      'HB-117-RT',
      CourierStatus.offline,
      DocumentStatus.pending,
      5,
      4,
      lat: 48.8488,
      lng: 2.3560,
    ),
  ];

  static Courier _courier(
    String id,
    String userId,
    String first,
    String last,
    int avatarNumber,
    VehicleType vehicle,
    String? plate,
    CourierStatus status,
    DocumentStatus documents,
    double rating,
    int joinedDaysAgo, {
    required double lat,
    required double lng,
  }) {
    final done = deliveries.where(
      (d) => d.courierId == id && d.status == DeliveryStatus.delivered,
    );
    return Courier(
      id: id,
      userId: userId,
      firstName: first,
      lastName: last,
      phone: '+33 7 ${50 + avatarNumber} 12 34 ${10 + avatarNumber}',
      avatarUrl: MockUsers.byId(userId).avatarUrl,
      vehicle: vehicle,
      plateNumber: plate,
      status: status,
      documents: _documents(documents, joinedDaysAgo),
      rating: rating,
      // Historique antérieur aux commandes mock + courses livrées.
      completedDeliveries: joinedDaysAgo ~/ 2 + done.length,
      totalEarnings:
          joinedDaysAgo * 6.4 + done.fold<double>(0, (s, d) => s + d.earnings),
      latitude: lat,
      longitude: lng,
      joinedAt: _now.subtract(Duration(days: joinedDaysAgo)),
    );
  }

  /// Une livraison par commande acceptée (sauf annulées) ; les commandes
  /// sans livreur attendent qu'un livreur accepte la course.
  static List<Delivery> _generate() => [
    for (final (i, order) in MockOrders.orders.indexed)
      if (order.status != OrderStatus.pending &&
          order.status != OrderStatus.cancelled)
        _delivery(i, order),
  ];

  static Delivery _delivery(int i, Order order) {
    final restaurant = MockCatalog.restaurantById(order.restaurantId);
    final status = switch (order.status) {
      OrderStatus.delivering => DeliveryStatus.inTransit,
      OrderStatus.delivered || OrderStatus.refunded => DeliveryStatus.delivered,
      _ => DeliveryStatus.waiting,
    };
    final assigned = status != DeliveryStatus.waiting;
    return Delivery(
      id: 'd-${i + 1}',
      orderId: order.id,
      orderReference: order.reference,
      courierId: assigned ? order.courierId ?? 'c-1' : null,
      status: status,
      pickupName: restaurant.name,
      pickupAddress: restaurant.address,
      customerName: order.customerName,
      dropoffAddress: order.deliveryAddress.fullAddress,
      distanceKm: restaurant.distanceKm + (i % 4) * 0.6,
      fee: 3.5 + (i % 5) * 0.6,
      tip: i % 3 == 0 ? 2 : 0,
      estimatedMinutes: restaurant.deliveryMinutes,
      createdAt: order.createdAt,
      assignedAt: assigned
          ? order.createdAt.add(const Duration(minutes: 9))
          : null,
      pickedUpAt: assigned
          ? order.createdAt.add(const Duration(minutes: 22))
          : null,
      deliveredAt: status == DeliveryStatus.delivered
          ? order.createdAt.add(const Duration(minutes: 41))
          : null,
    );
  }
}
