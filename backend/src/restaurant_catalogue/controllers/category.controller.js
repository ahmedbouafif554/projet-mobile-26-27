'use strict';

const categoryService = require('../services/category.service');

async function list(req, res) {
  res.json(await categoryService.list(req.auth));
}

async function getById(req, res) {
  res.json(await categoryService.get(req.auth, req.params.id));
}

async function create(req, res) {
  res.status(201).json(await categoryService.create(req.body || {}));
}

async function update(req, res) {
  res.json(await categoryService.update(req.params.id, req.body || {}));
}

async function reorder(req, res) {
  res.json(await categoryService.reorder(req.body || {}));
}

async function remove(req, res) {
  await categoryService.remove(req.params.id);
  res.status(204).send();
}

module.exports = { list, getById, create, update, reorder, remove };
