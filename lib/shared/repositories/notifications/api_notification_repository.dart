import '../../../core/network/api_exception.dart';
import '../../models/app_notification.dart';
import '../base/api_crud_repository.dart';
import 'notification_repository.dart';

class ApiNotificationRepository extends ApiCrudRepository<AppNotification>
    implements NotificationRepository {
  ApiNotificationRepository(super.dio) : super(path: '/notifications');

  @override
  AppNotification fromJson(Map<String, dynamic> json) =>
      AppNotification.fromJson(json);

  @override
  Map<String, dynamic> toJson(AppNotification item) => item.toJson();

  @override
  String idOf(AppNotification item) => item.id;

  @override
  Future<List<AppNotification>> forUser(String userId) =>
      getList('/users/$userId/notifications');

  @override
  Future<AppNotification> markRead(String id) => patch(id, 'read');

  @override
  Future<void> markAllRead(String userId) =>
      runApi(() => dio.post<void>('/users/$userId/notifications/read-all'));
}
