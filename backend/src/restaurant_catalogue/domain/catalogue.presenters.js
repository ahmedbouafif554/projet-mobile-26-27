'use strict';

const { toIso } = require('../../data/db');
const { RESTAURANT_STATUSES, RESTAURANT_DEFAULTS } = require('./catalogue.constants');

/**
 * Forme JSON exacte de `Restaurant.toJson()`, `Product.toJson()` et
 * `Category.toJson()` du frontend (plus latitude, longitude et e-mail du
 * restaurant, utilisés par le module Commandes).
 *
 * Les lignes créées avant ce module n'ont pas toujours les nouvelles colonnes :
 * `cuisine` et `section` retombent alors sur l'ancienne colonne `category`.
 */

function flag(value) {
  return Number(value) === 1;
}

function numberOr(value, fallback) {
  return value == null ? fallback : Number(value);
}

/** Colonne JSON (liste) : `[]` si vide ou illisible. */
function jsonList(value) {
  if (value == null || value === '') return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function presentRestaurant(row, categoryIds = []) {
  return {
    id: row.id,
    ownerId: row.owner_id || null,
    name: row.name,
    description: row.description || '',
    cuisine: row.cuisine || row.category || '',
    categoryIds,
    imageUrl: row.image_url || '',
    rating: numberOr(row.rating, 0),
    reviewCount: numberOr(row.review_count, 0),
    deliveryMinutes: numberOr(row.delivery_minutes, RESTAURANT_DEFAULTS.deliveryMinutes),
    deliveryFee: numberOr(row.delivery_fee, RESTAURANT_DEFAULTS.deliveryFee),
    minOrder: numberOr(row.min_order, RESTAURANT_DEFAULTS.minOrder),
    distanceKm: numberOr(row.distance_km, RESTAURANT_DEFAULTS.distanceKm),
    address: row.address || '',
    phone: row.phone || '',
    email: row.email || '',
    latitude: numberOr(row.latitude, RESTAURANT_DEFAULTS.latitude),
    longitude: numberOr(row.longitude, RESTAURANT_DEFAULTS.longitude),
    menuSections: jsonList(row.menu_sections).filter((s) => typeof s === 'string'),
    isOpen: flag(row.is_open),
    isPopular: flag(row.is_popular),
    promo: row.promo || null,
    // Statut inconnu : traité comme une demande non validée (jamais visible).
    status: RESTAURANT_STATUSES.includes(row.status) ? row.status : 'pending',
    createdAt: toIso(row.created_at),
  };
}

function presentProduct(row) {
  return {
    id: row.id,
    restaurantId: row.restaurant_id,
    categoryId: row.category || '',
    name: row.name,
    description: row.description || '',
    price: numberOr(row.price, 0),
    imageUrl: row.image_url || '',
    section: row.section || row.category || '',
    optionGroups: jsonList(row.option_groups),
    isAvailable: flag(row.is_available),
    isPopular: flag(row.is_popular),
    calories: row.calories == null ? null : Number(row.calories),
  };
}

function presentCategory(row) {
  return {
    id: row.id,
    name: row.name,
    emoji: row.emoji,
    colorValue: Number(row.color_value),
    position: Number(row.position),
    isActive: flag(row.is_active),
  };
}

module.exports = { presentRestaurant, presentProduct, presentCategory };
