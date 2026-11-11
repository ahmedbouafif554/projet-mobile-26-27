'use strict';

const avis = require('../services/avis.service');
const { actorOf } = require('../services/common');

module.exports = {
  async list(req, res) {
    res.json(await avis.list(req.query, actorOf(req)));
  },
  async forRestaurant(req, res) {
    res.json(await avis.forRestaurant(req.params.restaurantId, req.query, actorOf(req)));
  },
  async restaurantStats(req, res) {
    res.json(await avis.stats(req.params.restaurantId, actorOf(req)));
  },
  async stats(req, res) {
    res.json(await avis.stats(req.query.restaurantId || null, actorOf(req)));
  },
  async get(req, res) {
    res.json(await avis.get(req.params.id, actorOf(req)));
  },
  async create(req, res) {
    res.status(201).json(await avis.create(req.body, actorOf(req)));
  },
  async update(req, res) {
    res.json(await avis.update(req.params.id, req.body, actorOf(req)));
  },
  async remove(req, res) {
    await avis.remove(req.params.id, actorOf(req));
    res.status(204).send();
  },
  async moderate(req, res) {
    res.json(await avis.moderate(req.params.id, req.body?.status, actorOf(req)));
  },
  async reply(req, res) {
    res.json(await avis.reply(req.params.id, req.body, actorOf(req)));
  },
  async deleteReply(req, res) {
    res.json(await avis.deleteReply(req.params.id, actorOf(req)));
  },
  async markHelpful(req, res) {
    res.json(await avis.markHelpful(req.params.id, actorOf(req)));
  },
  async unmarkHelpful(req, res) {
    res.json(await avis.unmarkHelpful(req.params.id, actorOf(req)));
  },
  async report(req, res) {
    res.json(await avis.report(req.params.id, req.body, actorOf(req)));
  },
  async reports(req, res) {
    res.json(await avis.reports(req.params.id, actorOf(req)));
  },
};
