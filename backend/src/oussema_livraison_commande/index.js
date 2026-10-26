'use strict';

const express = require('express');
const commandeRoutes = require('./routes/commande.routes');
const livraisonRoutes = require('./routes/livraison.routes');

const commandeService = require('./services/commande.service');
const livraisonService = require('./services/livraison.service');
const geoUtils = require('./services/geo.utils');

const router = express.Router();

router.use('/commandes', commandeRoutes);
router.use('/livraisons', livraisonRoutes);

module.exports = {
  router,
  commandeRoutes,
  livraisonRoutes,
  commandeService,
  livraisonService,
  geoUtils,
};
