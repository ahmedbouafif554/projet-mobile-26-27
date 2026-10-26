const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate, requireAdmin } = require('../middleware/auth.middleware');
const HttpError = require('../errors/http-error');
const { MESSAGES } = require('../domain/roles');
const couriers = require('../services/couriers.service');

const router = express.Router();

router.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json(await couriers.list({ userId: req.query.userId, status: req.query.status }));
  }),
);

// Public : l'inscription livreur crée le profil avant l'ouverture de session.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    res.status(201).json(await couriers.create(req.body));
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    res.json(await couriers.get(req.params.id));
  }),
);

router.put(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const current = await couriers.get(req.params.id);
    if (req.auth.role !== 'admin' && req.auth.id !== current.userId) {
      throw new HttpError(403, MESSAGES.forbidden);
    }
    res.json(await couriers.update(req.params.id, req.body));
  }),
);

router.patch(
  '/:id/status',
  authenticate,
  asyncHandler(async (req, res) => {
    const current = await couriers.get(req.params.id);
    if (req.auth.role !== 'admin' && req.auth.id !== current.userId) {
      throw new HttpError(403, MESSAGES.forbidden);
    }
    res.json(await couriers.setStatus(req.params.id, req.body.status));
  }),
);

router.patch(
  '/:id/documents',
  authenticate,
  requireAdmin,
  asyncHandler(async (req, res) => {
    res.json(await couriers.reviewDocuments(req.params.id, req.body.status));
  }),
);

router.delete(
  '/:id',
  authenticate,
  requireAdmin,
  asyncHandler(async (req, res) => {
    await couriers.remove(req.params.id);
    res.status(204).send();
  }),
);

module.exports = router;
