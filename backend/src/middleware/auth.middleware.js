const jwt = require('jsonwebtoken');
const HttpError = require('../errors/http-error');
const config = require('../config');
const users = require('../services/users.service');
const couriers = require('../services/couriers.service');
const { MESSAGES } = require('../domain/roles');

const SESSION_EXPIRED = 'Session expirée, reconnectez-vous.';

/**
 * Vérifie le JWT renvoyé par `/auth/login` (ou `/auth/google`, `/auth/register`…).
 * - jeton absent, invalide, expiré ou révoqué → 401 (le front se déconnecte) ;
 * - compte bloqué, restaurateur en attente, livreur non validé → 403.
 * Le rôle est relu en base : un changement de rôle est pris en compte tout de suite.
 *
 * Les jetons `mock-token-<id>` ne sont acceptés que pendant les tests.
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    if (!token) return next(new HttpError(401, 'Access token required'));

    let userId = null;
    let tokenVersion = null;
    if (token.startsWith('mock-token-')) {
      if (!config.allowMockTokens) return next(new HttpError(401, SESSION_EXPIRED));
      userId = token.slice('mock-token-'.length);
    } else {
      try {
        const decoded = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
        userId = decoded.sub;
        tokenVersion = Number(decoded.tv) || 0;
      } catch {
        return next(new HttpError(401, SESSION_EXPIRED));
      }
    }

    const user = await users.findById(userId);
    if (!user) return next(new HttpError(401, SESSION_EXPIRED));
    if (tokenVersion != null && tokenVersion !== user.tokenVersion) {
      return next(new HttpError(401, SESSION_EXPIRED));
    }
    if (user.status === 'blocked') return next(new HttpError(403, MESSAGES.blocked));
    if (user.role === 'restaurant' && user.status === 'pending') {
      return next(new HttpError(403, MESSAGES.pendingRestaurant));
    }
    await couriers.assertApproved(user);

    req.auth = { id: user.id, role: user.role, email: user.email };
    req.user = { sub: user.id, role: user.role, email: user.email };
    return next();
  } catch (error) {
    return next(error);
  }
}

function optionalAuth(req, res, next) {
  if (!req.headers.authorization) return next();
  return authenticate(req, res, next);
}

function requireAdmin(req, res, next) {
  if (req.auth?.role !== 'admin') return next(new HttpError(403, MESSAGES.forbidden));
  return next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.auth?.role)) return next(new HttpError(403, MESSAGES.forbidden));
    return next();
  };
}

module.exports = authenticate;
module.exports.authenticate = authenticate;
module.exports.optionalAuth = optionalAuth;
module.exports.requireAdmin = requireAdmin;
module.exports.requireRole = requireRole;
