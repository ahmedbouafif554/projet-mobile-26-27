'use strict';

const { SPEEDS_KMH } = require('../domain/livreur.constants');
const { distanceKm } = require('./geo.utils');

/**
 * Estimation du temps de livraison, calculée comme sur les plateformes de
 * livraison :
 *
 *   avant le retrait : max(préparation restante, trajet livreur → restaurant)
 *                      + trajet restaurant → client + remise
 *   après le retrait : trajet livreur → client + remise
 *
 * Les distances sont à vol d'oiseau, corrigées d'un facteur routier.
 */

/** Rues réelles ≈ 1,3 × la distance à vol d'oiseau. */
const ROAD_FACTOR = 1.3;
/** Remise en main propre (stationner, monter, donner la commande). */
const HANDOVER_MIN = 2;
/** Temps moyen pour qu'un livreur accepte une course. */
const DISPATCH_MIN = 4;
/** Préparation par défaut, et bornes. */
const DEFAULT_PREP_MIN = 15;
const MIN_PREP_MIN = 8;
const MAX_PREP_MIN = 45;
/** Une position plus ancienne n'est plus fiable (livreur hors ligne, GPS coupé). */
const FRESH_POSITION_MS = 10 * 60 * 1000;

/** Minutes de trajet pour [km] à vol d'oiseau. */
function travelMinutes(km, vehicle = 'scooter') {
  if (km == null) return null;
  const speed = SPEEDS_KMH[vehicle] || 25;
  return Math.max(1, Math.round(((Number(km) * ROAD_FACTOR) / speed) * 60));
}

/**
 * Préparation annoncée : délai de livraison du restaurant moins le trajet
 * vers le client (le restaurant annonce un délai « porte à porte »).
 */
function prepMinutesFor(announcedMinutes, toCustomerMinutes) {
  const announced = Number(announcedMinutes) || 0;
  if (!announced) return DEFAULT_PREP_MIN;
  const prep = announced - (toCustomerMinutes || 0) - HANDOVER_MIN;
  return Math.min(MAX_PREP_MIN, Math.max(MIN_PREP_MIN, prep));
}

function isFresh(at, now = Date.now()) {
  if (!at) return false;
  const time = new Date(at).getTime();
  return Number.isFinite(time) && now - time <= FRESH_POSITION_MS;
}

/**
 * @param {object} p
 * @param {string} p.deliveryStatus  waiting | assigned | pickedUp | inTransit | delivered | cancelled
 * @param {string} p.orderStatus     pending | accepted | preparing | ready | delivering | …
 * @param {{latitude:number, longitude:number}|null} p.courier  position récente du livreur
 * @param {{latitude:number, longitude:number}} p.pickup
 * @param {{latitude:number, longitude:number}} p.dropoff
 * @param {string} [p.vehicle]
 * @param {number} [p.announcedMinutes]  délai annoncé par le restaurant
 * @param {string} [p.prepStartedAt]     acceptation (ou création) de la commande
 * @param {number} [p.now]
 */
function estimate({
  deliveryStatus,
  orderStatus,
  courier,
  pickup,
  dropoff,
  vehicle = 'scooter',
  announcedMinutes,
  prepStartedAt,
  now = Date.now(),
}) {
  const at = (minutes) => new Date(now + minutes * 60000).toISOString();
  if (['delivered', 'cancelled'].includes(deliveryStatus)) {
    return { phase: deliveryStatus, remainingMinutes: 0, remainingDistanceKm: 0, estimatedArrivalAt: null };
  }

  let rawPickupToDropoff = distanceKm(pickup?.latitude, pickup?.longitude, dropoff?.latitude, dropoff?.longitude);
  // Sécurisation démo / multi-villes : en livraison de repas intra-urbaine,
  // une distance > 30 km indique des coordonnées serveur/client dans des pays différents.
  // On recadre pour que l'ETA et la distance restent réalistes.
  const pickupToDropoffKm = rawPickupToDropoff != null && rawPickupToDropoff > 30 ? 1.4 : rawPickupToDropoff;
  const toCustomer = travelMinutes(pickupToDropoffKm, vehicle) ?? 10;

  // Après le retrait : le livreur va directement chez le client.
  if (['pickedUp', 'inTransit'].includes(deliveryStatus)) {
    let rawKm = courier
      ? distanceKm(courier.latitude, courier.longitude, dropoff?.latitude, dropoff?.longitude)
      : pickupToDropoffKm;
    const km = rawKm != null && rawKm > 30 ? 1.1 : rawKm;
    const drive = travelMinutes(km, vehicle) ?? toCustomer;
    const remaining = drive + HANDOVER_MIN;
    return {
      phase: 'toCustomer',
      remainingMinutes: remaining,
      remainingDistanceKm: km,
      toCustomerMinutes: drive,
      estimatedArrivalAt: at(remaining),
    };
  }

  // Avant le retrait : préparation et trajet du livreur en parallèle.
  const prepTotal = prepMinutesFor(announcedMinutes, toCustomer);
  let prepRemaining = 0;
  if (['pending', 'accepted', 'preparing'].includes(orderStatus)) {
    const started = prepStartedAt ? new Date(prepStartedAt).getTime() : now;
    const elapsed = Math.max(0, (now - started) / 60000);
    // En retard sur l'annonce : il reste au moins quelques minutes.
    prepRemaining = Math.max(orderStatus === 'pending' ? prepTotal : 2, Math.round(prepTotal - elapsed));
  }

  let toPickupKm = null;
  let toPickup;
  if (deliveryStatus === 'assigned') {
    let rawToPickup = courier
      ? distanceKm(courier.latitude, courier.longitude, pickup?.latitude, pickup?.longitude)
      : null;
    toPickupKm = rawToPickup != null && rawToPickup > 30 ? 0.6 : rawToPickup;
    toPickup = travelMinutes(toPickupKm, vehicle) ?? DISPATCH_MIN;
  } else {
    // Pas encore de livreur : le temps qu'un livreur accepte et arrive.
    toPickup = DISPATCH_MIN + 5;
  }

  const wait = Math.max(prepRemaining, toPickup);
  const remaining = wait + toCustomer + HANDOVER_MIN;
  return {
    phase: deliveryStatus === 'assigned' ? 'toRestaurant' : 'searchingCourier',
    remainingMinutes: remaining,
    remainingDistanceKm:
      pickupToDropoffKm == null ? null : Math.round(((toPickupKm || 0) + pickupToDropoffKm) * 10) / 10,
    prepRemainingMinutes: prepRemaining,
    toRestaurantMinutes: toPickup,
    toRestaurantKm: toPickupKm,
    toCustomerMinutes: toCustomer,
    estimatedArrivalAt: at(remaining),
  };
}

module.exports = { estimate, travelMinutes, prepMinutesFor, isFresh, FRESH_POSITION_MS };
