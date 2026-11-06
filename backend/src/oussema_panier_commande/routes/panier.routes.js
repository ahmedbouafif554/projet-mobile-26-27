'use strict';

const express = require('express');
const asyncHandler = require('../../middleware/async');
const { optionalAuth } = require('../../middleware/auth.middleware');
const panierCtrl = require('../controllers/panier.controller');

const router = express.Router();

router.use(optionalAuth);

// Totaux & calculs du panier
router.get('/totals', asyncHandler(panierCtrl.getTotals));
router.get('/items/totals', asyncHandler(panierCtrl.getTotals));

// Support complet pour ApiCartRepository de Flutter (/cart/items)
router.get('/items', asyncHandler(panierCtrl.listItems));
router.post('/items', asyncHandler(panierCtrl.addItem));
router.delete('/items', asyncHandler(panierCtrl.clearCart));
router.get('/items/:id', asyncHandler(panierCtrl.getItemById));
router.put('/items/:id', asyncHandler(panierCtrl.updateItem));
router.patch('/items/:id', asyncHandler(panierCtrl.updateItem));
router.delete('/items/:id', asyncHandler(panierCtrl.deleteItem));

// Support pour routes directes (/cart ou /panier)
router.get('/', asyncHandler(panierCtrl.listItems));
router.post('/', asyncHandler(panierCtrl.addItem));
router.delete('/', asyncHandler(panierCtrl.clearCart));
router.get('/:id', asyncHandler(panierCtrl.getItemById));
router.put('/:id', asyncHandler(panierCtrl.updateItem));
router.patch('/:id', asyncHandler(panierCtrl.updateItem));
router.delete('/:id', asyncHandler(panierCtrl.deleteItem));

module.exports = router;

