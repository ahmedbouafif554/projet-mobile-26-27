import 'json_utils.dart';

/// Type de notification (détermine l'icône, la couleur et le réglage associé).
enum NotificationType { order, chat, review, promo, system }

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
    NotificationType.order => 'Commandes',
    NotificationType.chat => 'Messages',
    NotificationType.review => 'Avis',
    NotificationType.promo => 'Promotions',
    NotificationType.system => 'Informations',
  };

  String get description => switch (this) {
    NotificationType.order => 'Préparation, livraison, arrivée du livreur',
    NotificationType.chat => 'Nouveaux messages des restaurants et livreurs',
    NotificationType.review => 'Réponses à vos avis, rappels pour noter',
    NotificationType.promo => 'Codes promo et offres exclusives',
    NotificationType.system => 'Nouveautés et informations importantes',
  };
}

/// Notification affichée dans le centre de notifications.
/// (Nommée AppNotification pour éviter le conflit avec `Notification` de Flutter.)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.route,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Page ouverte au clic (chemin go_router), optionnelle.
  final String? route;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    route: route,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: enumFromJson(
          NotificationType.values,
          json['type'],
          NotificationType.system,
        ),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: parseDate(json['created_at']),
        isRead: json['is_read'] as bool? ?? false,
        route: json['route'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    'is_read': isRead,
    'route': route,
  };
}
