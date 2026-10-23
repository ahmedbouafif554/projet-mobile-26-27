import '../../../core/constants/app_assets.dart';
import '../../../core/routes/app_routes.dart';
import '../models/address.dart';
import '../models/app_notification.dart';
import '../models/payment_method.dart';
import '../models/user_profile.dart';

/// Langue proposée dans les paramètres.
class AppLanguage {
  const AppLanguage(this.code, this.name, this.flag);

  final String code;
  final String name;
  final String flag;
}

/// Fausses données du profil utilisateur.
class ProfileMockData {
  ProfileMockData._();

  static final UserProfile user = UserProfile(
    firstName: 'Alex',
    lastName: 'Martin',
    email: 'alex.martin@exemple.fr',
    phone: '+33 6 12 34 56 78',
    avatarUrl: unsplash('1500648767791-00dcc994a43e', width: 300),
    loyaltyPoints: 340,
  );

  static const List<Address> addresses = [
    Address(
      id: 'a1',
      label: 'Maison',
      street: '12 rue de la Paix',
      city: '75002 Paris',
      type: AddressType.home,
      instructions: 'Digicode 4521B, 3e étage',
    ),
    Address(
      id: 'a2',
      label: 'Bureau',
      street: '45 avenue des Champs-Élysées',
      city: '75008 Paris',
      type: AddressType.work,
      instructions: 'Accueil au rez-de-chaussée',
    ),
    Address(
      id: 'a3',
      label: 'Chez Léa',
      street: '7 rue des Abbesses',
      city: '75018 Paris',
    ),
  ];

  static const List<PaymentMethod> paymentMethods = [
    PaymentMethod(
      id: 'pm1',
      type: PaymentType.visa,
      label: 'Visa',
      last4: '4242',
      expiry: '08/28',
      holder: 'ALEX MARTIN',
    ),
    PaymentMethod(
      id: 'pm2',
      type: PaymentType.mastercard,
      label: 'Mastercard',
      last4: '8810',
      expiry: '11/27',
      holder: 'ALEX MARTIN',
    ),
    PaymentMethod(id: 'pm3', type: PaymentType.paypal, label: 'PayPal'),
    PaymentMethod(
      id: 'pm4',
      type: PaymentType.cash,
      label: 'Espèces à la livraison',
    ),
  ];

  static const List<AppLanguage> languages = [
    AppLanguage('fr', 'Français', '🇫🇷'),
    AppLanguage('en', 'English', '🇬🇧'),
    AppLanguage('ar', 'العربية', '🇲🇦'),
    AppLanguage('es', 'Español', '🇪🇸'),
    AppLanguage('de', 'Deutsch', '🇩🇪'),
  ];

  /// Préférences de notifications : clé -> (titre, description, valeur).
  static const Map<String, (String, String, bool)> notificationPrefs = {
    'orders': (
      'Suivi de commande',
      'Préparation, livraison, arrivée du livreur',
      true,
    ),
    'promos': ('Promotions', 'Codes promo et offres exclusives', true),
    'news': ('Nouveautés', 'Nouveaux restaurants près de chez vous', false),
    'email': ('E-mails', 'Récapitulatifs et factures par e-mail', true),
    'sms': ('SMS', 'Alertes importantes par SMS', false),
  };

  static List<AppNotification> notifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        title: 'Votre commande est en préparation 🍜',
        body: 'Ramen Ichiban prépare votre commande #SF1046.',
        date: now.subtract(const Duration(minutes: 6)),
        kind: NotificationKind.order,
        route: AppRoutes.trackingOf('SF1046'),
      ),
      AppNotification(
        id: 'n2',
        title: '-30 % sur votre prochaine commande',
        body: 'Utilisez le code BIENVENUE30 avant dimanche minuit.',
        date: now.subtract(const Duration(hours: 3)),
        kind: NotificationKind.promo,
        route: AppRoutes.restaurantDetail('r1', hero: 'notif'),
      ),
      AppNotification(
        id: 'n3',
        title: 'Commande livrée ✅',
        body: 'Votre commande Sakura Sushi a été livrée. Bon appétit !',
        date: now.subtract(const Duration(days: 2, hours: 2)),
        kind: NotificationKind.order,
        route: AppRoutes.trackingOf('SF1045'),
        isRead: true,
      ),
      AppNotification(
        id: 'n4',
        title: 'Nouveau près de chez vous',
        body: 'Poké Paradise vient d\'arriver dans votre quartier.',
        date: now.subtract(const Duration(days: 3)),
        kind: NotificationKind.info,
        route: AppRoutes.restaurantDetail('r12', hero: 'notif'),
        isRead: true,
      ),
      AppNotification(
        id: 'n5',
        title: 'Livraison offerte ce week-end',
        body: 'Sur tous les restaurants healthy, sans minimum de commande.',
        date: now.subtract(const Duration(days: 5)),
        kind: NotificationKind.promo,
        route: AppRoutes.restaurantsWith(category: 'healthy'),
        isRead: true,
      ),
    ];
  }
}
