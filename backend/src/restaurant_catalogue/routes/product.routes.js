'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate, optionalAuth } = require('../../middleware/auth.middleware');
const { ensureReady } = require('../catalogue.schema');
const productCtrl = require('../controllers/product.controller');

const router = express.Router();

router.use(ensureReady);

// Lecture publique : produits des restaurants visibles
router.get('/', optionalAuth, asyncHandler(productCtrl.list));
router.get('/:id', optionalAuth, asyncHandler(productCtrl.getById));

// Gestion du menu : admin ou restaurateur du restaurant
router.post('/', authenticate, asyncHandler(productCtrl.create));
router.put('/:id', authenticate, asyncHandler(productCtrl.update));
router.patch('/:id/availability', authenticate, asyncHandler(productCtrl.updateAvailability));
router.delete('/:id', authenticate, asyncHandler(productCtrl.remove));

module.exports = router;
