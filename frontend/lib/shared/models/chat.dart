import 'json_utils.dart';

/// Interlocuteur principal de la conversation (du point de vue du client).
enum ChatType {
  restaurant('Restaurant'),
  courier('Livreur'),
  support('Support'),
  client('Client');

  const ChatType(this.label);
  final String label;
}

/// Conversation entre utilisateurs (client, restaurant, livreur, support).
class Chat {
  const Chat({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.participantIds = const [],
    this.orderId,
    this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isFlagged = false,
  });

  final String id;
  final ChatType type;
  final String title;

  /// « Commande #SF1046 », « Disponible 7j/7 »…
  final String? subtitle;
  final String? avatarUrl;
  final List<String> participantIds;
  final String? orderId;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  /// Signalée pour la supervision du back office.
  final bool isFlagged;

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'] as String,
    type: parseEnum(ChatType.values, json['type'], ChatType.support),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    participantIds: parseStrings(json['participantIds']),
    orderId: json['orderId'] as String?,
    lastMessage: json['lastMessage'] as String?,
    lastMessageAt: parseDate(json['lastMessageAt']),
    unreadCount: parseInt(json['unreadCount']),
    isOnline: json['isOnline'] as bool? ?? false,
    isFlagged: json['isFlagged'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'subtitle': subtitle,
    'avatarUrl': avatarUrl,
    'participantIds': participantIds,
    'orderId': orderId,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt.toIso8601String(),
    'unreadCount': unreadCount,
    'isOnline': isOnline,
    'isFlagged': isFlagged,
  };

  Chat copyWith({
    String? id,
    ChatType? type,
    String? title,
    Object? subtitle = keep,
    Object? avatarUrl = keep,
    List<String>? participantIds,
    Object? orderId = keep,
    Object? lastMessage = keep,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
    bool? isFlagged,
  }) => Chat(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    subtitle: subtitle == keep ? this.subtitle : subtitle as String?,
    avatarUrl: avatarUrl == keep ? this.avatarUrl : avatarUrl as String?,
    participantIds: participantIds ?? this.participantIds,
    orderId: orderId == keep ? this.orderId : orderId as String?,
    lastMessage: lastMessage == keep
        ? this.lastMessage
        : lastMessage as String?,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    isOnline: isOnline ?? this.isOnline,
    isFlagged: isFlagged ?? this.isFlagged,
  );
}
