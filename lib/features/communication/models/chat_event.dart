import 'chat_message.dart';

/// Événement temps réel d'une conversation (WebSocket, polling ou mock).
sealed class ChatEvent {
  const ChatEvent(this.conversationId);

  final String conversationId;

  /// Décode un événement envoyé par l'API (`null` si type inconnu).
  static ChatEvent? fromJson(Map<String, dynamic> json) =>
      switch (json['event']) {
        'message_received' => MessageReceived(
          ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
        ),
        'message_updated' => MessageUpdated(
          ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
        ),
        'typing' => TypingChanged(
          json['conversation_id'] as String,
          isTyping: json['is_typing'] as bool? ?? false,
        ),
        _ => null,
      };

  Map<String, dynamic> toJson() => switch (this) {
    MessageReceived(:final message) => {
      'event': 'message_received',
      'message': message.toJson(),
    },
    MessageUpdated(:final message) => {
      'event': 'message_updated',
      'message': message.toJson(),
    },
    TypingChanged(:final isTyping) => {
      'event': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    },
  };
}

/// Un nouveau message est arrivé.
class MessageReceived extends ChatEvent {
  MessageReceived(this.message) : super(message.conversationId);

  final ChatMessage message;
}

/// Un message existant a changé (statut lu, modification, suppression).
class MessageUpdated extends ChatEvent {
  MessageUpdated(this.message) : super(message.conversationId);

  final ChatMessage message;
}

/// L'interlocuteur commence ou arrête d'écrire.
class TypingChanged extends ChatEvent {
  const TypingChanged(super.conversationId, {required this.isTyping});

  final bool isTyping;
}
