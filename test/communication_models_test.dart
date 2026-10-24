import 'package:flutter_test/flutter_test.dart';
import 'package:superfaster/features/communication/data/mock/communication_mock_data.dart';
import 'package:superfaster/features/communication/models/app_notification.dart';
import 'package:superfaster/features/communication/models/chat_event.dart';
import 'package:superfaster/features/communication/models/chat_message.dart';
import 'package:superfaster/features/communication/models/conversation.dart';
import 'package:superfaster/features/communication/models/notification_settings.dart';
import 'package:superfaster/features/communication/models/rating_summary.dart';
import 'package:superfaster/features/communication/models/review.dart';

/// Aller-retour JSON des modèles du module 5.
void main() {
  test('Review : fromJson / toJson conserve toutes les données', () {
    final json = CommunicationMockData.reviewsJson().firstWhere(
      (r) => r['id'] == 'rev-me-1',
    );
    final review = Review.fromJson(json);

    expect(review.rating, 5);
    expect(review.criteria[ReviewCriterion.delivery], 4);
    expect(review.reply?.authorName, 'Sakura Sushi');
    expect(review.hasPhotos, isTrue);

    final again = Review.fromJson(review.toJson());
    expect(again.toJson(), review.toJson());
  });

  test('Review : statut inconnu → publié par défaut', () {
    final json = {
      ...CommunicationMockData.reviewsJson().first,
      'status': 'inconnu',
    };
    expect(Review.fromJson(json).status, ReviewStatus.approved);
  });

  test('RatingSummary : calcul et aller-retour JSON', () {
    final reviews = CommunicationMockData.reviewsJson()
        .where((r) => r['restaurant_id'] == 'r1' && r['status'] == 'approved')
        .map(Review.fromJson)
        .toList();
    final summary = RatingSummary.fromReviews(reviews);

    expect(summary.count, reviews.length);
    expect(summary.distribution.values.reduce((a, b) => a + b), reviews.length);
    expect(summary.ratioOf(5), greaterThan(0));
    final again = RatingSummary.fromJson(summary.toJson());
    expect(again.average, closeTo(summary.average, 1e-9));
    expect(again.distribution, summary.distribution);
  });

  test('AppNotification et NotificationSettings : aller-retour JSON', () {
    for (final json in CommunicationMockData.notificationsJson()) {
      final n = AppNotification.fromJson(json);
      expect(AppNotification.fromJson(n.toJson()).toJson(), n.toJson());
    }
    final settings = NotificationSettings.fromJson(
      CommunicationMockData.notificationSettingsJson(),
    );
    expect(settings.isTypeEnabled(NotificationType.system), isFalse);
    expect(settings.shouldShowBanner(NotificationType.order), isTrue);
    expect(
      settings
          .copyWith(doNotDisturb: true)
          .shouldShowBanner(NotificationType.order),
      isFalse,
    );
    expect(
      NotificationSettings.fromJson(settings.toJson()).toJson(),
      settings.toJson(),
    );
  });

  test('Conversation, ChatMessage et ChatEvent : aller-retour JSON', () {
    for (final json in CommunicationMockData.conversationsJson()) {
      final c = Conversation.fromJson(json);
      expect(Conversation.fromJson(c.toJson()).toJson(), c.toJson());
    }
    final message = ChatMessage.fromJson(
      CommunicationMockData.messagesJson()['conv-r5']!.first,
    );
    final events = <ChatEvent>[
      MessageReceived(message),
      MessageUpdated(message.copyWith(status: MessageStatus.read)),
      const TypingChanged('conv-r5', isTyping: true),
    ];
    for (final event in events) {
      final decoded = ChatEvent.fromJson(event.toJson());
      expect(decoded?.toJson(), event.toJson());
    }
    expect(ChatEvent.fromJson({'event': 'inconnu'}), isNull);
  });
}
