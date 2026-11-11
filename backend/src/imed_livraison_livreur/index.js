'use strict';

const express = require('express');
const courierRoutes = require('./routes/livreur.routes');
const deliveryRoutes = require('./routes/livraison.routes');
const livreurService = require('./services/livreur.service');
const livraisonService = require('./services/livraison.service');
const { ensureSchema } = require('./data/schema');

/** Alias en français : `/api/imed/livreurs` et `/api/imed/livraisons`. */
const router = express.Router();
router.use('/livreurs', courierRoutes);
router.use('/couriers', courierRoutes);
router.use('/livraisons', deliveryRoutes);
router.use('/deliveries', deliveryRoutes);

module.exports = {
  router,
  courierRoutes,
  deliveryRoutes,
  livreurService,
  livraisonService,
  /** Colonnes et tables du module (aussi fait à la première requête). */
  init: ensureSchema,
};
