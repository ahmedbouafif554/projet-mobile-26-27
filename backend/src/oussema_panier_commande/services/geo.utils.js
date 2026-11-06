'use strict';

/**
 * Calcule la distance orthodromique (formule de Haversine) entre deux points GPS en kilomètres.
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return 1.0;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const R = 6371; // Rayon de la Terre en km

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  // Arrondi à 1 décimale, minimum 0.2 km
  return Math.max(0.2, Math.round(distance * 10) / 10);
}

/**
 * Estime la durée d'une course en minutes selon la distance et le moyen de transport.
 * Vitesse moyenne en ville : vélo (15 km/h), scooter (30 km/h), voiture (25 km/h).
 * + 5 minutes de tampon pour le stationnement et la remise en main propre.
 */
function estimateDurationMinutes(distanceKm, vehicle = 'scooter') {
  const speeds = {
    bike: 15,
    scooter: 30,
    car: 25,
  };
  const speed = speeds[vehicle] || 25;
  const transitHours = distanceKm / speed;
  const transitMinutes = transitHours * 60;
  const bufferMinutes = 5;

  return Math.max(10, Math.round(transitMinutes + bufferMinutes));
}

module.exports = {
  haversineDistance,
  estimateDurationMinutes,
};
