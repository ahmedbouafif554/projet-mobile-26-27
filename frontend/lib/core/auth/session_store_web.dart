import 'dart:convert';
import 'dart:html' as html;

const _key = 'sf_session';

/// `localStorage` se lit directement : rien à charger.
Future<void> loadSession() async {}

Map<String, dynamic>? readSession() {
  final raw = html.window.localStorage[_key];
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

void writeSession(Map<String, dynamic>? session) {
  if (session == null) {
    html.window.localStorage.remove(_key);
  } else {
    html.window.localStorage[_key] = jsonEncode(session);
  }
}
