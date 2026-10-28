'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const {
  authenticate,
  optionalAuth,
  requireAdmin,
} = require('../../middleware/auth.middleware');
const { ensureReady } = require('../catalogue.schema');
const restaurantCtrl = require('../controllers/restaurant.controller');

const router = express.Router();

router.use(ensureReady);

// Lecture publique : restaurants validés (+ le sien pour un restaurateur, tous pour l'admin)
router.get('/', optionalAuth, asyncHandler(restaurantCtrl.list));
router.get('/:id', optionalAuth, asyncHandler(restaurantCtrl.getById));
router.get('/:id/products', optionalAuth, asyncHandler(restaurantCtrl.listProducts));

// Création : admin, restaurateur, ou inscription anonyme depuis l'Espace Pro
router.post('/', optionalAuth, asyncHandler(restaurantCtrl.create));

// Modification : admin ou restaurateur du restaurant
router.put('/:id', authenticate, asyncHandler(restaurantCtrl.update));

// Validation / refus / suspension et suppression : admin
router.patch('/:id/status', authenticate, requireAdmin, asyncHandler(restaurantCtrl.updateStatus));
router.delete('/:id', authenticate, requireAdmin, asyncHandler(restaurantCtrl.remove));

module.exports = router;
