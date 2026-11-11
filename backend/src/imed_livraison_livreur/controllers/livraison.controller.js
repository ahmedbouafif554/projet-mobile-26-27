'use strict';

const livraisons = require('../services/livraison.service');
const { actorOf } = require('../services/access');

module.exports = {
  async list(req, res) {
    res.json(await livraisons.list(req.query, actorOf(req)));
  },

  async available(req, res) {
    res.json(await livraisons.available(actorOf(req)));
  },

  async stats(req, res) {
    res.json(await livraisons.stats(actorOf(req)));
  },

  async get(req, res) {
    res.json(await livraisons.get(req.params.id, actorOf(req)));
  },

  async history(req, res) {
    res.json(await livraisons.history(req.params.id, actorOf(req)));
  },

  async tracking(req, res) {
    res.json(await livraisons.tracking(req.params.id, actorOf(req)));
  },

  async create(req, res) {
    const { created, delivery } = await livraisons.create(req.body, actorOf(req));
    res.status(created ? 201 : 200).json(delivery);
  },

  async update(req, res) {
    res.json(await livraisons.update(req.params.id, req.body, actorOf(req)));
  },

  async remove(req, res) {
    await livraisons.remove(req.params.id, actorOf(req));
    res.status(204).send();
  },

  async assign(req, res) {
    res.json(await livraisons.assign(req.params.id, req.body?.courierId, actorOf(req)));
  },

  async decline(req, res) {
    res.json(await livraisons.decline(req.params.id, actorOf(req)));
  },

  async autoAssign(req, res) {
    res.json(await livraisons.autoAssign(req.params.id, actorOf(req)));
  },

  async updateStatus(req, res) {
    const b = req.body || {};
    res.json(
      await livraisons.updateStatus(
        req.params.id,
        { status: b.status, otpCode: b.otpCode, note: b.note, reason: b.reason, courierId: b.courierId },
        actorOf(req),
      ),
    );
  },
};
