import '../models/address.dart';
import '../models/user.dart';
import 'mock_images.dart';

/// Comptes de démonstration (mot de passe : 6 caractères ou plus).
class DemoAccounts {
  DemoAccounts._();

  static const client = 'alex.martin@exemple.fr';
  static const courier = 'karim.benali@superfaster.fr';
  static const restaurant = 'contact@burgerfactory.fr';
  static const admin = 'admin@superfaster.fr';
  static const password = 'demo1234';
}

/// Utilisateurs et adresses mock (27 comptes).
class MockUsers {
  MockUsers._();

  static final DateTime _now = DateTime.now();
  static DateTime _daysAgo(int days) => _now.subtract(Duration(days: days));

  /// Prénoms féminins (choix du portrait de démonstration).
  static const _women = {
    'Sophie',
    'Emma',
    'Chloé',
    'Manon',
    'Léa',
    'Sarah',
    'Giulia',
    'Camille',
    'Inès',
  };

  // Portraits distribués dans l'ordre de la liste (moins de doublons).
  static int _womanPhotos = 0;
  static int _manPhotos = 0;

  static String _nextPortrait({required bool woman}) =>
      portrait(woman: woman, index: woman ? _womanPhotos++ : _manPhotos++);

  static User _user(
    String id,
    String first,
    String last,
    String email,
    UserRole role, {
    int avatarNumber = 1,
    String? photo,
    UserStatus status = UserStatus.active,
    String? restaurantId,
    int joinedDaysAgo = 120,
    int points = 0,
  }) => User(
    id: id,
    firstName: first,
    lastName: last,
    email: email,
    phone:
        '+33 6 ${12 + avatarNumber} ${34 + avatarNumber} 56 ${10 + avatarNumber}',
    role: role,
    status: status,
    avatarUrl: photo ?? _nextPortrait(woman: _women.contains(first)),
    restaurantId: restaurantId,
    loyaltyPoints: points,
    createdAt: _daysAgo(joinedDaysAgo),
    lastLoginAt: status == UserStatus.active
        ? _now.subtract(Duration(hours: avatarNumber * 3))
        : null,
  );

  static final List<User> users = [
    // Administration
    _user(
      'u-admin',
      'Sophie',
      'Laurent',
      DemoAccounts.admin,
      UserRole.admin,
      avatarNumber: 47,
      joinedDaysAgo: 400,
    ),

    // Clients
    _user(
      'u-client-1',
      'Alex',
      'Martin',
      DemoAccounts.client,
      UserRole.client,
      avatarNumber: 12,
      photo: unsplash('1500648767791-00dcc994a43e', width: 200),
      joinedDaysAgo: 210,
      points: 340,
    ),
    _user(
      'u-client-2',
      'Emma',
      'Petit',
      'emma.petit@exemple.fr',
      UserRole.client,
      avatarNumber: 5,
      joinedDaysAgo: 180,
      points: 120,
    ),
    _user(
      'u-client-3',
      'Lucas',
      'Moreau',
      'lucas.moreau@exemple.fr',
      UserRole.client,
      avatarNumber: 13,
      joinedDaysAgo: 95,
      points: 60,
    ),
    _user(
      'u-client-4',
      'Chloé',
      'Lefebvre',
      'chloe.lefebvre@exemple.fr',
      UserRole.client,
      avatarNumber: 9,
      joinedDaysAgo: 60,
      points: 210,
    ),
    _user(
      'u-client-5',
      'Hugo',
      'Garcia',
      'hugo.garcia@exemple.fr',
      UserRole.client,
      avatarNumber: 14,
      joinedDaysAgo: 45,
    ),
    _user(
      'u-client-6',
      'Manon',
      'Roux',
      'manon.roux@exemple.fr',
      UserRole.client,
      avatarNumber: 16,
      joinedDaysAgo: 30,
      points: 40,
    ),
    _user(
      'u-client-7',
      'Nathan',
      'Fournier',
      'nathan.fournier@exemple.fr',
      UserRole.client,
      avatarNumber: 15,
      joinedDaysAgo: 22,
    ),
    _user(
      'u-client-8',
      'Léa',
      'Girard',
      'lea.girard@exemple.fr',
      UserRole.client,
      avatarNumber: 20,
      joinedDaysAgo: 12,
      points: 15,
    ),
    _user(
      'u-client-9',
      'Thomas',
      'Bonnet',
      'thomas.bonnet@exemple.fr',
      UserRole.client,
      avatarNumber: 33,
      status: UserStatus.blocked,
      joinedDaysAgo: 150,
    ),
    _user(
      'u-client-10',
      'Sarah',
      'Dupont',
      'sarah.dupont@exemple.fr',
      UserRole.client,
      avatarNumber: 25,
      status: UserStatus.pending,
      joinedDaysAgo: 1,
    ),

    // Restaurateurs (un compte par restaurant)
    _user(
      'u-resto-1',
      'Marc',
      'Dubois',
      DemoAccounts.restaurant,
      UserRole.restaurant,
      avatarNumber: 52,
      restaurantId: 'r1',
      joinedDaysAgo: 330,
    ),
    _user(
      'u-resto-2',
      'Giulia',
      'Rossi',
      'giulia@pizzanapoli.fr',
      UserRole.restaurant,
      avatarNumber: 44,
      restaurantId: 'r2',
      joinedDaysAgo: 300,
    ),
    _user(
      'u-resto-3',
      'Kenji',
      'Tanaka',
      'kenji@sakurasushi.fr',
      UserRole.restaurant,
      avatarNumber: 59,
      restaurantId: 'r3',
      joinedDaysAgo: 290,
    ),
    _user(
      'u-resto-4',
      'Léa',
      'Moreau',
      'lea@greenbowl.fr',
      UserRole.restaurant,
      avatarNumber: 32,
      restaurantId: 'r4',
      joinedDaysAgo: 250,
    ),
    _user(
      'u-resto-5',
      'Hiro',
      'Sato',
      'hiro@ramenichiban.fr',
      UserRole.restaurant,
      avatarNumber: 60,
      restaurantId: 'r5',
      joinedDaysAgo: 240,
    ),
    _user(
      'u-resto-6',
      'Carlos',
      'Mendes',
      'carlos@tacoloco.fr',
      UserRole.restaurant,
      avatarNumber: 57,
      restaurantId: 'r6',
      joinedDaysAgo: 200,
    ),
    _user(
      'u-resto-7',
      'Camille',
      'Petit',
      'camille@sweetcorner.fr',
      UserRole.restaurant,
      avatarNumber: 41,
      restaurantId: 'r7',
      joinedDaysAgo: 170,
    ),
    _user(
      'u-resto-8',
      'Paul',
      'Garnier',
      'paul@petitmarche.fr',
      UserRole.restaurant,
      avatarNumber: 53,
      restaurantId: 'r8',
      joinedDaysAgo: 160,
    ),
    _user(
      'u-resto-9',
      'Minh',
      'Nguyen',
      'minh@wokexpress.fr',
      UserRole.restaurant,
      avatarNumber: 61,
      restaurantId: 'r9',
      status: UserStatus.pending,
      joinedDaysAgo: 3,
    ),
    _user(
      'u-resto-10',
      'Yann',
      'Le Goff',
      'yann@creperiebretonne.fr',
      UserRole.restaurant,
      avatarNumber: 62,
      restaurantId: 'r10',
      status: UserStatus.pending,
      joinedDaysAgo: 2,
    ),

    // Livreurs
    _user(
      'u-courier-1',
      'Karim',
      'Benali',
      DemoAccounts.courier,
      UserRole.courier,
      avatarNumber: 11,
      joinedDaysAgo: 280,
    ),
    _user(
      'u-courier-2',
      'Inès',
      'Haddad',
      'ines.haddad@superfaster.fr',
      UserRole.courier,
      avatarNumber: 26,
      joinedDaysAgo: 190,
    ),
    _user(
      'u-courier-3',
      'Lucas',
      'Bernard',
      'lucas.bernard@superfaster.fr',
      UserRole.courier,
      avatarNumber: 3,
      joinedDaysAgo: 150,
    ),
    _user(
      'u-courier-4',
      'Yanis',
      'Mansouri',
      'yanis.mansouri@superfaster.fr',
      UserRole.courier,
      avatarNumber: 7,
      joinedDaysAgo: 90,
    ),
    _user(
      'u-courier-5',
      'Chloé',
      'Fontaine',
      'chloe.fontaine@superfaster.fr',
      UserRole.courier,
      avatarNumber: 29,
      joinedDaysAgo: 40,
    ),
    _user(
      'u-courier-6',
      'Mehdi',
      'Ziani',
      'mehdi.ziani@superfaster.fr',
      UserRole.courier,
      avatarNumber: 8,
      status: UserStatus.pending,
      joinedDaysAgo: 4,
    ),
  ];

  static final List<Address> addresses = [
    const Address(
      id: 'a-1',
      userId: 'u-client-1',
      label: 'Maison',
      street: '12 rue de la Paix',
      postalCode: '75002',
      city: 'Paris',
      type: AddressType.home,
      instructions: 'Digicode 4521, 3e étage',
      isDefault: true,
      latitude: 48.8686,
      longitude: 2.3312,
    ),
    const Address(
      id: 'a-2',
      userId: 'u-client-1',
      label: 'Bureau',
      street: "45 avenue de l'Opéra",
      postalCode: '75001',
      city: 'Paris',
      type: AddressType.work,
      latitude: 48.8665,
      longitude: 2.3343,
    ),
    const Address(
      id: 'a-3',
      userId: 'u-client-1',
      label: 'Salle de sport',
      street: '8 rue Oberkampf',
      postalCode: '75011',
      city: 'Paris',
      type: AddressType.other,
      latitude: 48.8649,
      longitude: 2.3708,
    ),
    for (final (i, street) in const [
      '3 rue de Bretagne',
      '27 boulevard Voltaire',
      '14 rue des Martyrs',
      '60 rue de Charonne',
      '9 rue Montorgueil',
      '21 avenue Parmentier',
      '5 rue Saint-Maur',
      '33 rue du Faubourg Saint-Antoine',
      '18 rue de Rivoli',
    ].indexed)
      Address(
        id: 'a-${i + 4}',
        userId: 'u-client-${i + 2}',
        label: 'Maison',
        street: street,
        postalCode: '750${(i % 9 + 2).toString().padLeft(2, '0')}',
        city: 'Paris',
        isDefault: true,
        latitude: 48.85 + i * 0.004,
        longitude: 2.34 + i * 0.005,
      ),
  ];

  static User byId(String id) => users.firstWhere((u) => u.id == id);

  static Address defaultAddressOf(String userId) => addresses.firstWhere(
    (a) => a.userId == userId && a.isDefault,
    orElse: () => addresses.first,
  );
}
