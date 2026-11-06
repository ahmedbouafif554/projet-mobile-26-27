import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/user.dart';

/// Session client enregistrée sur l'appareil, ouverte seulement après
/// la biométrie du système (visage ou empreinte). Le visage n'est pas
/// envoyé au serveur.
class BiometricLogin {
  BiometricLogin({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  static const _enabledKey = 'client_biometric_enabled';
  static const _userKey = 'client_biometric_user';
  static const _tokenKey = 'client_biometric_token';

  final LocalAuthentication _auth;

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// L'appareil propose Face ID, le déverrouillage facial ou l'empreinte.
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason:
            'Confirmez votre identité pour ouvrir votre compte client.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Mémorise la session courante. À appeler seulement après [authenticate].
  Future<void> enable({required User user, required String token}) async {
    if (user.role != UserRole.client) {
      throw StateError('Réservé aux comptes client.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, token);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  Future<({User user, String token})?> readSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_enabledKey) != true) return null;
      final rawUser = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      if (rawUser == null || token == null || token.isEmpty) return null;
      final user = User.fromJson(
        Map<String, dynamic>.from(jsonDecode(rawUser) as Map),
      );
      if (user.role != UserRole.client) return null;
      return (user: user, token: token);
    } catch (_) {
      return null;
    }
  }
}

final biometricLoginProvider = Provider<BiometricLogin>(
  (ref) => BiometricLogin(),
);

/// Vrai quand un compte client a déjà activé la biométrie sur cet appareil.
final clientBiometricEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricLoginProvider).isEnabled();
});
