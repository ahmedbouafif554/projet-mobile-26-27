'use strict';

const ORDER_STATUSES = [
  'pending',
  'accepted',
  'confirmed',
  'preparing',
  'ready',
  'picked_up',
  'delivering',
  'delivered',
  'cancelled',
  'refunded',
];

const ORDER_STATUS_LABELS = {
  pending: 'En attente',
  accepted: 'Acceptée',
  confirmed: 'Confirmée',
  preparing: 'En préparation',
  ready: 'Prête pour livraison',
  picked_up: 'Récupérée par le livreur',
  delivering: 'En cours de livraison',
  delivered: 'Livrée',
  cancelled: 'Annulée',
  refunded: 'Remboursée',
};

// Machine d'états : transitions autorisées
const ALLOWED_ORDER_TRANSITIONS = {
  pending: ['accepted', 'confirmed', 'cancelled'],
  accepted: ['preparing', 'confirmed', 'cancelled'],
  confirmed: ['preparing', 'accepted', 'cancelled'],
  preparing: ['ready', 'cancelled'],
  ready: ['picked_up', 'delivering', 'cancelled'],
  picked_up: ['delivering', 'delivered', 'cancelled'],
  delivering: ['delivered', 'cancelled'],
  delivered: ['refunded'],
  cancelled: [],
  refunded: [],
};

// Rôles autorisés pour chaque transition
const STATUS_ROLE_PERMISSIONS = {
  accepted: ['restaurant', 'admin'],
  confirmed: ['restaurant', 'admin'],
  preparing: ['restaurant', 'admin'],
  ready: ['restaurant', 'admin'],
  delivering: ['courier', 'admin'],
  delivered: ['courier', 'admin'],
  cancelled: ['client', 'restaurant', 'courier', 'admin'],
  refunded: ['admin'],
};

module.exports = {
  ORDER_STATUSES,
  ORDER_STATUS_LABELS,
  ALLOWED_ORDER_TRANSITIONS,
  STATUS_ROLE_PERMISSIONS,
};
