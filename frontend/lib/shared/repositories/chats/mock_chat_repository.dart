import '../../models/chat.dart';
import '../base/mock_crud_repository.dart';
import 'chat_repository.dart';

class MockChatRepository extends MockCrudRepository<Chat>
    implements ChatRepository {
  MockChatRepository(super.seed) : super(idPrefix: 'chat');

  @override
  String idOf(Chat item) => item.id;

  @override
  Chat withId(Chat item, String id) => item.copyWith(id: id);

  @override
  Future<List<Chat>> getAll() async =>
      (await super.getAll())
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  @override
  Future<List<Chat>> forUser(String userId) async =>
      (await where((c) => c.participantIds.contains(userId)))
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

  @override
  Future<Chat> markRead(String id) =>
      mutate(id, (c) => c.copyWith(unreadCount: 0));

  @override
  Future<Chat> setFlagged(String id, bool isFlagged) =>
      mutate(id, (c) => c.copyWith(isFlagged: isFlagged));
}
