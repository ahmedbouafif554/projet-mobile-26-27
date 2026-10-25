import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../shared/models/models.dart';
import '../../../shared/repositories/orders/order_repository.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../shared/entity_list_controller.dart';
import '../delivery/delivery_controllers.dart';

/// Commandes (Module 3) : toutes pour l'admin, celles de son restaurant pour
/// un restaurateur (commandes reçues, cuisine).
final ordersControllerProvider =
    AsyncNotifierProvider<OrdersController, List<Order>>(OrdersController.new);

class OrdersController extends EntityListController<Order> {
  @override
  OrderRepository get repository => ref.read(orderRepositoryProvider);

  @override
  Future<List<Order>> build() {
    ref.watch(authServiceProvider.select((a) => a.user?.id));
    return load();
  }

  @override
  Future<List<Order>> load() {
    final user = ref.read(authServiceProvider).user;
    final restaurantId = user?.role == UserRole.restaurant
        ? user?.restaurantId
        : null;
    return restaurantId == null
        ? repository.getAll()
        : repository.forRestaurant(restaurantId);
  }

  /// Nouveau statut. Une commande prête crée la course à assigner.
  Future<void> updateStatus(Order order, OrderStatus status, {String? note}) =>
      run(() async {
        await repository.updateStatus(order.id, status, note: note);
        if (status == OrderStatus.ready) await _ensureDelivery(order);
      });

  Future<void> cancel(Order order, String reason) =>
      run(() => repository.cancel(order.id, reason));

  Future<void> refund(Order order) => run(() => repository.refund(order.id));

  /// Course « à assigner » pour une commande prête (si elle n'existe pas).
  Future<void> _ensureDelivery(Order order) async {
    final deliveries = ref.read(deliveryRepositoryProvider);
    final existing = await deliveries.getAll();
    if (existing.any((d) => d.orderId == order.id)) return;
    final restaurant = await ref
        .read(restaurantRepositoryProvider)
        .getById(order.restaurantId);
    await deliveries.create(
      Delivery(
        id: '',
        orderId: order.id,
        orderReference: order.reference,
        pickupName: restaurant.name,
        pickupAddress: restaurant.address,
        customerName: order.customerName,
        dropoffAddress: order.deliveryAddress.fullAddress,
        distanceKm: restaurant.distanceKm,
        fee: 3.5 + restaurant.distanceKm * 0.8,
        estimatedMinutes: restaurant.deliveryMinutes,
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidate(deliveriesControllerProvider);
  }
}
