import 'session_store_stub.dart'
    if (dart.library.html) 'session_store_web.dart' as impl;

/// Session enregistrée dans le navigateur (`null` hors web).
Map<String, dynamic>? readSession() => impl.readSession();

void writeSession(Map<String, dynamic>? session) => impl.writeSession(session);
