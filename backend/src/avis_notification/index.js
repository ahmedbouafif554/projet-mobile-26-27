'use strict';

const routes = require('./routes');
const { ensureSchema, clear } = require('./data/schema');
const avisService = require('./services/avis.service');
const notificationService = require('./services/notification.service');
const campagneService = require('./services/campagne.service');

module.exports = {
  ...routes,
  avisService,
  notificationService,
  campagneService,
  /** Crée les tables du module (aussi fait à la première requête). */
  init: ensureSchema,
  /** Vide les tables du module (tests). */
  clear,
};
