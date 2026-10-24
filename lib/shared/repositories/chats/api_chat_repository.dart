import '../../models/chat.dart';
import '../base/api_crud_repository.dart';
import 'chat_repository.dart';

class ApiChatRepository extends ApiCrudRepository<Chat>
    implements ChatRepository {
  ApiChatRepository(super.dio) : super(path: '/chats');

  @override
  Chat fromJson(Map<String, dynamic> json) => Chat.fromJson(json);

  @override
  Map<String, dynamic> toJson(Chat item) => item.toJson();

  @override
  String idOf(Chat item) => item.id;

  @override
  Future<List<Chat>> forUser(String userId) =>
      getList(path, query: {'userId': userId});

  @override
  Future<Chat> markRead(String id) => patch(id, 'read');

  @override
  Future<Chat> setFlagged(String id, bool isFlagged) =>
      patch(id, 'flag', {'isFlagged': isFlagged});
}
