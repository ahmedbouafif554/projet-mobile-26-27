import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Client HTTP partagé (Dio) : URL de base, délais, en-têtes,
/// jeton d'authentification et journalisation en mode debug.
class ApiClient {
  ApiClient._();

  /// Instance unique, créée seulement si un dépôt « API » est utilisé.
  static final Dio dio = create();

  /// Jeton renvoyé par l'API après connexion (à renseigner par le module auth).
  static String? authToken;

  static Dio create({String baseUrl = AppConfig.apiBaseUrl}) {
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
          final token = authToken;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: false),
      );
    }
    return dio;
  }
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
