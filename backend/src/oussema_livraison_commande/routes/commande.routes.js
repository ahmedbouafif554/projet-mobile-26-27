'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { optionalAuth } = require('../../middleware/auth.middleware');
const commandeCtrl = require('../controllers/commande.controller');

const router = express.Router();

router.use(optionalAuth);

// Statistiques globales ou par restaurant
router.get('/stats', asyncHandler(commandeCtrl.getStats));

// Liste des commandes (avec filtres ?userId=, ?restaurantId=, ?status=)
router.get('/', asyncHandler(commandeCtrl.list));

// Création d'une commande
router.post('/', asyncHandler(commandeCtrl.create));

// Détail d'une commande
router.get('/:id', asyncHandler(commandeCtrl.getById));

// Historique / timeline des statuts d'une commande
router.get('/:id/timeline', asyncHandler(commandeCtrl.getTimeline));

// Changement de statut (machine d'états)
router.patch('/:id/status', asyncHandler(commandeCtrl.updateStatus));
router.put('/:id', asyncHandler(commandeCtrl.updateStatus));

// Annulation de commande
router.post('/:id/cancel', asyncHandler(commandeCtrl.cancel));

module.exports = router;
