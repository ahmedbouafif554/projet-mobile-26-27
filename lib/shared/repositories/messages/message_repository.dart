import '../../models/message.dart';
import '../base/crud_repository.dart';

/// Messages des conversations (Module 5) : envoyer ([create]), modifier,
/// supprimer.
abstract interface class MessageRepository implements CrudRepository<Message> {
  /// Messages d'une conversation, du plus ancien au plus récent.
  Future<List<Message>> forChat(String chatId);
}
