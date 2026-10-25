import 'json_utils.dart';

/// Accusés : envoi en cours → envoyé → distribué → lu.
enum MessageStatus { sending, sent, delivered, read }

/// Message d'une conversation.
class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName = '',
    required this.text,
    this.status = MessageStatus.sent,
    this.isSystem = false,
    required this.sentAt,
    this.editedAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final MessageStatus status;

  /// Message automatique (« Commande récupérée par le livreur »).
  final bool isSystem;
  final DateTime sentAt;
  final DateTime? editedAt;

  bool isMine(String userId) => senderId == userId;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    chatId: json['chatId'] as String,
    senderId: json['senderId'] as String,
    senderName: json['senderName'] as String? ?? '',
    text: json['text'] as String? ?? '',
    status: parseEnum(MessageStatus.values, json['status'], MessageStatus.sent),
    isSystem: json['isSystem'] as bool? ?? false,
    sentAt: parseDate(json['sentAt']),
    editedAt: parseDateOrNull(json['editedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'status': status.name,
    'isSystem': isSystem,
    'sentAt': sentAt.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
  };

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? text,
    MessageStatus? status,
    bool? isSystem,
    DateTime? sentAt,
    Object? editedAt = keep,
  }) => Message(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    senderId: senderId ?? this.senderId,
    senderName: senderName ?? this.senderName,
    text: text ?? this.text,
    status: status ?? this.status,
    isSystem: isSystem ?? this.isSystem,
    sentAt: sentAt ?? this.sentAt,
    editedAt: editedAt == keep ? this.editedAt : editedAt as DateTime?,
  );
}
