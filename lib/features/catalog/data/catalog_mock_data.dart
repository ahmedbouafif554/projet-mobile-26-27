import 'package:flutter/painting.dart';

import '../../../core/constants/app_assets.dart';
import '../models/food_category.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../models/restaurant.dart';

/// Fausses données du catalogue (aucune API).
/// Les menus sont générés à partir de modèles par catégorie
/// pour garder ce fichier lisible.
class CatalogMockData {
  CatalogMockData._();

  // ---------------------------------------------------------------------------
  // Catégories
  // ---------------------------------------------------------------------------
  static const List<FoodCategory> categories = [
    FoodCategory(
      id: 'burger',
      name: 'Burgers',
      emoji: '🍔',
      color: Color(0xFFFFE8D9),
    ),
    FoodCategory(
      id: 'pizza',
      name: 'Italien',
      emoji: '🍕',
      color: Color(0xFFFFE3E0),
    ),
    FoodCategory(
      id: 'sushi',
      name: 'Sushi',
      emoji: '🍣',
      color: Color(0xFFE3F0FF),
    ),
    FoodCategory(
      id: 'healthy',
      name: 'Healthy',
      emoji: '🥗',
      color: Color(0xFFE2F7E9),
    ),
    FoodCategory(
      id: 'asian',
      name: 'Asiatique',
      emoji: '🍜',
      color: Color(0xFFFFF4D6),
    ),
    FoodCategory(
      id: 'tacos',
      name: 'Mexicain',
      emoji: '🌮',
      color: Color(0xFFFFEBD1),
    ),
    FoodCategory(
      id: 'dessert',
      name: 'Desserts',
      emoji: '🍩',
      color: Color(0xFFFCE4F3),
    ),
    FoodCategory(
      id: 'courses',
      name: 'Courses',
      emoji: '🛒',
      color: Color(0xFFE6F6F4),
    ),
  ];

  // ---------------------------------------------------------------------------
  // Restaurants et commerces
  // ---------------------------------------------------------------------------
  static final List<Restaurant> restaurants = [
    Restaurant(
      id: 'r1',
      name: 'Burger Factory',
      categoryId: 'burger',
      cuisine: 'Burgers • Américain',
      imageUrl: unsplash('1568901346375-23c9450c58cd'),
      rating: 4.8,
      reviewCount: 1240,
      deliveryMinutes: 25,
      deliveryFee: 0,
      distanceKm: 1.2,
      address: '18 rue Oberkampf, Paris 11e',
      description:
          'Des burgers smashés minute avec du bœuf français, un pain brioché toasté et des frites maison.',
      promo: '-20%',
      isPopular: true,
    ),
    Restaurant(
      id: 'r2',
      name: 'Pizza Napoli',
      categoryId: 'pizza',
      cuisine: 'Pizza • Italien',
      imageUrl: unsplash('1513104890138-7c749659a591'),
      rating: 4.7,
      reviewCount: 980,
      deliveryMinutes: 30,
      deliveryFee: 1.99,
      distanceKm: 2.4,
      address: '5 rue des Martyrs, Paris 9e',
      description:
          'Pâte maturée 48 h, cuisson au feu de bois et produits importés directement de Naples.',
      promo: '1 achetée = 1 offerte',
      isPopular: true,
    ),
    Restaurant(
      id: 'r3',
      name: 'Sakura Sushi',
      categoryId: 'sushi',
      cuisine: 'Sushi • Japonais',
      imageUrl: unsplash('1579871494447-9811cf80d66c'),
      rating: 4.9,
      reviewCount: 2104,
      deliveryMinutes: 35,
      deliveryFee: 2.49,
      distanceKm: 3.1,
      address: '42 rue Sainte-Anne, Paris 2e',
      description:
          'Sushis, makis et plateaux préparés à la commande par nos chefs japonais.',
      isPopular: true,
    ),
    Restaurant(
      id: 'r4',
      name: 'Green Bowl',
      categoryId: 'healthy',
      cuisine: 'Healthy • Bowls',
      imageUrl: unsplash('1512621776951-a57141f2eefd'),
      rating: 4.6,
      reviewCount: 640,
      deliveryMinutes: 20,
      deliveryFee: 0,
      distanceKm: 0.8,
      address: '9 boulevard Voltaire, Paris 11e',
      description:
          'Bowls gourmands et équilibrés, légumes de saison et sauces maison.',
      promo: 'Livraison offerte',
    ),
    Restaurant(
      id: 'r5',
      name: 'Ramen Ichiban',
      categoryId: 'asian',
      cuisine: 'Ramen • Japonais',
      imageUrl: unsplash('1569718212165-3a8278d5f624'),
      rating: 4.7,
      reviewCount: 870,
      deliveryMinutes: 30,
      deliveryFee: 1.49,
      distanceKm: 1.9,
      address: '27 rue Saint-Augustin, Paris 2e',
      description: 'Bouillons mijotés 12 h et nouilles fraîches faites maison.',
      isPopular: true,
    ),
    Restaurant(
      id: 'r6',
      name: 'Taco Loco',
      categoryId: 'tacos',
      cuisine: 'Tacos • Mexicain',
      imageUrl: unsplash('1565299585323-38d6b0865b47'),
      rating: 4.5,
      reviewCount: 410,
      deliveryMinutes: 25,
      deliveryFee: 1.99,
      distanceKm: 2.8,
      address: '61 rue de Charonne, Paris 11e',
      description:
          'Tortillas de maïs, viandes marinées et salsas maison bien relevées.',
      promo: '-15%',
    ),
    Restaurant(
      id: 'r7',
      name: 'Sweet Corner',
      categoryId: 'dessert',
      cuisine: 'Desserts • Café',
      imageUrl: unsplash('1551024601-bec78aea704b'),
      rating: 4.8,
      reviewCount: 760,
      deliveryMinutes: 20,
      deliveryFee: 0.99,
      distanceKm: 1.1,
      address: '3 rue de Bretagne, Paris 3e',
      description:
          'Donuts, pancakes et pâtisseries du jour pour les gourmands.',
      isPopular: true,
    ),
    Restaurant(
      id: 'r8',
      name: 'Le Petit Marché',
      categoryId: 'courses',
      cuisine: 'Épicerie • Produits frais',
      imageUrl: unsplash('1542838132-92c53300491e'),
      rating: 4.6,
      reviewCount: 530,
      deliveryMinutes: 30,
      deliveryFee: 2.99,
      distanceKm: 1.6,
      address: '120 rue du Faubourg Saint-Antoine, Paris 12e',
      description:
          'Fruits, légumes et épicerie fine livrés en moins de 30 minutes.',
    ),
    Restaurant(
      id: 'r9',
      name: 'Fresh Market',
      categoryId: 'courses',
      cuisine: 'Supermarché • Bio',
      imageUrl: unsplash('1488459716781-31db52582fe9'),
      rating: 4.5,
      reviewCount: 380,
      deliveryMinutes: 35,
      deliveryFee: 0,
      distanceKm: 2.2,
      address: '8 avenue Parmentier, Paris 11e',
      description: 'Votre supermarché bio de quartier, livré à votre porte.',
      promo: 'Livraison offerte',
    ),
    Restaurant(
      id: 'r10',
      name: 'Smash Bros',
      categoryId: 'burger',
      cuisine: 'Burgers • Street food',
      imageUrl: unsplash('1550547660-d9450f859349'),
      rating: 4.4,
      reviewCount: 290,
      deliveryMinutes: 20,
      deliveryFee: 1.49,
      distanceKm: 0.9,
      address: '14 rue Jean-Pierre Timbaud, Paris 11e',
      description: 'Le smash burger dans sa version la plus généreuse.',
    ),
    Restaurant(
      id: 'r11',
      name: 'Pasta Mia',
      categoryId: 'pizza',
      cuisine: 'Pâtes fraîches • Italien',
      imageUrl: unsplash('1621996346565-e3dbc646d9a9'),
      rating: 4.6,
      reviewCount: 450,
      deliveryMinutes: 30,
      deliveryFee: 1.99,
      distanceKm: 2.0,
      address: '33 rue Montorgueil, Paris 2e',
      description:
          'Pâtes fraîches roulées chaque matin et sauces traditionnelles.',
    ),
    Restaurant(
      id: 'r12',
      name: 'Poké Paradise',
      categoryId: 'healthy',
      cuisine: 'Poké • Hawaïen',
      imageUrl: unsplash('1546069901-ba9599a7e63c'),
      rating: 4.7,
      reviewCount: 715,
      deliveryMinutes: 25,
      deliveryFee: 0.99,
      distanceKm: 1.4,
      address: '22 rue de la Roquette, Paris 11e',
      description: 'Pokés à composer, poissons frais et toppings croquants.',
      isPopular: true,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Promotions (carrousel de l'accueil)
  // ---------------------------------------------------------------------------
  static final List<Promotion> promotions = [
    Promotion(
      id: 'p1',
      title: '-30% sur votre\n1ère commande',
      subtitle: 'Code BIENVENUE30',
      code: 'BIENVENUE30',
      imageUrl: unsplash('1571091718767-18b5b1457add', width: 500),
      colors: const [Color(0xFFFF7A45), Color(0xFFFF5A1F)],
      restaurantId: 'r1',
    ),
    Promotion(
      id: 'p2',
      title: 'Livraison offerte\nsur le healthy',
      subtitle: 'Bowls et salades sans frais',
      imageUrl: unsplash('1540189549336-e6e99c3679fe', width: 500),
      colors: const [Color(0xFF34D399), Color(0xFF16A34A)],
      categoryId: 'healthy',
    ),
    Promotion(
      id: 'p3',
      title: 'Pizza achetée =\npizza offerte',
      subtitle: 'Ce week-end chez Napoli',
      imageUrl: unsplash('1565299624946-b28f40a0ae38', width: 500),
      colors: const [Color(0xFF3A3A44), Color(0xFF1B1B1F)],
      restaurantId: 'r2',
    ),
  ];

  /// Suggestions affichées dans la recherche.
  static const List<String> recentSearches = [
    'Burger',
    'Sushi',
    'Poké',
    'Pizza',
    'Pancakes',
  ];

  // ---------------------------------------------------------------------------
  // Produits (générés à partir des modèles de menu)
  // ---------------------------------------------------------------------------
  static final List<Product> products = [
    for (final restaurant in restaurants)
      for (final template in _menuTemplates[restaurant.categoryId]!)
        template.toProduct(restaurant.id),
  ];

  /// Onglets du menu d'un restaurant (« Populaires » en premier).
  static List<String> menuSectionsOf(Restaurant restaurant) => [
    'Populaires',
    ..._sections[restaurant.categoryId]!,
  ];

  // --- Requêtes utilitaires ---

  static Restaurant restaurantById(String id) => restaurants.firstWhere(
    (r) => r.id == id,
    orElse: () => restaurants.first,
  );

  static Product productById(String id) =>
      products.firstWhere((p) => p.id == id, orElse: () => products.first);

  static FoodCategory? categoryById(String? id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<Product> productsOf(String restaurantId) =>
      products.where((p) => p.restaurantId == restaurantId).toList();

  static List<Restaurant> get popularRestaurants =>
      restaurants.where((r) => r.isPopular).toList();

  static List<Restaurant> get nearbyRestaurants =>
      [...restaurants]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

  /// Recherche simple, insensible à la casse, dans les restaurants.
  static List<Restaurant> searchRestaurants(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return restaurants
        .where(
          (r) =>
              r.name.toLowerCase().contains(q) ||
              r.cuisine.toLowerCase().contains(q) ||
              (categoryById(r.categoryId)?.name.toLowerCase().contains(q) ??
                  false),
        )
        .toList();
  }

  /// Recherche dans les plats (un seul résultat par nom de plat).
  static List<Product> searchProducts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final seen = <String>{};
    return products
        .where(
          (p) =>
              (p.name.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q)) &&
              seen.add(p.name),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Modèles de menus par catégorie
  // ---------------------------------------------------------------------------
  static const Map<String, List<String>> _sections = {
    'burger': ['Burgers', 'Accompagnements', 'Boissons'],
    'pizza': ['Pizzas', 'Pâtes', 'Desserts'],
    'sushi': ['Plateaux', 'Entrées', 'Boissons'],
    'healthy': ['Bowls', 'Salades', 'Boissons'],
    'asian': ['Ramen', 'Entrées', 'Boissons'],
    'tacos': ['Tacos', 'Accompagnements', 'Boissons'],
    'dessert': ['Pâtisseries', 'Glaces', 'Boissons'],
    'courses': ['Fruits & légumes', 'Épicerie', 'Boissons'],
  };

  // Groupes d'options réutilisables
  static const _size = ProductOptionGroup(
    id: 'size',
    title: 'Taille',
    isRequired: true,
    options: [
      ProductOption(id: 'normal', name: 'Normal'),
      ProductOption(id: 'large', name: 'Grand', extraPrice: 2),
      ProductOption(id: 'xl', name: 'XL', extraPrice: 3.5),
    ],
  );
  static const _pizzaSize = ProductOptionGroup(
    id: 'size',
    title: 'Taille',
    isRequired: true,
    options: [
      ProductOption(id: 'm', name: 'Moyenne (29 cm)'),
      ProductOption(id: 'l', name: 'Grande (33 cm)', extraPrice: 3),
      ProductOption(id: 'xl', name: 'Familiale (40 cm)', extraPrice: 6),
    ],
  );
  static const _drinkSize = ProductOptionGroup(
    id: 'size',
    title: 'Format',
    isRequired: true,
    options: [
      ProductOption(id: '33', name: '33 cl'),
      ProductOption(id: '50', name: '50 cl', extraPrice: 1),
    ],
  );

  static ProductOptionGroup _extras(List<ProductOption> options) =>
      ProductOptionGroup(
        id: 'extras',
        title: 'Suppléments',
        allowMultiple: true,
        options: options,
      );

  static final _burgerExtras = _extras(const [
    ProductOption(id: 'cheddar', name: 'Cheddar affiné', extraPrice: 1),
    ProductOption(id: 'bacon', name: 'Bacon croustillant', extraPrice: 1.5),
    ProductOption(id: 'onions', name: 'Oignons caramélisés', extraPrice: 0.8),
    ProductOption(id: 'bbq', name: 'Sauce BBQ maison', extraPrice: 0.5),
  ]);
  static final _pizzaExtras = _extras(const [
    ProductOption(id: 'mozza', name: 'Mozzarella di bufala', extraPrice: 1.5),
    ProductOption(id: 'mushrooms', name: 'Champignons', extraPrice: 1),
    ProductOption(id: 'ham', name: 'Jambon de Parme', extraPrice: 2),
    ProductOption(id: 'olives', name: 'Olives noires', extraPrice: 0.8),
  ]);
  static final _sushiExtras = _extras(const [
    ProductOption(id: 'soy', name: 'Sauce soja sucrée', extraPrice: 0.5),
    ProductOption(id: 'ginger', name: 'Gingembre mariné', extraPrice: 0.5),
    ProductOption(id: 'wasabi', name: 'Wasabi', extraPrice: 0.3),
  ]);
  static final _bowlExtras = _extras(const [
    ProductOption(id: 'avocado', name: 'Avocat', extraPrice: 1.5),
    ProductOption(id: 'egg', name: 'Œuf mollet', extraPrice: 1),
    ProductOption(id: 'feta', name: 'Feta', extraPrice: 1),
    ProductOption(id: 'seeds', name: 'Mélange de graines', extraPrice: 0.5),
  ]);
  static final _ramenExtras = _extras(const [
    ProductOption(id: 'egg', name: 'Œuf mariné', extraPrice: 1),
    ProductOption(id: 'chashu', name: 'Porc chashu', extraPrice: 2.5),
    ProductOption(id: 'noodles', name: 'Nouilles en plus', extraPrice: 2),
  ]);
  static final _tacosExtras = _extras(const [
    ProductOption(id: 'guac', name: 'Guacamole', extraPrice: 1.5),
    ProductOption(id: 'cheddar', name: 'Cheddar fondu', extraPrice: 1),
    ProductOption(id: 'jalapenos', name: 'Jalapeños', extraPrice: 0.5),
  ]);
  static final _dessertExtras = _extras(const [
    ProductOption(id: 'cream', name: 'Chantilly', extraPrice: 0.8),
    ProductOption(id: 'choco', name: 'Coulis chocolat', extraPrice: 1),
    ProductOption(id: 'nuts', name: 'Noisettes torréfiées', extraPrice: 0.6),
  ]);

  static final Map<String, List<_ProductTemplate>> _menuTemplates = {
    'burger': [
      _ProductTemplate(
        'classic',
        'Classic Cheeseburger',
        'Bœuf 150 g, cheddar, pickles, oignons, sauce maison.',
        9.9,
        '1568901346375-23c9450c58cd',
        'Burgers',
        popular: true,
        kcal: 720,
        groups: [_size, _burgerExtras],
      ),
      _ProductTemplate(
        'bacon',
        'Double Bacon',
        'Double steak, double cheddar, bacon croustillant, sauce BBQ.',
        12.5,
        '1550547660-d9450f859349',
        'Burgers',
        popular: true,
        kcal: 980,
        groups: [_size, _burgerExtras],
      ),
      _ProductTemplate(
        'chicken',
        'Chicken Crispy',
        'Poulet pané croustillant, salade, tomate, mayo épicée.',
        10.9,
        '1571091718767-18b5b1457add',
        'Burgers',
        kcal: 760,
        groups: [_size, _burgerExtras],
      ),
      _ProductTemplate(
        'veggie',
        'Veggie Deluxe',
        'Galette de légumes, avocat, roquette, sauce yaourt.',
        10.5,
        '1586190848861-99aa4a171e90',
        'Burgers',
        kcal: 610,
        groups: [_size, _burgerExtras],
      ),
      _ProductTemplate(
        'fries',
        'Frites maison',
        'Pommes de terre fraîches, double cuisson, fleur de sel.',
        3.5,
        '1573080496219-bb080dd4f877',
        'Accompagnements',
        kcal: 380,
        groups: [_size],
      ),
      _ProductTemplate(
        'lemonade',
        'Limonade maison',
        'Citron pressé, menthe fraîche, sucre de canne.',
        3.2,
        '1544145945-f90425340c7e',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'pizza': [
      _ProductTemplate(
        'margherita',
        'Margherita',
        'Sauce tomate San Marzano, mozzarella fior di latte, basilic.',
        10.9,
        '1574071318508-1cdbab80d002',
        'Pizzas',
        popular: true,
        kcal: 820,
        groups: [_pizzaSize, _pizzaExtras],
      ),
      _ProductTemplate(
        'pepperoni',
        'Pepperoni',
        'Sauce tomate, mozzarella, pepperoni épicé, origan.',
        12.9,
        '1565299624946-b28f40a0ae38',
        'Pizzas',
        popular: true,
        kcal: 950,
        groups: [_pizzaSize, _pizzaExtras],
      ),
      _ProductTemplate(
        '4cheese',
        'Quatre fromages',
        'Mozzarella, gorgonzola, parmesan, chèvre, miel.',
        13.5,
        '1513104890138-7c749659a591',
        'Pizzas',
        kcal: 1010,
        groups: [_pizzaSize, _pizzaExtras],
      ),
      _ProductTemplate(
        'carbonara',
        'Tagliatelle carbonara',
        'Pâtes fraîches, guanciale, jaune d\'œuf, pecorino.',
        12.0,
        '1621996346565-e3dbc646d9a9',
        'Pâtes',
        kcal: 870,
      ),
      _ProductTemplate(
        'arrabbiata',
        'Penne arrabbiata',
        'Sauce tomate pimentée, ail, persil, parmesan.',
        11.0,
        '1473093295043-cdd812d0e601',
        'Pâtes',
        kcal: 690,
      ),
      _ProductTemplate(
        'tiramisu',
        'Tiramisu maison',
        'Mascarpone, café, biscuits, cacao amer.',
        5.5,
        '1565958011703-44f9829ba187',
        'Desserts',
        kcal: 450,
      ),
    ],
    'sushi': [
      _ProductTemplate(
        'sakura',
        'Plateau Sakura (18 pcs)',
        'Assortiment de sushis, makis et california du chef.',
        22.9,
        '1579871494447-9811cf80d66c',
        'Plateaux',
        popular: true,
        kcal: 780,
        groups: [_sushiExtras],
      ),
      _ProductTemplate(
        'california',
        'California saumon avocat',
        '8 pièces, saumon frais, avocat, sésame.',
        7.9,
        '1617196034796-73dfa7b1fd56',
        'Plateaux',
        popular: true,
        kcal: 340,
        groups: [_sushiExtras],
      ),
      _ProductTemplate(
        'salmon',
        'Plateau Saumon (12 pcs)',
        'Sushis et sashimis de saumon norvégien.',
        16.9,
        '1611143669185-af224c5e3252',
        'Plateaux',
        kcal: 560,
        groups: [_sushiExtras],
      ),
      _ProductTemplate(
        'gyoza',
        'Gyoza poulet (6 pcs)',
        'Raviolis grillés, sauce ponzu.',
        6.5,
        '1563245372-f21724e3856d',
        'Entrées',
        kcal: 320,
      ),
      _ProductTemplate(
        'tea',
        'Thé vert glacé',
        'Thé matcha infusé à froid, légèrement sucré.',
        3.5,
        '1544145945-f90425340c7e',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'healthy': [
      _ProductTemplate(
        'poke',
        'Poké saumon',
        'Riz vinaigré, saumon mariné, edamame, mangue, avocat.',
        13.9,
        '1546069901-ba9599a7e63c',
        'Bowls',
        popular: true,
        kcal: 640,
        groups: [_size, _bowlExtras],
      ),
      _ProductTemplate(
        'buddha',
        'Buddha bowl',
        'Quinoa, pois chiches rôtis, patate douce, houmous.',
        12.5,
        '1512621776951-a57141f2eefd',
        'Bowls',
        popular: true,
        kcal: 590,
        groups: [_size, _bowlExtras],
      ),
      _ProductTemplate(
        'morning',
        'Bowl du matin',
        'Yaourt grec, granola maison, fruits frais, miel.',
        8.9,
        '1490645935967-10de6ba17061',
        'Bowls',
        kcal: 410,
        groups: [_bowlExtras],
      ),
      _ProductTemplate(
        'caesar',
        'Salade César',
        'Poulet grillé, romaine, parmesan, croûtons, sauce César.',
        10.9,
        '1540189549336-e6e99c3679fe',
        'Salades',
        kcal: 520,
        groups: [_bowlExtras],
      ),
      _ProductTemplate(
        'smoothie',
        'Smoothie détox',
        'Épinards, pomme, gingembre, citron.',
        5.5,
        '1544145945-f90425340c7e',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'asian': [
      _ProductTemplate(
        'tonkotsu',
        'Tonkotsu ramen',
        'Bouillon de porc 12 h, nouilles fraîches, chashu, œuf.',
        13.5,
        '1569718212165-3a8278d5f624',
        'Ramen',
        popular: true,
        kcal: 890,
        groups: [_size, _ramenExtras],
      ),
      _ProductTemplate(
        'veggie-ramen',
        'Ramen végétarien',
        'Bouillon miso, tofu grillé, champignons, maïs.',
        12.5,
        '1569718212165-3a8278d5f624',
        'Ramen',
        kcal: 640,
        groups: [_size, _ramenExtras],
      ),
      _ProductTemplate(
        'yakitori',
        'Brochettes yakitori',
        '4 brochettes de poulet laquées sauce teriyaki.',
        8.9,
        '1555939594-58d7cb561ad1',
        'Entrées',
        popular: true,
        kcal: 420,
      ),
      _ProductTemplate(
        'gyoza',
        'Gyoza porc (6 pcs)',
        'Raviolis grillés, sauce soja vinaigrée.',
        6.5,
        '1563245372-f21724e3856d',
        'Entrées',
        kcal: 330,
      ),
      _ProductTemplate(
        'tea',
        'Thé glacé yuzu',
        'Thé noir infusé à froid, yuzu et citron vert.',
        3.5,
        '1544145945-f90425340c7e',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'tacos': [
      _ProductTemplate(
        'pastor',
        'Tacos al pastor',
        'Porc mariné à l\'ananas, coriandre, oignon, salsa verde.',
        9.5,
        '1565299585323-38d6b0865b47',
        'Tacos',
        popular: true,
        kcal: 610,
        groups: [_size, _tacosExtras],
      ),
      _ProductTemplate(
        'pollo',
        'Tacos pollo',
        'Poulet grillé, pico de gallo, crème fraîche, citron vert.',
        8.9,
        '1565299585323-38d6b0865b47',
        'Tacos',
        kcal: 560,
        groups: [_size, _tacosExtras],
      ),
      _ProductTemplate(
        'fries',
        'Frites cheddar jalapeños',
        'Frites maison, cheddar fondu, jalapeños.',
        5.5,
        '1573080496219-bb080dd4f877',
        'Accompagnements',
        popular: true,
        kcal: 520,
      ),
      _ProductTemplate(
        'lemonade',
        'Agua fresca',
        'Pastèque, citron vert et menthe.',
        3.5,
        '1544145945-f90425340c7e',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'dessert': [
      _ProductTemplate(
        'donuts',
        'Donuts assortis (x4)',
        'Glaçage chocolat, fraise, vanille et caramel.',
        7.9,
        '1551024601-bec78aea704b',
        'Pâtisseries',
        popular: true,
        kcal: 980,
        groups: [_dessertExtras],
      ),
      _ProductTemplate(
        'pancakes',
        'Pancakes sirop d\'érable',
        'Pile de 3 pancakes moelleux, beurre, sirop d\'érable.',
        8.5,
        '1567620905732-2d1ec7ab7445',
        'Pâtisseries',
        popular: true,
        kcal: 640,
        groups: [_dessertExtras],
      ),
      _ProductTemplate(
        'cheesecake',
        'Cheesecake New York',
        'Base biscuitée, crème vanille, coulis de fruits rouges.',
        5.9,
        '1565958011703-44f9829ba187',
        'Pâtisseries',
        kcal: 470,
        groups: [_dessertExtras],
      ),
      _ProductTemplate(
        'sundae',
        'Coupe glacée',
        'Trois boules au choix, chantilly, sauce chocolat.',
        6.5,
        '1497034825429-c343d7c6a68f',
        'Glaces',
        kcal: 520,
        groups: [_dessertExtras],
      ),
      _ProductTemplate(
        'cappuccino',
        'Cappuccino',
        'Espresso, lait mousseux, cacao.',
        3.9,
        '1509042239860-f550ce710b93',
        'Boissons',
        groups: [_drinkSize],
      ),
    ],
    'courses': [
      _ProductTemplate(
        'fruits',
        'Panier de fruits de saison',
        'Environ 2 kg de fruits frais sélectionnés.',
        12.9,
        '1610832958506-aa56368176cf',
        'Fruits & légumes',
        popular: true,
      ),
      _ProductTemplate(
        'veggies',
        'Panier de légumes',
        'Légumes de producteurs locaux, environ 3 kg.',
        9.9,
        '1488459716781-31db52582fe9',
        'Fruits & légumes',
        popular: true,
      ),
      _ProductTemplate(
        'pasta',
        'Kit pâtes & sauce tomate',
        'Spaghetti 500 g + sauce tomate basilic.',
        5.9,
        '1473093295043-cdd812d0e601',
        'Épicerie',
      ),
      _ProductTemplate(
        'coffee',
        'Café en grains 1 kg',
        'Arabica torréfié artisanalement.',
        14.9,
        '1509042239860-f550ce710b93',
        'Épicerie',
      ),
      _ProductTemplate(
        'juice',
        'Jus d\'orange pressé 1 L',
        'Oranges pressées le jour même.',
        3.9,
        '1544145945-f90425340c7e',
        'Boissons',
      ),
    ],
  };
}

/// Modèle de produit, instancié pour chaque restaurant d'une catégorie.
class _ProductTemplate {
  const _ProductTemplate(
    this.key,
    this.name,
    this.description,
    this.price,
    this.photoId,
    this.section, {
    this.popular = false,
    this.kcal,
    this.groups = const [],
  });

  final String key;
  final String name;
  final String description;
  final double price;
  final String photoId;
  final String section;
  final bool popular;
  final int? kcal;
  final List<ProductOptionGroup> groups;

  Product toProduct(String restaurantId) => Product(
    id: '$restaurantId-$key',
    restaurantId: restaurantId,
    name: name,
    description: description,
    imageUrl: unsplash(photoId, width: 600),
    price: price,
    section: section,
    isPopular: popular,
    calories: kcal,
    optionGroups: groups,
  );
}
