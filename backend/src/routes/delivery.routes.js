const express = require('express');
const router = express.Router();

router.get('/',      (req, res) => res.json({ deliveries: [] }));
router.get('/:id',   (req, res) => res.json({ delivery: { id: req.params.id } }));
router.post('/',     (req, res) => res.status(201).json({ message: 'Delivery created (stub)' }));
router.put('/:id',   (req, res) => res.json({ message: 'Delivery updated (stub)' }));

module.exports = router;
