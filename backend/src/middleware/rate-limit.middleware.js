'use strict';

const rateLimit = require('express-rate-limit');

/** 5 créations de commande par minute par IP. */
const orderCreateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Trop de commandes en peu de temps. Réessayez dans une minute.' },
  skip: () => process.env.NODE_ENV === 'test',
});

/** 30 requêtes par minute pour le panier. */
const cartLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Trop de requêtes sur le panier. Réessayez dans une minute.' },
  skip: () => process.env.NODE_ENV === 'test',
});

/** Rate limiter global : 200 req/min par IP. */
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Trop de requêtes. Réessayez dans une minute.' },
  skip: () => process.env.NODE_ENV === 'test',
});

module.exports = { orderCreateLimiter, cartLimiter, globalLimiter };
