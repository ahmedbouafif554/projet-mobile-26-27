const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate, optionalAuth, requireAdmin } = require('../middleware/auth.middleware');
const users = require('../services/users.service');
const addresses = require('../services/addresses.service');

const router = express.Router();

// Lecture publique : le front cherche l'e-mail et charge le compte
// avant d'avoir un jeton (connexion, OTP, connexion de démo).
router.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json(await users.list({ email: req.query.email, role: req.query.role }));
  }),
);

router.post(
  '/',
  optionalAuth,
  asyncHandler(async (req, res) => {
    res.status(201).json(await users.create(req.body, req.auth));
  }),
);

router.get(
  '/:id/addresses',
  authenticate,
  asyncHandler(async (req, res) => {
    users.assertSelfOrAdmin(req.auth, req.params.id);
    res.json(await addresses.forUser(req.params.id));
  }),
);

router.get(
  '/:id/favorites',
  authenticate,
  asyncHandler(async (req, res) => {
    users.assertSelfOrAdmin(req.auth, req.params.id);
    res.json(await users.favoritesOf(req.params.id));
  }),
);

router.put(
  '/:id/favorites/:restaurantId',
  authenticate,
  asyncHandler(async (req, res) => {
    await users.addFavorite(req.auth, req.params.id, req.params.restaurantId);
    res.status(204).send();
  }),
);

router.delete(
  '/:id/favorites/:restaurantId',
  authenticate,
  asyncHandler(async (req, res) => {
    await users.removeFavorite(req.auth, req.params.id, req.params.restaurantId);
    res.status(204).send();
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    res.json(await users.get(req.params.id));
  }),
);

router.put(
  '/:id',
  optionalAuth,
  asyncHandler(async (req, res) => {
    res.json(await users.update(req.auth, req.params.id, req.body));
  }),
);

router.patch(
  '/:id/status',
  authenticate,
  requireAdmin,
  asyncHandler(async (req, res) => {
    res.json(await users.setStatus(req.auth, req.params.id, req.body.status));
  }),
);

router.patch(
  '/:id/role',
  authenticate,
  requireAdmin,
  asyncHandler(async (req, res) => {
    res.json(await users.setRole(req.auth, req.params.id, req.body.role));
  }),
);

router.delete(
  '/:id',
  authenticate,
  requireAdmin,
  asyncHandler(async (req, res) => {
    await users.remove(req.auth, req.params.id);
    res.status(204).send();
  }),
);

module.exports = router;
