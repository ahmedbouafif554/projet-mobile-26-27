'use strict';

const HttpError = require('../../errors/http-error');
const { query } = require('../../data/db');
const { MESSAGES } = require('../../domain/roles');

/**
 * Qui fait la requête. `req.auth` est posé par `authenticate` (toutes les
 * routes du module exigent un jeton). Un appel sans jeton est anonyme et
 * n'a aucun droit.
 */
function actorOf(req) {
  if (!req.auth) return { anonymous: true, id: null, role: null, courierId: null };
  return { anonymous: false, id: req.auth.id, role: req.auth.role, courierId: null };
}

/** Ajoute l'identifiant du profil livreur pour un compte livreur. */
async function withCourier(actor) {
  if (actor.role !== 'courier' || actor.courierId) return actor;
  const rows = await query('SELECT id FROM couriers WHERE user_id = ? LIMIT 1', [actor.id]);
  return { ...actor, courierId: rows[0]?.id || null };
}

function isAdmin(actor) {
  return actor.role === 'admin';
}

/** Seul l'admin voit et gère toutes les courses. */
function isTrusted(actor) {
  return isAdmin(actor);
}

function forbid(message = MESSAGES.forbidden) {
  throw new HttpError(403, message);
}

function requireAdmin(actor) {
  if (!isAdmin(actor)) forbid();
}

module.exports = { actorOf, withCourier, isAdmin, isTrusted, forbid, requireAdmin };
