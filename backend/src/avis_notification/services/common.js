'use strict';

const HttpError = require('../../errors/http-error');
const { query } = require('../../data/db');
const { MESSAGES } = require('../../domain/roles');

/** Horodatage ISO (UTC). */
function nowIso() {
  return new Date().toISOString();
}

/** Date stockée → ISO (les dates SQLite sans fuseau sont en UTC). */
function iso(value) {
  if (value == null || value === '') return null;
  let text = String(value);
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d+)?$/.test(text)) text = `${text.replace(' ', 'T')}Z`;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

/** Date reçue, ou null si absente ; 422 si illisible. */
function parseDateInput(value, message) {
  if (value == null || value === '') return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(422, message);
  return date.toISOString();
}

function json(value, fallback) {
  try {
    const parsed = JSON.parse(value);
    return parsed ?? fallback;
  } catch (_error) {
    return fallback;
  }
}

/** Appelant (posé par `optionalAuth` / `authenticate`). */
function actorOf(req) {
  if (!req.auth) return { anonymous: true, id: null, role: null };
  return { anonymous: false, id: req.auth.id, role: req.auth.role };
}

function isAdmin(actor) {
  return actor.role === 'admin';
}

function forbid(message = MESSAGES.forbidden) {
  throw new HttpError(403, message);
}

function requireUser(actor) {
  if (actor.anonymous) throw new HttpError(401, 'Access token required');
}

function requireAdmin(actor) {
  requireUser(actor);
  if (!isAdmin(actor)) forbid();
}

async function findUser(id) {
  if (!id) return null;
  const rows = await query(
    'SELECT id, first_name, last_name, role, status, avatar_url, restaurant_id FROM users WHERE id = ? LIMIT 1',
    [id],
  );
  return rows[0] || null;
}

/** Le restaurateur gère son restaurant (`owner_id`) ou celui rattaché à son compte. */
async function ownsRestaurant(actor, restaurantId) {
  if (actor.role !== 'restaurant' || !restaurantId) return false;
  const user = await findUser(actor.id);
  if (user?.restaurant_id === restaurantId) return true;
  const rows = await query('SELECT owner_id FROM restaurants WHERE id = ? LIMIT 1', [restaurantId]);
  return rows[0]?.owner_id === actor.id;
}

/** Restaurants gérés par un restaurateur (pour filtrer en SQL). */
async function ownedRestaurantIds(actor) {
  if (actor.role !== 'restaurant') return [];
  const user = await findUser(actor.id);
  const rows = await query('SELECT id FROM restaurants WHERE owner_id = ?', [actor.id]);
  const ids = new Set(rows.map((row) => row.id));
  if (user?.restaurant_id) ids.add(user.restaurant_id);
  return [...ids];
}

module.exports = {
  nowIso,
  iso,
  parseDateInput,
  json,
  actorOf,
  isAdmin,
  forbid,
  requireUser,
  requireAdmin,
  findUser,
  ownsRestaurant,
  ownedRestaurantIds,
};
