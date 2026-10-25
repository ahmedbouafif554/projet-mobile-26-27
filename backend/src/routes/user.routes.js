const express = require('express');
const router = express.Router();

// GET /api/users
router.get('/', (req, res) => res.json({ users: [] }));

// GET /api/users/:id
router.get('/:id', (req, res) => res.json({ user: { id: req.params.id } }));

// PUT /api/users/:id
router.put('/:id', (req, res) => res.json({ message: 'User updated (stub)' }));

// DELETE /api/users/:id
router.delete('/:id', (req, res) => res.json({ message: 'User deleted (stub)' }));

module.exports = router;
