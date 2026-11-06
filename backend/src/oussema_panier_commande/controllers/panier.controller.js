'use strict';

const panierService = require('../services/panier.service');

function getUserId(req) {
  return req.auth?.id || req.query.userId || req.headers['x-user-id'] || req.body?.userId || 'u-client-1';
}

async function listItems(req, res) {
  const userId = getUserId(req);
  const items = await panierService.getCart(userId);
  res.json(items);
}

async function getItemById(req, res) {
  const userId = getUserId(req);
  const item = await panierService.getItem(userId, req.params.id);
  res.json(item);
}

async function addItem(req, res) {
  const userId = getUserId(req);
  const created = await panierService.addItem(userId, req.body);
  res.status(201).json(created);
}

async function updateItem(req, res) {
  const userId = getUserId(req);
  const updated = await panierService.updateItem(userId, req.params.id, req.body);
  res.json(updated);
}

async function deleteItem(req, res) {
  const userId = getUserId(req);
  const result = await panierService.deleteItem(userId, req.params.id);
  res.status(200).json(result);
}

async function clearCart(req, res) {
  const userId = getUserId(req);
  const result = await panierService.clearCart(userId);
  res.status(200).json(result);
}

async function getTotals(req, res) {
  const userId = getUserId(req);
  const totals = await panierService.getTotals(userId, req.query.promoCode);
  res.json(totals);
}

module.exports = {
  listItems,
  getItemById,
  addItem,
  updateItem,
  deleteItem,
  clearCart,
  getTotals,
};

