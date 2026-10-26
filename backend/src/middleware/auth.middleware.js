const jwt = require('jsonwebtoken');
const HttpError = require('../errors/http-error');
const users = require('../services/users.service');
const couriers = require('../services/couriers.service');
const { MESSAGES } = require('../domain/roles');

/**
 * Accepte le JWT de `POST /auth/login` et le jeton `mock-token-<id>`
 * que le frontend pose aujourd'hui dans `AuthService._open`.
 * Le rôle est relu en base : un changement de rôle est pris en compte tout de suite.
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    if (!token) return next(new HttpError(401, 'Access token required'));

    let userId = null;
    if (token.startsWith('mock-token-')) {
      userId = token.slice('mock-token-'.length);
    } else {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'changeme');
        userId = decoded.sub;
      } catch {
        return next(new HttpError(403, 'Invalid or expired token'));
      }
    }

    const user = await users.findById(userId);
    if (!user) return next(new HttpError(403, 'Invalid or expired token'));
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

module.exports = authenticate;
module.exports.authenticate = authenticate;
module.exports.optionalAuth = optionalAuth;
module.exports.requireAdmin = requireAdmin;
