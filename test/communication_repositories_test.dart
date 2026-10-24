import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/core/config/app_config.dart';
import 'package:superfaster/core/network/api_exception.dart';
import 'package:superfaster/features/communication/data/chat/chat_mock_repository.dart';
import 'package:superfaster/features/communication/data/mock/communication_mock_data.dart';
import 'package:superfaster/features/communication/data/notifications/notification_mock_repository.dart';
import 'package:superfaster/features/communication/data/reviews/review_api_repository.dart';
import 'package:superfaster/features/communication/data/reviews/review_mock_repository.dart';
import 'package:superfaster/features/communication/models/app_notification.dart';
import 'package:superfaster/features/communication/models/chat_event.dart';
import 'package:superfaster/features/communication/models/chat_message.dart';
import 'package:superfaster/features/communication/models/review.dart';

/// Faux adaptateur HTTP : renvoie une réponse JSON préparée par route.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, (int, Object?)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) =
        routes['${options.method} ${options.path}'] ??
        (404, {'error': 'introuvable'});
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

void main() {
  setUpAll(() {
    AppConfig.mockLatency = const Duration(milliseconds: 5);
    AppConfig.mockServerDelay = const Duration(milliseconds: 40);
  });

  group('ReviewMockRepository', () {
    test(
      'un avis publié est validé puis reçoit une réponse + une notification',
      () async {
        final notifications = NotificationMockRepository();
        final repository = ReviewMockRepository(notifications: notifications);
        final pushes = <AppNotification>[];
        final subscription = notifications.incoming.listen(pushes.add);

        final created = await repository.createReview(
          const ReviewInput(
            restaurantId: 'r2',
            rating: 4,
            criteria: {ReviewCriterion.food: 5},
            comment: 'Très bonne pizza',
          ),
        );
        expect(created.status, ReviewStatus.pending);
        expect((await repository.fetchMyReviews()).first.id, created.id);

        await Future<void>.delayed(const Duration(milliseconds: 120));
        final updated = await repository.fetchReview(created.id);
        expect(updated.status, ReviewStatus.approved);
        expect(updated.reply, isNotNull);
        expect(pushes.single.type, NotificationType.review);
        await subscription.cancel();
      },
    );

    test('le résumé inclut les nouveaux avis', () async {
      final repository = ReviewMockRepository();
      final before = await repository.fetchSummary('r4');
      await repository.createReview(
        const ReviewInput(
          restaurantId: 'r4',
          rating: 1,
          criteria: {},
          comment: '',
        ),
      );
      final after = await repository.fetchSummary('r4');
      expect(after.count, before.count + 1);
      expect(after.distribution[1], (before.distribution[1] ?? 0) + 1);
    });

    test(
      'modération : approuver un avis signalé efface les signalements',
      () async {
        final repository = ReviewMockRepository();
        final queue = await repository.fetchModerationQueue();
        final reported = queue.firstWhere((r) => r.isReported);
        final moderated = await repository.moderateReview(
          reported.id,
          ReviewStatus.approved,
        );
        expect(moderated.reportCount, 0);
        final remaining = await repository.fetchModerationQueue();
        expect(remaining.any((r) => r.id == reported.id), isFalse);
      },
    );
  });

  test('ChatMockRepository : distribué → lu → écrit… → réponse', () async {
    final repository = ChatMockRepository();
    final events = <ChatEvent>[];
    final subscription = repository.events.listen(events.add);

    final sent = await repository.sendMessage('conv-support', 'Bonjour');
    expect(sent.status, MessageStatus.sent);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final statuses = events
        .whereType<MessageUpdated>()
        .where((e) => e.message.id == sent.id)
        .map((e) => e.message.status);
    expect(
      statuses,
      containsAllInOrder([MessageStatus.delivered, MessageStatus.read]),
    );
    expect(events.whereType<TypingChanged>().map((e) => e.isTyping), [
      true,
      false,
    ]);
    final reply = events.whereType<MessageReceived>().single.message;
    expect(reply.isMine(AppConfig.currentUserId), isFalse);

    final conversations = await repository.fetchConversations();
    expect(conversations.first.id, 'conv-support');
    expect(conversations.first.unreadCount, 1);
    await subscription.cancel();
  });

  group('ReviewApiRepository (Dio)', () {
    test('lit une liste enveloppée dans {"data": ...}', () async {
      final adapter = _FakeAdapter({
        'GET /restaurants/r1/reviews': (
          200,
          {'data': CommunicationMockData.reviewsJson().take(2).toList()},
        ),
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;

      final reviews = await ReviewApiRepository(
        dio,
      ).fetchRestaurantReviews('r1');
      expect(reviews, hasLength(2));
      expect(adapter.requests.single.path, '/restaurants/r1/reviews');
    });

    test('envoie le JSON de création et traduit les erreurs', () async {
      final adapter = _FakeAdapter({
        'POST /reviews': (201, CommunicationMockData.reviewsJson().first),
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = ReviewApiRepository(dio);

      await repository.createReview(
        const ReviewInput(
          restaurantId: 'r1',
          rating: 5,
          criteria: {},
          comment: 'Top',
        ),
      );
      expect((adapter.requests.single.data as Map)['rating'], 5);

      await expectLater(
        repository.fetchReview('absent'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Ressource introuvable.'),
        ),
      );
    });
  });
}
