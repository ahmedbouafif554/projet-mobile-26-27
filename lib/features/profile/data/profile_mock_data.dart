import '../../../core/constants/app_assets.dart';
import '../models/address.dart';
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
}
