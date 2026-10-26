'use strict';

const DELIVERY_STATUSES = [
  'waiting',
  'assigned',
  'picked_up',
  'on_the_way',
  'in_transit',
  'delivered',
  'failed',
  'cancelled',
];

const DELIVERY_STATUS_LABELS = {
  waiting: 'En recherche de livreur',
  assigned: 'Livreur assigné',
  picked_up: 'Commande récupérée',
  on_the_way: 'En route vers le client',
  in_transit: 'En transit',
  delivered: 'Livrée avec succès',
  failed: 'Échec de livraison',
  cancelled: 'Livraison annulée',
};

const ALLOWED_DELIVERY_TRANSITIONS = {
  waiting: ['assigned', 'cancelled'],
  assigned: ['picked_up', 'waiting', 'cancelled'],
  picked_up: ['on_the_way', 'in_transit', 'delivered', 'failed', 'cancelled'],
  on_the_way: ['delivered', 'failed'],
  in_transit: ['delivered', 'failed'],
  delivered: [],
  failed: ['waiting'], // Réassignation possible
  cancelled: [],
};

const BASE_DELIVERY_FEE = 2.5;
const PER_KM_FEE = 0.8;
const FREE_DELIVERY_THRESHOLD = 35.0; // Livraison offerte dès 35€ de commande
const COURIER_FEE_SHARE = 0.8; // Le livreur perçoit 80% des frais de livraison + 100% des pourboires

module.exports = {
  DELIVERY_STATUSES,
  DELIVERY_STATUS_LABELS,
  ALLOWED_DELIVERY_TRANSITIONS,
  BASE_DELIVERY_FEE,
  PER_KM_FEE,
  FREE_DELIVERY_THRESHOLD,
  COURIER_FEE_SHARE,
};
