'use strict';

const { DELIVERY_ESTIMATE } = require('../domain/catalogue.constants');

const EARTH_RADIUS_KM = 6371;

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

/** Distance à vol d'oiseau entre deux points GPS (formule de haversine), en km. */
function distanceKm(from, to) {
  const dLat = toRadians(to.latitude - from.latitude);
  const dLng = toRadians(to.longitude - from.longitude);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(from.latitude)) * Math.cos(toRadians(to.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** Arrondi au dixième (affichage « 1,2 km »). */
function roundKm(km) {
  return Math.round(km * 10) / 10;
}

/**
 * Délai de livraison estimé pour une distance : le délai annoncé par le
 * restaurant, plus le trajet au-delà des kilomètres qu'il couvre déjà.
 */
function estimatedMinutes(baseMinutes, km) {
  const extraKm = Math.max(0, roundKm(km) - DELIVERY_ESTIMATE.includedKm);
  return baseMinutes + Math.ceil(roundKm(extraKm * DELIVERY_ESTIMATE.minutesPerKm));
}

module.exports = { distanceKm, roundKm, estimatedMinutes };
