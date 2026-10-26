const express = require('express');
const router = express.Router();

// Tableau JSON : le profil client compte les commandes via GET /orders?userId=
router.get('/', (_req, res) => res.json([]));
router.get('/:id',   (req, res) => res.json({ order: { id: req.params.id } }));
router.post('/',     (req, res) => res.status(201).json({ message: 'Order created (stub)' }));
router.put('/:id',   (req, res) => res.json({ message: 'Order updated (stub)' }));
router.delete('/:id',(req, res) => res.json({ message: 'Order deleted (stub)' }));

module.exports = router;
