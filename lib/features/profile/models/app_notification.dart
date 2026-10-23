/// Catégorie de notification (détermine l'icône et la couleur).
enum NotificationKind { order, promo, info }

/// Notification affichée dans le centre de notifications.
/// Nommée AppNotification pour éviter le conflit avec `Notification` de Flutter.
class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.kind,
    this.route,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final NotificationKind kind;

  /// Page ouverte au clic (optionnelle).
  final String? route;
  bool isRead;
}
