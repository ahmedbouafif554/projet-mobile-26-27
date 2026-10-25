import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'crud_repository.dart';

/// Base des dépôts API (REST) : `GET /path`, `GET /path/:id`, `POST /path`,
/// `PUT /path/:id`, `DELETE /path/:id`. Les réponses peuvent être brutes
/// ou enveloppées dans `{"data": ...}` ; les erreurs deviennent des
/// [ApiException] au message lisible.
abstract class ApiCrudRepository<T> implements CrudRepository<T> {
  ApiCrudRepository(this.dio, {required this.path});

  final Dio dio;

  /// Ressource REST (ex. `/users`).
  final String path;

  T fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson(T item);

  String idOf(T item);

  @override
  Future<List<T>> getAll() => getList(path);

  @override
  Future<T> getById(String id) => runApi(() async {
    final response = await dio.get('$path/$id');
    return fromJson(jsonMap(response.data));
  });

  @override
  Future<T> create(T item) => runApi(() async {
    final response = await dio.post(path, data: toJson(item));
    return fromJson(jsonMap(response.data));
  });

  @override
  Future<T> update(T item) => runApi(() async {
    final response = await dio.put('$path/${idOf(item)}', data: toJson(item));
    return fromJson(jsonMap(response.data));
  });

  @override
  Future<void> delete(String id) => runApi(() => dio.delete<void>('$path/$id'));

  /// Liste d'éléments d'une URL (avec paramètres de requête éventuels).
  @protected
  Future<List<T>> getList(String url, {Map<String, dynamic>? query}) =>
      runApi(() async {
        final response = await dio.get(url, queryParameters: query);
        return jsonList(response.data).map(fromJson).toList();
      });

  /// Action ciblée sur un élément (`PATCH /path/:id/action`).
  @protected
  Future<T> patch(String id, String action, [Map<String, dynamic>? data]) =>
      runApi(() async {
        final response = await dio.patch('$path/$id/$action', data: data);
        return fromJson(jsonMap(response.data));
      });
}
