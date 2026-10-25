import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/shared/mock/mock_catalog.dart';
import 'package:superfaster/shared/mock/mock_communication.dart';
import 'package:superfaster/shared/mock/mock_delivery.dart';
import 'package:superfaster/shared/mock/mock_orders.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/models.dart';

void main() {
  test('volumes demandés pour la démo', () {
    expect(MockUsers.users.length, greaterThanOrEqualTo(20));
    expect(MockCatalog.approvedRestaurants.length, greaterThanOrEqualTo(8));
    expect(MockCatalog.products.length, greaterThanOrEqualTo(40));
    expect(MockOrders.orders.length, greaterThanOrEqualTo(30));
    expect(MockDelivery.couriers.length, 6);
    expect(MockCommunication.reviews.length, greaterThanOrEqualTo(20));
    expect(MockCommunication.notifications.length, greaterThanOrEqualTo(15));
  });

  test('identifiants uniques', () {
    void unique(Iterable<String> ids, String what) =>
        expect(ids.toSet().length, ids.length, reason: what);
    unique(MockUsers.users.map((e) => e.id), 'utilisateurs');
    unique(MockUsers.users.map((e) => e.email), 'e-mails');
    unique(MockUsers.addresses.map((e) => e.id), 'adresses');
    unique(MockCatalog.restaurants.map((e) => e.id), 'restaurants');
    unique(MockCatalog.categories.map((e) => e.id), 'catégories');
    unique(MockCatalog.products.map((e) => e.id), 'produits');
    unique(MockOrders.orders.map((e) => e.id), 'commandes');
    unique(MockOrders.orders.map((e) => e.reference), 'numéros');
    unique(MockDelivery.couriers.map((e) => e.id), 'livreurs');
    unique(MockDelivery.deliveries.map((e) => e.id), 'livraisons');
    unique(MockCommunication.reviews.map((e) => e.id), 'avis');
    unique(MockCommunication.messages.map((e) => e.id), 'messages');
  });

  test('les références entre entités existent', () {
    final users = {for (final u in MockUsers.users) u.id: u};
    final restaurants = {for (final r in MockCatalog.restaurants) r.id};
    final categories = {for (final c in MockCatalog.categories) c.id};
    final orders = {for (final o in MockOrders.orders) o.id};
    final couriers = {for (final c in MockDelivery.couriers) c.id};
    final chats = {for (final c in MockCommunication.chats) c.id};

    for (final a in MockUsers.addresses) {
      expect(users, contains(a.userId));
    }
    for (final r in MockCatalog.restaurants) {
      expect(users[r.ownerId]?.restaurantId, r.id, reason: r.name);
      expect(categories, containsAll(r.categoryIds));
    }
    for (final p in MockCatalog.products) {
      expect(restaurants, contains(p.restaurantId));
      expect(categories, contains(p.categoryId));
    }
    for (final o in MockOrders.orders) {
      expect(users[o.userId]?.role, UserRole.client);
      expect(restaurants, contains(o.restaurantId));
      expect(o.items, isNotEmpty);
      if (o.courierId != null) expect(couriers, contains(o.courierId));
      expect(o.history.last.status, o.status);
    }
    for (final c in MockDelivery.couriers) {
      expect(users[c.userId]?.role, UserRole.courier);
    }
    for (final d in MockDelivery.deliveries) {
      expect(orders, contains(d.orderId));
      if (d.courierId != null) expect(couriers, contains(d.courierId));
    }
    for (final r in MockCommunication.reviews) {
      expect(restaurants, contains(r.restaurantId));
      expect(users, contains(r.userId));
    }
    for (final m in MockCommunication.messages) {
      expect(chats, contains(m.chatId));
    }
  });

  test('les comptes de démo existent pour chaque rôle', () {
    for (final email in [
      DemoAccounts.client,
      DemoAccounts.courier,
      DemoAccounts.restaurant,
      DemoAccounts.admin,
    ]) {
      expect(MockUsers.users.where((u) => u.email == email), hasLength(1));
    }
    // Des commandes à accepter et une livraison en cours pour le livreur démo.
    expect(
      MockDelivery.deliveries.where((d) => d.status == DeliveryStatus.waiting),
      isNotEmpty,
    );
    expect(
      MockDelivery.deliveries.where(
        (d) => d.courierId == 'c-1' && d.status.isActive,
      ),
      isNotEmpty,
    );
    // Des demandes d'inscription à valider dans le back office.
    expect(
      MockCatalog.restaurants.where(
        (r) => r.status == RestaurantStatus.pending,
      ),
      isNotEmpty,
    );
  });
}
