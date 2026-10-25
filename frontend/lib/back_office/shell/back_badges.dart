import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../modules/catalog/catalog_controllers.dart';
import '../modules/communication/communication_controllers.dart';
import '../modules/delivery/delivery_controllers.dart';
import '../modules/orders/orders_controller.dart';

// =============================================================================
// Compteurs du menu latéral et des alertes de la topbar. Ils lisent les
// mêmes contrôleurs que les pages : valider un restaurant ou traiter une
// commande met le compteur à jour immédiatement.
// =============================================================================

int _count<T>(AsyncValue<List<T>> value, bool Function(T item) test) =>
    value.value?.where(test).length ?? 0;

int pendingRestaurantsBadge(WidgetRef ref, UserRole role) => _count(
  ref.watch(restaurantsControllerProvider),
  (r) => r.status == RestaurantStatus.pending,
);

int outOfStockBadge(WidgetRef ref, UserRole role) => role == UserRole.restaurant
    ? _count(ref.watch(productsControllerProvider), (p) => !p.isAvailable)
    : 0;

int newOrdersBadge(WidgetRef ref, UserRole role) => _count(
  ref.watch(ordersControllerProvider),
  (o) => o.status == OrderStatus.pending,
);

int documentsToReviewBadge(WidgetRef ref, UserRole role) => _count(
  ref.watch(couriersControllerProvider),
  (c) => c.documentStatus == DocumentStatus.pending,
);

int unassignedDeliveriesBadge(WidgetRef ref, UserRole role) => _count(
  ref.watch(deliveriesControllerProvider),
  (d) => d.status == DeliveryStatus.waiting,
);

/// Admin : avis à modérer. Restaurant : avis publiés sans réponse.
int reviewsBadge(WidgetRef ref, UserRole role) => _count(
  ref.watch(reviewsControllerProvider),
  (r) => role == UserRole.admin
      ? r.status == ReviewStatus.pending
      : r.status == ReviewStatus.approved && r.reply == null,
);

/// Admin : conversations signalées. Restaurant : messages non lus.
int chatsBadge(WidgetRef ref, UserRole role) {
  final chats = ref.watch(chatsControllerProvider).value ?? const <Chat>[];
  return role == UserRole.admin
      ? chats.where((c) => c.isFlagged).length
      : chats.fold(0, (sum, c) => sum + c.unreadCount);
}
