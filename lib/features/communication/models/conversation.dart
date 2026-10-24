import 'chat_message.dart';
import 'json_utils.dart';

/// Interlocuteur d'une conversation.
enum ConversationType { restaurant, courier, support }

extension ConversationTypeX on ConversationType {
  String get label => switch (this) {
    ConversationType.restaurant => 'Restaurant',
    ConversationType.courier => 'Livreur',
    ConversationType.support => 'Support',
  };
}

/// Conversation (fil de discussion) avec un restaurant, un livreur ou le support.
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.updatedAt,
    this.avatarUrl,
    this.subtitle,
    this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String id;
  final ConversationType type;
  final String title;

  /// Information complémentaire (ex. « Commande #SF1046 »).
  final String? subtitle;
  final String? avatarUrl;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isOnline;
  final DateTime updatedAt;

  Conversation copyWith({
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isOnline,
    DateTime? updatedAt,
  }) => Conversation(
    id: id,
    type: type,
    title: title,
    subtitle: subtitle,
    avatarUrl: avatarUrl,
    lastMessage: lastMessage ?? this.lastMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    isOnline: isOnline ?? this.isOnline,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    type: enumFromJson(
      ConversationType.values,
      json['type'],
      ConversationType.support,
    ),
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastMessage: json['last_message'] == null
        ? null
        : ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>),
    unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    isOnline: json['is_online'] as bool? ?? false,
    updatedAt: parseDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'subtitle': subtitle,
    'avatar_url': avatarUrl,
    'last_message': lastMessage?.toJson(),
    'unread_count': unreadCount,
    'is_online': isOnline,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
