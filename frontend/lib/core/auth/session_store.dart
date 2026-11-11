import 'session_store_stub.dart'
    if (dart.library.html) 'session_store_web.dart'
    as impl;

/// Session enregistrée sur l'appareil : stockage chiffré (mobile) ou
/// `localStorage` (navigateur).

/// À appeler une fois au démarrage, avant [readSession].
Future<void> loadSession() => impl.loadSession();

Map<String, dynamic>? readSession() => impl.readSession();

void writeSession(Map<String, dynamic>? session) => impl.writeSession(session);
