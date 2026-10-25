import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../models/models.dart';
import '../repositories/repository_providers.dart';

// =============================================================================
// Messagerie partagée par les deux applications (Module 5) : messages d'une
// conversation, indicateur « en train d'écrire », noms des participants.
// =============================================================================

/// Incrémenté quand une conversation change (nouveau message) : les listes
/// de conversations des deux apps le surveillent et se rechargent.
final chatsRevisionProvider = NotifierProvider<ChatsRevision, int>(
  ChatsRevision.new,
);

class ChatsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Comptes de la plateforme par identifiant (noms des participants).
final usersByIdProvider = FutureProvider<Map<String, User>>((ref) async {
  final users = await ref.watch(userRepositoryProvider).getAll();
  return {for (final u in users) u.id: u};
});

/// « En train d'écrire… » pour une conversation.
final chatTypingProvider = NotifierProvider.autoDispose
    .family<ChatTypingNotifier, bool, String>(ChatTypingNotifier.new);

class ChatTypingNotifier extends Notifier<bool> {
  ChatTypingNotifier(this.chatId);

  final String chatId;

  @override
  bool build() => false;

  void set(bool typing) => state = typing;
}

/// Messages d'une conversation : envoyer, modifier, supprimer. Après un
/// envoi, l'autre participant répond automatiquement (démonstration).
final chatMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ChatMessagesController, List<Message>, String>(
      ChatMessagesController.new,
    );

class ChatMessagesController extends AsyncNotifier<List<Message>> {
  ChatMessagesController(this.chatId);

  final String chatId;
  Timer? _replyTimer;

  static const _replies = [
    'Merci beaucoup !',
    'Parfait, merci 🙏',
    "D'accord, c'est noté.",
    'Super, à tout à l’heure !',
    'Merci pour votre réactivité 👍',
  ];

  @override
  Future<List<Message>> build() {
    ref.onDispose(() => _replyTimer?.cancel());
    return ref.read(messageRepositoryProvider).forChat(chatId);
  }

  /// Envoi optimiste : la bulle apparaît tout de suite (« envoi… »).
  Future<void> send(String text, {required Chat chat}) async {
    final user = ref.read(authServiceProvider).user!;
    final draft = Message(
      id: 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderId: user.id,
      senderName: user.role == UserRole.admin
          ? 'Support SuperFaster'
          : user.fullName,
      text: text,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
    );
    state = AsyncData([...?state.value, draft]);
    final sent = await ref
        .read(messageRepositoryProvider)
        .create(draft.copyWith(id: ''));
    if (!ref.mounted) return;
    state = AsyncData([
      for (final m in state.value ?? const <Message>[])
        m.id == draft.id ? sent : m,
    ]);
    await _touchChat(text);
    if (ref.mounted) _scheduleReply(chat, user.id);
  }

  Future<void> edit(Message message, String text) async {
    final updated = await ref
        .read(messageRepositoryProvider)
        .update(message.copyWith(text: text, editedAt: DateTime.now()));
    state = AsyncData([
      for (final m in state.value ?? const <Message>[])
        m.id == message.id ? updated : m,
    ]);
  }

  Future<void> delete(Message message) async {
    await ref.read(messageRepositoryProvider).delete(message.id);
    state = AsyncData([
      for (final m in state.value ?? const <Message>[])
        if (m.id != message.id) m,
    ]);
  }

  /// Met à jour l'aperçu de la conversation dans la liste.
  Future<void> _touchChat(String text) async {
    if (!ref.mounted) return;
    final chats = ref.read(chatRepositoryProvider);
    final current = await chats.getById(chatId);
    await chats.update(
      current.copyWith(
        lastMessage: text,
        lastMessageAt: DateTime.now(),
        unreadCount: 0,
      ),
    );
    if (ref.mounted) ref.read(chatsRevisionProvider.notifier).bump();
  }

  /// Réponse simulée de l'autre participant après quelques secondes.
  void _scheduleReply(Chat chat, String myId) {
    final otherId = chat.participantIds
        .where((id) => id != myId)
        .firstOrNull;
    if (otherId == null) return;
    _replyTimer?.cancel();
    void setTyping(bool typing) {
      if (ref.mounted) ref.read(chatTypingProvider(chatId).notifier).set(typing);
    }

    _replyTimer = Timer(const Duration(milliseconds: 1200), () {
      setTyping(true);
      _replyTimer = Timer(const Duration(milliseconds: 2200), () async {
        setTyping(false);
        if (!ref.mounted) return;
        final users = ref.read(usersByIdProvider).value ?? const {};
        final text = _replies[math.Random().nextInt(_replies.length)];
        final reply = await ref
            .read(messageRepositoryProvider)
            .create(
              Message(
                id: '',
                chatId: chatId,
                senderId: otherId,
                senderName: users[otherId]?.firstName ?? '',
                text: text,
                sentAt: DateTime.now(),
              ),
            );
        if (!ref.mounted) return;
        state = AsyncData([...?state.value, reply]);
        await _touchChat(text);
      });
    });
  }
}
