'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const {
  authenticate,
  optionalAuth,
  requireAdmin,
} = require('../../middleware/auth.middleware');
const { ensureReady } = require('../catalogue.schema');
const categoryCtrl = require('../controllers/category.controller');

const router = express.Router();

router.use(ensureReady);

// Lecture publique : catégories actives dans l'ordre d'affichage (toutes pour l'admin)
router.get('/', optionalAuth, asyncHandler(categoryCtrl.list));

// Nouvel ordre d'affichage — déclaré avant « /:id » pour ne pas être pris pour un identifiant
router.put('/order', authenticate, requireAdmin, asyncHandler(categoryCtrl.reorder));

router.get('/:id', optionalAuth, asyncHandler(categoryCtrl.getById));

// Gestion des catégories : admin
router.post('/', authenticate, requireAdmin, asyncHandler(categoryCtrl.create));
router.put('/:id', authenticate, requireAdmin, asyncHandler(categoryCtrl.update));
router.delete('/:id', authenticate, requireAdmin, asyncHandler(categoryCtrl.remove));

module.exports = router;
