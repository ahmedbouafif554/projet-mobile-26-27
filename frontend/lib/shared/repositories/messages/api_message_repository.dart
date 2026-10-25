import '../../models/message.dart';
import '../base/api_crud_repository.dart';
import 'message_repository.dart';

class ApiMessageRepository extends ApiCrudRepository<Message>
    implements MessageRepository {
  ApiMessageRepository(super.dio) : super(path: '/messages');

  @override
  Message fromJson(Map<String, dynamic> json) => Message.fromJson(json);

  @override
  Map<String, dynamic> toJson(Message item) => item.toJson();

  @override
  String idOf(Message item) => item.id;

  @override
  Future<List<Message>> forChat(String chatId) =>
      getList('/chats/$chatId/messages');
}
