'use strict';

const HttpError = require('../../errors/http-error');
const { query, toSqlDate } = require('../../data/db');
const settings = require('../catalogue.config');
const { ALLERGENS, NUTRI_SCORES, LIMITS, MESSAGES } = require('../domain/catalogue.constants');
const { getJson, ExternalServiceError } = require('./http.client');

/**
 * Fiche produit à partir d'un code-barres grâce à Open Food Facts (base
 * collaborative de produits alimentaires, gratuite et sans clé).
 * La fiche pré-remplit le formulaire du back office : rien n'est enregistré
 * dans le catalogue ici. Les réponses sont gardées dans `barcode_lookups`.
 */

const DAY_MS = 24 * 60 * 60 * 1000;
const FOUND_TTL_MS = 7 * DAY_MS;
const NOT_FOUND_TTL_MS = DAY_MS;

const FIELDS = [
  'product_name_fr',
  'product_name',
  'generic_name_fr',
  'brands',
  'quantity',
  'image_front_url',
  'image_url',
  'nutriscore_grade',
  'allergens_tags',
  'nutriments',
].join(',');

function clip(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max).trim() : '';
}

function kilocalories(value) {
  const kcal = Number(value);
  return Number.isFinite(kcal) && kcal >= 0 && kcal <= LIMITS.maxCalories ? Math.round(kcal) : null;
}

/** Fiche Open Food Facts → champs du produit SuperFaster. */
function toSuggestion(barcode, product) {
  const brand = clip(String(product.brands ?? '').split(',')[0], LIMITS.nameLength);
  // « 400 g e » : le « e » (℮) est la mention de quantité estimée.
  const quantity = clip(String(product.quantity ?? '').replace(/\s+[e℮]$/u, ''), 40);
  const imageUrl = [product.image_front_url, product.image_url].find(
    (url) => typeof url === 'string' && /^https?:\/\/\S+$/i.test(url) && url.length <= LIMITS.urlLength,
  );
  const perServing = kilocalories(product.nutriments?.['energy-kcal_serving']);
  const per100g = kilocalories(product.nutriments?.['energy-kcal_100g']);
  const allergens = [];
  for (const tag of Array.isArray(product.allergens_tags) ? product.allergens_tags : []) {
    const code = String(tag).replace(/^en:/, '');
    if (Object.hasOwn(ALLERGENS, code) && !allergens.includes(code)) allergens.push(code);
  }
  const grade = String(product.nutriscore_grade ?? '').toLowerCase();

  return {
    barcode,
    name: clip(product.product_name_fr || product.product_name || product.generic_name_fr, LIMITS.nameLength),
    description: clip([brand, quantity].filter(Boolean).join(' · '), LIMITS.descriptionLength),
    imageUrl: imageUrl || '',
    calories: perServing ?? per100g,
    caloriesBasis: perServing != null ? 'serving' : per100g != null ? '100g' : null,
    allergens,
    nutriScore: NUTRI_SCORES.includes(grade) ? grade : null,
    source: 'Open Food Facts',
  };
}

async function cached(barcode) {
  const [row] = await query('SELECT * FROM barcode_lookups WHERE barcode = ?', [barcode]);
  if (!row) return null;
  const found = Number(row.found) === 1;
  const age = Date.now() - new Date(row.fetched_at).getTime();
  if (!(age >= 0 && age < (found ? FOUND_TTL_MS : NOT_FOUND_TTL_MS))) return null;
  if (!found) return { found: false };
  try {
    return { found: true, suggestion: JSON.parse(row.payload) };
  } catch {
    return null;
  }
}

async function remember(barcode, suggestion) {
  await query(
    `INSERT OR REPLACE INTO barcode_lookups (barcode, found, payload, fetched_at)
     VALUES (?, ?, ?, ?)`,
    [barcode, suggestion ? 1 : 0, suggestion ? JSON.stringify(suggestion) : null, toSqlDate(new Date())],
  );
}

/**
 * Fiche pré-remplie pour un code-barres déjà validé.
 * 404 : produit inconnu d'Open Food Facts ; 502 : service injoignable.
 */
async function lookup(barcode) {
  const hit = await cached(barcode);
  if (hit?.found) return hit.suggestion;
  if (hit) throw new HttpError(404, MESSAGES.barcodeNotFound);

  let data;
  try {
    data = await getJson(
      'Open Food Facts',
      `${settings.openFoodFactsUrl}/api/v2/product/${barcode}.json?fields=${FIELDS}`,
    );
  } catch (error) {
    if (error instanceof ExternalServiceError) {
      throw new HttpError(502, MESSAGES.barcodeServiceUnavailable);
    }
    throw error;
  }

  const product = data && Number(data.status) === 1 && data.product ? data.product : null;
  if (!product) {
    await remember(barcode, null);
    throw new HttpError(404, MESSAGES.barcodeNotFound);
  }
  const suggestion = toSuggestion(barcode, product);
  await remember(barcode, suggestion);
  return suggestion;
}

module.exports = { lookup };
