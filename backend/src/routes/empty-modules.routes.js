'use strict';

const express = require('express');

/**
 * Avis, campagnes, conversations et notifications n'ont pas encore de tables.
 * Répondre une liste vide évite d'afficher les jeux fictifs du front.
 */
function emptyList() {
  const router = express.Router();
  router.get('/', (_req, res) => res.json([]));
  return router;
}

module.exports = {
  reviews: emptyList(),
  campaigns: emptyList(),
  chats: emptyList(),
  messages: emptyList(),
  notifications: emptyList(),
};
