import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/repositories/repository_providers.dart';

// =============================================================================
// Module 4 (front office) : espace livreur — profil, disponibilité, courses
// proposées, course en cours et historique.
// =============================================================================

/// Profil livreur du compte connecté (null si absent).
final myCourierProvider = AsyncNotifierProvider<MyCourierController, Courier?>(
  MyCourierController.new,
);

class MyCourierController extends AsyncNotifier<Courier?> {
  @override
  Future<Courier?> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    if (userId == null) return null;
    return ref.watch(courierRepositoryProvider).findByUser(userId);
  }

  /// En ligne / hors ligne (impossible pendant une course).
  Future<void> setOnline(bool online) async {
    final courier = state.value;
    if (courier == null) return;
    if (courier.status == CourierStatus.busy) {
      throw const ApiException('Terminez votre course avant de vous déconnecter.');
    }
    if (online && courier.documentStatus != DocumentStatus.approved) {
      throw const ApiException(
        'Vos justificatifs doivent être validés avant de recevoir des courses.',
      );
    }
    final status = online ? CourierStatus.available : CourierStatus.offline;
    state = AsyncData(courier.copyWith(status: status));
    await ref.read(courierRepositoryProvider).setStatus(courier.id, status);
  }

  /// Véhicule et zone (CRUD du profil livreur).
  Future<void> save(Courier courier) async {
    final saved = await ref.read(courierRepositoryProvider).update(courier);
    state = AsyncData(saved);
  }

  /// Nouvel envoi d'un justificatif (repasse « à vérifier »).
  Future<void> resubmit(DocumentType type) async {
    final courier = state.value;
    if (courier == null) return;
    final updated = courier.copyWith(
      documents: [
        for (final d in courier.documents)
          d.type == type
              ? CourierDocument(type: type, uploadedAt: DateTime.now())
              : d,
      ],
    );
    await save(updated);
  }

  void refreshLocal(Courier courier) => state = AsyncData(courier);
}

/// Courses en attente d'un livreur (« commandes à accepter »).
final availableDeliveriesProvider =
    AsyncNotifierProvider<AvailableDeliveriesController, List<Delivery>>(
      AvailableDeliveriesController.new,
    );

class AvailableDeliveriesController extends AsyncNotifier<List<Delivery>> {
  /// Courses refusées pendant la session (masquées).
  final Set<String> _declined = {};

  @override
  Future<List<Delivery>> build() async {
    final list = await ref.watch(deliveryRepositoryProvider).available();
    return list.where((d) => !_declined.contains(d.id)).toList()
      ..sort((a, b) => b.earnings.compareTo(a.earnings));
  }

  Future<void> accept(Delivery delivery) async {
    final courier = await ref.read(myCourierProvider.future);
    if (courier == null) throw const ApiException('Profil livreur introuvable.');
    if (courier.status == CourierStatus.offline) {
      throw const ApiException('Passez en ligne pour accepter des courses.');
    }
    if (courier.status == CourierStatus.busy) {
      throw const ApiException('Vous avez déjà une course en cours.');
    }
    final deliveries = ref.read(deliveryRepositoryProvider);
    await deliveries.assign(delivery.id, courier.id);
    await ref
        .read(courierRepositoryProvider)
        .setStatus(courier.id, CourierStatus.busy);
    ref
      ..invalidate(myCourierProvider)
      ..invalidate(myDeliveriesProvider)
      ..invalidateSelf();
    await future;
  }

  void decline(Delivery delivery) {
    _declined.add(delivery.id);
    state = AsyncData([
      for (final d in state.value ?? const <Delivery>[])
        if (d.id != delivery.id) d,
    ]);
  }
}

/// Courses du livreur connecté (en cours et terminées).
final myDeliveriesProvider =
    AsyncNotifierProvider<MyDeliveriesController, List<Delivery>>(
      MyDeliveriesController.new,
    );

class MyDeliveriesController extends AsyncNotifier<List<Delivery>> {
  @override
  Future<List<Delivery>> build() async {
    final courier = await ref.watch(myCourierProvider.future);
    if (courier == null) return const [];
    return ref.watch(deliveryRepositoryProvider).forCourier(courier.id);
  }

  /// Étape suivante : récupérée → en route → livrée. La commande suit ; à la
  /// livraison, le livreur redevient disponible et ses gains augmentent.
  Future<void> advance(Delivery delivery) async {
    final next = switch (delivery.status) {
      DeliveryStatus.assigned => DeliveryStatus.pickedUp,
      DeliveryStatus.pickedUp => DeliveryStatus.inTransit,
      DeliveryStatus.inTransit => DeliveryStatus.delivered,
      _ => null,
    };
    if (next == null) return;
    await ref.read(deliveryRepositoryProvider).updateStatus(delivery.id, next);
    final orderStatus = switch (next) {
      DeliveryStatus.pickedUp || DeliveryStatus.inTransit => OrderStatus.delivering,
      DeliveryStatus.delivered => OrderStatus.delivered,
      _ => null,
    };
    if (orderStatus != null) {
      try {
        await ref
            .read(orderRepositoryProvider)
            .updateStatus(delivery.orderId, orderStatus);
      } on ApiException {
        // Commande supprimée entre-temps : la course reste mise à jour.
      }
    }
    if (next == DeliveryStatus.delivered) {
      final couriers = ref.read(courierRepositoryProvider);
      final courier = await couriers.getById(delivery.courierId!);
      final updated = await couriers.update(
        courier.copyWith(
          status: CourierStatus.available,
          completedDeliveries: courier.completedDeliveries + 1,
          totalEarnings: courier.totalEarnings + delivery.earnings,
        ),
      );
      ref.read(myCourierProvider.notifier).refreshLocal(updated);
      ref.invalidate(availableDeliveriesProvider);
    }
    ref.invalidateSelf();
    await future;
  }
}

/// Gains par jour sur les 7 derniers jours (le plus ancien d'abord).
List<(DateTime, double)> earningsByDay(List<Delivery> deliveries) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final day = today.subtract(Duration(days: i));
        final total = deliveries
            .where(
              (d) =>
                  d.status == DeliveryStatus.delivered &&
                  _sameDay(d.deliveredAt ?? d.createdAt, day),
            )
            .fold<double>(0, (s, d) => s + d.earnings);
        return (day, total);
      }(),
  ];
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime date) => _sameDay(date, DateTime.now());
