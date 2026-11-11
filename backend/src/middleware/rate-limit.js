'use strict';

const HttpError = require('../errors/http-error');

/**
 * Limiteur en mémoire (fenêtre fixe), par adresse IP et, si fourni, par
 * e-mail : freine les essais de mots de passe et l'envoi massif d'e-mails.
 * Suffisant pour une instance ; derrière plusieurs instances, utiliser un
 * stockage partagé (Redis).
 */
function rateLimit({ windowMs, max, message, keyBy = () => '' }) {
  const hits = new Map();

  const sweep = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of hits) {
      if (entry.resetAt <= now) hits.delete(key);
    }
  }, Math.min(windowMs, 60_000));
  sweep.unref();

  function middleware(req, res, next) {
    if (process.env.NODE_ENV === 'test' && !middleware.enabledInTests) return next();
    const extra = String(keyBy(req) || '').toLowerCase().trim();
    const key = `${req.ip}|${extra}`;
    const now = Date.now();
    let entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(key, entry);
    }
    entry.count += 1;
    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return next(new HttpError(429, message));
    }
    return next();
  }

  middleware.reset = () => hits.clear();
  middleware.enabledInTests = false;
  return middleware;
}

const byEmail = (req) => req.body?.email;

const loginLimiter = rateLimit({
  windowMs: 15 * 60_000,
  max: 10,
  message: 'Trop de tentatives de connexion. Réessayez dans quelques minutes.',
  keyBy: byEmail,
});

const resetLimiter = rateLimit({
  windowMs: 60 * 60_000,
  max: 5,
  message: 'Trop de demandes de réinitialisation. Réessayez plus tard.',
  keyBy: byEmail,
});

const signupLimiter = rateLimit({
  windowMs: 60 * 60_000,
  max: 20,
  message: "Trop d'inscriptions depuis cette adresse. Réessayez plus tard.",
});

module.exports = { rateLimit, loginLimiter, resetLimiter, signupLimiter };
