const express = require('express');
const router = express.Router();

// POST /api/auth/register
router.post('/register', (req, res) => {
  // TODO: hash password, save user to DB, return JWT
  res.status(201).json({ message: 'User registered (stub)' });
});

// POST /api/auth/login
router.post('/login', (req, res) => {
  // TODO: validate credentials, return JWT
  res.json({ message: 'Login successful (stub)', token: 'your-jwt-here' });
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  res.json({ message: 'Logged out (stub)' });
});

module.exports = router;
