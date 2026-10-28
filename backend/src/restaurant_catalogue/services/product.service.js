'use strict';

const HttpError = require('../../errors/http-error');
const { query, newId, toSqlDate } = require('../../data/db');
const { MESSAGES } = require('../domain/catalogue.constants');
const { presentProduct } = require('../domain/catalogue.presenters');
const { requestedId, productInput } = require('../domain/catalogue.validation');
const access = require('./access.service');
const categories = require('./category.service');
const { insertRow, updateRow, findById, isForeignKeyError } = require('./sql.utils');

const FIELDS = [
  'restaurantId',
  'categoryId',
  'name',
  'description',
  'price',
  'imageUrl',
  'section',
  'optionGroups',
  'isAvailable',
  'isPopular',
  'calories',
];

function pick(body) {
  const picked = {};
  for (const field of FIELDS) {
    if (body[field] !== undefined) picked[field] = body[field];
  }
  return picked;
}

function toRow(input) {
  return {
    restaurant_id: input.restaurantId,
    category: input.categoryId || null,
    name: input.name,
    description: input.description,
    price: input.price,
    image_url: input.imageUrl || null,
    section: input.section,
    option_groups: JSON.stringify(input.optionGroups),
    is_available: input.isAvailable ? 1 : 0,
    is_popular: input.isPopular ? 1 : 0,
    calories: input.calories,
  };
}

function findRow(id) {
  return findById('products', id);
}

function findRestaurant(id) {
  return findById('restaurants', id);
}

/**
 * Produit à modifier par `actor` (administrateur ou restaurateur du
 * restaurant). Un produit orphelin n'est accessible qu'à l'administrateur.
 */
async function loadForManage(actor, id) {
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.productNotFound);
  const restaurant = await findRestaurant(row.restaurant_id);
  if (!restaurant && access.isAdmin(actor)) return row;
  await access.assertCanManage(actor, restaurant, MESSAGES.productNotFound);
  return row;
}

function availabilityFilter(value) {
  if (value === 'true') return 1;
  if (value === 'false') return 0;
  throw new HttpError(422, 'available : true ou false attendu.');
}

// ── Lecture ─────────────────────────────────────────────────────────────────

/**
 * Produits visibles par `actor` : ceux des restaurants qu'il peut voir.
 * Filtres : `?restaurantId=`, `?categoryId=`, `?available=true|false`.
 */
async function list(actor, filters = {}) {
  const conditions = [];
  const params = [];
  const visibility = await access.visibilityFilter(actor, 'r');
  if (visibility) {
    conditions.push(visibility.sql);
    params.push(...visibility.params);
  }
  if (filters.restaurantId) {
    conditions.push('p.restaurant_id = ?');
    params.push(String(filters.restaurantId));
  }
  if (filters.categoryId) {
    conditions.push('p.category = ?');
    params.push(String(filters.categoryId));
  }
  if (filters.available !== undefined) {
    conditions.push('p.is_available = ?');
    params.push(availabilityFilter(filters.available));
  }
  const join = visibility ? 'JOIN restaurants r ON r.id = p.restaurant_id' : '';
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const rows = await query(
    `SELECT p.* FROM products p ${join} ${where} ORDER BY p.restaurant_id, p.created_at, p.id`,
    params,
  );
  return rows.map(presentProduct);
}

/** Menu d'un restaurant (`GET /restaurants/:id/products`). */
async function forRestaurant(actor, restaurantId) {
  await access.assertCanView(actor, await findRestaurant(restaurantId));
  const rows = await query(
    'SELECT * FROM products WHERE restaurant_id = ? ORDER BY created_at, id',
    [restaurantId],
  );
  return rows.map(presentProduct);
}

async function get(actor, id) {
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.productNotFound);
  const restaurant = await findRestaurant(row.restaurant_id);
  if (!(restaurant ? await access.canView(actor, restaurant) : access.isAdmin(actor))) {
    throw new HttpError(404, MESSAGES.productNotFound);
  }
  return presentProduct(row);
}

// ── Écriture ────────────────────────────────────────────────────────────────

async function create(actor, body) {
  // Droits d'abord : on ne valide pas le contenu pour quelqu'un qui n'a pas accès.
  const restaurantId = typeof body.restaurantId === 'string' ? body.restaurantId.trim() : '';
  if (!restaurantId) throw new HttpError(422, 'Le restaurant est obligatoire.');
  const restaurant = await findRestaurant(restaurantId);
  if (!restaurant) throw new HttpError(422, MESSAGES.unknownRestaurant);
  await access.assertCanManage(actor, restaurant);

  const input = productInput({ ...body, restaurantId }, newId);
  if (input.categoryId) await categories.assertExist([input.categoryId]);
  const id = requestedId(body.id) || newId('prod');
  if (await findRow(id)) throw new HttpError(409, MESSAGES.duplicateId);

  await insertRow('products', {
    id,
    ...toRow(input),
    created_at: toSqlDate(new Date().toISOString()),
  });
  return presentProduct(await findRow(id));
}

/** Mise à jour (fusion avec l'existant). Déplacer un produit : administrateur. */
async function update(actor, id, body) {
  const row = await loadForManage(actor, id);
  const current = presentProduct(row);
  const input = productInput({ ...current, ...pick(body) }, newId);

  if (input.restaurantId !== current.restaurantId) {
    if (!access.isAdmin(actor)) throw new HttpError(403, MESSAGES.moveProduct);
    if (!(await findRestaurant(input.restaurantId))) {
      throw new HttpError(422, MESSAGES.unknownRestaurant);
    }
  }
  // Une ancienne catégorie inchangée n'est pas revérifiée.
  if (input.categoryId && input.categoryId !== current.categoryId) {
    await categories.assertExist([input.categoryId]);
  }

  await updateRow('products', id, toRow(input));
  return presentProduct(await findRow(id));
}

/** Interrupteur disponible / rupture du back office. */
async function setAvailability(actor, id, body) {
  await loadForManage(actor, id);
  if (typeof body?.isAvailable !== 'boolean') {
    throw new HttpError(422, MESSAGES.availabilityRequired);
  }
  await updateRow('products', id, { is_available: body.isAvailable ? 1 : 0 });
  return presentProduct(await findRow(id));
}

async function remove(actor, id) {
  await loadForManage(actor, id);
  try {
    await query('DELETE FROM products WHERE id = ?', [id]);
  } catch (error) {
    if (isForeignKeyError(error)) throw new HttpError(409, MESSAGES.productInUse);
    throw error;
  }
}

module.exports = { list, forRestaurant, get, create, update, setAvailability, remove };
