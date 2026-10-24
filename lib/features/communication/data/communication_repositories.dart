import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'chat/chat_api_repository.dart';
import 'chat/chat_mock_repository.dart';
import 'chat/chat_repository.dart';
import 'notifications/notification_api_repository.dart';
import 'notifications/notification_mock_repository.dart';
import 'notifications/notification_repository.dart';
import 'reviews/review_api_repository.dart';
import 'reviews/review_mock_repository.dart';
import 'reviews/review_repository.dart';

/// Point d'accès unique aux dépôts du module 5.
///
/// Selon [AppConfig.useMockData], renvoie l'implémentation mock (en mémoire)
/// ou l'implémentation API (Dio). Les écrans ne connaissent que les interfaces.
class CommunicationRepositories {
  CommunicationRepositories._();

  static NotificationMockRepository? _mockNotifications;
  static NotificationRepository? _notifications;
  static ReviewRepository? _reviews;
  static ChatRepository? _chat;

  static NotificationMockRepository get _notificationsMock =>
      _mockNotifications ??= NotificationMockRepository();

  static NotificationRepository get notifications =>
      _notifications ??= AppConfig.useMockData
      ? _notificationsMock
      : NotificationApiRepository(ApiClient.dio);

  static ReviewRepository get reviews => _reviews ??= AppConfig.useMockData
      // Le mock des avis « envoie » des push via le mock des notifications.
      ? ReviewMockRepository(notifications: _notificationsMock)
      : ReviewApiRepository(ApiClient.dio);

  static ChatRepository get chat => _chat ??= AppConfig.useMockData
      ? ChatMockRepository()
      : ChatApiRepository(ApiClient.dio);

  /// Injecte des implémentations personnalisées (tests).
  @visibleForTesting
  static void override({
    NotificationRepository? notifications,
    ReviewRepository? reviews,
    ChatRepository? chat,
  }) {
    _notifications = notifications ?? _notifications;
    _reviews = reviews ?? _reviews;
    _chat = chat ?? _chat;
  }
}
