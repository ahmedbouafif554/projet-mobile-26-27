'use strict';

const restaurantService = require('../services/restaurant.service');
const productService = require('../services/product.service');

async function list(req, res) {
  res.json(await restaurantService.list(req.auth, req.query));
}

async function getById(req, res) {
  res.json(await restaurantService.get(req.auth, req.params.id));
}

async function listProducts(req, res) {
  res.json(await productService.forRestaurant(req.auth, req.params.id));
}

async function create(req, res) {
  res.status(201).json(await restaurantService.create(req.auth, req.body || {}));
}

async function update(req, res) {
  res.json(await restaurantService.update(req.auth, req.params.id, req.body || {}));
}

async function updateStatus(req, res) {
  res.json(await restaurantService.setStatus(req.params.id, req.body || {}));
}

async function remove(req, res) {
  await restaurantService.remove(req.params.id);
  res.status(204).send();
}

module.exports = { list, getById, listProducts, create, update, updateStatus, remove };
