import 'json_utils.dart';

/// Cycle de vie d'un message envoyé.
enum MessageStatus { sending, sent, delivered, read, failed }

/// Message d'une conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.editedAt,
    this.isDeleted = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;
  final DateTime? editedAt;
  final bool isDeleted;

  bool isMine(String userId) => senderId == userId;
  bool get isEdited => editedAt != null && !isDeleted;

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageStatus? status,
    DateTime? editedAt,
    bool? isDeleted,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId,
    senderId: senderId,
    text: text ?? this.text,
    sentAt: sentAt,
    status: status ?? this.status,
    editedAt: editedAt ?? this.editedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    text: json['text'] as String? ?? '',
    sentAt: parseDate(json['sent_at']),
    status: enumFromJson(
      MessageStatus.values,
      json['status'],
      MessageStatus.sent,
    ),
    editedAt: parseDateOrNull(json['edited_at']),
    isDeleted: json['is_deleted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'text': text,
    'sent_at': sentAt.toUtc().toIso8601String(),
    'status': status.name,
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
  };
}
