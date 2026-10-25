const express = require('express');
const router = express.Router();

router.get('/',      (req, res) => res.json({ orders: [] }));
router.get('/:id',   (req, res) => res.json({ order: { id: req.params.id } }));
router.post('/',     (req, res) => res.status(201).json({ message: 'Order created (stub)' }));
router.put('/:id',   (req, res) => res.json({ message: 'Order updated (stub)' }));
router.delete('/:id',(req, res) => res.json({ message: 'Order deleted (stub)' }));

module.exports = router;
