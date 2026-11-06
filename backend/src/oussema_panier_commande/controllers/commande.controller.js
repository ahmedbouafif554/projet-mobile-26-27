'use strict';

const commandeService = require('../services/commande.service');
const panierService = require('../services/panier.service');

async function create(req, res) {
  const userId = req.body.userId || req.auth?.id || 'u-client-1';
  const order = await commandeService.createOrder({
    ...req.body,
    userId,
  });

  // Si la commande provient du panier, on peut vider le panier automatiquement
  if (req.body.clearCart !== false) {
    try {
      await panierService.clearCart(userId);
    } catch (_) {}
  }

  res.status(201).json(order);
}

async function getById(req, res) {
  const order = await commandeService.getOrderById(req.params.id);
  res.json(order);
}

async function list(req, res) {
  const orders = await commandeService.listOrders(req.query);
  res.json(orders);
}

async function update(req, res) {
  const updated = await commandeService.updateOrder(req.params.id, req.body, {
    actorId: req.auth?.id,
    role: req.auth?.role,
    note: req.body?.note,
  });
  res.json(updated);
}

async function updateStatus(req, res) {
  const updated = await commandeService.updateOrderStatus(req.params.id, req.body.status, {
    actorId: req.auth?.id,
    role: req.auth?.role,
    note: req.body.note,
  });
  res.json(updated);
}

async function cancel(req, res) {
  const cancelled = await commandeService.cancelOrder(req.params.id, {
    actorId: req.auth?.id,
    role: req.auth?.role,
    reason: req.body.reason,
  });
  res.json(cancelled);
}

async function remove(req, res) {
  const result = await commandeService.deleteOrder(req.params.id);
  res.status(200).json(result);
}

async function getTimeline(req, res) {
  const timeline = await commandeService.getOrderTimeline(req.params.id);
  res.json(timeline);
}

async function getStats(req, res) {
  const stats = await commandeService.getOrderStats(req.query);
  res.json(stats);
}

const livraisonService = require('../services/livraison.service');

async function refund(req, res) {
  const refunded = await commandeService.updateOrderStatus(req.params.id, 'refunded', {
    actorId: req.auth?.id,
    role: req.auth?.role || 'admin',
    note: req.body?.reason || 'Remboursement de la commande',
  });
  res.json(refunded);
}

async function getTracking(req, res) {
  const tracking = await livraisonService.getDeliveryTracking(req.params.id);
  res.json(tracking);
}

module.exports = {
  create,
  getById,
  list,
  update,
  updateStatus,
  cancel,
  remove,
  refund,
  getTracking,
  getTimeline,
  getStats,
};
