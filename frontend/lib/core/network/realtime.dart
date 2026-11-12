import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import 'api_client.dart';

// =============================================================================
// Temps réel : connexion Socket.IO au backend.
//
// Le serveur envoie un signal `sync` après chaque écriture (nouvelle commande,
// acceptation, course prise, livreur en route…). Les providers de données
// surveillent [realtimeRevisionProvider] et se rechargent tout seuls : les
// écrans du client, du restaurant et du livreur restent à jour sans
// « tirer pour actualiser ».
//
// Filet de sécurité : si le socket est coupé (Wi-Fi instable), les données
// sont relues toutes les 15 secondes, ainsi qu'au retour au premier plan.
// =============================================================================

/// Sujets de rechargement.
abstract final class RealtimeTopic {
  /// Commandes, courses et livreurs (liés : accepter une commande crée une
  /// course, livrer une course clôt la commande).
  static const logistics = 'logistics';
  static const catalogue = 'catalogue';
  static const notifications = 'notifications';
  static const reviews = 'reviews';

  /// Position du livreur d'une commande.
  static String location(String orderId) => 'location:$orderId';

  static const all = [logistics, catalogue, notifications, reviews];
}

/// Compteur par sujet : incrémenté à chaque changement côté serveur.
/// Un provider qui fait `ref.watch(realtimeRevisionProvider(topic))` se
/// recharge à chaque signal (l'affichage garde les anciennes données pendant
/// le rechargement).
final realtimeRevisionProvider =
    NotifierProvider.family<RealtimeRevision, int, String>(
      RealtimeRevision.new,
    );

class RealtimeRevision extends Notifier<int> {
  RealtimeRevision(this.topic);

  final String topic;

  @override
  int build() => 0;

  void bump() => state++;
}

/// Raccourci pour les providers : se recharger avec les commandes/courses.
void watchLogistics(Ref ref) =>
    ref.watch(realtimeRevisionProvider(RealtimeTopic.logistics));

/// Dernière position GPS reçue pour une commande (mise à jour instantanée
/// du repère sur la carte de suivi, sans attendre la relecture).
final liveCourierPositionProvider =
    NotifierProvider.family<
      LiveCourierPosition,
      ({double lat, double lng})?,
      String
    >(LiveCourierPosition.new);

class LiveCourierPosition extends Notifier<({double lat, double lng})?> {
  LiveCourierPosition(this.orderId);

  final String orderId;

  @override
  ({double lat, double lng})? build() => null;

  void set(double lat, double lng) => state = (lat: lat, lng: lng);
}

/// État de la connexion (affichable dans l'interface).
final realtimeConnectedProvider = NotifierProvider<RealtimeConnected, bool>(
  RealtimeConnected.new,
);

class RealtimeConnected extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

bool get _inFlutterTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Connexion Socket.IO du compte connecté. À surveiller depuis la racine de
/// l'application (`ref.watch(realtimeConnectionProvider)`).
final realtimeConnectionProvider = Provider<void>((ref) {
  final token = ref.watch(authTokenProvider);
  if (token == null || token.isEmpty) return;
  // Données mock en mémoire : rien à synchroniser.
  if (AppConfig.useMockData && !AppConfig.useApiOrders) return;
  // Tests de widgets : pas de socket réseau.
  if (_inFlutterTest) return;

  void bump(String topic) =>
      ref.read(realtimeRevisionProvider(topic).notifier).bump();
  void bumpAll() {
    for (final topic in RealtimeTopic.all) {
      bump(topic);
    }
  }

  final serverUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
  final socket = io.io(
    serverUrl,
    io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .setAuth({'token': token})
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .disableAutoConnect()
        .build(),
  );

  var everConnected = false;
  socket
    ..onConnect((_) {
      ref.read(realtimeConnectedProvider.notifier).set(true);
      // Rattrape ce qui a changé pendant la coupure.
      if (everConnected) bumpAll();
      everConnected = true;
      if (kDebugMode) debugPrint('[realtime] connecté à $serverUrl');
    })
    ..onDisconnect((_) {
      ref.read(realtimeConnectedProvider.notifier).set(false);
    })
    ..on('sync', (data) {
      if (data is! Map) return;
      final topic = data['topic'];
      switch (topic) {
        case 'orders' || 'deliveries' || 'couriers':
          bump(RealtimeTopic.logistics);
        case 'catalogue':
          bump(RealtimeTopic.catalogue);
        case 'notifications':
          bump(RealtimeTopic.notifications);
        case 'reviews':
          bump(RealtimeTopic.reviews);
        case 'location':
          final orderId = data['orderId'];
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (orderId is String && lat != null && lng != null) {
            ref
                .read(liveCourierPositionProvider(orderId).notifier)
                .set(lat, lng);
            bump(RealtimeTopic.location(orderId));
          }
      }
    })
    ..connect();

  // Filet de sécurité : relecture régulière si le socket est coupé.
  final fallback = Timer.periodic(const Duration(seconds: 15), (_) {
    if (!socket.connected) bumpAll();
  });

  // Retour au premier plan : relecture immédiate.
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (!socket.connected) socket.connect();
      bumpAll();
    },
  );

  ref.onDispose(() {
    fallback.cancel();
    lifecycle.dispose();
    socket
      ..clearListeners()
      ..dispose();
  });
});
