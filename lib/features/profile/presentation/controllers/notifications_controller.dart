import 'package:flutter/foundation.dart';

import '../../data/profile_mock_data.dart';
import '../../models/app_notification.dart';

/// Centre de notifications (lu / non lu, suppression).
class NotificationsController extends ChangeNotifier {
  NotificationsController._();
  static final NotificationsController instance = NotificationsController._();

  final List<AppNotification> _items = ProfileMockData.notifications();

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;

  void markRead(String id) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || _items[index].isRead) return;
    _items[index].isRead = true;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _items) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
