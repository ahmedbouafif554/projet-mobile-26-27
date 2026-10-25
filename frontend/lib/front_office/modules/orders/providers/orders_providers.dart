import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/repositories/orders/order_repository.dart';
import '../../../../shared/repositories/repository_providers.dart';
import 'cart_controller.dart';

/// Commandes du client connecté (Module 3), les plus récentes d'abord :
/// passer une commande, annuler, recommander.
final myOrdersProvider = AsyncNotifierProvider<MyOrdersController, List<Order>>(
  MyOrdersController.new,
);

class MyOrdersController extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final userId = ref.watch(authServiceProvider.select((a) => a.user?.id));
    if (userId == null) return const [];
    return ref.watch(orderRepositoryProvider).forUser(userId);
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// Crée la commande à partir du panier, vide le panier et envoie une
  /// notification de confirmation.
  Future<Order> place({
    required Address address,
    required PaymentMethod paymentMethod,
    String? note,
    String? promoCode,
    double discount = 0,
  }) async {
    final user = ref.read(authServiceProvider).user!;
    final items = await ref.read(cartProvider.future);
    if (items.isEmpty) throw const ApiException('Votre panier est vide.');
    final restaurant = await ref
        .read(restaurantRepositoryProvider)
        .getById(items.first.product.restaurantId);
    if (!restaurant.isOpen) {
      throw ApiException('${restaurant.name} est fermé pour le moment.');
    }
    final totals = CartTotals.of(items, restaurant, discount: discount);
    final now = DateTime.now();
    final order = await ref
        .read(orderRepositoryProvider)
        .create(
          Order(
            id: '',
            reference: '',
            userId: user.id,
            customerName: user.fullName,
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            items: items,
            deliveryAddress: address,
            deliveryFee: totals.deliveryFee,
            serviceFee: totals.serviceFee,
            discount: discount,
            paymentMethod: paymentMethod,
            paymentStatus: paymentMethod == PaymentMethod.cash
                ? PaymentStatus.pending
                : PaymentStatus.paid,
            note: note == null || note.trim().isEmpty ? null : note.trim(),
            promoCode: promoCode,
            history: [OrderStatusEvent(status: OrderStatus.pending, at: now)],
            createdAt: now,
          ),
        );
    await ref.read(cartProvider.notifier).clear();
    await ref
        .read(notificationRepositoryProvider)
        .create(
          AppNotification(
            id: '',
            userId: user.id,
            title: 'Commande #${order.reference} confirmée 🎉',
            body: '${restaurant.name} a bien reçu votre commande.',
            type: NotificationType.order,
            route: '/orders/${order.id}',
            imageUrl: restaurant.imageUrl,
            createdAt: now,
          ),
        );
    await _reload();
    return order;
  }

  /// Annulation par le client (tant que le restaurant n'a pas accepté).
  Future<void> cancel(Order order) async {
    if (order.status != OrderStatus.pending) {
      throw const ApiException(
        'La commande est déjà en préparation : contactez le restaurant.',
      );
    }
    await ref
        .read(orderRepositoryProvider)
        .cancel(order.id, 'Annulée par le client');
    await _reload();
  }

  /// Remet les articles d'une commande dans le panier (vidé avant si besoin).
  Future<void> reorder(Order order) async {
    final cart = ref.read(cartProvider.notifier);
    await cart.clear();
    for (final item in order.items) {
      await cart.add(
        item.product,
        quantity: item.quantity,
        options: item.options,
        note: item.note,
      );
    }
  }
}

/// Une commande du client (fiche, suivi).
final orderProvider = FutureProvider.autoDispose.family<Order, String>(
  (ref, id) async {
    // Se recharge quand la liste change (annulation, progression…).
    ref.watch(myOrdersProvider);
    return ref.watch(orderRepositoryProvider).getById(id);
  },
);

/// Suivi en temps réel (démo) : fait avancer la commande d'une étape
/// (appelé toutes les quelques secondes par la page de suivi). Renvoie le
/// nouveau statut, ou null quand la commande est terminée.
Future<OrderStatus?> advanceOrderDemo(
  OrderRepository repository,
  String orderId,
) async {
  final order = await repository.getById(orderId);
  final next = switch (order.status) {
    OrderStatus.pending => OrderStatus.accepted,
    OrderStatus.accepted => OrderStatus.preparing,
    OrderStatus.preparing => OrderStatus.ready,
    OrderStatus.ready => OrderStatus.delivering,
    OrderStatus.delivering => OrderStatus.delivered,
    _ => null,
  };
  if (next == null) return null;
  await repository.updateStatus(orderId, next);
  return next;
}
