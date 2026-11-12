import 'package:dio/dio.dart';

/// Erreur réseau avec un message lisible par l'utilisateur.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    // Erreur métier (4xx) : le serveur explique la raison en français
    // (`{ "error": "…" }`) — on l'affiche telle quelle.
    final serverMessage = _serverMessage(error.response?.data);
    if (serverMessage != null &&
        status != null &&
        status >= 400 &&
        status < 500 &&
        status != 401) {
      return ApiException(serverMessage, statusCode: status);
    }
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Le serveur met trop de temps à répondre.',
      DioExceptionType.connectionError => 'Pas de connexion Internet.',
      DioExceptionType.cancel => 'Requête annulée.',
      DioExceptionType.badResponse => switch (status) {
        401 => 'Session expirée, reconnectez-vous.',
        403 => "Vous n'avez pas accès à cette ressource.",
        404 => 'Ressource introuvable.',
        422 => 'Données invalides.',
        final int code when code >= 500 =>
          'Erreur du serveur, réessayez plus tard.',
        _ => 'Requête refusée ($status).',
      },
      _ => 'Une erreur inattendue est survenue.',
    };
    return ApiException(message, statusCode: status);
  }

  static String? _serverMessage(Object? data) {
    if (data is! Map) return null;
    final value = data['error'];
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  @override
  String toString() => message;
}

/// Exécute un appel Dio et transforme les erreurs en [ApiException].
Future<T> runApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw ApiException.fromDio(error);
  }
}
