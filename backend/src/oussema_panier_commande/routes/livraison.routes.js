'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate, requireAdmin } = require('../../middleware/auth.middleware');
const livraisonCtrl = require('../controllers/livraison.controller');
const imedCtrl = require('../../imed_livraison_livreur/controllers/livraison.controller');
const imedCourierCtrl = require('../../imed_livraison_livreur/controllers/livreur.controller');
const { schemaReady } = require('../../imed_livraison_livreur/data/schema');

/**
 * Outils de dispatch du back office (`/api/oussema/livraisons`, et repli de
 * `/api/deliveries`), réservés à l'administrateur.
 *
 * Toute écriture (assignation, statut, position, dispatch automatique) passe
 * par le module livraison & livreur : une seule implémentation des règles
 * (justificatifs, livreur libre, gains, commande synchronisée).
 */
const router = express.Router();

router.use(schemaReady);
router.use(authenticate, requireAdmin);

// Lecture : livreurs proches, liste, détail, suivi.
router.get('/nearby-couriers', asyncHandler(livraisonCtrl.findNearbyCouriers));
router.get('/couriers/:courierId/stats', asyncHandler(livraisonCtrl.getCourierStats));
router.get('/', asyncHandler(livraisonCtrl.list));
router.get('/:id', asyncHandler(livraisonCtrl.getById));
router.get('/:id/tracking', asyncHandler(livraisonCtrl.getTracking));

// Écritures déléguées au module livraison & livreur.
router.post('/couriers/:courierId/location', (req, _res, next) => {
  req.params.id = req.params.courierId;
  next();
}, asyncHandler(imedCourierCtrl.updateLocation));
router.post('/:id/auto-dispatch', asyncHandler(imedCtrl.autoAssign));
router.post('/:id/assign', asyncHandler(imedCtrl.assign));
router.patch('/:id/assign', asyncHandler(imedCtrl.assign));
router.patch('/:id/status', asyncHandler(imedCtrl.updateStatus));
router.put('/:id/status', asyncHandler(imedCtrl.updateStatus));

module.exports = router;
