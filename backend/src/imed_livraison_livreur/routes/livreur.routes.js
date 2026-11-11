'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate } = require('../../middleware/auth.middleware');
const { schemaReady } = require('../data/schema');
const ctrl = require('../controllers/livreur.controller');

/** `/api/couriers` — contrat de `ApiCourierRepository` + fonctions avancées. */
const router = express.Router();

router.use(schemaReady);
// Toutes les routes exigent une session : profils, positions et gains sont
// des données personnelles. L'inscription d'un livreur crée son profil via
// POST /api/auth/register.
router.use(authenticate);

router.get('/', asyncHandler(ctrl.list));
router.post('/', asyncHandler(ctrl.create));

// Routes fixes avant `/:id`.
router.get('/me', asyncHandler(ctrl.me));
router.get('/overview', asyncHandler(ctrl.overview));
router.get('/nearby', asyncHandler(ctrl.nearby));

router.get('/:id', asyncHandler(ctrl.get));
router.put('/:id', asyncHandler(ctrl.update));
router.delete('/:id', asyncHandler(ctrl.remove));

router.patch('/:id/status', asyncHandler(ctrl.setStatus));
router.patch('/:id/documents', asyncHandler(ctrl.reviewDocuments));
router.get('/:id/scan', asyncHandler(ctrl.identityScan));

router.get('/:id/stats', asyncHandler(ctrl.stats));
router.get('/:id/earnings', asyncHandler(ctrl.stats));
router.get('/:id/deliveries', asyncHandler(ctrl.deliveries));

router.post('/:id/location', asyncHandler(ctrl.updateLocation));
router.patch('/:id/location', asyncHandler(ctrl.updateLocation));
router.get('/:id/locations', asyncHandler(ctrl.locationHistory));

module.exports = router;
