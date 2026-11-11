'use strict';

const panierService = require('../services/panier.service');

/** Le panier est toujours celui du compte connecté. */
const userOf = (req) => req.auth.id;

async function listItems(req, res) {
  res.json(await panierService.getCart(userOf(req)));
}

async function getItemById(req, res) {
  res.json(await panierService.getItem(userOf(req), req.params.id));
}

async function addItem(req, res) {
  res.status(201).json(await panierService.addItem(userOf(req), req.body || {}));
}

async function updateItem(req, res) {
  res.json(await panierService.updateItem(userOf(req), req.params.id, req.body || {}));
}

async function deleteItem(req, res) {
  res.json(await panierService.deleteItem(userOf(req), req.params.id));
}

async function clearCart(req, res) {
  res.json(await panierService.clearCart(userOf(req)));
}

async function getTotals(req, res) {
  res.json(await panierService.getTotals(userOf(req), req.query.promoCode));
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
