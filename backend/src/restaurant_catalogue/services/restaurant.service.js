'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toSqlDate } = require('../../data/db');
const users = require('../../services/users.service');
const { MESSAGES: ROLE_MESSAGES } = require('../../domain/roles');
const { APPROVED, MESSAGES } = require('../domain/catalogue.constants');
const { presentRestaurant } = require('../domain/catalogue.presenters');
const {
  requestedId,
  restaurantInput,
  restaurantStatus,
} = require('../domain/catalogue.validation');
const access = require('./access.service');
const categories = require('./category.service');
const {
  placeholders,
  insertRow,
  updateRow,
  findById,
  isForeignKeyError,
} = require('./sql.utils');

/**
 * Champs modifiables par le restaurateur. Le frontend renvoie l'objet complet :
 * les champs réservés à l'administrateur (statut, propriétaire, mise en avant,
 * note…) sont ignorés au lieu d'être refusés.
 */
const OWNER_FIELDS = [
  'name',
  'description',
  'cuisine',
  'categoryIds',
  'imageUrl',
  'address',
  'phone',
  'email',
  'deliveryMinutes',
  'deliveryFee',
  'minOrder',
  'menuSections',
  'isOpen',
  'promo',
  'latitude',
  'longitude',
];
const ADMIN_FIELDS = [
  ...OWNER_FIELDS,
  'ownerId',
  'status',
  'isPopular',
  'rating',
  'reviewCount',
  'distanceKm',
];

function pick(body, fields) {
  const picked = {};
  for (const field of fields) {
    if (body[field] !== undefined) picked[field] = body[field];
  }
  return picked;
}

function findRow(id) {
  return findById('restaurants', id);
}

/** Catégories de chaque restaurant, dans l'ordre d'affichage des catégories. */
async function categoryIdsOf(restaurantIds) {
  const byRestaurant = new Map(restaurantIds.map((id) => [id, []]));
  if (restaurantIds.length === 0) return byRestaurant;
  const rows = await query(
    `SELECT rc.restaurant_id, rc.category_id
       FROM restaurant_categories rc
       LEFT JOIN categories c ON c.id = rc.category_id
      WHERE rc.restaurant_id IN (${placeholders(restaurantIds.length)})
      ORDER BY c.position, rc.category_id`,
    restaurantIds,
  );
  for (const row of rows) byRestaurant.get(row.restaurant_id)?.push(row.category_id);
  return byRestaurant;
}

async function present(rows) {
  const categoryIds = await categoryIdsOf(rows.map((row) => row.id));
  return rows.map((row) => presentRestaurant(row, categoryIds.get(row.id)));
}

async function presentOne(row) {
  const [restaurant] = await present([row]);
  return restaurant;
}

/** Un restaurant non validé est toujours fermé (aucune commande possible). */
function toRow(input, status) {
  return {
    name: input.name,
    description: input.description,
    cuisine: input.cuisine,
    image_url: input.imageUrl || null,
    address: input.address,
    phone: input.phone,
    email: input.email || null,
    delivery_minutes: input.deliveryMinutes,
    delivery_fee: input.deliveryFee,
    min_order: input.minOrder,
    distance_km: input.distanceKm,
    menu_sections: JSON.stringify(input.menuSections),
    is_open: status === APPROVED && input.isOpen ? 1 : 0,
    is_popular: input.isPopular ? 1 : 0,
    promo: input.promo,
    rating: input.rating,
    review_count: input.reviewCount,
    latitude: input.latitude,
    longitude: input.longitude,
    owner_id: input.ownerId,
    status,
  };
}

async function writeCategoryLinks(restaurantId, categoryIds) {
  await query('DELETE FROM restaurant_categories WHERE restaurant_id = ?', [restaurantId]);
  for (const categoryId of categoryIds) {
    await query('INSERT INTO restaurant_categories (restaurant_id, category_id) VALUES (?, ?)', [
      restaurantId,
      categoryId,
    ]);
  }
}

/**
 * Un restaurateur gère un seul restaurant. Une inscription anonyme ne peut
 * viser qu'un compte restaurateur encore en attente de validation.
 */
async function assertOwnerAvailable(ownerId, { restaurantId = null, mustBePending = false } = {}) {
  const owner = await users.findById(ownerId);
  if (!owner || owner.role !== 'restaurant') throw new HttpError(422, MESSAGES.invalidOwner);
  if (mustBePending && owner.status !== 'pending') {
    throw new HttpError(422, MESSAGES.ownerNotPending);
  }
  const owned = await query('SELECT id FROM restaurants WHERE owner_id = ?', [ownerId]);
  const linked =
    owner.restaurantId && owner.restaurantId !== restaurantId
      ? await findRow(owner.restaurantId)
      : null;
  if (linked || owned.some((row) => row.id !== restaurantId)) {
    throw new HttpError(409, MESSAGES.ownerAlreadyLinked);
  }
}

// ── Lecture ─────────────────────────────────────────────────────────────────

/**
 * Restaurants visibles par `actor` (plus récents d'abord).
 * Filtres : `?categoryId=`, `?status=`.
 */
async function list(actor, filters = {}) {
  const conditions = [];
  const params = [];
  const visibility = await access.visibilityFilter(actor, 'r');
  if (visibility) {
    conditions.push(visibility.sql);
    params.push(...visibility.params);
  }
  if (filters.status) {
    conditions.push('r.status = ?');
    params.push(restaurantStatus(filters.status));
  }
  if (filters.categoryId) {
    conditions.push('r.id IN (SELECT restaurant_id FROM restaurant_categories WHERE category_id = ?)');
    params.push(String(filters.categoryId));
  }
  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
  const rows = await query(
    `SELECT r.* FROM restaurants r ${where} ORDER BY r.created_at DESC, r.id`,
    params,
  );
  return present(rows);
}

async function get(actor, id) {
  const row = await findRow(id);
  await access.assertCanView(actor, row);
  return presentOne(row);
}

// ── Écriture ────────────────────────────────────────────────────────────────

/**
 * - administrateur : restaurant complet, validé par défaut ;
 * - restaurateur connecté : demande pour son propre compte ;
 * - anonyme (inscription Espace Pro) : demande liée au compte `ownerId`
 *   créé juste avant, toujours « en attente ».
 */
async function create(actor, body) {
  if (actor && !['admin', 'restaurant'].includes(actor.role)) {
    throw new HttpError(403, ROLE_MESSAGES.forbidden);
  }
  const admin = access.isAdmin(actor);
  const input = restaurantInput(
    admin ? body : { ...pick(body, OWNER_FIELDS), ownerId: actor ? actor.id : body.ownerId },
  );
  if (!admin && !input.ownerId) throw new HttpError(422, MESSAGES.ownerRequired);

  const id = requestedId(body.id) || newId('rest');
  if (await findRow(id)) throw new HttpError(409, MESSAGES.duplicateId);
  if (input.ownerId) await assertOwnerAvailable(input.ownerId, { mustBePending: !actor });
  await categories.assertExist(input.categoryIds);

  const status = admin ? input.status || APPROVED : 'pending';
  await withTransaction(async () => {
    await insertRow('restaurants', {
      id,
      ...toRow(input, status),
      created_at: toSqlDate(new Date().toISOString()),
    });
    await writeCategoryLinks(id, input.categoryIds);
  });
  return presentOne(await findRow(id));
}

/** Mise à jour (fusion avec l'existant) par l'administrateur ou le restaurateur. */
async function update(actor, id, body) {
  const row = await findRow(id);
  await access.assertCanManage(actor, row);
  const admin = access.isAdmin(actor);
  const current = await presentOne(row);
  const input = restaurantInput({ ...current, ...pick(body, admin ? ADMIN_FIELDS : OWNER_FIELDS) });

  if (input.ownerId && input.ownerId !== current.ownerId) {
    await assertOwnerAvailable(input.ownerId, { restaurantId: id });
  }
  // Seules les catégories ajoutées sont vérifiées.
  await categories.assertExist(input.categoryIds.filter((c) => !current.categoryIds.includes(c)));

  const status = input.status || current.status;
  await withTransaction(async () => {
    await updateRow('restaurants', id, toRow(input, status));
    await writeCategoryLinks(id, input.categoryIds);
  });
  return presentOne(await findRow(id));
}

/**
 * Validation, refus, suspension ou réactivation (administrateur).
 * Valider ouvre le restaurant ; tout autre statut le ferme.
 */
async function setStatus(id, body) {
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.restaurantNotFound);
  const status = restaurantStatus(body?.status);
  if (status !== row.status) {
    await updateRow('restaurants', id, { status, is_open: status === APPROVED ? 1 : 0 });
  }
  return presentOne(await findRow(id));
}

/** Supprime le restaurant, son menu et ses catégories (administrateur). */
async function remove(id) {
  if (!(await findRow(id))) throw new HttpError(404, MESSAGES.restaurantNotFound);
  try {
    await withTransaction(async () => {
      await query('DELETE FROM restaurant_categories WHERE restaurant_id = ?', [id]);
      await query('DELETE FROM products WHERE restaurant_id = ?', [id]);
      await query('DELETE FROM restaurants WHERE id = ?', [id]);
    });
  } catch (error) {
    if (isForeignKeyError(error)) throw new HttpError(409, MESSAGES.restaurantInUse);
    throw error;
  }
}

module.exports = { list, get, create, update, setStatus, remove };
