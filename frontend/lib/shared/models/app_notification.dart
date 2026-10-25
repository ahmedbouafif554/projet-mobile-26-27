import 'json_utils.dart';

enum NotificationType {
  order('Commandes'),
  promo('Promotions'),
  message('Messages'),
  review('Avis'),
  system('Système');

  const NotificationType(this.label);
  final String label;
}

/// Notification reçue par un utilisateur (centre de notifications).
class AppNotification {
  const AppNotification({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    this.type = NotificationType.system,
    this.isRead = false,
    this.route,
    this.imageUrl,
    required this.createdAt,
  });

  final String id;

  /// Destinataire (null = envoyée à tous, via une campagne).
  final String? userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;

  /// Écran ouvert au toucher (lien profond go_router).
  final String? route;
  final String? imageUrl;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        type: parseEnum(
          NotificationType.values,
          json['type'],
          NotificationType.system,
        ),
        isRead: json['isRead'] as bool? ?? false,
        route: json['route'] as String?,
        imageUrl: json['imageUrl'] as String?,
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type.name,
    'isRead': isRead,
    'route': route,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  AppNotification copyWith({
    String? id,
    Object? userId = keep,
    String? title,
    String? body,
    NotificationType? type,
    bool? isRead,
    Object? route = keep,
    Object? imageUrl = keep,
    DateTime? createdAt,
  }) => AppNotification(
    id: id ?? this.id,
    userId: userId == keep ? this.userId : userId as String?,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    isRead: isRead ?? this.isRead,
    route: route == keep ? this.route : route as String?,
    imageUrl: imageUrl == keep ? this.imageUrl : imageUrl as String?,
    createdAt: createdAt ?? this.createdAt,
  );
}

enum CampaignAudience {
  all('Tous les utilisateurs'),
  clients('Clients'),
  couriers('Livreurs'),
  restaurants('Restaurants');

  const CampaignAudience(this.label);
  final String label;
}

enum CampaignStatus {
  draft('Brouillon'),
  scheduled('Programmée'),
  sent('Envoyée');

  const CampaignStatus(this.label);
  final String label;
}

/// Campagne de notifications envoyée depuis le back office.
class NotificationCampaign {
  const NotificationCampaign({
    required this.id,
    required this.title,
    required this.body,
    this.audience = CampaignAudience.all,
    this.status = CampaignStatus.draft,
    this.scheduledAt,
    this.sentAt,
    this.recipientCount = 0,
    this.openRate = 0,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final CampaignAudience audience;
  final CampaignStatus status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final int recipientCount;

  /// Taux d'ouverture (0 à 1).
  final double openRate;
  final DateTime createdAt;

  factory NotificationCampaign.fromJson(Map<String, dynamic> json) =>
      NotificationCampaign(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        audience: parseEnum(
          CampaignAudience.values,
          json['audience'],
          CampaignAudience.all,
        ),
        status: parseEnum(
          CampaignStatus.values,
          json['status'],
          CampaignStatus.draft,
        ),
        scheduledAt: parseDateOrNull(json['scheduledAt']),
        sentAt: parseDateOrNull(json['sentAt']),
        recipientCount: parseInt(json['recipientCount']),
        openRate: parseDouble(json['openRate']),
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'audience': audience.name,
    'status': status.name,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'sentAt': sentAt?.toIso8601String(),
    'recipientCount': recipientCount,
    'openRate': openRate,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationCampaign copyWith({
    String? id,
    String? title,
    String? body,
    CampaignAudience? audience,
    CampaignStatus? status,
    Object? scheduledAt = keep,
    Object? sentAt = keep,
    int? recipientCount,
    double? openRate,
    DateTime? createdAt,
  }) => NotificationCampaign(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    audience: audience ?? this.audience,
    status: status ?? this.status,
    scheduledAt: scheduledAt == keep
        ? this.scheduledAt
        : scheduledAt as DateTime?,
    sentAt: sentAt == keep ? this.sentAt : sentAt as DateTime?,
    recipientCount: recipientCount ?? this.recipientCount,
    openRate: openRate ?? this.openRate,
    createdAt: createdAt ?? this.createdAt,
  );
}
