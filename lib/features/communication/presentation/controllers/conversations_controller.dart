import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../communication_routes.dart';
import '../../data/chat/chat_repository.dart';
import '../../data/communication_repositories.dart';
import '../../models/app_notification.dart';
import '../../models/chat_event.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'notification_center_controller.dart';

/// Liste des conversations, compteur global de non lus et indicateurs
/// « en train d'écrire ». Partagé par toute l'application.
class ConversationsController extends ChangeNotifier {
  ConversationsController(this._repository) {
    _subscription = _repository.events.listen(_onEvent);
  }

  static final ConversationsController instance = ConversationsController(
    CommunicationRepositories.chat,
  );

  final ChatRepository _repository;
  late final StreamSubscription<ChatEvent> _subscription;

  List<Conversation> _conversations = [];
  final Set<String> _typing = {};
  String? _openConversationId;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;
  String? get error => _error;
  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  bool isTyping(String conversationId) => _typing.contains(conversationId);

  Conversation? byId(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    // Pas de notification ici : load() peut être appelé depuis un initState
    // alors que d'autres widgets écoutent ce contrôleur partagé.
    _loading = true;
    _error = null;
    try {
      _conversations = await _repository.fetchConversations();
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Conversation actuellement affichée (ses messages sont lus à l'arrivée).
  void setOpenConversation(String? conversationId) {
    _openConversationId = conversationId;
    if (conversationId != null) markAsRead(conversationId);
  }

  Future<void> markAsRead(String conversationId) async {
    final conversation = byId(conversationId);
    if (conversation == null || conversation.unreadCount == 0) return;
    _replace(conversation.copyWith(unreadCount: 0));
    try {
      await _repository.markAsRead(conversationId);
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  /// Appelé après l'envoi d'un message pour remonter la conversation.
  void onMessageSent(ChatMessage message) {
    final conversation = byId(message.conversationId);
    if (conversation == null) return;
    _replace(
      conversation.copyWith(lastMessage: message, updatedAt: message.sentAt),
    );
  }

  void _replace(Conversation conversation) {
    _conversations = [
      for (final c in _conversations)
        c.id == conversation.id ? conversation : c,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  void _onEvent(ChatEvent event) {
    switch (event) {
      case MessageReceived(:final message):
        _typing.remove(message.conversationId);
        final conversation = byId(message.conversationId);
        if (conversation == null) return;
        final isOpen = _openConversationId == message.conversationId;
        _replace(
          conversation.copyWith(
            lastMessage: message,
            updatedAt: message.sentAt,
            unreadCount: isOpen ? 0 : conversation.unreadCount + 1,
          ),
        );
        if (isOpen) {
          _repository.markAsRead(message.conversationId).ignore();
        } else {
          // Conversation fermée : bannière + entrée dans le centre de notifications.
          NotificationCenterController.instance.addLocal(
            AppNotification(
              id: 'local-chat-${message.id}',
              type: NotificationType.chat,
              title: conversation.title,
              body: message.text,
              createdAt: message.sentAt,
              route: CommunicationRoutes.chat(conversation.id),
            ),
          );
        }
      case MessageUpdated(:final message):
        final conversation = byId(message.conversationId);
        if (conversation?.lastMessage?.id == message.id) {
          _replace(conversation!.copyWith(lastMessage: message));
        }
      case TypingChanged(:final conversationId, :final isTyping):
        isTyping ? _typing.add(conversationId) : _typing.remove(conversationId);
        notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
