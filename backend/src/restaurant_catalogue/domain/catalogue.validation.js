'use strict';

const HttpError = require('../../errors/http-error');
const { requireName, requirePhone, requireEmail, oneOf } = require('../../domain/validate');
const {
  RESTAURANT_STATUSES,
  RESTAURANT_DEFAULTS,
  CATEGORY_DEFAULTS,
  LIMITS,
  MESSAGES,
} = require('./catalogue.constants');

const ID = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;
const WEB_URL = /^https?:\/\/\S+$/i;

function invalid(message) {
  return new HttpError(422, message);
}

// ── Briques de base ─────────────────────────────────────────────────────────

/** Texte facultatif : `''` si absent, erreur si ce n'est pas une chaîne. */
function optionalText(value, label, max) {
  if (value == null) return '';
  if (typeof value !== 'string') throw invalid(`${label} : texte attendu.`);
  const result = value.trim();
  if (result.length > max) throw invalid(`${label} : ${max} caractères maximum.`);
  return result;
}

function requiredText(value, label, max, missingMessage) {
  const result = optionalText(value, label, max);
  if (!result) throw invalid(missingMessage);
  return result;
}

function name(value, max) {
  const result = requireName(value);
  if (result.length > max) throw invalid(`Le nom : ${max} caractères maximum.`);
  return result;
}

/** Nombre (ou chaîne numérique) borné ; `fallback` s'il est absent. */
function number(value, { label, min, max, integer = false, fallback }) {
  if (value == null || value === '') {
    if (fallback !== undefined) return fallback;
    throw invalid(`${label} est obligatoire.`);
  }
  const parsed = typeof value === 'string' ? Number(value.trim()) : value;
  if (typeof parsed !== 'number' || !Number.isFinite(parsed)) {
    throw invalid(`${label} : nombre attendu.`);
  }
  if (integer && !Number.isInteger(parsed)) throw invalid(`${label} : nombre entier attendu.`);
  if (parsed < min || parsed > max) {
    throw invalid(`${label} doit être compris entre ${min} et ${max}.`);
  }
  return parsed;
}

function money(value, options) {
  return Math.round(number(value, options) * 100) / 100;
}

function bool(value, label, fallback) {
  if (value == null) return fallback;
  if (typeof value !== 'boolean') throw invalid(`${label} : vrai ou faux attendu.`);
  return value;
}

/** Liste de textes : nettoyée, sans doublon ni élément vide. */
function textList(value, { label, maxItems, maxLength }) {
  if (value == null) return [];
  if (!Array.isArray(value)) throw invalid(`${label} : liste attendue.`);
  const result = [];
  for (const item of value) {
    const entry = optionalText(item, label, maxLength);
    if (entry && !result.includes(entry)) result.push(entry);
  }
  if (result.length > maxItems) throw invalid(`${label} : ${maxItems} éléments maximum.`);
  return result;
}

function imageUrl(value) {
  const url = optionalText(value, "L'URL de l'image", LIMITS.urlLength);
  if (url && !WEB_URL.test(url)) {
    throw invalid("L'URL de l'image doit commencer par http:// ou https://.");
  }
  return url;
}

/** Identifiant fourni par le client : `''` s'il est vide (le service en génère un). */
function requestedId(value) {
  const id = optionalText(value, "L'identifiant", LIMITS.idLength);
  if (id && !ID.test(id)) throw invalid('Identifiant invalide (lettres, chiffres, - et _).');
  return id;
}

function restaurantStatus(value) {
  return oneOf(value, RESTAURANT_STATUSES, MESSAGES.invalidStatus);
}

function phoneNumber(value) {
  const phone = requirePhone(value);
  if (phone.length > LIMITS.phoneLength) {
    throw invalid(`Le téléphone : ${LIMITS.phoneLength} caractères maximum.`);
  }
  return phone;
}

function optionalEmail(value) {
  const email = optionalText(value, "L'e-mail", LIMITS.emailLength);
  return email ? requireEmail(email) : '';
}

// ── Restaurant ──────────────────────────────────────────────────────────────

/**
 * Restaurant complet et normalisé à partir de la forme JSON du frontend.
 * Les champs réservés à l'administrateur sont filtrés en amont par le service.
 */
function restaurantInput(body) {
  return {
    name: name(body.name, LIMITS.nameLength),
    description: optionalText(body.description, 'La description', LIMITS.descriptionLength),
    cuisine: requiredText(body.cuisine, 'La cuisine', LIMITS.cuisineLength, 'La cuisine est obligatoire.'),
    categoryIds: textList(body.categoryIds, {
      label: 'Les catégories',
      maxItems: LIMITS.categoriesPerRestaurant,
      maxLength: LIMITS.idLength,
    }),
    imageUrl: imageUrl(body.imageUrl),
    address: requiredText(body.address, "L'adresse", LIMITS.addressLength, "L'adresse est obligatoire."),
    phone: phoneNumber(body.phone),
    email: optionalEmail(body.email),
    deliveryMinutes: number(body.deliveryMinutes, {
      label: 'Le délai de livraison',
      min: 1,
      max: LIMITS.maxDeliveryMinutes,
      integer: true,
      fallback: RESTAURANT_DEFAULTS.deliveryMinutes,
    }),
    deliveryFee: money(body.deliveryFee, {
      label: 'Les frais de livraison',
      min: 0,
      max: LIMITS.maxDeliveryFee,
      fallback: RESTAURANT_DEFAULTS.deliveryFee,
    }),
    minOrder: money(body.minOrder, {
      label: 'Le minimum de commande',
      min: 0,
      max: LIMITS.maxMinOrder,
      fallback: RESTAURANT_DEFAULTS.minOrder,
    }),
    distanceKm: number(body.distanceKm, {
      label: 'La distance',
      min: 0,
      max: LIMITS.maxDistanceKm,
      fallback: RESTAURANT_DEFAULTS.distanceKm,
    }),
    menuSections: textList(body.menuSections, {
      label: 'Les onglets du menu',
      maxItems: LIMITS.menuSections,
      maxLength: LIMITS.sectionLength,
    }),
    isOpen: bool(body.isOpen, "L'ouverture", true),
    isPopular: bool(body.isPopular, 'La mise en avant', false),
    promo: optionalText(body.promo, "L'offre", LIMITS.promoLength) || null,
    rating: number(body.rating, { label: 'La note', min: 0, max: 5, fallback: 0 }),
    reviewCount: number(body.reviewCount, {
      label: "Le nombre d'avis",
      min: 0,
      max: LIMITS.maxReviewCount,
      integer: true,
      fallback: 0,
    }),
    latitude: number(body.latitude, {
      label: 'La latitude',
      min: -90,
      max: 90,
      fallback: RESTAURANT_DEFAULTS.latitude,
    }),
    longitude: number(body.longitude, {
      label: 'La longitude',
      min: -180,
      max: 180,
      fallback: RESTAURANT_DEFAULTS.longitude,
    }),
    ownerId: optionalText(body.ownerId, 'Le restaurateur', LIMITS.idLength) || null,
    status: body.status == null ? null : restaurantStatus(body.status),
  };
}

// ── Produit ─────────────────────────────────────────────────────────────────

function optionInput(option, label, newId) {
  if (!option || typeof option !== 'object' || Array.isArray(option)) {
    throw invalid(`${label} : choix invalide.`);
  }
  return {
    id: requestedId(option.id) || newId('opt'),
    name: requiredText(option.name, label, LIMITS.sectionLength, `${label} : le nom du choix est obligatoire.`),
    price: money(option.price, {
      label: `${label} : le supplément`,
      min: 0,
      max: LIMITS.maxPrice,
      fallback: 0,
    }),
  };
}

function groupInput(group, index, newId) {
  const label = `Groupe d'options n° ${index + 1}`;
  if (!group || typeof group !== 'object' || Array.isArray(group)) {
    throw invalid(`${label} : groupe invalide.`);
  }
  if (!Array.isArray(group.options) || group.options.length === 0) {
    throw invalid(`${label} : au moins un choix est obligatoire.`);
  }
  if (group.options.length > LIMITS.optionsPerGroup) {
    throw invalid(`${label} : ${LIMITS.optionsPerGroup} choix maximum.`);
  }
  const options = group.options.map((option) => optionInput(option, label, newId));
  assertUniqueIds(options, `${label} : deux choix ont le même identifiant.`);
  return {
    id: requestedId(group.id) || newId('grp'),
    name: requiredText(group.name, label, LIMITS.sectionLength, `${label} : le nom est obligatoire.`),
    isRequired: bool(group.isRequired, `${label} : « obligatoire »`, false),
    maxChoices: number(group.maxChoices, {
      label: `${label} : le nombre de choix`,
      min: 1,
      max: options.length,
      integer: true,
      fallback: 1,
    }),
    options,
  };
}

function assertUniqueIds(items, message) {
  const ids = items.map((item) => item.id);
  if (new Set(ids).size !== ids.length) throw invalid(message);
}

/** Groupes d'options d'un produit (`newId` génère les identifiants manquants). */
function optionGroupsInput(value, newId) {
  if (value == null) return [];
  if (!Array.isArray(value)) throw invalid("Les groupes d'options : liste attendue.");
  if (value.length > LIMITS.optionGroups) {
    throw invalid(`${LIMITS.optionGroups} groupes d'options maximum.`);
  }
  const groups = value.map((group, index) => groupInput(group, index, newId));
  assertUniqueIds(groups, "Deux groupes d'options ont le même identifiant.");
  return groups;
}

/** Produit complet et normalisé à partir de la forme JSON du frontend. */
function productInput(body, newId) {
  return {
    restaurantId: requiredText(
      body.restaurantId,
      'Le restaurant',
      LIMITS.idLength,
      'Le restaurant est obligatoire.',
    ),
    categoryId: optionalText(body.categoryId, 'La catégorie', LIMITS.idLength),
    name: name(body.name, LIMITS.nameLength),
    description: optionalText(body.description, 'La description', LIMITS.descriptionLength),
    price: money(body.price, { label: 'Le prix', min: 0.01, max: LIMITS.maxPrice }),
    imageUrl: imageUrl(body.imageUrl),
    section: requiredText(
      body.section,
      "L'onglet du menu",
      LIMITS.sectionLength,
      "L'onglet du menu est obligatoire.",
    ),
    optionGroups: optionGroupsInput(body.optionGroups, newId),
    isAvailable: bool(body.isAvailable, 'La disponibilité', true),
    isPopular: bool(body.isPopular, 'La mise en avant', false),
    calories:
      body.calories == null
        ? null
        : number(body.calories, {
            label: 'Les calories',
            min: 0,
            max: LIMITS.maxCalories,
            integer: true,
          }),
  };
}

// ── Catégorie ───────────────────────────────────────────────────────────────

function categoryInput(body) {
  return {
    name: name(body.name, LIMITS.categoryNameLength),
    emoji:
      optionalText(body.emoji, "L'emoji", LIMITS.emojiLength) || CATEGORY_DEFAULTS.emoji,
    colorValue: number(body.colorValue, {
      label: 'La couleur',
      min: 0,
      max: LIMITS.maxColorValue,
      integer: true,
      fallback: CATEGORY_DEFAULTS.colorValue,
    }),
    isActive: bool(body.isActive, "L'activation", true),
  };
}

/** Nouvel ordre des catégories : identifiants uniques. */
function orderedIdsInput(value) {
  if (!Array.isArray(value) || value.length === 0) {
    throw invalid('ids : liste des catégories attendue.');
  }
  const ids = value.map((id) => requiredText(id, 'ids', LIMITS.idLength, 'ids : identifiant vide.'));
  if (new Set(ids).size !== ids.length) throw invalid('ids : une catégorie apparaît deux fois.');
  return ids;
}

module.exports = {
  requestedId,
  restaurantStatus,
  restaurantInput,
  productInput,
  categoryInput,
  orderedIdsInput,
};
