import '../../models/chat.dart';
import '../base/crud_repository.dart';

/// Conversations (Module 5).
abstract interface class ChatRepository implements CrudRepository<Chat> {
  /// Conversations d'un utilisateur, les plus récentes d'abord.
  Future<List<Chat>> forUser(String userId);

  /// Remet le compteur de messages non lus à zéro.
  Future<Chat> markRead(String id);

  /// Signale (ou non) la conversation pour la supervision.
  Future<Chat> setFlagged(String id, bool isFlagged);
}
