const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate } = require('../middleware/auth.middleware');
const addresses = require('../services/addresses.service');

const router = express.Router();

router.post(
  '/',
  authenticate,
  asyncHandler(async (req, res) => {
    res.status(201).json(await addresses.create(req.auth, req.body));
  }),
);

router.put(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await addresses.update(req.auth, req.params.id, req.body));
  }),
);

router.patch(
  '/:id/default',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await addresses.setDefault(req.auth, req.params.id));
  }),
);

router.delete(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    await addresses.remove(req.auth, req.params.id);
    res.status(204).send();
  }),
);

module.exports = router;
