'use strict';

const express = require('express');
const panierRoutes = require('./routes/panier.routes');
const commandeRoutes = require('./routes/commande.routes');
const livraisonRoutes = require('./routes/livraison.routes');

const panierService = require('./services/panier.service');
const commandeService = require('./services/commande.service');
const livraisonService = require('./services/livraison.service');
const geoUtils = require('./services/geo.utils');
const notificationLivreurService = require('./services/notification-livreur.service');

const router = express.Router();

router.use('/panier', panierRoutes);
router.use('/cart', panierRoutes);
router.use('/commandes', commandeRoutes);
router.use('/orders', commandeRoutes);
router.use('/livraisons', livraisonRoutes);
router.use('/deliveries', livraisonRoutes);

module.exports = {
  router,
  panierRoutes,
  cartRoutes: panierRoutes,
  commandeRoutes,
  orderRoutes: commandeRoutes,
  livraisonRoutes,
  deliveryRoutes: livraisonRoutes,
  panierService,
  cartService: panierService,
  commandeService,
  orderService: commandeService,
  livraisonService,
  geoUtils,
  notificationLivreurService,
};
