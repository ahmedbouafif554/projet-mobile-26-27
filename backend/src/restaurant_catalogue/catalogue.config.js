'use strict';

const appConfig = require('../config');

/**
 * Réglages des API externes du module, lus à chaque appel (variables
 * d'environnement, toutes facultatives) :
 *
 *  GEOCODING_ENABLED          géolocalisation des adresses (défaut : oui, sauf en test)
 *  NOMINATIM_URL              https://nominatim.openstreetmap.org
 *  GEOCODING_COUNTRY          fr (codes pays ISO séparés par des virgules, vide = monde)
 *  GEOCODING_MIN_INTERVAL_MS  1100 (règle Nominatim : une requête par seconde au plus)
 *  OPEN_FOOD_FACTS_URL        https://world.openfoodfacts.org
 *  EXTERNAL_API_TIMEOUT_MS    8000
 *  EXTERNAL_API_CONTACT       contact placé dans l'User-Agent (exigé par les deux services)
 */

function env(name, fallback) {
  const value = process.env[name];
  return value == null || value.trim() === '' ? fallback : value.trim();
}

function flag(name, fallback) {
  const value = env(name, null);
  return value == null ? fallback : ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

function integer(name, fallback, min) {
  const value = Number(env(name, ''));
  return Number.isInteger(value) && value >= min ? value : fallback;
}

function baseUrl(name, fallback) {
  return env(name, fallback).replace(/\/+$/, '');
}

module.exports = {
  /** Désactivée par défaut dans les tests : aucun appel réseau involontaire. */
  get geocodingEnabled() {
    return flag('GEOCODING_ENABLED', !appConfig.isTest);
  },
  get nominatimUrl() {
    return baseUrl('NOMINATIM_URL', 'https://nominatim.openstreetmap.org');
  },
  get geocodingCountry() {
    return process.env.GEOCODING_COUNTRY == null ? 'fr' : process.env.GEOCODING_COUNTRY.trim();
  },
  get geocodingMinIntervalMs() {
    return integer('GEOCODING_MIN_INTERVAL_MS', 1100, 0);
  },
  get openFoodFactsUrl() {
    return baseUrl('OPEN_FOOD_FACTS_URL', 'https://world.openfoodfacts.org');
  },
  get timeoutMs() {
    return integer('EXTERNAL_API_TIMEOUT_MS', 8000, 100);
  },
  get userAgent() {
    const contact = env('EXTERNAL_API_CONTACT', 'https://github.com/ahmedbouafif554/projet-mobile-26-27');
    return `SuperFaster/1.0 (${contact})`;
  },
};
