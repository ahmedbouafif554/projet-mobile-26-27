'use strict';

const productService = require('../services/product.service');

async function list(req, res) {
  res.json(await productService.list(req.auth, req.query));
}

async function getById(req, res) {
  res.json(await productService.get(req.auth, req.params.id));
}

async function create(req, res) {
  res.status(201).json(await productService.create(req.auth, req.body || {}));
}

async function update(req, res) {
  res.json(await productService.update(req.auth, req.params.id, req.body || {}));
}

async function updateAvailability(req, res) {
  res.json(await productService.setAvailability(req.auth, req.params.id, req.body || {}));
}

async function remove(req, res) {
  await productService.remove(req.auth, req.params.id);
  res.status(204).send();
}

module.exports = { list, getById, create, update, updateAvailability, remove };
