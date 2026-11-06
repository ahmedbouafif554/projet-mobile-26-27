'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { optionalAuth } = require('../../middleware/auth.middleware');
const livraisonCtrl = require('../controllers/livraison.controller');

const router = express.Router();

router.use(optionalAuth);

// Recherche des livreurs les plus proches (Dispatch Haversine)
router.get('/nearby-couriers', asyncHandler(livraisonCtrl.findNearbyCouriers));

// Télémétrie GPS : mise à jour de la position d'un livreur
router.post('/couriers/:courierId/location', asyncHandler(livraisonCtrl.updateLocation));

// Statistiques et gains d'un livreur
router.get('/couriers/:courierId/stats', asyncHandler(livraisonCtrl.getCourierStats));

// Liste des livraisons (avec filtres ?courierId=, ?status=)
router.get('/', asyncHandler(livraisonCtrl.list));

// Détail d'une livraison
router.get('/:id', asyncHandler(livraisonCtrl.getById));

// Données de suivi en direct pour l'écran de tracking (carte + timeline)
router.get('/:id/tracking', asyncHandler(livraisonCtrl.getTracking));

// Assignation automatique du livreur le plus proche
router.post('/:id/auto-dispatch', asyncHandler(livraisonCtrl.autoDispatch));

// Assignation manuelle d'un livreur (POST & PATCH pour compatibilité Flutter ApiDeliveryRepository)
router.post('/:id/assign', asyncHandler(livraisonCtrl.assign));
router.patch('/:id/assign', asyncHandler(livraisonCtrl.assign));

// Mise à jour du statut de la course (pris en charge, en route, livrée)
router.patch('/:id/status', asyncHandler(livraisonCtrl.updateStatus));
router.put('/:id/status', asyncHandler(livraisonCtrl.updateStatus));
router.put('/:id', asyncHandler(livraisonCtrl.updateStatus));

module.exports = router;
