import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/network/api_exception.dart';
import 'package:superfaster/shared/mock/mock_catalog.dart';
import 'package:superfaster/shared/mock/mock_communication.dart';
import 'package:superfaster/shared/mock/mock_delivery.dart';
import 'package:superfaster/shared/mock/mock_orders.dart';
import 'package:superfaster/shared/mock/mock_users.dart';
import 'package:superfaster/shared/models/models.dart';
import 'package:superfaster/shared/repositories/addresses/mock_address_repository.dart';
import 'package:superfaster/shared/repositories/campaigns/mock_campaign_repository.dart';
import 'package:superfaster/shared/repositories/categories/mock_category_repository.dart';
import 'package:superfaster/shared/repositories/deliveries/mock_delivery_repository.dart';
import 'package:superfaster/shared/repositories/notifications/mock_notification_repository.dart';
import 'package:superfaster/shared/repositories/orders/mock_order_repository.dart';
import 'package:superfaster/shared/repositories/users/api_user_repository.dart';
import 'package:superfaster/shared/repositories/users/mock_user_repository.dart';

import '../test_helpers.dart';

/// Faux serveur HTTP : renvoie [body] avec le code [status] et mémorise
/// les requêtes reçues.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.body, {this.status = 200});

  final Object? body;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;

void main() {
  setUpAll(setUpAppTestEnvironment);

  group('dépôt mock générique (utilisateurs)', () {
    test('créer, lire, modifier, supprimer', () async {
      final repository = MockUserRepository(MockUsers.users);
      final count = (await repository.getAll()).length;

      final created = await repository.create(
        User(
          id: '',
          firstName: 'Nina',
          lastName: 'Simon',
          email: 'nina@exemple.fr',
          phone: '0600000000',
          role: UserRole.client,
          createdAt: DateTime(2026),
        ),
      );
      expect(created.id, startsWith('u-'));
      expect((await repository.getAll()).length, count + 1);
      expect((await repository.findByEmail('NINA@exemple.fr'))?.id, created.id);

      await repository.update(created.copyWith(lastName: 'Simone'));
      expect((await repository.getById(created.id)).lastName, 'Simone');

      final blocked = await repository.setStatus(
        created.id,
        UserStatus.blocked,
      );
      expect(blocked.isBlocked, isTrue);

      await repository.delete(created.id);
      expect((await repository.getAll()).length, count);
      await expectLater(
        repository.getById(created.id),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 404)),
      );
    });

    test('les données de départ ne sont pas modifiées', () async {
      final repository = MockUserRepository(MockUsers.users);
      await repository.delete(MockUsers.users.first.id);
      expect(MockUsers.users.first.id, 'u-admin');
      expect(
        (await MockUserRepository(MockUsers.users).getAll()).length,
        MockUsers.users.length,
      );
    });
  });

  group('méthodes spécifiques', () {
    test(
      'commandes : numéro attribué, statut, annulation, remboursement',
      () async {
        final repository = MockOrderRepository(MockOrders.orders);
        final sample = MockOrders.orders.first;
        final created = await repository.create(
          sample.copyWith(id: '', reference: '', history: const []),
        );
        expect(created.reference, 'SF1078');
        expect(
          (await repository.getAll()).first.createdAt.isAfter(DateTime(2000)),
          isTrue,
        );

        final accepted = await repository.updateStatus(
          created.id,
          OrderStatus.accepted,
        );
        expect(accepted.history.last.status, OrderStatus.accepted);

        final cancelled = await repository.cancel(created.id, 'Client absent');
        expect(cancelled.status, OrderStatus.cancelled);
        expect(cancelled.cancelReason, 'Client absent');

        final refunded = await repository.refund(created.id);
        expect(refunded.paymentStatus, PaymentStatus.refunded);
        expect(
          await repository.forUser(sample.userId),
          everyElement(
            isA<Order>().having((o) => o.userId, 'userId', sample.userId),
          ),
        );
      },
    );

    test('catégories : ordre d\'affichage', () async {
      final repository = MockCategoryRepository(MockCatalog.categories);
      final ids = [for (final c in await repository.getAll()) c.id];
      await repository.reorder(ids.reversed.toList());
      expect([for (final c in await repository.getAll()) c.id], ids.reversed);
    });

    test('livraisons : accepter puis livrer une course', () async {
      final repository = MockDeliveryRepository(MockDelivery.deliveries);
      final offer = (await repository.available()).first;
      final assigned = await repository.assign(offer.id, 'c-3');
      expect(assigned.status, DeliveryStatus.assigned);
      expect(assigned.assignedAt, isNotNull);
      final delivered = await repository.updateStatus(
        offer.id,
        DeliveryStatus.delivered,
      );
      expect(delivered.deliveredAt, isNotNull);
      expect([
        for (final d in await repository.available()) d.id,
      ], isNot(contains(offer.id)));
    });

    test('adresses : une seule adresse par défaut', () async {
      final repository = MockAddressRepository(MockUsers.addresses);
      final addresses = await repository.setDefault('u-client-1', 'a-2');
      expect(addresses.where((a) => a.isDefault).map((a) => a.id), ['a-2']);
    });

    test('notifications : tout marquer comme lu', () async {
      final repository = MockNotificationRepository(
        MockCommunication.notifications,
      );
      expect(
        (await repository.forUser('u-client-1')).any((n) => !n.isRead),
        isTrue,
      );
      await repository.markAllRead('u-client-1');
      expect(
        (await repository.forUser('u-client-1')).every((n) => n.isRead),
        isTrue,
      );
    });

    test('campagnes : envoi', () async {
      final repository = MockCampaignRepository(MockCommunication.campaigns);
      final sent = await repository.send('camp-5');
      expect(sent.status, CampaignStatus.sent);
      expect(sent.recipientCount, greaterThan(0));
    });
  });

  group('dépôt API (Dio)', () {
    test('lit une liste enveloppée dans {"data": …}', () async {
      final adapter = FakeAdapter({
        'data': [for (final u in MockUsers.users.take(3)) u.toJson()],
      });
      final users = await ApiUserRepository(fakeDio(adapter)).getAll();
      expect(users, hasLength(3));
      expect(adapter.requests.single.path, '/users');
    });

    test('PATCH /users/:id/status pour bloquer', () async {
      final adapter = FakeAdapter(
        MockUsers.users[1].copyWith(status: UserStatus.blocked).toJson(),
      );
      final user = await ApiUserRepository(
        fakeDio(adapter),
      ).setStatus('u-client-1', UserStatus.blocked);
      expect(user.isBlocked, isTrue);
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/users/u-client-1/status');
    });

    test('une erreur HTTP devient une ApiException lisible', () async {
      final adapter = FakeAdapter({'message': 'introuvable'}, status: 404);
      await expectLater(
        ApiUserRepository(fakeDio(adapter)).getById('x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'code', 404)
              .having((e) => e.message, 'message', 'Ressource introuvable.'),
        ),
      );
    });
  });
}
