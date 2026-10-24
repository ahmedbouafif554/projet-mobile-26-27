import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/app_notification.dart';
import '../../models/notification_settings.dart';
import 'notification_repository.dart';

/// Notifications via l'API REST.
///
/// Le temps réel est assuré par un polling léger ; il pourra être remplacé
/// par Firebase Cloud Messaging ou un WebSocket sans toucher aux écrans.
class NotificationApiRepository implements NotificationRepository {
  NotificationApiRepository(
    this._dio, {
    this.pollInterval = const Duration(seconds: 30),
  });

  final Dio _dio;
  final Duration pollInterval;

  StreamController<AppNotification>? _incoming;
  Timer? _poller;
  DateTime _lastSync = DateTime.now();

  @override
  Future<List<AppNotification>> fetchNotifications() => runApi(() async {
    final response = await _dio.get('/notifications');
    _lastSync = DateTime.now();
    return jsonList(response.data).map(AppNotification.fromJson).toList();
  });

  @override
  Future<void> markAsRead(String notificationId) => runApi(
    () => _dio.patch<void>(
      '/notifications/$notificationId',
      data: {'is_read': true},
    ),
  );

  @override
  Future<void> markAllAsRead() =>
      runApi(() => _dio.post<void>('/notifications/read-all'));

  @override
  Future<void> delete(String notificationId) =>
      runApi(() => _dio.delete<void>('/notifications/$notificationId'));

  @override
  Future<NotificationSettings> fetchSettings() => runApi(() async {
    final response = await _dio.get('/notifications/settings');
    return NotificationSettings.fromJson(jsonMap(response.data));
  });

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings settings) =>
      runApi(() async {
        final response = await _dio.put(
          '/notifications/settings',
          data: settings.toJson(),
        );
        return NotificationSettings.fromJson(jsonMap(response.data));
      });

  @override
  Stream<AppNotification> get incoming {
    _incoming ??= StreamController<AppNotification>.broadcast(
      onListen: () => _poller = Timer.periodic(pollInterval, (_) => _poll()),
      onCancel: () => _poller?.cancel(),
    );
    return _incoming!.stream;
  }

  Future<void> _poll() async {
    try {
      final since = _lastSync;
      final response = await _dio.get(
        '/notifications',
        queryParameters: {'since': since.toUtc().toIso8601String()},
      );
      _lastSync = DateTime.now();
      for (final json in jsonList(response.data)) {
        _incoming?.add(AppNotification.fromJson(json));
      }
    } on DioException {
      // Réseau indisponible : nouvelle tentative au prochain tour.
    }
  }
}
