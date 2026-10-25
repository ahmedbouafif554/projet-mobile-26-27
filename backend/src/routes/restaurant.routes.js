const express = require('express');
const router = express.Router();

router.get('/',      (req, res) => res.json({ restaurants: [] }));
router.get('/:id',   (req, res) => res.json({ restaurant: { id: req.params.id } }));
router.post('/',     (req, res) => res.status(201).json({ message: 'Restaurant created (stub)' }));
router.put('/:id',   (req, res) => res.json({ message: 'Restaurant updated (stub)' }));
router.delete('/:id',(req, res) => res.json({ message: 'Restaurant deleted (stub)' }));

module.exports = router;
