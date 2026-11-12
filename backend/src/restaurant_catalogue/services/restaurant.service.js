'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toSqlDate } = require('../../data/db');
const users = require('../../services/users.service');
const { MESSAGES: ROLE_MESSAGES } = require('../../domain/roles');
const settings = require('../catalogue.config');
const { APPROVED, MESSAGES } = require('../domain/catalogue.constants');
const { presentRestaurant } = require('../domain/catalogue.presenters');
const {
  requestedId,
  restaurantInput,
  restaurantStatus,
  nearbyInput,
  hasManualCoordinates,
} = require('../domain/catalogue.validation');
const access = require('./access.service');
const categories = require('./category.service');
const geocoding = require('./geocoding.service');
const { ExternalServiceError } = require('./http.client');
const { distanceKm, roundKm, estimatedMinutes } = require('./geo.utils');
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
  'menuImageUrl',
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
    menu_image_url: input.menuImageUrl || null,
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

// ── Localisation (OpenStreetMap) ────────────────────────────────────────────

/**
 * Colonnes de localisation d'une adresse. Un échec du service n'empêche
 * jamais d'enregistrer : le restaurant est marqué `error` et sera relocalisé
 * plus tard (`npm run geocode:catalogue`). Appelé hors transaction.
 */
async function locate(address, { force = false } = {}) {
  if (!settings.geocodingEnabled) return { geo_status: 'pending', geocoded_at: null };
  try {
    const result = await geocoding.geocode(address, { force });
    const geocodedAt = toSqlDate(new Date());
    return result.found
      ? { latitude: result.latitude, longitude: result.longitude, geo_status: 'ok', geocoded_at: geocodedAt }
      : { geo_status: 'not_found', geocoded_at: geocodedAt };
  } catch (error) {
    if (error instanceof ExternalServiceError) return { geo_status: 'error', geocoded_at: null };
    throw error;
  }
}

function manualLocation(input) {
  return {
    latitude: input.latitude,
    longitude: input.longitude,
    geo_status: 'manual',
    geocoded_at: toSqlDate(new Date()),
  };
}

/**
 * Localisation après une modification : coordonnées déplacées à la main →
 * `manual` ; adresse changée, ou jamais localisée / en erreur → nouveau
 * géocodage ; sinon inchangée (`{}`).
 */
async function relocation(current, input, changes) {
  const moved = ['latitude', 'longitude'].some(
    (key) => changes[key] != null && Math.abs(input[key] - current[key]) > 1e-7,
  );
  if (moved) return manualLocation(input);
  const addressChanged =
    geocoding.addressKey(input.address) !== geocoding.addressKey(current.address);
  const notLocatedYet = ['pending', 'error'].includes(current.locationStatus);
  if (addressChanged || (notLocatedYet && settings.geocodingEnabled)) return locate(input.address);
  return {};
}

/** Distance (km) et délai estimé depuis la position du client. */
function withDistance(restaurant, km) {
  return {
    ...restaurant,
    distanceKm: roundKm(km),
    estimatedMinutes: estimatedMinutes(restaurant.deliveryMinutes, km),
  };
}

/**
 * Du plus proche au plus loin. Les restaurants sans coordonnées fiables
 * suivent, sauf si un rayon est demandé (distance inconnue → exclus).
 */
function sortByDistance(restaurants, origin) {
  const located = [];
  const others = [];
  for (const restaurant of restaurants) {
    if (!restaurant.hasLocation) {
      others.push(restaurant);
      continue;
    }
    const km = distanceKm(origin, restaurant);
    if (origin.radiusKm == null || km <= origin.radiusKm) located.push({ km, restaurant });
  }
  located.sort((a, b) => a.km - b.km);
  const sorted = located.map(({ km, restaurant }) => withDistance(restaurant, km));
  return origin.radiusKm == null ? [...sorted, ...others] : sorted;
}

// ── Lecture ─────────────────────────────────────────────────────────────────

/**
 * Restaurants visibles par `actor` (plus récents d'abord).
 * Filtres : `?categoryId=`, `?status=`.
 * Avec `?latitude=&longitude=` (et `&radiusKm=`) : distance et délai estimés,
 * du plus proche au plus loin.
 */
async function list(actor, filters = {}) {
  const origin = nearbyInput(filters);
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
  const restaurants = await present(rows);
  return origin ? sortByDistance(restaurants, origin) : restaurants;
}

/** Fiche d'un restaurant ; avec `?latitude=&longitude=`, sa distance du client. */
async function get(actor, id, params = {}) {
  const origin = nearbyInput(params);
  const row = await findRow(id);
  await access.assertCanView(actor, row);
  const restaurant = await presentOne(row);
  return origin && restaurant.hasLocation
    ? withDistance(restaurant, distanceKm(origin, restaurant))
    : restaurant;
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
  const fields = admin ? body : pick(body, OWNER_FIELDS);
  const input = restaurantInput(
    admin ? fields : { ...fields, ownerId: actor ? actor.id : body.ownerId },
  );
  const manual = hasManualCoordinates(fields);
  if (!admin && !input.ownerId) throw new HttpError(422, MESSAGES.ownerRequired);

  const id = requestedId(body.id) || newId('rest');
  if (await findRow(id)) throw new HttpError(409, MESSAGES.duplicateId);
  if (input.ownerId) await assertOwnerAvailable(input.ownerId, { mustBePending: !actor });
  await categories.assertExist(input.categoryIds);

  // Avant la transaction : l'appel à OpenStreetMap ne bloque pas la base.
  const location = manual ? manualLocation(input) : await locate(input.address);
  const status = admin ? input.status || APPROVED : 'pending';
  await withTransaction(async () => {
    await insertRow('restaurants', {
      id,
      ...toRow(input, status),
      ...location,
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
  const changes = pick(body, admin ? ADMIN_FIELDS : OWNER_FIELDS);
  // Coordonnées absentes (null) : on garde celles connues, jamais les valeurs par défaut.
  for (const key of ['latitude', 'longitude']) {
    if (changes[key] == null) delete changes[key];
  }
  const input = restaurantInput({ ...current, ...changes });

  if (input.ownerId && input.ownerId !== current.ownerId) {
    await assertOwnerAvailable(input.ownerId, { restaurantId: id });
  }
  // Seules les catégories ajoutées sont vérifiées.
  await categories.assertExist(input.categoryIds.filter((c) => !current.categoryIds.includes(c)));

  const location = await relocation(current, input, changes);
  const status = input.status || current.status;
  await withTransaction(async () => {
    await updateRow('restaurants', id, { ...toRow(input, status), ...location });
    await writeCategoryLinks(id, input.categoryIds);
  });
  return presentOne(await findRow(id));
}

/** Relocalise l'adresse tout de suite, sans le cache (administrateur ou restaurateur). */
async function relocate(actor, id) {
  const row = await findRow(id);
  await access.assertCanManage(actor, row);
  if (!settings.geocodingEnabled) throw new HttpError(503, MESSAGES.geocodingDisabled);
  const location = await locate(row.address, { force: true });
  if (location.geo_status === 'error') throw new HttpError(502, MESSAGES.geocodingUnavailable);
  await updateRow('restaurants', id, location);
  return presentOne(await findRow(id));
}

/**
 * Localise les restaurants jamais localisés ou en erreur
 * (`npm run geocode:catalogue`). Renvoie le nombre de restaurants par résultat.
 */
async function locatePending() {
  if (!settings.geocodingEnabled) throw new HttpError(503, MESSAGES.geocodingDisabled);
  const rows = await query(
    "SELECT id, address FROM restaurants WHERE geo_status IN ('pending', 'error') ORDER BY created_at, id",
  );
  const counts = { ok: 0, not_found: 0, error: 0 };
  for (const row of rows) {
    const location = await locate(row.address);
    await updateRow('restaurants', row.id, location);
    counts[location.geo_status] += 1;
  }
  return counts;
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

module.exports = { list, get, create, update, setStatus, remove, relocate, locatePending };
