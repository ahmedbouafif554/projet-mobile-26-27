'use strict';

const { query, toSqlDate } = require('../../data/db');
const settings = require('../catalogue.config');
const { getJson } = require('./http.client');

/**
 * Coordonnées GPS d'une adresse de restaurant, avec Nominatim (OpenStreetMap,
 * gratuit et sans clé). Appelé côté serveur uniquement :
 *  - une requête par seconde au plus (règle d'utilisation de Nominatim) ;
 *  - résultats gardés dans `geocode_cache` : une adresse n'est demandée qu'une
 *    fois (et une adresse introuvable n'est redemandée qu'après 7 jours) ;
 *  - aucune donnée de client ni jeton n'est envoyé au service.
 */

const DAY_MS = 24 * 60 * 60 * 1000;
const FOUND_TTL_MS = 180 * DAY_MS;
const NOT_FOUND_TTL_MS = 7 * DAY_MS;

/** Clé de cache : même adresse, mêmes coordonnées (casse et espaces ignorés). */
function addressKey(address) {
  return String(address ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
}

let nextSlot = 0;
let queue = Promise.resolve();

/** Appels exécutés l'un après l'autre, espacés d'au moins l'intervalle réglé. */
function throttled(task) {
  const run = queue.then(async () => {
    const wait = nextSlot - Date.now();
    if (wait > 0) await new Promise((resolve) => setTimeout(resolve, wait));
    nextSlot = Date.now() + settings.geocodingMinIntervalMs;
    return task();
  });
  queue = run.catch(() => {});
  return run;
}

async function cached(key) {
  const [row] = await query('SELECT * FROM geocode_cache WHERE address_key = ?', [key]);
  if (!row) return null;
  const found = Number(row.found) === 1;
  const age = Date.now() - new Date(row.fetched_at).getTime();
  if (!(age >= 0 && age < (found ? FOUND_TTL_MS : NOT_FOUND_TTL_MS))) return null;
  return found
    ? { found: true, latitude: Number(row.latitude), longitude: Number(row.longitude) }
    : { found: false };
}

async function remember(key, result) {
  await query(
    `INSERT OR REPLACE INTO geocode_cache (address_key, found, latitude, longitude, fetched_at)
     VALUES (?, ?, ?, ?, ?)`,
    [
      key,
      result.found ? 1 : 0,
      result.found ? result.latitude : null,
      result.found ? result.longitude : null,
      toSqlDate(new Date()),
    ],
  );
}

/** Première réponse de Nominatim → coordonnées, si elles sont valides. */
function parse(results) {
  const first = Array.isArray(results) ? results[0] : null;
  const latitude = Number(first?.lat);
  const longitude = Number(first?.lon);
  const valid =
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    Math.abs(latitude) <= 90 &&
    Math.abs(longitude) <= 180;
  return valid ? { found: true, latitude, longitude } : { found: false };
}

/**
 * `{ found: true, latitude, longitude }` ou `{ found: false }`.
 * Lève ExternalServiceError si Nominatim ne répond pas : rien n'est mis en
 * cache, l'adresse sera redemandée plus tard. `force` ignore le cache.
 */
async function geocode(address, { force = false } = {}) {
  const key = addressKey(address);
  if (!key) return { found: false };
  if (!force) {
    const hit = await cached(key);
    if (hit) return hit;
  }
  const params = new URLSearchParams({ format: 'jsonv2', limit: '1', q: String(address).trim() });
  if (settings.geocodingCountry) params.set('countrycodes', settings.geocodingCountry);
  const response = await throttled(() =>
    getJson('OpenStreetMap', `${settings.nominatimUrl}/search?${params}`),
  );
  const result = parse(response);
  await remember(key, result);
  return result;
}

module.exports = { geocode, addressKey };
