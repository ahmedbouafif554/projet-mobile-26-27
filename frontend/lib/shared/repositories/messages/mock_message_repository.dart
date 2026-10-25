import '../../models/message.dart';
import '../base/mock_crud_repository.dart';
import 'message_repository.dart';

class MockMessageRepository extends MockCrudRepository<Message>
    implements MessageRepository {
  MockMessageRepository(super.seed) : super(idPrefix: 'm');

  @override
  String idOf(Message item) => item.id;

  /// Un message créé est considéré comme envoyé.
  @override
  Message withId(Message item, String id) =>
      item.copyWith(id: id, status: MessageStatus.sent);

  @override
  Future<List<Message>> forChat(String chatId) async =>
      (await where((m) => m.chatId == chatId))
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
}
