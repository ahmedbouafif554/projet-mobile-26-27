const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate } = require('../middleware/auth.middleware');
const auth = require('../services/auth.service');
const users = require('../services/users.service');

const router = express.Router();

// Inscription client ou livreur. Pas de session : l'OTP l'ouvre ensuite.
router.post(
  '/register',
  asyncHandler(async (req, res) => {
    res.status(201).json(await auth.register(req.body));
  }),
);

router.post(
  '/login',
  asyncHandler(async (req, res) => {
    res.json(await auth.login(req.body));
  }),
);

router.post(
  '/verify-otp',
  asyncHandler(async (req, res) => {
    res.json(await auth.verifyOtp(req.body));
  }),
);

router.post('/logout', (_req, res) => {
  res.json({ message: 'Déconnexion réussie.' });
});

router.post('/forgot-password', (_req, res) => {
  auth.forgotPassword();
  res.json({
    message:
      'Si un compte existe pour cette adresse, vous recevrez un lien de réinitialisation dans quelques minutes.',
  });
});

router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await auth.profile(req.auth.id));
  }),
);

router.put(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await users.update(req.auth, req.auth.id, req.body));
  }),
);

module.exports = router;
