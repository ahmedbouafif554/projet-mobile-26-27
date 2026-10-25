import '../../models/app_notification.dart';
import '../base/crud_repository.dart';

/// Notifications reçues par les utilisateurs (Module 5).
abstract interface class NotificationRepository
    implements CrudRepository<AppNotification> {
  /// Notifications personnelles et envoyées à tous, les plus récentes d'abord.
  Future<List<AppNotification>> forUser(String userId);

  Future<AppNotification> markRead(String id);

  Future<void> markAllRead(String userId);
}
