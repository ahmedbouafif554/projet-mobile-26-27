import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/chat/chat_repository.dart';
import '../../data/communication_repositories.dart';
import '../../models/chat_event.dart';
import '../../models/chat_message.dart';
import 'conversations_controller.dart';

/// État d'un écran de conversation : messages, envoi optimiste,
/// modification / suppression et indicateur « en train d'écrire ».
class ChatRoomController extends ChangeNotifier {
  ChatRoomController(this.conversationId, {ChatRepository? repository})
    : _repository = repository ?? CommunicationRepositories.chat {
    _subscription = _repository.events
        .where((e) => e.conversationId == conversationId)
        .listen(_onEvent);
  }

  final String conversationId;
  final ChatRepository _repository;
  late final StreamSubscription<ChatEvent> _subscription;

  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _isTyping = false;
  ChatMessage? _editing;
  bool _disposed = false;

  /// Messages apparus après l'ouverture (animés à l'arrivée).
  final Set<String> _fresh = {};

  /// Identifiant serveur → identifiant local, pour garder la même bulle
  /// (et éviter de rejouer son animation) quand le serveur confirme l'envoi.
  final Map<String, String> _localKeys = {};

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  ChatMessage? get editing => _editing;
  String get me => AppConfig.currentUserId;

  String keyOf(ChatMessage message) => _localKeys[message.id] ?? message.id;
  bool isFresh(ChatMessage message) => _fresh.contains(keyOf(message));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _messages = await _repository.fetchMessages(conversationId);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _replaceById(String id, ChatMessage message) {
    _messages = [for (final m in _messages) m.id == id ? message : m];
    _notify();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final draft = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: me,
      text: trimmed,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    _messages = [..._messages, draft];
    _fresh.add(draft.id);
    _notify();
    await _deliver(draft);
  }

  Future<void> _deliver(ChatMessage draft) async {
    try {
      final sent = await _repository.sendMessage(conversationId, draft.text);
      _localKeys[sent.id] = draft.id;
      _replaceById(draft.id, sent);
      ConversationsController.instance.onMessageSent(sent);
    } on ApiException catch (e) {
      _error = e.message;
      _replaceById(draft.id, draft.copyWith(status: MessageStatus.failed));
    }
  }

  /// Renvoie un message en échec.
  Future<void> retry(ChatMessage failed) async {
    final draft = failed.copyWith(status: MessageStatus.sending);
    _replaceById(failed.id, draft);
    await _deliver(draft);
  }

  void startEditing(ChatMessage message) {
    _editing = message;
    _notify();
  }

  void cancelEditing() {
    _editing = null;
    _notify();
  }

  /// Enregistre la modification en cours (optimiste). Retourne une erreur éventuelle.
  Future<String?> saveEdit(String text) async {
    final original = _editing;
    final trimmed = text.trim();
    _editing = null;
    if (original == null || trimmed.isEmpty || trimmed == original.text) {
      _notify();
      return null;
    }
    _replaceById(
      original.id,
      original.copyWith(text: trimmed, editedAt: DateTime.now()),
    );
    try {
      _replaceById(
        original.id,
        await _repository.editMessage(original, trimmed),
      );
      return null;
    } on ApiException catch (e) {
      _replaceById(original.id, original);
      return e.message;
    }
  }

  Future<String?> delete(ChatMessage message) async {
    _replaceById(message.id, message.copyWith(text: '', isDeleted: true));
    try {
      _replaceById(message.id, await _repository.deleteMessage(message));
      return null;
    } on ApiException catch (e) {
      _replaceById(message.id, message);
      return e.message;
    }
  }

  void _onEvent(ChatEvent event) {
    switch (event) {
      case MessageReceived(:final message):
        if (_messages.any((m) => m.id == message.id)) return;
        _isTyping = false;
        _fresh.add(message.id);
        _messages = [..._messages, message];
        _notify();
      case MessageUpdated(:final message):
        if (_messages.any((m) => m.id == message.id)) {
          _replaceById(message.id, message);
        }
      case TypingChanged(:final isTyping):
        _isTyping = isTyping;
        _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
