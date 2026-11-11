'use strict';

const { SPEEDS_KMH } = require('../domain/livreur.constants');

function isCoordinate(lat, lng) {
  const a = Number(lat);
  const b = Number(lng);
  return (
    lat != null && lng != null && lat !== '' && lng !== '' &&
    Number.isFinite(a) && Number.isFinite(b) &&
    a >= -90 && a <= 90 && b >= -180 && b <= 180
  );
}

/** Distance à vol d'oiseau (formule de Haversine), en km, arrondie à 0,1. */
function distanceKm(lat1, lng1, lat2, lng2) {
  if (!isCoordinate(lat1, lng1) || !isCoordinate(lat2, lng2)) return null;
  const toRad = (deg) => (Number(deg) * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  const km = 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(km * 10) / 10;
}

/** Durée estimée : trajet à la vitesse du véhicule + 5 min de remise en main propre. */
function etaMinutes(km, vehicle = 'scooter') {
  const speed = SPEEDS_KMH[vehicle] || 25;
  return Math.max(5, Math.round(((Number(km) || 0) / speed) * 60 + 5));
}

module.exports = { isCoordinate, distanceKm, etaMinutes };
