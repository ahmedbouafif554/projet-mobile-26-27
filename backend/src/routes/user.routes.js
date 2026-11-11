const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate, requireAdmin } = require('../middleware/auth.middleware');
const users = require('../services/users.service');
const addresses = require('../services/addresses.service');

const router = express.Router();

// Annuaire : réservé aux comptes connectés. Contact (e-mail, téléphone)
// visible seulement pour l'admin et pour soi-même.
router.get(
  '/',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await users.listFor(req.auth, { email: req.query.email, role: req.query.role }));
  }),
);

// Création directe d'un compte : back office (admin). L'inscription publique
// passe par /api/auth/register et /api/auth/register-restaurant.
router.post(
  '/',
  authenticate,
  requireAdmin,
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
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await users.getFor(req.auth, req.params.id));
  }),
);

router.put(
  '/:id',
  authenticate,
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
