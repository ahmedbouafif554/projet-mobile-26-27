import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../models/chat_event.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'chat_repository.dart';

/// Messagerie via l'API REST.
///
/// Les événements temps réel sont récupérés par polling de `/chat/events` ;
/// un WebSocket pourra le remplacer sans changer les écrans.
class ChatApiRepository implements ChatRepository {
  ChatApiRepository(
    this._dio, {
    this.pollInterval = const Duration(seconds: 4),
  });

  final Dio _dio;
  final Duration pollInterval;

  StreamController<ChatEvent>? _events;
  Timer? _poller;
  DateTime _lastSync = DateTime.now();

  @override
  Future<List<Conversation>> fetchConversations() => runApi(() async {
    final response = await _dio.get('/conversations');
    return jsonList(response.data).map(Conversation.fromJson).toList();
  });

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) =>
      runApi(() async {
        final response = await _dio.get(
          '/conversations/$conversationId/messages',
        );
        return jsonList(response.data).map(ChatMessage.fromJson).toList();
      });

  @override
  Future<ChatMessage> sendMessage(String conversationId, String text) =>
      runApi(() async {
        final response = await _dio.post(
          '/conversations/$conversationId/messages',
          data: {'text': text},
        );
        return ChatMessage.fromJson(jsonMap(response.data));
      });

  @override
  Future<ChatMessage> editMessage(ChatMessage message, String text) =>
      runApi(() async {
        final response = await _dio.patch(
          '/messages/${message.id}',
          data: {'text': text},
        );
        return ChatMessage.fromJson(jsonMap(response.data));
      });

  @override
  Future<ChatMessage> deleteMessage(ChatMessage message) => runApi(() async {
    await _dio.delete<void>('/messages/${message.id}');
    return message.copyWith(text: '', isDeleted: true);
  });

  @override
  Future<void> markAsRead(String conversationId) =>
      runApi(() => _dio.post<void>('/conversations/$conversationId/read'));

  @override
  Stream<ChatEvent> get events {
    _events ??= StreamController<ChatEvent>.broadcast(
      onListen: () => _poller = Timer.periodic(pollInterval, (_) => _poll()),
      onCancel: () => _poller?.cancel(),
    );
    return _events!.stream;
  }

  Future<void> _poll() async {
    try {
      final since = _lastSync;
      final response = await _dio.get(
        '/chat/events',
        queryParameters: {'since': since.toUtc().toIso8601String()},
      );
      _lastSync = DateTime.now();
      for (final json in jsonList(response.data)) {
        final event = ChatEvent.fromJson(json);
        if (event != null) _events?.add(event);
      }
    } on DioException {
      // Réseau indisponible : nouvelle tentative au prochain tour.
    }
  }
}
