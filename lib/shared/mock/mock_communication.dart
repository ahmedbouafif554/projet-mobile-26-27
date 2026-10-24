import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/review.dart';
import 'mock_catalog.dart';
import 'mock_users.dart';

/// Avis (24), notifications (18), campagnes, conversations et messages mock.
class MockCommunication {
  MockCommunication._();

  static final DateTime _now = DateTime.now();
  static DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      _now.subtract(Duration(days: days, hours: hours, minutes: minutes));

  // ---------------------------------------------------------------------------
  // Avis
  // ---------------------------------------------------------------------------
  static const _comments = [
    (5, 'Excellent comme toujours, livreur très sympa et super rapide.'),
    (5, 'Une vraie pépite du quartier, les portions sont généreuses.'),
    (4, 'Très bon, juste un peu tiède à l\'arrivée.'),
    (5, 'Le meilleur de Paris, je recommande les yeux fermés !'),
    (3, 'Correct mais la livraison a pris plus de temps que prévu.'),
    (4, 'Produits frais et emballage soigné, je recommanderai.'),
    (2, 'Commande incomplète, il manquait la boisson.'),
    (5, 'Parfait pour un dîner rapide en semaine.'),
    (4, 'Bon rapport qualité-prix, sauces maison délicieuses.'),
    (1, 'Très déçu, plat froid et livreur injoignable.'),
    (5, 'Accueil au top et cuisine savoureuse.'),
    (4, 'Rapide et bon, rien à redire.'),
  ];

  static final List<Review> reviews = [for (var i = 0; i < 24; i++) _review(i)];

  static Review _review(int i) {
    final (rating, comment) = _comments[i % _comments.length];
    final userId = 'u-client-${i % 8 + 1}';
    final user = MockUsers.byId(userId);
    final restaurant = MockCatalog.approvedRestaurants[i % 8];
    final status = switch (i) {
      2 || 9 || 15 || 21 => ReviewStatus.pending,
      6 || 13 => ReviewStatus.rejected,
      _ => ReviewStatus.approved,
    };
    return Review(
      id: 'rev-${i + 1}',
      restaurantId: restaurant.id,
      userId: userId,
      userName: '${user.firstName} ${user.lastName[0]}.',
      userAvatar: user.avatarUrl,
      orderId: 'o-${i + 8}',
      rating: rating,
      foodRating: rating,
      deliveryRating: (rating - (i % 2)).clamp(1, 5),
      packagingRating: (rating + (i % 3 == 0 ? 0 : -1)).clamp(1, 5),
      comment: comment,
      photos: i % 5 == 0 ? [restaurant.imageUrl] : const [],
      status: status,
      reply: i % 4 == 1
          ? ReviewReply(
              text: 'Merci beaucoup pour votre retour, à très vite ! 🙏',
              authorName: restaurant.name,
              at: _ago(days: i ~/ 2, hours: 2),
            )
          : null,
      helpfulCount: (i * 7) % 23,
      reportCount: rating <= 2 ? 2 : 0,
      createdAt: _ago(days: i ~/ 2, hours: i * 3 % 11),
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications (Alex, le client de démo, et quelques envois à tous)
  // ---------------------------------------------------------------------------
  static final List<AppNotification> notifications = [
    _notif(
      1,
      'Votre commande est en préparation 🍜',
      'Pizza Napoli prépare votre commande #SF1077.',
      NotificationType.order,
      _ago(minutes: 4),
      route: '/orders/o-1',
    ),
    _notif(
      2,
      'Karim vous a écrit',
      'Je récupère votre commande dans 5 minutes.',
      NotificationType.message,
      _ago(minutes: 12),
      route: '/account/messages/chat-2',
    ),
    _notif(
      3,
      '-30 % sur votre prochaine commande',
      'Utilisez le code BIENVENUE30 avant dimanche minuit.',
      NotificationType.promo,
      _ago(hours: 3),
    ),
    _notif(
      4,
      'Sakura Sushi a répondu à votre avis',
      '« Merci beaucoup pour votre retour, à très vite ! »',
      NotificationType.review,
      _ago(days: 1, hours: 2),
      read: true,
    ),
    _notif(
      5,
      'Commande livrée ✅',
      'Votre commande #SF1071 a été livrée. Bon appétit !',
      NotificationType.order,
      _ago(days: 1, hours: 5),
      read: true,
      route: '/orders/o-7',
    ),
    _notif(
      6,
      'Notez votre commande',
      'Comment était votre repas chez Ramen Ichiban ?',
      NotificationType.review,
      _ago(days: 1, hours: 6),
      read: true,
    ),
    _notif(
      7,
      'Nouveau restaurant près de chez vous',
      'Green Bowl livre désormais dans votre quartier.',
      NotificationType.promo,
      _ago(days: 2),
      read: true,
    ),
    _notif(
      8,
      'Livraison offerte ce week-end',
      'Sur tous les restaurants partenaires, dès 15 € d\'achat.',
      NotificationType.promo,
      _ago(days: 2, hours: 4),
      read: true,
      broadcast: true,
    ),
    _notif(
      9,
      'Commande annulée',
      'Le restaurant a annulé votre commande #SF1064, vous êtes remboursé.',
      NotificationType.order,
      _ago(days: 3),
      read: true,
    ),
    _notif(
      10,
      'Remboursement effectué',
      '12,40 € ont été recrédités sur votre carte.',
      NotificationType.order,
      _ago(days: 3, hours: 1),
      read: true,
    ),
    _notif(
      11,
      'Le support vous a répondu',
      'Un avoir de 3,50 € a été ajouté à votre compte.',
      NotificationType.message,
      _ago(days: 3, hours: 5),
      read: true,
      route: '/account/messages/chat-3',
    ),
    _notif(
      12,
      'Vos points fidélité',
      'Vous avez gagné 40 points avec votre dernière commande.',
      NotificationType.system,
      _ago(days: 4),
      read: true,
    ),
    _notif(
      13,
      'Mise à jour des conditions',
      'Nos conditions générales évoluent le 1er du mois.',
      NotificationType.system,
      _ago(days: 5),
      read: true,
      broadcast: true,
    ),
    _notif(
      14,
      'Happy hour sushi 🍣',
      '-20 % sur les plateaux de 18 h à 20 h.',
      NotificationType.promo,
      _ago(days: 5, hours: 3),
      read: true,
    ),
    _notif(
      15,
      'Commande livrée ✅',
      'Votre commande #SF1059 a été livrée.',
      NotificationType.order,
      _ago(days: 6),
      read: true,
    ),
    _notif(
      16,
      'Parrainez vos amis',
      '10 € offerts pour vous et votre filleul.',
      NotificationType.promo,
      _ago(days: 6, hours: 2),
      read: true,
    ),
    _notif(
      17,
      'Nouvelle connexion',
      'Connexion depuis un nouvel appareil (Chrome, Paris).',
      NotificationType.system,
      _ago(days: 7),
      read: true,
    ),
    _notif(
      18,
      'Merci pour votre avis',
      'Votre avis sur Pizza Napoli a été publié.',
      NotificationType.review,
      _ago(days: 8),
      read: true,
    ),
  ];

  static AppNotification _notif(
    int n,
    String title,
    String body,
    NotificationType type,
    DateTime at, {
    bool read = false,
    bool broadcast = false,
    String? route,
  }) => AppNotification(
    id: 'n-$n',
    userId: broadcast ? null : 'u-client-1',
    title: title,
    body: body,
    type: type,
    isRead: read,
    route: route,
    createdAt: at,
  );

  // ---------------------------------------------------------------------------
  // Campagnes du back office
  // ---------------------------------------------------------------------------
  static final List<NotificationCampaign> campaigns = [
    NotificationCampaign(
      id: 'camp-1',
      title: 'Livraison offerte ce week-end',
      body: "Sur tous les restaurants partenaires, dès 15 € d'achat.",
      audience: CampaignAudience.clients,
      status: CampaignStatus.sent,
      sentAt: _ago(days: 2, hours: 4),
      recipientCount: 11320,
      openRate: 0.42,
      createdAt: _ago(days: 3),
    ),
    NotificationCampaign(
      id: 'camp-2',
      title: 'Mise à jour des conditions',
      body: 'Nos conditions générales évoluent le 1er du mois.',
      status: CampaignStatus.sent,
      sentAt: _ago(days: 5),
      recipientCount: 12480,
      openRate: 0.27,
      createdAt: _ago(days: 6),
    ),
    NotificationCampaign(
      id: 'camp-3',
      title: 'Bonus pluie : +2 € par course',
      body: 'Ce soir de 19 h à 22 h, chaque course est majorée de 2 €.',
      audience: CampaignAudience.couriers,
      status: CampaignStatus.scheduled,
      scheduledAt: _now.add(const Duration(hours: 6)),
      createdAt: _ago(hours: 5),
    ),
    NotificationCampaign(
      id: 'camp-4',
      title: 'Nouveau : statistiques avancées',
      body: 'Découvrez vos ventes heure par heure dans votre espace pro.',
      audience: CampaignAudience.restaurants,
      createdAt: _ago(days: 1),
    ),
    NotificationCampaign(
      id: 'camp-5',
      title: 'Soirée sushi -20 %',
      body: 'Jeudi soir, -20 % chez nos partenaires japonais.',
      audience: CampaignAudience.clients,
      createdAt: _ago(hours: 2),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Conversations et messages
  // ---------------------------------------------------------------------------
  static final List<Chat> chats = [
    Chat(
      id: 'chat-1',
      type: ChatType.restaurant,
      title: 'Burger Factory',
      subtitle: 'Commande #SF1077',
      avatarUrl: MockCatalog.restaurantById('r1').imageUrl,
      participantIds: const ['u-client-1', 'u-resto-1'],
      orderId: 'o-1',
      lastMessage: "Bien sûr, c'est noté 👍",
      lastMessageAt: _ago(minutes: 8),
      unreadCount: 1,
      isOnline: true,
    ),
    Chat(
      id: 'chat-2',
      type: ChatType.courier,
      title: 'Karim B.',
      subtitle: 'Livreur • Commande #SF1071',
      avatarUrl: MockUsers.byId('u-courier-1').avatarUrl,
      participantIds: const ['u-client-1', 'u-courier-1'],
      orderId: 'o-7',
      lastMessage: 'Je récupère votre commande dans 5 minutes.',
      lastMessageAt: _ago(minutes: 12),
      unreadCount: 2,
      isOnline: true,
    ),
    Chat(
      id: 'chat-3',
      type: ChatType.support,
      title: 'Support SuperFaster',
      subtitle: 'Disponible 7j/7',
      avatarUrl: MockUsers.byId('u-admin').avatarUrl,
      participantIds: const ['u-client-1', 'u-admin'],
      lastMessage: 'Un avoir de 3,50 € a été ajouté à votre compte.',
      lastMessageAt: _ago(days: 3, hours: 5),
      isOnline: true,
    ),
    Chat(
      id: 'chat-4',
      type: ChatType.restaurant,
      title: 'Pizza Napoli',
      subtitle: 'Commande #SF1075',
      avatarUrl: MockCatalog.restaurantById('r2').imageUrl,
      participantIds: const ['u-client-2', 'u-resto-2'],
      orderId: 'o-3',
      lastMessage: 'Vous êtes nuls, je ne commanderai plus jamais !',
      lastMessageAt: _ago(hours: 1),
      isFlagged: true,
    ),
    Chat(
      id: 'chat-5',
      type: ChatType.support,
      title: 'Support SuperFaster',
      subtitle: 'Inès H. • Livreuse',
      avatarUrl: MockUsers.byId('u-courier-2').avatarUrl,
      participantIds: const ['u-courier-2', 'u-admin'],
      lastMessage: 'Merci, mon paiement est bien arrivé.',
      lastMessageAt: _ago(days: 1),
    ),
    Chat(
      id: 'chat-6',
      type: ChatType.client,
      title: 'Lucas M.',
      subtitle: 'Client • Commande #SF1074',
      avatarUrl: MockUsers.byId('u-client-3').avatarUrl,
      participantIds: const ['u-client-3', 'u-courier-1'],
      orderId: 'o-4',
      lastMessage: 'Je suis devant la porte.',
      lastMessageAt: _ago(hours: 2),
      unreadCount: 1,
    ),
  ];

  static final List<Message> messages = [
    ..._thread('chat-1', [
      ('u-client-1', 'Alex', 'Bonjour, est-ce possible sans oignons ?', 15),
      ('u-resto-1', 'Burger Factory', "Bien sûr, c'est noté 👍", 8),
    ]),
    ..._thread('chat-2', [
      (
        'u-courier-1',
        'Karim',
        'Bonjour, je suis en route vers le restaurant.',
        20,
      ),
      ('u-client-1', 'Alex', 'Super, merci !', 18),
      ('u-courier-1', 'Karim', 'La commande est presque prête.', 14),
      (
        'u-courier-1',
        'Karim',
        'Je récupère votre commande dans 5 minutes.',
        12,
      ),
    ]),
    ..._thread('chat-3', [
      (
        'u-client-1',
        'Alex',
        'Bonjour, il manquait une boisson dans ma commande.',
        4700,
      ),
      (
        'u-admin',
        'Support',
        'Désolé pour ce désagrément, nous regardons.',
        4680,
      ),
      (
        'u-admin',
        'Support',
        'Un avoir de 3,50 € a été ajouté à votre compte.',
        4620,
      ),
    ]),
    ..._thread('chat-4', [
      ('u-client-2', 'Emma', 'Ma pizza est arrivée froide.', 80),
      (
        'u-resto-2',
        'Pizza Napoli',
        'Nous sommes désolés, voulez-vous un avoir ?',
        70,
      ),
      (
        'u-client-2',
        'Emma',
        'Vous êtes nuls, je ne commanderai plus jamais !',
        60,
      ),
    ]),
    ..._thread('chat-5', [
      (
        'u-courier-2',
        'Inès',
        'Bonjour, mon paiement de la semaine est en retard.',
        1600,
      ),
      (
        'u-admin',
        'Support',
        'Le virement a été relancé, il arrive demain.',
        1550,
      ),
      ('u-courier-2', 'Inès', 'Merci, mon paiement est bien arrivé.', 1440),
    ]),
    ..._thread('chat-6', [
      ('u-courier-1', 'Karim', 'Bonjour, je suis en bas de chez vous.', 125),
      ('u-client-3', 'Lucas', 'Je suis devant la porte.', 120),
    ]),
  ];

  /// Fil de messages : (expéditeur, nom, texte, il y a N minutes).
  static List<Message> _thread(
    String chatId,
    List<(String, String, String, int)> lines,
  ) => [
    for (final (i, (sender, name, text, minutes)) in lines.indexed)
      Message(
        id: '$chatId-m${i + 1}',
        chatId: chatId,
        senderId: sender,
        senderName: name,
        text: text,
        status: MessageStatus.read,
        sentAt: _ago(minutes: minutes),
      ),
  ];
}
