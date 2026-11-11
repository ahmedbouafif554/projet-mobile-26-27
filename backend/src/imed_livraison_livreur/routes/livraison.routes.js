'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate } = require('../../middleware/auth.middleware');
const { schemaReady } = require('../data/schema');
const ctrl = require('../controllers/livraison.controller');

/**
 * `/api/deliveries` — contrat de `ApiDeliveryRepository` + fonctions avancées.
 * Toutes les routes exigent un jeton ; les droits dépendent du rôle
 * (admin : tout ; livreur : ses courses et celles à accepter ; client : les
 * courses de ses commandes ; restaurateur : celles de son restaurant).
 */
const router = express.Router();

router.use(schemaReady);
router.use(authenticate);

router.get('/', asyncHandler(ctrl.list));
router.post('/', asyncHandler(ctrl.create));

// Routes fixes avant `/:id`.
router.get('/available', asyncHandler(ctrl.available));
router.get('/stats', asyncHandler(ctrl.stats));

router.get('/:id', asyncHandler(ctrl.get));
router.put('/:id', asyncHandler(ctrl.update));
router.delete('/:id', asyncHandler(ctrl.remove));

router.get('/:id/history', asyncHandler(ctrl.history));
router.get('/:id/tracking', asyncHandler(ctrl.tracking));

router.patch('/:id/assign', asyncHandler(ctrl.assign));
router.post('/:id/assign', asyncHandler(ctrl.assign));
router.post('/:id/accept', asyncHandler(ctrl.assign));
router.post('/:id/decline', asyncHandler(ctrl.decline));
router.post('/:id/auto-assign', asyncHandler(ctrl.autoAssign));

router.patch('/:id/status', asyncHandler(ctrl.updateStatus));
router.put('/:id/status', asyncHandler(ctrl.updateStatus));

module.exports = router;
