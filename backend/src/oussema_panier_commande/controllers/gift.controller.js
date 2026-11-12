'use strict';

const asyncHandler = require('../../middleware/async');
const HttpError = require('../../errors/http-error');
const giftService = require('../services/gift.service');

/**
 * POST /orders/:id/gift – Ajoute un cadeau à une commande.
 */
async function addGift(req, res) {
  const orderId = req.params.id;
  const gift = await giftService.createGift(orderId, req.body);
  res.status(201).json(gift);
}

/**
 * GET /orders/:id/gift – Récupère le cadeau d'une commande.
 */
async function getGift(req, res) {
  const gift = await giftService.getGift(req.params.id);
  res.json(gift);
}

/**
 * POST /orders/gifts/reveal – Révèle un cadeau via QR token.
 * Corps : { qrToken: "..." }
 */
async function revealGift(req, res) {
  const { qrToken } = req.body;
  if (!qrToken) throw new HttpError(400, 'qrToken requis.');
  const result = await giftService.revealGift(qrToken);
  res.json(result);
}

module.exports = { addGift, getGift, revealGift };

