import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../catalog/data/catalog_mock_data.dart';
import '../../communication_routes.dart';
import '../../models/conversation.dart';

/// Fausses réponses « serveur » du module 5, au format JSON.
/// Les dépôts mock les transforment avec les `fromJson` des modèles,
/// exactement comme le feraient les dépôts API.
class CommunicationMockData {
  CommunicationMockData._();

  static const me = AppConfig.currentUserId;

  static String _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now()
          .subtract(Duration(days: days, hours: hours, minutes: minutes))
          .toUtc()
          .toIso8601String();

  // ---------------------------------------------------------------------------
  // Avis
  // ---------------------------------------------------------------------------
  static final List<(String, String, String)> _reviewers = [
    ('u-1', 'Sarah L.', '1494790108377-be9c29b29330'),
    ('u-2', 'Thomas R.', '1507003211169-0a1dd7228f2d'),
    ('u-3', 'Inès B.', '1544005313-94ddf0286df2'),
    ('u-4', 'Mehdi K.', '1506794778202-cad84cf45f1d'),
    ('u-5', 'Camille D.', '1438761681033-6461ffad8d80'),
    ('u-6', 'Lucas M.', '1527980965255-d3b416303d12'),
    ('u-7', 'Emma P.', '1534528741775-53994a69daeb'),
    ('u-8', 'Yanis T.', '1517841905240-472988babdf9'),
  ];

  static const Map<int, List<String>> _comments = {
    5: [
      "Tout était parfait, encore chaud à l'arrivée ! Je recommande les yeux fermés.",
      'Excellent comme toujours, livreur très sympa et super rapide.',
      'Une vraie pépite du quartier, les portions sont généreuses.',
      'Qualité au top et emballage soigné, rien à redire 👌',
    ],
    4: [
      "Très bon, juste un peu d'attente mais ça valait le coup.",
      'Bonne cuisine, la livraison aurait pu être un peu plus rapide.',
      'Très satisfait, il manquait juste une sauce.',
    ],
    3: [
      'Correct sans plus, le plat était un peu tiède.',
      'Bon goût mais portions un peu justes pour le prix.',
    ],
    2: ['Commande arrivée froide et avec 20 minutes de retard.'],
    1: ["Il manquait un plat et impossible de joindre le restaurant."],
  };

  static const Map<int, String> _replies = {
    5: 'Merci beaucoup pour ce retour ! Toute l\'équipe est ravie 🙏',
    4: 'Merci ! Nous travaillons à réduire les délais aux heures de pointe.',
    3: 'Merci pour votre avis, nous allons revoir nos portions et la température.',
    2: 'Toutes nos excuses, un bon de réduction vous a été envoyé par e-mail.',
    1: 'Nous sommes désolés, le service client vous recontacte rapidement.',
  };

  static const _ratingPattern = [5, 5, 4, 5, 3, 4, 2, 5];

  static Map<String, dynamic> _review({
    required String id,
    required String restaurantId,
    required (String, String, String) author,
    required int rating,
    required String comment,
    required String createdAt,
    List<String> photos = const [],
    String? reply,
    String status = 'approved',
    int helpful = 0,
    int reports = 0,
    String? orderId,
    Map<String, int>? criteria,
  }) => {
    'id': id,
    'restaurant_id': restaurantId,
    'author_id': author.$1,
    'author_name': author.$2,
    'author_avatar_url': unsplash(author.$3, width: 200),
    'order_id': orderId,
    'rating': rating,
    'criteria':
        criteria ??
        {
          'food': rating,
          'delivery': (rating - (helpful % 2)).clamp(1, 5).toInt(),
          'packaging': (rating + (helpful % 3 == 0 ? 0 : -1))
              .clamp(1, 5)
              .toInt(),
        },
    'comment': comment,
    'photos': photos,
    'created_at': createdAt,
    'updated_at': null,
    'reply': reply == null
        ? null
        : {
            'author_name': CatalogMockData.restaurantById(restaurantId).name,
            'message': reply,
            'created_at': createdAt,
          },
    'status': status,
    'helpful_count': helpful,
    'is_helpful_by_me': false,
    'report_count': reports,
  };

  /// Avis de tous les restaurants (+ ceux de l'utilisateur et la file de modération).
  static List<Map<String, dynamic>> reviewsJson() {
    final list = <Map<String, dynamic>>[];
    for (final (ri, restaurant) in CatalogMockData.restaurants.indexed) {
      final photos = CatalogMockData.productsOf(
        restaurant.id,
      ).map((p) => p.imageUrl).toList();
      for (var i = 0; i < _ratingPattern.length; i++) {
        final rating = _ratingPattern[i];
        final comments = _comments[rating]!;
        list.add(
          _review(
            id: 'rev-${restaurant.id}-$i',
            restaurantId: restaurant.id,
            author: _reviewers[(i + ri) % _reviewers.length],
            rating: rating,
            comment: comments[(i + ri) % comments.length],
            createdAt: _ago(days: i * 3 + ri % 4, hours: i * 5),
            photos: i % 3 == 0
                ? photos.take(1 + (i ~/ 3) % 2).toList()
                : const [],
            reply: rating <= 3 || i == 1 ? _replies[rating] : null,
            helpful: (i * 7 + ri * 3) % 25,
            // Deux avis signalés alimentent la modération.
            reports: (ri == 1 && i == 6) || (ri == 5 && i == 4) ? 3 : 0,
          ),
        );
      }
    }

    // Avis en attente de validation (file de modération).
    list.addAll([
      _review(
        id: 'rev-pending-1',
        restaurantId: 'r1',
        author: _reviewers[2],
        rating: 4,
        comment:
            'Nouveau burger du mois testé : vraiment bon, sauce maison top !',
        createdAt: _ago(hours: 2),
        status: 'pending',
      ),
      _review(
        id: 'rev-pending-2',
        restaurantId: 'r5',
        author: _reviewers[5],
        rating: 1,
        comment: 'NUL NUL NUL, plus jamais !!!',
        createdAt: _ago(hours: 5),
        status: 'pending',
      ),
      _review(
        id: 'rev-pending-3',
        restaurantId: 'r12',
        author: _reviewers[6],
        rating: 5,
        comment: 'Le meilleur poké de Paris, les toppings sont ultra frais 🥑',
        createdAt: _ago(hours: 9),
        status: 'pending',
        photos: [CatalogMockData.productsOf('r12').first.imageUrl],
      ),
    ]);

    // Avis de l'utilisateur connecté (commande SF1045 livrée).
    list.add(
      _review(
        id: 'rev-me-1',
        restaurantId: 'r3',
        author: (me, 'Alex M.', '1500648767791-00dcc994a43e'),
        rating: 5,
        comment:
            'Plateau Sakura incroyable, poisson ultra frais ! Livraison rapide et soignée.',
        createdAt: _ago(days: 1, hours: 20),
        photos: [CatalogMockData.productById('r3-sakura').imageUrl],
        reply: 'Merci beaucoup Alex ! Au plaisir de vous régaler à nouveau 🍣',
        helpful: 4,
        orderId: 'SF1045',
        criteria: {'food': 5, 'delivery': 4, 'packaging': 5},
      ),
    );
    return list;
  }

  /// Photos proposées par le sélecteur simulé (remplace image_picker).
  static List<String> photoGallery(String restaurantId) => [
    ...CatalogMockData.productsOf(restaurantId).map((p) => p.imageUrl),
    unsplash('1504674900247-0877df9cc836', width: 600),
    unsplash('1414235077428-338989a2e8c0', width: 600),
  ];

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> notificationsJson() => [
    {
      'id': 'n1',
      'type': 'order',
      'title': 'Votre commande est en préparation 🍜',
      'body': 'Ramen Ichiban prépare votre commande #SF1046.',
      'created_at': _ago(minutes: 6),
      'is_read': false,
      'route': AppRoutes.trackingOf('SF1046'),
    },
    {
      'id': 'n2',
      'type': 'chat',
      'title': 'Karim B. vous a écrit',
      'body': 'Je récupère votre commande dans 5 minutes.',
      'created_at': _ago(minutes: 12),
      'is_read': false,
      'route': CommunicationRoutes.chat('conv-courier'),
    },
    {
      'id': 'n3',
      'type': 'promo',
      'title': '-30 % sur votre prochaine commande',
      'body': 'Utilisez le code BIENVENUE30 avant dimanche minuit.',
      'created_at': _ago(hours: 3),
      'is_read': false,
      'route': AppRoutes.restaurantDetail('r1', hero: 'notif'),
    },
    {
      'id': 'n4',
      'type': 'review',
      'title': 'Sakura Sushi a répondu à votre avis',
      'body':
          '« Merci beaucoup Alex ! Au plaisir de vous régaler à nouveau 🍣 »',
      'created_at': _ago(days: 1, hours: 2),
      'is_read': true,
      'route': CommunicationRoutes.myReviews,
    },
    {
      'id': 'n5',
      'type': 'order',
      'title': 'Commande livrée ✅',
      'body': 'Votre commande Sakura Sushi a été livrée. Bon appétit !',
      'created_at': _ago(days: 2, hours: 2),
      'is_read': true,
      'route': AppRoutes.trackingOf('SF1045'),
    },
    {
      'id': 'n6',
      'type': 'system',
      'title': 'Nouveau près de chez vous',
      'body': "Poké Paradise vient d'arriver dans votre quartier.",
      'created_at': _ago(days: 3),
      'is_read': true,
      'route': AppRoutes.restaurantDetail('r12', hero: 'notif'),
    },
    {
      'id': 'n7',
      'type': 'promo',
      'title': 'Livraison offerte ce week-end',
      'body': 'Sur tous les restaurants healthy, sans minimum de commande.',
      'created_at': _ago(days: 5),
      'is_read': true,
      'route': AppRoutes.restaurantsWith(category: 'healthy'),
    },
    {
      'id': 'n8',
      'type': 'system',
      'title': 'Mise à jour des conditions',
      'body': "Nos conditions d'utilisation évoluent le 1er du mois.",
      'created_at': _ago(days: 12),
      'is_read': true,
      'route': null,
    },
  ];

  static Map<String, dynamic> notificationSettingsJson() => {
    'types': {
      'order': true,
      'chat': true,
      'review': true,
      'promo': true,
      'system': false,
    },
    'in_app_banner': true,
    'sound': true,
    'do_not_disturb': false,
  };

  /// Notifications « push » envoyées par le bouton de simulation.
  static List<Map<String, dynamic>> demoPushesJson() => [
    {
      'type': 'order',
      'title': 'Votre livreur est en route 🛵',
      'body': 'Karim arrive dans environ 12 minutes.',
      'route': AppRoutes.trackingOf('SF1046'),
    },
    {
      'type': 'promo',
      'title': 'Flash : -20 % chez Pizza Napoli',
      'body': "Pendant 1 heure seulement, sur toutes les pizzas.",
      'route': AppRoutes.restaurantDetail('r2', hero: 'notif'),
    },
    {
      'type': 'review',
      'title': 'Comment était Sakura Sushi ? ⭐',
      'body': 'Notez votre dernière commande en 10 secondes.',
      'route': CommunicationRoutes.writeReview(
        restaurantId: 'r3',
        orderId: 'SF1045',
      ),
    },
    {
      'type': 'chat',
      'title': 'Support SuperFaster',
      'body': 'Votre demande de remboursement a été validée.',
      'route': CommunicationRoutes.chat('conv-support'),
    },
  ];

  // ---------------------------------------------------------------------------
  // Messagerie
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> _message(
    String id,
    String conversationId,
    String senderId,
    String text,
    String sentAt, {
    String status = 'read',
  }) => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'text': text,
    'sent_at': sentAt,
    'status': status,
    'edited_at': null,
    'is_deleted': false,
  };

  static Map<String, List<Map<String, dynamic>>> messagesJson() => {
    'conv-r5': [
      _message(
        'm1',
        'conv-r5',
        'r5',
        'Bonjour Alex ! Votre commande #SF1046 est en préparation 🍜',
        _ago(minutes: 9),
      ),
      _message(
        'm2',
        'conv-r5',
        me,
        'Super, merci ! Pouvez-vous ajouter des baguettes ?',
        _ago(minutes: 8),
      ),
      _message(
        'm3',
        'conv-r5',
        'r5',
        "Bien sûr, c'est noté 👍",
        _ago(minutes: 7),
      ),
    ],
    'conv-courier': [
      _message(
        'm4',
        'conv-courier',
        'courier',
        'Bonjour, je suis Karim, votre livreur pour la commande #SF1046.',
        _ago(minutes: 14),
      ),
      _message(
        'm5',
        'conv-courier',
        'courier',
        'Je récupère votre commande dans 5 minutes.',
        _ago(minutes: 12),
      ),
    ],
    'conv-support': [
      _message(
        'm6',
        'conv-support',
        'support',
        'Bonjour Alex 👋 Comment pouvons-nous vous aider ?',
        _ago(days: 1, hours: 3),
      ),
      _message(
        'm7',
        'conv-support',
        me,
        "J'ai reçu une boisson en moins dans ma commande.",
        _ago(days: 1, hours: 3),
      ),
      _message(
        'm8',
        'conv-support',
        'support',
        'Désolé ! Un avoir de 3,50 € a été ajouté à votre compte.',
        _ago(days: 1, hours: 2),
      ),
    ],
    'conv-r3': [
      _message(
        'm9',
        'conv-r3',
        me,
        'Merci pour le plateau, il était délicieux !',
        _ago(days: 2),
      ),
      _message(
        'm10',
        'conv-r3',
        'r3',
        'Merci à vous Alex, à bientôt 🍣',
        _ago(days: 2),
      ),
    ],
  };

  static List<Map<String, dynamic>> conversationsJson() {
    final messages = messagesJson();
    Map<String, dynamic> conv(
      String id,
      String type,
      String title,
      String? subtitle,
      String avatar, {
      int unread = 0,
      bool online = false,
    }) => {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'avatar_url': avatar,
      'last_message': messages[id]!.last,
      'unread_count': unread,
      'is_online': online,
      'updated_at': messages[id]!.last['sent_at'],
    };

    return [
      conv(
        'conv-courier',
        'courier',
        'Karim B.',
        'Commande #SF1046',
        unsplash('1535713875002-d1d0cf377fde', width: 200),
        unread: 2,
        online: true,
      ),
      conv(
        'conv-r5',
        'restaurant',
        'Ramen Ichiban',
        'Commande #SF1046',
        CatalogMockData.restaurantById('r5').imageUrl,
        unread: 1,
        online: true,
      ),
      conv(
        'conv-support',
        'support',
        'Support SuperFaster',
        'Disponible 7j/7',
        unsplash('1438761681033-6461ffad8d80', width: 200),
        online: true,
      ),
      conv(
        'conv-r3',
        'restaurant',
        'Sakura Sushi',
        'Commande #SF1045',
        CatalogMockData.restaurantById('r3').imageUrl,
      ),
    ];
  }

  /// Réponses automatiques de l'interlocuteur simulé.
  static const Map<ConversationType, List<String>> autoReplies = {
    ConversationType.restaurant: [
      'Merci pour votre message ! Nous regardons ça tout de suite.',
      "C'est noté, le chef s'en occupe 👨‍🍳",
      'Votre commande sera prête dans quelques minutes.',
    ],
    ConversationType.courier: [
      'Bien reçu 👍',
      "J'arrive dans 5 minutes.",
      'Je suis en bas de chez vous.',
    ],
    ConversationType.support: [
      'Merci, un conseiller vous répond dans un instant.',
      'Pouvez-vous me donner votre numéro de commande ?',
      "C'est réglé ! Puis-je vous aider pour autre chose ?",
    ],
  };
}
