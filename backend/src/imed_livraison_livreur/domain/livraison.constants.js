'use strict';

/**
 * Statuts de livraison.
 *
 * Le frontend Flutter utilise `DeliveryStatus.name` (camelCase) :
 *   waiting, assigned, pickedUp, inTransit, delivered, cancelled.
 * La table `deliveries` (partagée avec le module commandes) stocke les noms
 * snake_case : waiting, assigned, picked_up, in_transit (ou on_the_way),
 * delivered, cancelled, failed.
 */

const FRONT_STATUSES = Object.freeze([
  'waiting',
  'assigned',
  'pickedUp',
  'inTransit',
  'delivered',
  'cancelled',
]);

/** Nom stocké en base → nom envoyé au front. */
const DB_TO_FRONT = Object.freeze({
  waiting: 'waiting',
  assigned: 'assigned',
  picked_up: 'pickedUp',
  pickedUp: 'pickedUp',
  in_transit: 'inTransit',
  on_the_way: 'inTransit',
  inTransit: 'inTransit',
  delivered: 'delivered',
  cancelled: 'cancelled',
  failed: 'cancelled',
});

/** Nom reçu (front ou base) → nom stocké en base. */
const FRONT_TO_DB = Object.freeze({
  waiting: 'waiting',
  assigned: 'assigned',
  pickedUp: 'picked_up',
  picked_up: 'picked_up',
  inTransit: 'in_transit',
  in_transit: 'in_transit',
  on_the_way: 'in_transit',
  delivered: 'delivered',
  cancelled: 'cancelled',
  failed: 'cancelled',
});

/** Libellés identiques à `DeliveryStatus.label`. */
const STATUS_LABELS = Object.freeze({
  waiting: 'À assigner',
  assigned: 'Assignée',
  pickedUp: 'Récupérée',
  inTransit: 'En route',
  delivered: 'Livrée',
  cancelled: 'Annulée',
});

/** Course en cours pour le livreur (`DeliveryStatus.isActive`). */
const ACTIVE_STATUSES = Object.freeze(['assigned', 'pickedUp', 'inTransit']);
const ACTIVE_DB_STATUSES = Object.freeze(['assigned', 'picked_up', 'in_transit', 'on_the_way']);
const FINAL_STATUSES = Object.freeze(['delivered', 'cancelled']);

/**
 * Transitions autorisées (noms front).
 * - assigned → waiting : le livreur est retiré, la course repart à assigner.
 * - pickedUp → delivered : autorisé (le livreur peut sauter « en route »).
 */
const TRANSITIONS = Object.freeze({
  waiting: ['assigned', 'cancelled'],
  assigned: ['pickedUp', 'waiting', 'cancelled'],
  pickedUp: ['inTransit', 'delivered', 'cancelled'],
  inTransit: ['delivered', 'cancelled'],
  delivered: [],
  cancelled: [],
});

/** Étapes que le livreur lui-même peut déclencher. */
const COURIER_STEPS = Object.freeze(['pickedUp', 'inTransit', 'delivered', 'waiting']);

/** Statut de commande à appliquer quand la course avance. */
const ORDER_STATUS_FOR = Object.freeze({
  pickedUp: 'delivering',
  inTransit: 'delivering',
  delivered: 'delivered',
});

/** Statuts de commande qu'on ne modifie plus depuis une course. */
const FINAL_ORDER_STATUSES = Object.freeze(['delivered', 'cancelled', 'refunded']);

/** Rémunération par défaut du livreur (même formule que le back office Flutter). */
const BASE_COURIER_FEE = 3.5;
const PER_KM_COURIER_FEE = 0.8;

function round2(value) {
  return Math.round(Number(value) * 100) / 100;
}

function courierFeeFor(distanceKm) {
  return round2(BASE_COURIER_FEE + (Number(distanceKm) || 0) * PER_KM_COURIER_FEE);
}

function toFront(status) {
  return DB_TO_FRONT[status] || 'waiting';
}

function toDb(status) {
  return FRONT_TO_DB[status] || null;
}

module.exports = {
  FRONT_STATUSES,
  STATUS_LABELS,
  ACTIVE_STATUSES,
  ACTIVE_DB_STATUSES,
  FINAL_STATUSES,
  TRANSITIONS,
  COURIER_STEPS,
  ORDER_STATUS_FOR,
  FINAL_ORDER_STATUSES,
  BASE_COURIER_FEE,
  PER_KM_COURIER_FEE,
  courierFeeFor,
  round2,
  toFront,
  toDb,
};
