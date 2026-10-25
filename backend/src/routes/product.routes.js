const express = require('express');
const router = express.Router();

router.get('/',      (req, res) => res.json({ products: [] }));
router.get('/:id',   (req, res) => res.json({ product: { id: req.params.id } }));
router.post('/',     (req, res) => res.status(201).json({ message: 'Product created (stub)' }));
router.put('/:id',   (req, res) => res.json({ message: 'Product updated (stub)' }));
router.delete('/:id',(req, res) => res.json({ message: 'Product deleted (stub)' }));

module.exports = router;
