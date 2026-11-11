'use strict';

const notifications = require('../services/notification.service');
const campagnes = require('../services/campagne.service');
const { actorOf } = require('../services/common');

module.exports = {
  // ── /notifications ──
  async list(req, res) {
    res.json(await notifications.list(req.query, actorOf(req)));
  },
  async get(req, res) {
    res.json(await notifications.get(req.params.id, actorOf(req)));
  },
  async create(req, res) {
    res.status(201).json(await notifications.create(req.body, actorOf(req)));
  },
  async update(req, res) {
    res.json(await notifications.update(req.params.id, req.body, actorOf(req)));
  },
  async remove(req, res) {
    await notifications.remove(req.params.id, actorOf(req));
    res.status(204).send();
  },
  async markRead(req, res) {
    res.json(await notifications.markRead(req.params.id, actorOf(req)));
  },

  // ── /users/:userId/... ──
  async forUser(req, res) {
    res.json(await notifications.forUser(req.params.userId, actorOf(req), req.query));
  },
  async unreadCount(req, res) {
    res.json(await notifications.unreadCount(req.params.userId, actorOf(req)));
  },
  async markAllRead(req, res) {
    res.json(await notifications.markAllRead(req.params.userId, actorOf(req)));
  },
  async clearRead(req, res) {
    res.json(await notifications.clearRead(req.params.userId, actorOf(req)));
  },
  async getSettings(req, res) {
    res.json(await notifications.getSettings(req.params.userId, actorOf(req)));
  },
  async saveSettings(req, res) {
    res.json(await notifications.saveSettings(req.params.userId, req.body, actorOf(req)));
  },

  // ── /campaigns ──
  async listCampaigns(req, res) {
    res.json(await campagnes.list(req.query, actorOf(req)));
  },
  async getCampaign(req, res) {
    res.json(await campagnes.get(req.params.id, actorOf(req)));
  },
  async createCampaign(req, res) {
    res.status(201).json(await campagnes.create(req.body, actorOf(req)));
  },
  async updateCampaign(req, res) {
    res.json(await campagnes.update(req.params.id, req.body, actorOf(req)));
  },
  async removeCampaign(req, res) {
    await campagnes.remove(req.params.id, actorOf(req));
    res.status(204).send();
  },
  async sendCampaign(req, res) {
    res.json(await campagnes.send(req.params.id, actorOf(req)));
  },
};
