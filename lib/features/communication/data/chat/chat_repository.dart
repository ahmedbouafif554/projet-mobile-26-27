import '../../models/chat_event.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';

/// Accès à la messagerie (implémenté par l'API Dio et par les données mock).
abstract interface class ChatRepository {
  Future<List<Conversation>> fetchConversations();
  Future<List<ChatMessage>> fetchMessages(String conversationId);
  Future<ChatMessage> sendMessage(String conversationId, String text);
  Future<ChatMessage> editMessage(ChatMessage message, String text);
  Future<ChatMessage> deleteMessage(ChatMessage message);

  /// Remet à zéro le compteur de non lus d'une conversation.
  Future<void> markAsRead(String conversationId);

  /// Événements temps réel : nouveaux messages, statuts, « en train d'écrire ».
  Stream<ChatEvent> get events;
}
