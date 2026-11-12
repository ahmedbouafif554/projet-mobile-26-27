'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { authenticate } = require('../../middleware/auth.middleware');
const commandeCtrl = require('../controllers/commande.controller');
const { schemaReady: deliverySchemaReady } = require('../../imed_livraison_livreur/data/schema');
const { orderCreateLimiter } = require('../../middleware/rate-limit.middleware');
const stripeCtrl = require('../controllers/stripe.controller');
const giftCtrl = require('../controllers/gift.controller');
const tipCtrl = require('../controllers/tip.controller');

const router = express.Router();

// Cadeau – Révélation publique via QR token (accessible au destinataire sans session préalable)
router.post('/gifts/reveal', asyncHandler(giftCtrl.revealGift));

router.use(authenticate);
// Le cycle de vie d'une commande crée et met à jour sa course de livraison.
router.use(deliverySchemaReady);

// Statistiques globales ou par restaurant
router.get('/stats', asyncHandler(commandeCtrl.getStats));

// Routes statiques AVANT les routes paramétrées /:id

// Pourboires – Historique livreur
router.get('/couriers/:courierId/tips', asyncHandler(tipCtrl.getCourierTips));

// Liste des commandes (avec filtres ?userId=, ?restaurantId=, ?status=)
router.get('/', asyncHandler(commandeCtrl.list));

// Création d'une commande
router.post('/', orderCreateLimiter, asyncHandler(commandeCtrl.create));

// Détail d'une commande
router.get('/:id', asyncHandler(commandeCtrl.getById));

// Mise à jour complète d'une commande (pour ApiCrudRepository.update)
router.put('/:id', asyncHandler(commandeCtrl.update));
router.patch('/:id', asyncHandler(commandeCtrl.update));

// Suppression d'une commande (pour ApiCrudRepository.delete)
router.delete('/:id', asyncHandler(commandeCtrl.remove));

// Suivi / tracking en temps réel d'une commande
router.get('/:id/tracking', asyncHandler(commandeCtrl.getTracking));

// Historique / timeline des statuts d'une commande
router.get('/:id/timeline', asyncHandler(commandeCtrl.getTimeline));

// Changement de statut (machine d'états)
router.patch('/:id/status', asyncHandler(commandeCtrl.updateStatus));
router.put('/:id/status', asyncHandler(commandeCtrl.updateStatus));

// Annulation de commande (POST & PATCH pour compatibilité Flutter ApiOrderRepository)
router.post('/:id/cancel', asyncHandler(commandeCtrl.cancel));
router.patch('/:id/cancel', asyncHandler(commandeCtrl.cancel));

// Remboursement de commande (POST & PATCH pour compatibilité Flutter ApiOrderRepository)
router.post('/:id/refund', asyncHandler(commandeCtrl.refund));
router.patch('/:id/refund', asyncHandler(commandeCtrl.refund));

// Paiement Stripe en ligne (card / Apple Pay)
router.post('/:id/payment-intent', asyncHandler(stripeCtrl.createPaymentIntent));
router.post('/:id/confirm-payment', asyncHandler(stripeCtrl.confirmPayment));

// Cadeau – Gift Orders (sub-routes par orderId)
router.post('/:id/gift', asyncHandler(giftCtrl.addGift));
router.get('/:id/gift', asyncHandler(giftCtrl.getGift));

// Pourboires – Tips pour les livreurs
router.post('/:id/tip', asyncHandler(tipCtrl.addTip));
router.get('/:id/tip', asyncHandler(tipCtrl.getTip));

module.exports = router;