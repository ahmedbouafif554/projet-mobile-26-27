'use strict';

const livreurs = require('../services/livreur.service');
const livraisons = require('../services/livraison.service');
const { actorOf, requireAdmin } = require('../services/access');

module.exports = {
  async list(req, res) {
    res.json(await livreurs.listFor(req.query, actorOf(req)));
  },

  async create(req, res) {
    res.status(201).json(await livreurs.create(req.body, actorOf(req)));
  },

  async me(req, res) {
    res.json(await livreurs.me(actorOf(req)));
  },

  async overview(req, res) {
    res.json(await livreurs.overview(actorOf(req)));
  },

  async nearby(req, res) {
    requireAdmin(actorOf(req));
    res.json(
      await livreurs.nearby({
        latitude: req.query.latitude,
        longitude: req.query.longitude,
        radiusKm: req.query.radiusKm,
        limit: req.query.limit,
      }),
    );
  },

  async get(req, res) {
    res.json(await livreurs.get(req.params.id, actorOf(req)));
  },

  async update(req, res) {
    res.json(await livreurs.update(req.params.id, req.body, actorOf(req)));
  },

  async setStatus(req, res) {
    res.json(await livreurs.setStatus(req.params.id, req.body?.status, actorOf(req)));
  },

  async reviewDocuments(req, res) {
    res.json(await livreurs.reviewDocuments(req.params.id, req.body || {}, actorOf(req)));
  },

  async identityScan(req, res) {
    res.json(await livreurs.identityScan(req.params.id, actorOf(req)));
  },

  async remove(req, res) {
    await livreurs.remove(req.params.id, actorOf(req));
    res.status(204).send();
  },

  async stats(req, res) {
    res.json(await livreurs.stats(req.params.id, actorOf(req)));
  },

  async deliveries(req, res) {
    res.json(await livraisons.list({ ...req.query, courierId: req.params.id }, actorOf(req)));
  },

  async updateLocation(req, res) {
    res.json(await livreurs.updateLocation(req.params.id, req.body || {}, actorOf(req)));
  },

  async locationHistory(req, res) {
    res.json(await livreurs.locationHistory(req.params.id, actorOf(req), req.query));
  },
};
