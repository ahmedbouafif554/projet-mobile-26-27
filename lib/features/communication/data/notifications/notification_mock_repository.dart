import 'dart:async';

import '../../../../core/config/app_config.dart';
import '../../models/app_notification.dart';
import '../../models/notification_settings.dart';
import '../mock/communication_mock_data.dart';
import 'notification_repository.dart';

/// Notifications simulées en mémoire.
class NotificationMockRepository implements NotificationRepository {
  late final List<AppNotification> _items =
      CommunicationMockData.notificationsJson()
          .map(AppNotification.fromJson)
          .toList();
  NotificationSettings _settings = NotificationSettings.fromJson(
    CommunicationMockData.notificationSettingsJson(),
  );
  final _incoming = StreamController<AppNotification>.broadcast();

  Future<T> _respond<T>(T Function() compute) async {
    await Future<void>.delayed(AppConfig.mockLatency);
    return compute();
  }

  /// Simule l'arrivée d'une notification push envoyée par le serveur.
  void simulateIncoming(AppNotification notification) {
    _items.insert(0, notification);
    _incoming.add(notification);
  }

  @override
  Stream<AppNotification> get incoming => _incoming.stream;

  @override
  Future<List<AppNotification>> fetchNotifications() =>
      _respond(() => List.of(_items));

  @override
  Future<void> markAsRead(String notificationId) => _respond(() {
    final index = _items.indexWhere((n) => n.id == notificationId);
    if (index >= 0) _items[index] = _items[index].copyWith(isRead: true);
  });

  @override
  Future<void> markAllAsRead() => _respond(() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  });

  @override
  Future<void> delete(String notificationId) =>
      _respond(() => _items.removeWhere((n) => n.id == notificationId));

  @override
  Future<NotificationSettings> fetchSettings() => _respond(() => _settings);

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings settings) =>
      _respond(() => _settings = settings);
}
