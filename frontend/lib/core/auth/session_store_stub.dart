import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session sur mobile et bureau : chiffrée par le système (Android Keystore,
/// trousseau iOS). Une copie en mémoire permet une lecture immédiate ;
/// [loadSession] la remplit au démarrage, avant l'affichage de l'application.

const _key = 'sf_session';
const _storage = FlutterSecureStorage();

Map<String, dynamic>? _cache;

/// Vrai une fois [loadSession] appelé (application lancée). Sans lui (tests),
/// aucune session n'est gardée : chaque test démarre déconnecté.
bool _enabled = false;

Future<void> loadSession() async {
  _enabled = true;
  try {
    final raw = await _storage.read(key: _key);
    _cache = _decode(raw);
  } catch (_) {
    // Stockage illisible (restauration d'appareil, clé changée) : on repart
    // d'une session vide plutôt que de bloquer le démarrage.
    _cache = null;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

Map<String, dynamic>? readSession() => _cache;

void writeSession(Map<String, dynamic>? session) {
  if (!_enabled) return;
  _cache = session;
  _persist(session);
}

/// Écriture en arrière-plan ; une erreur de stockage ne bloque pas l'appli.
Future<void> _persist(Map<String, dynamic>? session) async {
  try {
    if (session == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: jsonEncode(session));
    }
  } catch (_) {}
}

Map<String, dynamic>? _decode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}
