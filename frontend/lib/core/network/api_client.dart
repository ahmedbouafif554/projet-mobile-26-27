import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Jeton renvoyé par l'API après connexion (renseigné par l'AuthService).
final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(
  AuthTokenNotifier.new,
);

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

/// Client HTTP partagé par tous les dépôts « API ».
final dioProvider = Provider<Dio>((ref) => createDio(ref));

/// Crée le client Dio : URL de base, délais, en-têtes, jeton d'authentification
/// et journalisation en mode debug.
Dio createDio(Ref ref, {String baseUrl = AppConfig.apiBaseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json', 'Accept-Language': 'fr'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true));
  }
  return dio;
}

/// Extrait la charge utile d'une réponse, qu'elle soit renvoyée directement
/// (`[...]`, `{...}`) ou dans une enveloppe `{"data": ...}`.
dynamic unwrapData(dynamic body) =>
    body is Map<String, dynamic> && body.containsKey('data')
    ? body['data']
    : body;

/// Convertit une réponse JSON en liste de maps.
List<Map<String, dynamic>> jsonList(dynamic body) =>
    (unwrapData(body) as List).cast<Map<String, dynamic>>();

/// Convertit une réponse JSON en map.
Map<String, dynamic> jsonMap(dynamic body) =>
    unwrapData(body) as Map<String, dynamic>;
