import 'dart:async';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/chat_event.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../mock/communication_mock_data.dart';
import 'chat_repository.dart';

/// Messagerie simulée : après chaque envoi, le message passe à « distribué »
/// puis « lu », l'interlocuteur écrit… et répond automatiquement.
class ChatMockRepository implements ChatRepository {
  late final List<Conversation> _conversations =
      CommunicationMockData.conversationsJson()
          .map(Conversation.fromJson)
          .toList();
  late final Map<String, List<ChatMessage>> _messages = {
    for (final entry in CommunicationMockData.messagesJson().entries)
      entry.key: entry.value.map(ChatMessage.fromJson).toList(),
  };

  final _events = StreamController<ChatEvent>.broadcast();

  /// Minuteurs de la réponse simulée en cours, par conversation.
  final Map<String, List<Timer>> _pending = {};
  final Map<String, int> _replyIndex = {};
  int _sequence = 0;

  String get _me => AppConfig.currentUserId;
  Duration get _tick => AppConfig.mockLatency;

  Future<T> _respond<T>(T Function() compute) async {
    await Future<void>.delayed(_tick);
    return compute();
  }

  Conversation _conversation(String id) => _conversations.firstWhere(
    (c) => c.id == id,
    orElse: () =>
        throw const ApiException('Conversation introuvable.', statusCode: 404),
  );

  void _updateConversation(
    String id,
    Conversation Function(Conversation) update,
  ) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index >= 0) _conversations[index] = update(_conversations[index]);
  }

  ChatMessage _replace(ChatMessage message) {
    final list = _messages[message.conversationId] ?? [];
    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) list[index] = message;
    final conversation = _conversation(message.conversationId);
    if (conversation.lastMessage?.id == message.id) {
      _updateConversation(
        message.conversationId,
        (c) => c.copyWith(lastMessage: message),
      );
    }
    _events.add(MessageUpdated(message));
    return message;
  }

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<List<Conversation>> fetchConversations() => _respond(
    () =>
        List.of(_conversations)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) =>
      _respond(() => List.of(_messages[conversationId] ?? const []));

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text) =>
      _respond(() {
        final message = ChatMessage(
          id: 'msg-${++_sequence}',
          conversationId: conversationId,
          senderId: _me,
          text: text,
          sentAt: DateTime.now(),
        );
        (_messages[conversationId] ??= []).add(message);
        _updateConversation(
          conversationId,
          (c) => c.copyWith(lastMessage: message, updatedAt: message.sentAt),
        );
        _simulateRecipient(message);
        return message;
      });

  /// Simule l'interlocuteur : distribué → lu → « en train d'écrire » → réponse.
  /// Plusieurs messages rapides ne déclenchent qu'une seule réponse.
  void _simulateRecipient(ChatMessage sent) {
    final id = sent.conversationId;
    for (final timer in _pending.remove(id) ?? const <Timer>[]) {
      timer.cancel();
    }

    void markAll(MessageStatus status) {
      for (final m in List.of(_messages[id] ?? const <ChatMessage>[])) {
        if (m.isMine(_me) && !m.isDeleted && m.status.index < status.index) {
          _replace(m.copyWith(status: status));
        }
      }
    }

    _pending[id] = [
      Timer(_tick * 1, () => markAll(MessageStatus.delivered)),
      Timer(_tick * 2.5, () => markAll(MessageStatus.read)),
      Timer(_tick * 3, () => _events.add(TypingChanged(id, isTyping: true))),
      Timer(_tick * 6, () {
        _events.add(TypingChanged(id, isTyping: false));
        _receive(id, _replyFor(id, sent.text));
        _pending.remove(id);
      }),
    ];
  }

  String _replyFor(String conversationId, String text) {
    if (text.toLowerCase().contains('merci')) return 'Avec plaisir 😊';
    final replies =
        CommunicationMockData.autoReplies[_conversation(conversationId).type]!;
    final index = _replyIndex.update(
      conversationId,
      (i) => i + 1,
      ifAbsent: () => 0,
    );
    return replies[index % replies.length];
  }

  void _receive(String conversationId, String text) {
    final conversation = _conversation(conversationId);
    final message = ChatMessage(
      id: 'msg-${++_sequence}',
      conversationId: conversationId,
      senderId: conversation.type.name,
      text: text,
      sentAt: DateTime.now(),
      status: MessageStatus.delivered,
    );
    (_messages[conversationId] ??= []).add(message);
    _updateConversation(
      conversationId,
      (c) => c.copyWith(
        lastMessage: message,
        updatedAt: message.sentAt,
        unreadCount: c.unreadCount + 1,
      ),
    );
    _events.add(MessageReceived(message));
  }

  @override
  Future<ChatMessage> editMessage(ChatMessage message, String text) => _respond(
    () => _replace(message.copyWith(text: text, editedAt: DateTime.now())),
  );

  @override
  Future<ChatMessage> deleteMessage(ChatMessage message) =>
      _respond(() => _replace(message.copyWith(text: '', isDeleted: true)));

  @override
  Future<void> markAsRead(String conversationId) => _respond(
    () =>
        _updateConversation(conversationId, (c) => c.copyWith(unreadCount: 0)),
  );
}
