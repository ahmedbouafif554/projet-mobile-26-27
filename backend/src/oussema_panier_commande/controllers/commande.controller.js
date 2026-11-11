'use strict';

const commandeService = require('../services/commande.service');

async function create(req, res) {
  res.status(201).json(await commandeService.createOrder(req.auth, req.body || {}));
}

async function getById(req, res) {
  res.json(await commandeService.getOrderFor(req.auth, req.params.id));
}

async function list(req, res) {
  res.json(await commandeService.listOrders(req.auth, req.query));
}

async function update(req, res) {
  res.json(await commandeService.updateOrder(req.auth, req.params.id, req.body || {}));
}

async function updateStatus(req, res) {
  const body = req.body || {};
  res.json(await commandeService.updateOrderStatus(req.auth, req.params.id, body.status, { note: body.note }));
}

async function cancel(req, res) {
  res.json(await commandeService.cancelOrder(req.auth, req.params.id, { reason: req.body?.reason }));
}

async function refund(req, res) {
  res.json(await commandeService.refundOrder(req.auth, req.params.id));
}

async function remove(req, res) {
  res.json(await commandeService.deleteOrder(req.auth, req.params.id));
}

async function getTimeline(req, res) {
  res.json(await commandeService.getOrderTimeline(req.auth, req.params.id));
}

async function getStats(req, res) {
  res.json(await commandeService.getOrderStats(req.auth, req.query));
}

/** Suivi : la course liée à la commande (positions, étapes). */
async function getTracking(req, res) {
  await commandeService.readableRow(req.auth, req.params.id);
  const livraisons = require('../../imed_livraison_livreur').livraisonService;
  const [delivery] = await livraisons.list({ orderId: req.params.id }, { anonymous: false, id: req.auth.id, role: 'admin' });
  const order = await commandeService.getOrderById(req.params.id);
  if (!delivery) {
    res.json({ order, delivery: null, steps: order.timeline });
    return;
  }
  const tracking = await livraisons.tracking(delivery.id, { anonymous: false, id: req.auth.id, role: 'admin' });
  // Le code de remise reste réservé au client de la commande.
  if (req.auth.role !== 'admin' && req.auth.id !== order.userId && tracking.delivery) {
    delete tracking.delivery.otpCode;
  }
  res.json({ order, ...tracking });
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
