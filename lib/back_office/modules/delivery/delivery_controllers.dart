import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/repositories/couriers/courier_repository.dart';
import '../../../shared/repositories/deliveries/delivery_repository.dart';
import '../../../shared/repositories/repository_providers.dart';
import '../../shared/entity_list_controller.dart';
import '../orders/orders_controller.dart';

/// Livreurs (Module 4, admin) : CRUD, justificatifs et statut en ligne.
final couriersControllerProvider =
    AsyncNotifierProvider<CouriersController, List<Courier>>(
      CouriersController.new,
    );

class CouriersController extends EntityListController<Courier> {
  @override
  CourierRepository get repository => ref.read(courierRepositoryProvider);

  Future<void> setStatus(Courier courier, CourierStatus status) =>
      run(() => repository.setStatus(courier.id, status));

  Future<void> reviewDocuments(Courier courier, DocumentStatus status) =>
      run(() => repository.reviewDocuments(courier.id, status));
}

/// Livraisons (Module 4, admin) : assignation et statut des courses.
final deliveriesControllerProvider =
    AsyncNotifierProvider<DeliveriesController, List<Delivery>>(
      DeliveriesController.new,
    );

class DeliveriesController extends EntityListController<Delivery> {
  @override
  DeliveryRepository get repository => ref.read(deliveryRepositoryProvider);

  @override
  Future<List<Delivery>> load() async =>
      (await repository.getAll())
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Assigne un livreur, qui passe « en livraison ». La commande suivra quand
  /// la course sera récupérée ([updateStatus]).
  Future<void> assign(Delivery delivery, Courier courier) => run(() async {
    await repository.assign(delivery.id, courier.id);
    await ref
        .read(courierRepositoryProvider)
        .setStatus(courier.id, CourierStatus.busy);
    ref.invalidate(couriersControllerProvider);
  });

  /// Nouveau statut de course, répercuté sur la commande.
  Future<void> updateStatus(Delivery delivery, DeliveryStatus status) =>
      run(() async {
        await repository.updateStatus(delivery.id, status);
        final orderStatus = switch (status) {
          DeliveryStatus.pickedUp ||
          DeliveryStatus.inTransit => OrderStatus.delivering,
          DeliveryStatus.delivered => OrderStatus.delivered,
          _ => null,
        };
        if (orderStatus != null) {
          await ref
              .read(orderRepositoryProvider)
              .updateStatus(delivery.orderId, orderStatus);
          ref.invalidate(ordersControllerProvider);
        }
        // Course terminée ou annulée : le livreur redevient disponible ; une
        // livraison réussie s'ajoute à ses statistiques.
        final courierId = delivery.courierId;
        if (courierId != null &&
            (status == DeliveryStatus.delivered ||
                status == DeliveryStatus.cancelled)) {
          final couriers = ref.read(courierRepositoryProvider);
          final courier = await couriers.getById(courierId);
          final delivered = status == DeliveryStatus.delivered;
          await couriers.update(
            courier.copyWith(
              status: CourierStatus.available,
              completedDeliveries:
                  courier.completedDeliveries + (delivered ? 1 : 0),
              totalEarnings:
                  courier.totalEarnings + (delivered ? delivery.earnings : 0),
            ),
          );
          ref.invalidate(couriersControllerProvider);
        }
      });
}
