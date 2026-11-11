'use strict';

/**
 * Statuts de commande : exactement ceux de `OrderStatus` (Flutter).
 * Un statut inconnu serait affiché « Nouvelle » par l'application.
 */
const ORDER_STATUSES = Object.freeze([
  'pending',
  'accepted',
  'preparing',
  'ready',
  'delivering',
  'delivered',
  'cancelled',
  'refunded',
]);

/** Anciens noms encore acceptés en entrée. */
const STATUS_ALIASES = Object.freeze({
  confirmed: 'accepted',
  picked_up: 'delivering',
  pickedUp: 'delivering',
});

const ORDER_STATUS_LABELS = Object.freeze({
  pending: 'Nouvelle',
  accepted: 'Acceptée',
  preparing: 'En préparation',
  ready: 'Prête',
  delivering: 'En livraison',
  delivered: 'Livrée',
  cancelled: 'Annulée',
  refunded: 'Remboursée',
});

/** Transitions autorisées (machine d'états). */
const ALLOWED_ORDER_TRANSITIONS = Object.freeze({
  pending: ['accepted', 'cancelled'],
  accepted: ['preparing', 'cancelled'],
  preparing: ['ready', 'cancelled'],
  ready: ['delivering', 'cancelled'],
  delivering: ['delivered', 'cancelled'],
  delivered: ['refunded'],
  cancelled: ['refunded'],
  refunded: [],
});

/**
 * Qui peut déclencher chaque statut (voir `nextOrderStatus` du back office :
 * le restaurateur s'arrête à « Prête »). Le livreur ne change pas la commande
 * directement : sa course (récupérée, livrée) la fait avancer. L'annulation
 * et le remboursement ont leurs propres règles (service).
 */
const STATUS_ROLE_PERMISSIONS = Object.freeze({
  accepted: ['restaurant', 'admin'],
  preparing: ['restaurant', 'admin'],
  ready: ['restaurant', 'admin'],
  delivering: ['admin'],
  delivered: ['admin'],
  cancelled: ['client', 'restaurant', 'admin'],
  refunded: ['admin'],
});

/** Jusqu'où chacun peut annuler. */
const CANCELLABLE_BY = Object.freeze({
  client: ['pending'],
  restaurant: ['pending', 'accepted', 'preparing', 'ready'],
  admin: ['pending', 'accepted', 'preparing', 'ready', 'delivering'],
});

const PAYMENT_METHODS = Object.freeze(['card', 'applePay', 'cash']);
/** Moyens acceptés aujourd'hui : espèces à la livraison uniquement. */
const ACCEPTED_PAYMENT_METHODS = Object.freeze(['cash']);
const PAYMENT_STATUSES = Object.freeze(['pending', 'paid', 'refunded']);
const FINAL_ORDER_STATUSES = Object.freeze(['delivered', 'cancelled', 'refunded']);

function normalizeStatus(status) {
  if (typeof status !== 'string') return null;
  const value = STATUS_ALIASES[status] || status;
  return ORDER_STATUSES.includes(value) ? value : null;
}

module.exports = {
  ORDER_STATUSES,
  ORDER_STATUS_LABELS,
  ALLOWED_ORDER_TRANSITIONS,
  STATUS_ROLE_PERMISSIONS,
  CANCELLABLE_BY,
  PAYMENT_METHODS,
  ACCEPTED_PAYMENT_METHODS,
  PAYMENT_STATUSES,
  FINAL_ORDER_STATUSES,
  normalizeStatus,
};
