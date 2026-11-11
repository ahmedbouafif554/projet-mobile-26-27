import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../network/api_exception.dart';

/// Obtient un ID token Google (Android / iOS). Le serveur le vérifie dans
/// `POST /auth/google` : l'application ne fait jamais confiance au profil
/// Google seule.
class GoogleAuth {
  GoogleAuth._();

  static Future<void>? _initializing;

  static Future<void> _initialize() =>
      _initializing ??= GoogleSignIn.instance.initialize(
        clientId: AppConfig.googleClientId.isEmpty
            ? null
            : AppConfig.googleClientId,
        serverClientId: AppConfig.googleServerClientId.isEmpty
            ? null
            : AppConfig.googleServerClientId,
      );

  static Future<String> idToken() async {
    try {
      await _initialize();
      final signIn = GoogleSignIn.instance;
      if (!signIn.supportsAuthenticate()) {
        throw const ApiException(
          "La connexion Google n'est pas disponible sur cet appareil.",
        );
      }
      final account = await signIn.authenticate(scopeHint: const ['email']);
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException("Google n'a pas renvoyé votre identité.");
      }
      return token;
    } on GoogleSignInException catch (error) {
      _initializing = null;
      final detail = (error.description ?? '').trim();
      // Sur Android, « canceled » arrive aussi quand l'application n'est pas
      // déclarée dans Google Cloud (client OAuth Android : paquet + SHA-1).
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw ApiException(
          detail.isEmpty
              ? 'Connexion Google annulée.'
              : 'Connexion Google annulée ($detail).',
        );
      }
      throw ApiException(
        'Connexion Google impossible (${detail.isEmpty ? error.code.name : detail}).',
      );
    }
  }

  /// Oublie le compte Google choisi (à la déconnexion).
  static Future<void> signOut() async {
    if (_initializing == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Pas de session Google ouverte : rien à faire.
    }
  }
}
