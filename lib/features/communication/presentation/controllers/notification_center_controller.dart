import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/communication_repositories.dart';
import '../../data/mock/communication_mock_data.dart';
import '../../data/notifications/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../models/notification_settings.dart';

/// État global des notifications : liste, compteur de non lues, réglages
/// et flux des bannières in-app (notifications « push »).
class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController(this._repository) {
    _subscription = _repository.incoming.listen(_onIncoming);
  }

  static final NotificationCenterController instance =
      NotificationCenterController(CommunicationRepositories.notifications);

  /// Délai pendant lequel une suppression peut être annulée.
  static const undoDelay = Duration(seconds: 4);

  final NotificationRepository _repository;
  late final StreamSubscription<AppNotification> _subscription;
  final _banners = StreamController<AppNotification>.broadcast();
  final Map<String, Timer> _pendingDeletes = {};

  List<AppNotification> _items = [];
  NotificationSettings _settings = NotificationSettings.defaults;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _demoIndex = 0;

  List<AppNotification> get items => List.unmodifiable(_items);
  NotificationSettings get settings => _settings;
  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  /// Bannières à afficher en haut de l'écran.
  Stream<AppNotification> get banners => _banners.stream;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    // Pas de notification ici : load() peut être appelé depuis un initState
    // alors que d'autres widgets écoutent ce contrôleur partagé.
    _loading = true;
    _error = null;
    try {
      final remote = await _repository.fetchNotifications();
      _settings = await _repository.fetchSettings();
      // Les notifications générées localement (messages reçus…) sont conservées.
      final local = _items.where((n) => n.id.startsWith('local-'));
      _items = [...local, ...remote]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onIncoming(AppNotification notification) {
    if (_items.any((n) => n.id == notification.id)) return;
    _items = [notification, ..._items];
    notifyListeners();
    if (_settings.shouldShowBanner(notification.type)) {
      if (_settings.sound) HapticFeedback.mediumImpact();
      _banners.add(notification);
    }
  }

  /// Ajoute une notification produite par l'application elle-même
  /// (ex. : nouveau message reçu alors que la conversation est fermée).
  void addLocal(AppNotification notification) => _onIncoming(notification);

  /// Simule la réception d'une notification push (bouton de démonstration).
  void simulatePush() {
    final templates = CommunicationMockData.demoPushesJson();
    final json = templates[_demoIndex++ % templates.length];
    _onIncoming(
      AppNotification.fromJson({
        ...json,
        'id': 'local-push-${DateTime.now().microsecondsSinceEpoch}',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
      }),
    );
  }

  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || _items[index].isRead) return;
    _items = [..._items]..[index] = _items[index].copyWith(isRead: true);
    notifyListeners();
    if (!id.startsWith('local-')) {
      await _silently(() => _repository.markAsRead(id));
    }
  }

  Future<void> markAllAsRead() async {
    _items = [for (final n in _items) n.copyWith(isRead: true)];
    notifyListeners();
    await _silently(_repository.markAllAsRead);
  }

  /// Retire la notification de la liste ; la suppression côté serveur n'est
  /// envoyée qu'après [undoDelay] pour permettre « Annuler ».
  int remove(AppNotification notification) {
    final index = _items.indexWhere((n) => n.id == notification.id);
    if (index < 0) return -1;
    _items = [..._items]..removeAt(index);
    notifyListeners();
    _pendingDeletes[notification.id] = Timer(undoDelay, () {
      _pendingDeletes.remove(notification.id);
      if (!notification.id.startsWith('local-')) {
        _silently(() => _repository.delete(notification.id));
      }
    });
    return index;
  }

  void undoRemove(AppNotification notification, int index) {
    _pendingDeletes.remove(notification.id)?.cancel();
    _items = [..._items]..insert(index.clamp(0, _items.length), notification);
    notifyListeners();
  }

  /// Met à jour les réglages (optimiste, avec retour arrière en cas d'erreur).
  Future<String?> updateSettings(NotificationSettings settings) async {
    final previous = _settings;
    _settings = settings;
    notifyListeners();
    try {
      _settings = await _repository.updateSettings(settings);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      _settings = previous;
      notifyListeners();
      return e.message;
    }
  }

  Future<void> _silently(Future<void> Function() call) async {
    try {
      await call();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    _banners.close();
    super.dispose();
  }
}
