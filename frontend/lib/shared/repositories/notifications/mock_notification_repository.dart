import '../../models/app_notification.dart';
import '../base/mock_crud_repository.dart';
import 'notification_repository.dart';

class MockNotificationRepository extends MockCrudRepository<AppNotification>
    implements NotificationRepository {
  MockNotificationRepository(super.seed) : super(idPrefix: 'n');

  @override
  String idOf(AppNotification item) => item.id;

  @override
  AppNotification withId(AppNotification item, String id) =>
      item.copyWith(id: id);

  bool _isFor(AppNotification n, String userId) =>
      n.userId == null || n.userId == userId;

  @override
  Future<List<AppNotification>> forUser(String userId) async =>
      (await where((n) => _isFor(n, userId)))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<AppNotification> markRead(String id) =>
      mutate(id, (n) => n.copyWith(isRead: true));

  @override
  Future<void> markAllRead(String userId) async {
    await latency();
    replaceAll([
      for (final n in items) _isFor(n, userId) ? n.copyWith(isRead: true) : n,
    ]);
  }
}
