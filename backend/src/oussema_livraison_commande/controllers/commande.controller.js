'use strict';

const commandeService = require('../services/commande.service');

async function create(req, res) {
  const order = await commandeService.createOrder({
    ...req.body,
    userId: req.body.userId || req.auth?.id || 'u-client-1',
  });
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

async function getTimeline(req, res) {
  const timeline = await commandeService.getOrderTimeline(req.params.id);
  res.json(timeline);
}

async function getStats(req, res) {
  const stats = await commandeService.getOrderStats(req.query);
  res.json(stats);
}

module.exports = {
  create,
  getById,
  list,
  updateStatus,
  cancel,
  getTimeline,
  getStats,
};
