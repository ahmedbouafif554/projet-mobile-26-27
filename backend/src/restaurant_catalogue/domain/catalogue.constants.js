'use strict';

/** Cycle de vie d'un restaurant, calqué sur `RestaurantStatus` du frontend. */
const RESTAURANT_STATUSES = Object.freeze(['pending', 'approved', 'rejected', 'suspended']);

/** Seul un restaurant validé est visible des clients et peut être ouvert. */
const APPROVED = 'approved';

/** Valeurs par défaut, identiques à celles des modèles Flutter. */
const RESTAURANT_DEFAULTS = Object.freeze({
  deliveryMinutes: 30,
  deliveryFee: 0,
  minOrder: 10,
  distanceKm: 1,
  latitude: 48.8566,
  longitude: 2.3522,
});

const CATEGORY_DEFAULTS = Object.freeze({
  emoji: '🍽️',
  colorValue: 0xffffe8d9,
});

/**
 * Localisation d'un restaurant (adresse → coordonnées GPS) :
 *  - pending   : pas encore géocodé (ou géolocalisation désactivée) ;
 *  - ok        : coordonnées trouvées par OpenStreetMap ;
 *  - not_found : adresse inconnue d'OpenStreetMap ;
 *  - error     : service indisponible, à réessayer ;
 *  - manual    : coordonnées saisies à la main.
 */
const GEO_STATUSES = Object.freeze(['pending', 'ok', 'not_found', 'error', 'manual']);

/** Statuts dont les coordonnées sont fiables (distance et carte). */
const LOCATED = Object.freeze(['ok', 'manual']);

/**
 * Délai estimé : le délai annoncé par le restaurant couvre les premiers
 * kilomètres, puis on ajoute le trajet d'un scooter en ville (≈ 20 km/h).
 */
const DELIVERY_ESTIMATE = Object.freeze({ includedKm: 2, minutesPerKm: 3 });

/** Nutri-Score affiché sur les produits alimentaires. */
const NUTRI_SCORES = Object.freeze(['a', 'b', 'c', 'd', 'e']);

/**
 * Les 14 allergènes à déclaration obligatoire (règlement UE n° 1169/2011),
 * avec les identifiants d'Open Food Facts.
 */
const ALLERGENS = Object.freeze({
  gluten: 'Gluten',
  crustaceans: 'Crustacés',
  eggs: 'Œufs',
  fish: 'Poisson',
  peanuts: 'Arachides',
  soybeans: 'Soja',
  milk: 'Lait',
  nuts: 'Fruits à coque',
  celery: 'Céleri',
  mustard: 'Moutarde',
  'sesame-seeds': 'Sésame',
  'sulphur-dioxide-and-sulphites': 'Sulfites',
  lupin: 'Lupin',
  molluscs: 'Mollusques',
});

/** Bornes de validation (longueurs en caractères, montants en euros). */
const LIMITS = Object.freeze({
  idLength: 64,
  nameLength: 120,
  descriptionLength: 1000,
  cuisineLength: 160,
  addressLength: 255,
  phoneLength: 32,
  emailLength: 255,
  urlLength: 2048,
  // Photo du menu en base64 : ~2 Mo d'image.
  menuImageLength: 2_800_000,
  promoLength: 120,
  sectionLength: 60,
  menuSections: 30,
  categoriesPerRestaurant: 20,
  categoryNameLength: 60,
  emojiLength: 16,
  optionGroups: 20,
  optionsPerGroup: 30,
  maxPrice: 10000,
  maxDeliveryFee: 100,
  maxMinOrder: 1000,
  maxDeliveryMinutes: 240,
  maxDistanceKm: 1000,
  maxCalories: 10000,
  maxReviewCount: 1000000,
  maxColorValue: 0xffffffff,
  maxRadiusKm: 50,
});

/** Catégories créées avec la table (les mêmes que le catalogue mock du frontend). */
const DEFAULT_CATEGORIES = Object.freeze([
  { id: 'burger', name: 'Burgers', emoji: '🍔', colorValue: 0xffffe8d9, isActive: true },
  { id: 'pizza', name: 'Italien', emoji: '🍕', colorValue: 0xffffe3e0, isActive: true },
  { id: 'sushi', name: 'Sushi', emoji: '🍣', colorValue: 0xffe3f0ff, isActive: true },
  { id: 'healthy', name: 'Healthy', emoji: '🥗', colorValue: 0xffe2f7e9, isActive: true },
  { id: 'asian', name: 'Asiatique', emoji: '🍜', colorValue: 0xfffff4d6, isActive: true },
  { id: 'tacos', name: 'Mexicain', emoji: '🌮', colorValue: 0xffffebd1, isActive: true },
  { id: 'dessert', name: 'Desserts', emoji: '🍩', colorValue: 0xfffce4f3, isActive: true },
  { id: 'courses', name: 'Courses', emoji: '🛒', colorValue: 0xffe6f6f4, isActive: true },
  { id: 'breakfast', name: 'Petit-déj', emoji: '🥐', colorValue: 0xfffff0db, isActive: true },
  { id: 'drinks', name: 'Boissons', emoji: '🥤', colorValue: 0xffe8e6ff, isActive: false },
]);

const MESSAGES = Object.freeze({
  restaurantNotFound: 'Restaurant introuvable.',
  productNotFound: 'Produit introuvable.',
  categoryNotFound: 'Catégorie introuvable.',
  unknownRestaurant: "Ce restaurant n'existe pas.",
  duplicateId: 'Cet élément existe déjà.',
  duplicateCategoryName: 'Une catégorie porte déjà ce nom.',
  ownerRequired: 'Le restaurateur (ownerId) est obligatoire.',
  invalidOwner: "Le restaurateur doit être un compte « Restaurant » existant.",
  ownerNotPending: "Ce compte restaurateur n'est pas une demande d'inscription en cours.",
  ownerAlreadyLinked: 'Ce restaurateur gère déjà un restaurant.',
  moveProduct: 'Seul un administrateur peut déplacer un produit vers un autre restaurant.',
  invalidStatus: 'Statut de restaurant invalide.',
  restaurantInUse:
    'Ce restaurant est lié à des commandes : suspendez-le plutôt que de le supprimer.',
  productInUse:
    'Ce produit figure dans des commandes : rendez-le indisponible plutôt que de le supprimer.',
  availabilityRequired: 'isAvailable : vrai ou faux attendu.',
  coordinatesPair: 'La latitude et la longitude vont ensemble.',
  radiusNeedsPosition: 'Le rayon (radiusKm) demande une latitude et une longitude.',
  geocodingDisabled: 'La géolocalisation des adresses est désactivée sur ce serveur.',
  geocodingUnavailable: 'Le service de géolocalisation ne répond pas, réessayez dans un instant.',
  barcodeRequired: 'Le code-barres est obligatoire.',
  invalidBarcode: 'Code-barres invalide : 8, 12, 13 ou 14 chiffres avec une clé de contrôle correcte.',
  duplicateBarcode: 'Ce code-barres est déjà utilisé par un autre produit de ce restaurant.',
  barcodeNotFound: 'Aucun produit ne correspond à ce code-barres sur Open Food Facts.',
  barcodeServiceUnavailable: 'Open Food Facts ne répond pas, réessayez dans un instant.',
  invalidNutriScore: 'Nutri-Score invalide (A, B, C, D ou E).',
});

module.exports = {
  RESTAURANT_STATUSES,
  APPROVED,
  RESTAURANT_DEFAULTS,
  CATEGORY_DEFAULTS,
  GEO_STATUSES,
  LOCATED,
  DELIVERY_ESTIMATE,
  NUTRI_SCORES,
  ALLERGENS,
  LIMITS,
  DEFAULT_CATEGORIES,
  MESSAGES,
};
