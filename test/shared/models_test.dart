import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/shared/mock/mock_catalog.dart';
import 'package:superfaster/shared/mock/mock_communication.dart';
import 'package:superfaster/shared/mock/mock_delivery.dart';
import 'package:superfaster/shared/mock/mock_orders.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/models.dart';

/// Aller-retour JSON : `fromJson(toJson(x))` redonne exactement `x`.
void expectRoundTrip<T>(
  List<T> items,
  Map<String, dynamic> Function(T) toJson,
  T Function(Map<String, dynamic>) fromJson,
) {
  expect(items, isNotEmpty);
  for (final item in items) {
    final json = jsonDecode(jsonEncode(toJson(item))) as Map<String, dynamic>;
    expect(jsonEncode(toJson(fromJson(json))), jsonEncode(toJson(item)));
  }
}

void main() {
  test(
    'les 13 modèles (et les campagnes) survivent à un aller-retour JSON',
    () {
      expectRoundTrip(MockUsers.users, (e) => e.toJson(), User.fromJson);
      expectRoundTrip(MockUsers.addresses, (e) => e.toJson(), Address.fromJson);
      expectRoundTrip(
        MockCatalog.restaurants,
        (e) => e.toJson(),
        Restaurant.fromJson,
      );
      expectRoundTrip(
        MockCatalog.categories,
        (e) => e.toJson(),
        Category.fromJson,
      );
      expectRoundTrip(
        MockCatalog.products,
        (e) => e.toJson(),
        Product.fromJson,
      );
      expectRoundTrip(
        [for (final o in MockOrders.orders) ...o.items],
        (e) => e.toJson(),
        CartItem.fromJson,
      );
      expectRoundTrip(MockOrders.orders, (e) => e.toJson(), Order.fromJson);
      expectRoundTrip(
        MockDelivery.couriers,
        (e) => e.toJson(),
        Courier.fromJson,
      );
      expectRoundTrip(
        MockDelivery.deliveries,
        (e) => e.toJson(),
        Delivery.fromJson,
      );
      expectRoundTrip(
        MockCommunication.reviews,
        (e) => e.toJson(),
        Review.fromJson,
      );
      expectRoundTrip(
        MockCommunication.notifications,
        (e) => e.toJson(),
        AppNotification.fromJson,
      );
      expectRoundTrip(
        MockCommunication.campaigns,
        (e) => e.toJson(),
        NotificationCampaign.fromJson,
      );
      expectRoundTrip(
        MockCommunication.chats,
        (e) => e.toJson(),
        Chat.fromJson,
      );
      expectRoundTrip(
        MockCommunication.messages,
        (e) => e.toJson(),
        Message.fromJson,
      );
    },
  );

  test('fromJson tolère les champs absents et les valeurs inconnues', () {
    final user = User.fromJson({
      'id': 'u',
      'firstName': 'A',
      'lastName': 'B',
      'email': 'a@b.fr',
      'role': 'inconnu',
      'createdAt': '2026-01-01T00:00:00.000',
    });
    expect(user.role, UserRole.client);
    expect(user.status, UserStatus.active);
    expect(user.phone, '');
  });

  test('copyWith : `keep` garde la valeur, null l\'efface', () {
    final order = MockOrders.orders.firstWhere((o) => o.courierId != null);
    expect(order.copyWith(note: 'x').courierId, order.courierId);
    expect(order.copyWith(courierId: null).courierId, isNull);
  });

  test('calculs : panier, commande et statut des justificatifs', () {
    final product = MockCatalog.products.first;
    final large = product.optionGroups.first.options[1];
    final item = CartItem(
      id: 'i',
      product: product,
      quantity: 2,
      options: [large],
    );
    expect(item.unitPrice, product.price + large.price);
    expect(item.totalPrice, closeTo((product.price + large.price) * 2, 1e-9));

    final order = MockOrders.orders.first;
    expect(
      order.total,
      closeTo(
        order.subtotal + order.deliveryFee + order.serviceFee - order.discount,
        1e-9,
      ),
    );
    final withStatus = order.withStatus(OrderStatus.ready);
    expect(withStatus.history.last.status, OrderStatus.ready);

    final courier = MockDelivery.couriers.first;
    expect(courier.documentStatus, DocumentStatus.approved);
    final rejected = courier.copyWith(
      documents: [
        courier.documents.first.copyWith(status: DocumentStatus.rejected),
        ...courier.documents.skip(1),
      ],
    );
    expect(rejected.documentStatus, DocumentStatus.rejected);
  });
}
