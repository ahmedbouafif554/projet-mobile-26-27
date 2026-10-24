import '../../models/app_notification.dart';
import '../../models/notification_settings.dart';

/// Accès aux notifications (implémenté par l'API Dio et par les données mock).
abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
  Future<void> delete(String notificationId);

  Future<NotificationSettings> fetchSettings();
  Future<NotificationSettings> updateSettings(NotificationSettings settings);

  /// Notifications reçues en temps réel (push).
  Stream<AppNotification> get incoming;
}
