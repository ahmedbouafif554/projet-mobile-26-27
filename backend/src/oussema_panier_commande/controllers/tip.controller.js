'use strict';

const HttpError = require('../../errors/http-error');
const tipService = require('../services/tip.service');

/**
 * POST /orders/:id/tip – Ajoute un pourboire pour une commande.
 */
async function addTip(req, res) {
  const tipperId = req.auth.id;
  const orderId = req.params.id;
  const tip = await tipService.addTip(tipperId, orderId, req.body);
  res.status(201).json(tip);
}

/**
 * GET /orders/:id/tip – Récupère les pourboires d'une commande.
 */
async function getTip(req, res) {
  const tips = await tipService.getTipsForOrder(req.params.id);
  res.json({ tips, count: tips.length });
}

/**
 * GET /orders/couriers/:courierId/tips – Historique des pourboires d'un livreur.
 */
async function getCourierTips(req, res) {
  const { courierId } = req.params;
  // Allow couriers to see their own tips, admins see any
  if (req.auth.role !== 'admin' && req.auth.id !== courierId) {
    throw new HttpError(403, 'Accès refusé.');
  }
  const result = await tipService.getCourierTipHistory(courierId);
  res.json(result);
}

module.exports = { addTip, getTip, getCourierTips };

