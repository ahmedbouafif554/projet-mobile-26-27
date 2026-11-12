'use strict';

/**
 * Script de remplissage complet du catalogue de restaurants et produits.
 * Remplit la base SQLite avec 11 restaurants et plus de 55 produits avec photos
 * Unsplash haute définition, options détaillées, calories, sections de menu,
 * et coordonnées géographiques réelles à Ariana / Tunis pour la démo.
 *
 * Utilisation : node --experimental-sqlite src/restaurant_catalogue/seed/populate-full-catalogue.js
 */

const { init, query, withTransaction, close } = require('../../data/db');
const demo = require('./demo-catalogue.json');

// Coordonnées réelles situées autour d'Ariana / Ennasr / Menzah
const ARIANA_LOCATIONS = {
  r1: { lat: 36.9045, lng: 10.1860, address: 'Av. Hédi Nouira, Ennasr 2, Ariana' },
  r2: { lat: 36.9080, lng: 10.1810, address: 'Rue Taieb Mhiri, Ariana Centre' },
  r3: { lat: 36.9020, lng: 10.1840, address: 'Avenue Habib Bourguiba, Ariana' },
  r4: { lat: 36.9075, lng: 10.1890, address: 'Av. de l’Ère Nouvelle, Ennasr 1, Ariana' },
  r5: { lat: 36.8995, lng: 10.1820, address: 'Rue Ibn Khaldoun, Menzah 6, Ariana' },
  r6: { lat: 36.9100, lng: 10.1870, address: 'Avenue Ahmed Tlili, Borj Louzir, Ariana' },
  r7: { lat: 36.9030, lng: 10.1790, address: 'Avenue Othman Ibn Affan, Menzah 7, Ariana' },
  r8: { lat: 36.9050, lng: 10.1880, address: 'Marché Municipal, Ariana' },
  r9: { lat: 36.9060, lng: 10.1815, address: 'Avenue de la République, Ariana Centre' },
  r10: { lat: 36.9010, lng: 10.1875, address: 'Rue Salah Ben Youssef, Menzah 9, Ariana' },
  rest_demo: { lat: 36.9015, lng: 10.1865, address: 'Av. Hédi Nouira, Ennasr 2, Ariana' },
};

const ADDITIONAL_PRODUCTS = [
  // Produits Wok Express (r9)
  {
    id: 'r9-poulet-teriyaki',
    restaurantId: 'r9',
    categoryId: 'asian',
    name: 'Wok Poulet Teriyaki',
    description: 'Nouilles fraîches, émincé de poulet mariné, légumes croquants et sauce teriyaki maison.',
    price: 11.5,
    imageUrl: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?auto=format&fit=crop&w=600&q=80',
    section: 'Woks',
    isAvailable: true,
    isPopular: true,
    calories: 680,
    optionGroups: [
      {
        id: 'base',
        name: 'Base au choix',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'nouilles', name: 'Nouilles aux œufs', price: 0 },
          { id: 'riz', name: 'Riz jasmin sauté', price: 0 },
          { id: 'udon', name: 'Nouilles Udon épaisses', price: 1.5 },
        ],
      },
      {
        id: 'piment',
        name: 'Niveau d’épice',
        isRequired: false,
        maxChoices: 1,
        options: [
          { id: 'doux', name: 'Non piquant', price: 0 },
          { id: 'moyen', name: 'Légèrement relevé 🌶️', price: 0 },
          { id: 'fort', name: 'Épicé 🔥', price: 0 },
        ],
      },
    ],
  },
  {
    id: 'r9-crevettes',
    restaurantId: 'r9',
    categoryId: 'asian',
    name: 'Wok Crevettes Sweet Chili',
    description: 'Crevettes tigrées sautées au wok, poivrons rouges, coriandre fraîche et sauce aigre-douce pimentée.',
    price: 13.9,
    imageUrl: 'https://images.unsplash.com/photo-1552611052-33e04de081de?auto=format&fit=crop&w=600&q=80',
    section: 'Woks',
    isAvailable: true,
    isPopular: true,
    calories: 590,
    optionGroups: [
      {
        id: 'base',
        name: 'Base au choix',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'riz', name: 'Riz jasmin sauté', price: 0 },
          { id: 'nouilles', name: 'Nouilles de blé', price: 0 },
        ],
      },
    ],
  },
  {
    id: 'r9-boeuf-oignons',
    restaurantId: 'r9',
    categoryId: 'asian',
    name: 'Wok Bœuf aux Oignons',
    description: 'Lamelles de bœuf tendre, oignons doux caramélisés, pousses de bambou et sésame torréfié.',
    price: 12.9,
    imageUrl: 'https://images.unsplash.com/photo-1585032226651-759b368d7246?auto=format&fit=crop&w=600&q=80',
    section: 'Woks',
    isAvailable: true,
    calories: 740,
    optionGroups: [],
  },
  {
    id: 'r9-nems',
    restaurantId: 'r9',
    categoryId: 'asian',
    name: 'Nems Croustillants au Poulet (x4)',
    description: 'Galettes de riz frites farcies au poulet et légumes, servies avec sauce nuoc-mâm et menthe fraîche.',
    price: 5.5,
    imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
    section: 'Entrées',
    isAvailable: true,
    isPopular: true,
    calories: 320,
    optionGroups: [],
  },
  {
    id: 'r9-bubble-tea',
    restaurantId: 'r9',
    categoryId: 'asian',
    name: 'Bubble Tea Brown Sugar',
    description: 'Thé noir au lait velouté, perles de tapioca chaudes infusées au sucre brun caramélisé.',
    price: 4.9,
    imageUrl: 'https://images.unsplash.com/photo-1558857563-b37cf5a13398?auto=format&fit=crop&w=600&q=80',
    section: 'Boissons',
    isAvailable: true,
    calories: 280,
    optionGroups: [
      {
        id: 'size',
        name: 'Taille',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'medium', name: 'Medium (500 ml)', price: 0 },
          { id: 'large', name: 'Large (700 ml)', price: 1.0 },
        ],
      },
    ],
  },

  // Produits La Crêperie Bretonne (r10)
  {
    id: 'r10-complete',
    restaurantId: 'r10',
    categoryId: 'dessert',
    name: 'Galette Complète Tradition',
    description: 'Farine de sarrasin bretonne bio, jambon supérieur, emmental râpé fondant et œuf fermier coulant.',
    price: 8.9,
    imageUrl: 'https://images.unsplash.com/photo-1519676867240-f03562e64548?auto=format&fit=crop&w=600&q=80',
    section: 'Galettes de sarrasin',
    isAvailable: true,
    isPopular: true,
    calories: 520,
    optionGroups: [
      {
        id: 'extras',
        name: 'Ingrédient supplémentaire',
        isRequired: false,
        maxChoices: 2,
        options: [
          { id: 'champignons', name: 'Champignons poêlés', price: 1.5 },
          { id: 'fromage', name: 'Double fromage', price: 1.5 },
        ],
      },
    ],
  },
  {
    id: 'r10-chevre-miel',
    restaurantId: 'r10',
    categoryId: 'dessert',
    name: 'Galette Chèvre, Miel & Noix',
    description: 'Bûche de chèvre rôtie, miel artisanal de romarin, cerneaux de noix croquants et mesclun frais.',
    price: 9.9,
    imageUrl: 'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?auto=format&fit=crop&w=600&q=80',
    section: 'Galettes de sarrasin',
    isAvailable: true,
    isPopular: true,
    calories: 610,
    optionGroups: [],
  },
  {
    id: 'r10-nutella-banane',
    restaurantId: 'r10',
    categoryId: 'dessert',
    name: 'Crêpe Nutella Banane',
    description: 'Crêpe dorée au beurre, généreuse couche de Nutella, rondelles de bananes fraîches et noisettes.',
    price: 6.5,
    imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=600&q=80',
    section: 'Crêpes sucrées',
    isAvailable: true,
    isPopular: true,
    calories: 480,
    optionGroups: [
      {
        id: 'topping',
        name: 'Gourmandise en plus',
        isRequired: false,
        maxChoices: 1,
        options: [
          { id: 'chantilly', name: 'Crème chantilly maison', price: 1.0 },
          { id: 'glace', name: 'Boule de glace vanille', price: 1.5 },
        ],
      },
    ],
  },
  {
    id: 'r10-caramel-beurre-sale',
    restaurantId: 'r10',
    categoryId: 'dessert',
    name: 'Crêpe Caramel au Beurre Salé',
    description: 'Caramel artisanal au sel de Guérande préparé maison, parsemé d’amandes effilées grillées.',
    price: 5.9,
    imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80',
    section: 'Crêpes sucrées',
    isAvailable: true,
    calories: 420,
    optionGroups: [],
  },
  {
    id: 'r10-cidre',
    restaurantId: 'r10',
    categoryId: 'dessert',
    name: 'Cidre Doux Breton 33cl',
    description: 'Cidre artisanal pur jus produit en Bretagne, doux et fruité avec une fine effervescence.',
    price: 3.8,
    imageUrl: 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=600&q=80',
    section: 'Boissons',
    isAvailable: true,
    calories: 130,
    optionGroups: [],
  },

  // Mise à jour premium des produits de rest_demo
  {
    id: 'prod_1',
    restaurantId: 'rest_demo',
    categoryId: 'burger',
    name: 'Classic Smash Burger',
    description: 'Steak de bœuf smashé à la plancha, cheddar irlandais affiné, pickles maison, sauce secrète.',
    price: 9.9,
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=600&q=80',
    section: 'Burgers',
    isAvailable: true,
    isPopular: true,
    calories: 680,
    optionGroups: [
      {
        id: 'taille',
        name: 'Taille',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'simple', name: 'Simple steak (150g)', price: 0 },
          { id: 'double', name: 'Double steak (300g)', price: 3.0 },
        ],
      },
    ],
  },
  {
    id: 'prod_2',
    restaurantId: 'rest_demo',
    categoryId: 'burger',
    name: 'Cheeseburger Fondant',
    description: 'Double tranche de cheddar fondu, oignons rouges compotés, sauce barbecue fumée et pain brioché.',
    price: 10.9,
    imageUrl: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&w=600&q=80',
    section: 'Burgers',
    isAvailable: true,
    isPopular: true,
    calories: 790,
    optionGroups: [],
  },
  {
    id: 'prod_3',
    restaurantId: 'rest_demo',
    categoryId: 'burger',
    name: 'Frites Fraîches Maison',
    description: 'Pommes de terre fraîches coupées à la main, double cuisson à l’huile de tournesol, fleur de sel.',
    price: 3.5,
    imageUrl: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=600&q=80',
    section: 'Accompagnements',
    isAvailable: true,
    calories: 360,
    optionGroups: [
      {
        id: 'sauce',
        name: 'Sauce offerte',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'mayo', name: 'Mayonnaise maison', price: 0 },
          { id: 'ketchup', name: 'Ketchup bio', price: 0 },
          { id: 'samourai', name: 'Sauce Samouraï 🌶️', price: 0 },
        ],
      },
    ],
  },
  {
    id: 'prod_4',
    restaurantId: 'rest_demo',
    categoryId: 'burger',
    name: 'Boisson Fraîche 33cl',
    description: 'Canette fraîche servie très fraîche avec rondelle de citron.',
    price: 2.5,
    imageUrl: 'https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=600&q=80',
    section: 'Boissons',
    isAvailable: true,
    calories: 140,
    optionGroups: [
      {
        id: 'choix',
        name: 'Boisson',
        isRequired: true,
        maxChoices: 1,
        options: [
          { id: 'coca', name: 'Coca-Cola Zero', price: 0 },
          { id: 'fanta', name: 'Fanta Orange', price: 0 },
          { id: 'sprite', name: 'Sprite Citron', price: 0 },
          { id: 'eau', name: 'Eau minérale 50cl', price: 0 },
        ],
      },
    ],
  },
];

async function populate() {
  console.log('🚀 Début du remplissage complet du catalogue...');
  await init();

  // 1. Catégories de base
  const categoriesList = [
    { id: 'burger', name: 'Burgers', emoji: '🍔', color: 4294961369, pos: 0 },
    { id: 'pizza', name: 'Italien', emoji: '🍕', color: 4294960096, pos: 1 },
    { id: 'sushi', name: 'Sushi', emoji: '🍣', color: 4293128447, pos: 2 },
    { id: 'healthy', name: 'Healthy', emoji: '🥗', color: 4293064681, pos: 3 },
    { id: 'asian', name: 'Asiatique', emoji: '🍜', color: 4294964438, pos: 4 },
    { id: 'tacos', name: 'Mexicain', emoji: '🌮', color: 4294962129, pos: 5 },
    { id: 'dessert', name: 'Desserts', emoji: '🍩', color: 4294763763, pos: 6 },
    { id: 'courses', name: 'Courses', emoji: '🛒', color: 4293326580, pos: 7 },
  ];

  for (const c of categoriesList) {
    await query(
      `INSERT INTO categories (id, name, emoji, color_value, position, is_active)
       VALUES (?, ?, ?, ?, ?, 1)
       ON CONFLICT(id) DO UPDATE SET name = excluded.name, emoji = excluded.emoji, is_active = 1`,
      [c.id, c.name, c.emoji, c.color, c.pos],
    );
  }
  console.log(`✅ ${categoriesList.length} catégories configurées.`);

  // 2. Insérer tous les restaurants
  const allRestaurants = [
    ...demo.restaurants,
    {
      id: 'rest_demo',
      name: 'SuperBurger Demo',
      description: 'Burgers gourmets smashés minute avec frites fraîches et sauces artisanales.',
      cuisine: 'Burgers • Américain',
      categoryIds: ['burger'],
      imageUrl: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&w=800&q=80',
      rating: 4.8,
      reviewCount: 380,
      deliveryMinutes: 20,
      deliveryFee: 2.0,
      minOrder: 10,
      distanceKm: 0.8,
      address: 'Av. Hédi Nouira, Ennasr 2, Ariana',
      phone: '+216 71 800 120',
      menuSections: ['Burgers', 'Accompagnements', 'Boissons'],
      isOpen: true,
      isPopular: true,
      promo: '-20 %',
      status: 'approved',
    },
  ];

  let restCount = 0;
  for (const r of allRestaurants) {
    const loc = ARIANA_LOCATIONS[r.id] || { lat: 36.9050, lng: 10.1850, address: r.address || 'Ariana' };
    const category = r.categoryIds?.[0] || 'burger';
    const menuSectionsJson = JSON.stringify(r.menuSections || ['Menu']);

    await query(
      `INSERT INTO restaurants (
        id, name, description, address, phone, email, category, image_url,
        latitude, longitude, rating, is_open, status, cuisine, review_count,
        delivery_minutes, delivery_fee, min_order, distance_km, menu_sections,
        is_popular, promo, geo_status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'ok')
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        description = excluded.description,
        address = excluded.address,
        phone = excluded.phone,
        category = excluded.category,
        image_url = excluded.image_url,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        rating = excluded.rating,
        is_open = 1,
        status = 'approved',
        cuisine = excluded.cuisine,
        review_count = excluded.review_count,
        delivery_minutes = excluded.delivery_minutes,
        delivery_fee = excluded.delivery_fee,
        min_order = excluded.min_order,
        distance_km = excluded.distance_km,
        menu_sections = excluded.menu_sections,
        is_popular = excluded.is_popular,
        promo = excluded.promo,
        geo_status = 'ok'`,
      [
        r.id,
        r.name,
        r.description || '',
        loc.address,
        r.phone || '+216 71 000 000',
        `${r.id}@superfaster.tn`,
        category,
        r.imageUrl || '',
        loc.lat,
        loc.lng,
        r.rating || 4.7,
        r.isOpen ? 1 : 1,
        r.cuisine || 'Gourmet',
        r.reviewCount || 250,
        r.deliveryMinutes || 25,
        r.deliveryFee || 2.0,
        r.minOrder || 10,
        r.distanceKm || 1.1,
        menuSectionsJson,
        r.isPopular ? 1 : 0,
        r.promo || null,
      ],
    );

    // Lier les catégories
    for (const catId of (r.categoryIds || [category])) {
      await query(
        `INSERT OR IGNORE INTO restaurant_categories (restaurant_id, category_id) VALUES (?, ?)`,
        [r.id, catId],
      );
    }
    restCount++;
  }
  console.log(`✅ ${restCount} restaurants enregistrés et activés.`);

  // 3. Insérer tous les produits
  const allProducts = [...demo.products, ...ADDITIONAL_PRODUCTS];
  let prodCount = 0;

  for (const p of allProducts) {
    const category = p.categoryId || 'burger';
    const optionGroupsJson = JSON.stringify(p.optionGroups || []);

    await query(
      `INSERT INTO products (
        id, restaurant_id, name, description, price, category, image_url,
        is_available, section, option_groups, is_popular, calories, allergens
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, '[]')
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        description = excluded.description,
        price = excluded.price,
        category = excluded.category,
        image_url = excluded.image_url,
        is_available = 1,
        section = excluded.section,
        option_groups = excluded.option_groups,
        is_popular = excluded.is_popular,
        calories = excluded.calories`,
      [
        p.id,
        p.restaurantId,
        p.name,
        p.description || '',
        p.price,
        category,
        p.imageUrl || '',
        p.section || 'Plats',
        optionGroupsJson,
        p.isPopular ? 1 : 0,
        p.calories || null,
      ],
    );
    prodCount++;
  }
  console.log(`✅ ${prodCount} produits enregistrés avec photos, sections et options.`);
  console.log('🎉 Base de données remplie avec succès !');
}

populate()
  .catch((e) => {
    console.error('❌ Erreur :', e);
    process.exit(1);
  })
  .finally(close);

