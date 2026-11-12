'use strict';

/**
 * Commandes (`ApiOrderRepository`, `/api/orders`).
 *
 * - Création : client (depuis son panier) ou restaurateur / admin (commande
 *   par téléphone). Produits, options, frais et réduction sont recalculés à
 *   partir de la base ; les montants envoyés par l'application sont ignorés.
 * - Lecture : le client voit ses commandes, le restaurateur celles de son
 *   restaurant, le livreur celles qu'il livre, l'admin toutes.
 * - Statut : machine d'états + droits par rôle. La course de livraison suit
 *   (créée à l'acceptation, annulée avec la commande, terminée à la livraison).
 */

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toIso } = require('../../data/db');
const { MESSAGES: ROLE_MESSAGES } = require('../../domain/roles');
const {
  ORDER_STATUS_LABELS,
  ALLOWED_ORDER_TRANSITIONS,
  STATUS_ROLE_PERMISSIONS,
  CANCELLABLE_BY,
  ACCEPTED_PAYMENT_METHODS,
  FINAL_ORDER_STATUSES,
  normalizeStatus,
} = require('../domain/commande.constants');
const pricing = require('./pricing');
const { parseCoordinates } = require('./geo.utils');
const { notifyCouriersOfNewDelivery } = require('./notification-livreur.service');

/** Frais de service d'une commande saisie au téléphone (`order_form.dart`). */
const PHONE_ORDER_SERVICE_FEE = 0.99;
/** Identifiant client des commandes par téléphone (pas de compte). */
const GUEST_USER_ID = 'guest';

const MESSAGES = Object.freeze({
  notFound: (id) => `Commande introuvable (${id}).`,
  forbidden: ROLE_MESSAGES.forbidden,
  restaurantRequired: 'Le restaurant est obligatoire.',
  restaurantNotFound: 'Restaurant introuvable.',
  restaurantUnavailable: "Ce restaurant n'accepte pas de commandes pour le moment.",
  restaurantClosed: (name) => `${name} est fermé pour le moment.`,
  emptyCart: 'Votre panier est vide.',
  addressRequired: "L'adresse de livraison est obligatoire.",
  addressIncomplete: "L'adresse de livraison est incomplète (rue et ville).",
  addressNotYours: "Cette adresse n'appartient pas à votre compte.",
  productNotFound: "Un article de votre panier n'existe plus.",
  productOtherRestaurant: 'Tous les articles doivent venir du même restaurant.',
  productUnavailable: (name) => `« ${name} » n'est plus disponible.`,
  minOrder: (amount) => `Le minimum de commande est de ${amount.toFixed(2).replace('.', ',')} €.`,
  badPayment: 'Seul le paiement en espèces à la livraison est disponible.',
  badPromo: 'Code promo invalide.',
  badStatus: (status) => `Statut de commande invalide : ${status}`,
  transition: (from, to) =>
    `Transition impossible de « ${ORDER_STATUS_LABELS[from] || from} » vers « ${ORDER_STATUS_LABELS[to] || to} ».`,
  roleNotAllowed: (status) => `Vous ne pouvez pas passer la commande en « ${ORDER_STATUS_LABELS[status] || status} ».`,
  clientCancel: 'La commande est déjà en préparation : contactez le restaurant.',
  cannotCancel: 'Cette commande ne peut plus être annulée.',
  refundState: 'Seule une commande livrée ou annulée peut être remboursée.',
  nothingToRefund: 'Aucun paiement à rembourser pour cette commande.',
  noteTooLong: 'La note est trop longue (500 caractères maximum).',
});

// ── Présentation (`Order.fromJson`) ─────────────────────────────────────────

function parseJson(value, fallback) {
  if (value == null || value === '') return fallback;
  if (typeof value !== 'string') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function presentAddress(row) {
  const stored = parseJson(row.delivery_address, null);
  const base = stored && typeof stored === 'object' ? stored : { street: String(row.delivery_address || '') };
  return {
    id: base.id || `addr_${row.id}`,
    userId: base.userId || row.user_id || GUEST_USER_ID,
    label: base.label || 'Adresse de livraison',
    street: base.street || '',
    postalCode: base.postalCode || '',
    city: base.city || '',
    type: base.type || 'other',
    instructions: base.instructions ?? null,
    isDefault: Boolean(base.isDefault),
    latitude: row.delivery_lat != null ? Number(row.delivery_lat) : base.latitude ?? null,
    longitude: row.delivery_lng != null ? Number(row.delivery_lng) : base.longitude ?? null,
  };
}

function presentItem(item, order) {
  const product = parseJson(item.product_data, null) || {
    id: item.product_id,
    restaurantId: order.restaurant_id,
    categoryId: '',
    name: item.name,
    description: '',
    price: Number(item.price),
    imageUrl: '',
    section: '',
    optionGroups: [],
    isAvailable: true,
    isPopular: false,
    calories: null,
  };
  const options = parseJson(item.options, []);
  const quantity = Number(item.quantity) || 1;
  // `price` est le prix unitaire figé (produit + suppléments).
  const unit = Number(item.price);
  return {
    id: String(item.id),
    product,
    productId: item.product_id,
    name: item.name,
    price: unit,
    quantity,
    options: Array.isArray(options) ? options : [],
    note: item.note || null,
    total: pricing.round2(unit * quantity),
  };
}

function presentOrder(row, items = [], events = []) {
  const address = presentAddress(row);
  return {
    id: row.id,
    reference: row.reference || `SF${row.id.slice(-4).toUpperCase()}`,
    userId: row.user_id || GUEST_USER_ID,
    customerName: row.customer_name || row.u_name || 'Client',
    customerPhone: row.customer_phone || row.u_phone || '',
    restaurantId: row.restaurant_id,
    restaurantName: row.r_name || 'Restaurant',
    restaurantAddress: row.r_address || '',
    courierId: row.courier_id || null,
    courierName: row.c_name || null,
    status: normalizeStatus(row.status) || 'pending',
    statusLabel: ORDER_STATUS_LABELS[normalizeStatus(row.status)] || row.status,
    subtotal: pricing.round2(items.reduce((sum, i) => sum + Number(i.price) * (Number(i.quantity) || 1), 0)),
    totalAmount: Number(row.total_amount) || 0,
    total: Number(row.total_amount) || 0,
    deliveryFee: Number(row.delivery_fee) || 0,
    serviceFee: Number(row.service_fee) || 0,
    discount: Number(row.discount) || 0,
    paymentMethod: row.payment_method || 'card',
    paymentStatus: row.payment_status || 'pending',
    deliveryAddress: address,
    deliveryAddressText: [address.street, [address.postalCode, address.city].filter(Boolean).join(' ')]
      .filter(Boolean)
      .join(', '),
    deliveryLat: address.latitude,
    deliveryLng: address.longitude,
    note: row.notes || null,
    notes: row.notes || null,
    promoCode: row.promo_code || null,
    cancelReason: row.cancel_reason || null,
    estimatedMinutes: Number(row.estimated_time) || 30,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    items: items.map((item) => presentItem(item, row)),
    history: events.map((e) => ({ status: normalizeStatus(e.status) || e.status, at: toIso(e.created_at), note: e.note || null })),
    timeline: events.map((e) => ({
      id: e.id,
      status: normalizeStatus(e.status) || e.status,
      statusLabel: ORDER_STATUS_LABELS[normalizeStatus(e.status)] || e.status,
      note: e.note || null,
      actorId: e.actor_id || null,
      at: toIso(e.created_at),
    })),
  };
}

const ORDER_SELECT = `
  SELECT o.*,
         u.first_name || ' ' || u.last_name AS u_name,
         u.phone AS u_phone,
         r.name AS r_name,
         r.address AS r_address,
         r.owner_id AS r_owner_id,
         c.first_name || ' ' || c.last_name AS c_name
    FROM orders o
    LEFT JOIN users u ON u.id = o.user_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN couriers c ON c.id = o.courier_id`;

async function findRow(orderId) {
  const rows = await query(`${ORDER_SELECT} WHERE o.id = ? LIMIT 1`, [orderId]);
  if (!rows[0]) throw new HttpError(404, MESSAGES.notFound(orderId));
  return rows[0];
}

async function getOrderById(orderId) {
  const row = await findRow(orderId);
  const items = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [orderId]);
  const events = await query('SELECT * FROM order_events WHERE order_id = ? ORDER BY id ASC', [orderId]);
  return presentOrder(row, items, events);
}

// ── Droits ──────────────────────────────────────────────────────────────────

/** Restaurants gérés par un restaurateur (lien du compte ou propriétaire). */
async function restaurantIdsOf(userId) {
  const rows = await query(
    `SELECT id FROM restaurants WHERE owner_id = ?
     UNION SELECT restaurant_id AS id FROM users WHERE id = ? AND restaurant_id IS NOT NULL`,
    [userId, userId],
  );
  return rows.map((r) => r.id).filter(Boolean);
}

async function courierIdOf(userId) {
  const rows = await query('SELECT id FROM couriers WHERE user_id = ? LIMIT 1', [userId]);
  return rows[0]?.id || null;
}

/** Lien de l'appelant avec la commande : admin, client, restaurant, livreur ou rien. */
async function relationTo(actor, row) {
  if (!actor) return null;
  if (actor.role === 'admin') return 'admin';
  if (actor.role === 'client') return row.user_id === actor.id ? 'client' : null;
  if (actor.role === 'restaurant') {
    return (await restaurantIdsOf(actor.id)).includes(row.restaurant_id) ? 'restaurant' : null;
  }
  if (actor.role === 'courier') {
    const courierId = await courierIdOf(actor.id);
    return courierId && row.courier_id === courierId ? 'courier' : null;
  }
  return null;
}

async function readableRow(actor, orderId) {
  const row = await findRow(orderId);
  const relation = await relationTo(actor, row);
  if (!relation) throw new HttpError(403, MESSAGES.forbidden);
  return { row, relation };
}

// ── Lecture ─────────────────────────────────────────────────────────────────

async function getOrderFor(actor, orderId) {
  await readableRow(actor, orderId);
  return getOrderById(orderId);
}

/**
 * Liste filtrée (`?userId=`, `?restaurantId=`, `?courierId=`, `?status=`),
 * toujours limitée à ce que l'appelant a le droit de voir.
 */
async function listOrders(actor, filters = {}) {
  const where = [];
  const params = [];

  if (actor.role === 'client') {
    where.push('o.user_id = ?');
    params.push(actor.id);
  } else if (actor.role === 'restaurant') {
    const ids = await restaurantIdsOf(actor.id);
    if (ids.length === 0) return [];
    where.push(`o.restaurant_id IN (${ids.map(() => '?').join(',')})`);
    params.push(...ids);
  } else if (actor.role === 'courier') {
    where.push('o.courier_id = ?');
    params.push((await courierIdOf(actor.id)) || '__none__');
  } else if (actor.role !== 'admin') {
    throw new HttpError(403, MESSAGES.forbidden);
  }

  for (const [key, column] of [['userId', 'o.user_id'], ['restaurantId', 'o.restaurant_id'], ['courierId', 'o.courier_id']]) {
    if (typeof filters[key] === 'string' && filters[key].trim()) {
      where.push(`${column} = ?`);
      params.push(filters[key].trim());
    }
  }
  if (typeof filters.status === 'string' && filters.status.trim()) {
    const statuses = filters.status.split(',').map((s) => normalizeStatus(s.trim())).filter(Boolean);
    if (statuses.length === 0) throw new HttpError(422, MESSAGES.badStatus(filters.status));
    where.push(`o.status IN (${statuses.map(() => '?').join(',')})`);
    params.push(...statuses);
  }

  // Pagination — only applied when ?page or ?limit are explicitly provided
  const wantsPagination = filters.page !== undefined || filters.limit !== undefined;
  const page = Math.max(1, parseInt(filters.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(filters.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const baseSql = `${ORDER_SELECT}${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY o.created_at DESC, o.id DESC`;

  let total = null;
  let rows;
  if (wantsPagination) {
    const countSql = `SELECT COUNT(*) as total FROM orders o${where.length ? ` WHERE ${where.join(' AND ')}` : ''}`;
    const [{ total: countTotal }] = await query(countSql, params);
    total = Number(countTotal);
    const paginatedSql = baseSql + ` LIMIT ${limit} OFFSET ${offset}`;
    rows = await query(paginatedSql, params);
  } else {
    rows = await query(baseSql, params);
  }

  if (rows.length === 0) {
    if (!wantsPagination) return [];
    return { data: [], pagination: { page, limit, total: total || 0, totalPages: 0, hasNext: false, hasPrev: false } };
  }

  const ids = rows.map((o) => o.id);
  const marks = ids.map(() => '?').join(',');
  const items = await query(`SELECT * FROM order_items WHERE order_id IN (${marks}) ORDER BY id`, ids);
  const events = await query(`SELECT * FROM order_events WHERE order_id IN (${marks}) ORDER BY id ASC`, ids);
  const group = (list) => {
    const map = new Map();
    for (const entry of list) {
      if (!map.has(entry.order_id)) map.set(entry.order_id, []);
      map.get(entry.order_id).push(entry);
    }
    return map;
  };
  const itemsBy = group(items);
  const eventsBy = group(events);

  const data = rows.map((o) => presentOrder(o, itemsBy.get(o.id) || [], eventsBy.get(o.id) || []));

  if (!wantsPagination) {
    return data;
  }

  const totalPages = Math.ceil(total / limit);
  return {
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
  };
}

async function getOrderTimeline(actor, orderId) {
  return (await getOrderFor(actor, orderId)).timeline;
}

async function getOrderStats(actor, { restaurantId = null } = {}) {
  let scope = null;
  if (actor.role === 'restaurant') {
    const ids = await restaurantIdsOf(actor.id);
    scope = restaurantId ? ids.filter((id) => id === restaurantId) : ids;
    if (scope.length === 0) throw new HttpError(403, MESSAGES.forbidden);
  } else if (actor.role === 'admin') {
    scope = restaurantId ? [restaurantId] : null;
  } else {
    throw new HttpError(403, MESSAGES.forbidden);
  }
  const where = scope ? ` WHERE restaurant_id IN (${scope.map(() => '?').join(',')})` : '';
  const rows = await query(
    `SELECT status, COUNT(*) AS count, SUM(total_amount) AS revenue FROM orders${where} GROUP BY status`,
    scope || [],
  );
  const byStatus = Object.fromEntries(Object.keys(ORDER_STATUS_LABELS).map((s) => [s, 0]));
  let totalOrders = 0;
  let totalRevenue = 0;
  for (const r of rows) {
    const status = normalizeStatus(r.status) || r.status;
    byStatus[status] = (byStatus[status] || 0) + Number(r.count);
    totalOrders += Number(r.count);
    // Le chiffre d'affaires ne compte que les commandes non annulées ni remboursées.
    if (!['cancelled', 'refunded'].includes(status)) totalRevenue += Number(r.revenue) || 0;
  }
  const billable = totalOrders - byStatus.cancelled - byStatus.refunded;
  return {
    totalOrders,
    totalRevenue: pricing.round2(totalRevenue),
    averageBasket: billable > 0 ? pricing.round2(totalRevenue / billable) : 0,
    byStatus,
  };
}

// ── Création ────────────────────────────────────────────────────────────────

function cleanNote(value) {
  if (value == null) return null;
  const note = String(value).trim();
  if (note.length > 500) throw new HttpError(422, MESSAGES.noteTooLong);
  return note || null;
}

function cleanText(value, max = 200) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

async function nextReference() {
  const rows = await query("SELECT COUNT(*) AS n FROM orders");
  let n = 1001 + Number(rows[0].n);
  // Unicité garantie même après suppression de commandes.
  for (;;) {
    const reference = `SF${n}`;
    const taken = await query('SELECT 1 FROM orders WHERE reference = ? LIMIT 1', [reference]);
    if (!taken[0]) return reference;
    n += 1;
  }
}

/** Adresse de livraison : copie figée dans la commande. */
async function deliveryAddressOf(raw, { ownerId, staff }) {
  if (!raw || typeof raw !== 'object') throw new HttpError(422, MESSAGES.addressRequired);
  const street = cleanText(raw.street, 200);
  const city = cleanText(raw.city, 100);
  if (!street || !city) throw new HttpError(422, MESSAGES.addressIncomplete);
  const id = cleanText(raw.id, 80);
  if (id && !staff) {
    const rows = await query('SELECT user_id FROM addresses WHERE id = ? LIMIT 1', [id]);
    if (rows[0] && rows[0].user_id !== ownerId) throw new HttpError(403, MESSAGES.addressNotYours);
  }
  const coords = parseCoordinates(raw.latitude, raw.longitude);
  return {
    id: id || `addr_${Date.now().toString(36)}`,
    userId: ownerId,
    label: cleanText(raw.label, 60) || 'Livraison',
    street,
    postalCode: cleanText(raw.postalCode, 12),
    city,
    type: ['home', 'work', 'other'].includes(raw.type) ? raw.type : 'other',
    instructions: cleanText(raw.instructions, 300) || null,
    isDefault: Boolean(raw.isDefault),
    latitude: coords ? coords.latitude : null,
    longitude: coords ? coords.longitude : null,
  };
}

/**
 * `POST /orders` (JSON de `Order.toJson()`).
 * Client : commande pour lui-même. Restaurateur (son restaurant) ou admin :
 * commande par téléphone (`userId: 'guest'`, nom et téléphone saisis).
 */
async function createOrder(actor, data = {}) {
  const staff = actor.role === 'restaurant' || actor.role === 'admin';
  if (actor.role !== 'client' && !staff) throw new HttpError(403, MESSAGES.forbidden);

  const restaurantId = cleanText(data.restaurantId, 80);
  if (!restaurantId) throw new HttpError(422, MESSAGES.restaurantRequired);
  const restaurant = await pricing.loadRestaurant(restaurantId);
  if (!restaurant) throw new HttpError(404, MESSAGES.restaurantNotFound);
  if (actor.role === 'restaurant' && !(await restaurantIdsOf(actor.id)).includes(restaurantId)) {
    throw new HttpError(403, MESSAGES.forbidden);
  }
  if (restaurant.status !== 'approved') throw new HttpError(409, MESSAGES.restaurantUnavailable);
  if (Number(restaurant.is_open) !== 1) throw new HttpError(409, MESSAGES.restaurantClosed(restaurant.name));

  // Client de la commande.
  let userId = actor.id;
  let customerName = null;
  let customerPhone = null;
  if (staff) {
    const requested = cleanText(data.userId, 80);
    const account = requested && requested !== GUEST_USER_ID
      ? (await query("SELECT id FROM users WHERE id = ? AND role = 'client' LIMIT 1", [requested]))[0]
      : null;
    userId = account ? account.id : GUEST_USER_ID;
    if (!account) {
      customerName = cleanText(data.customerName, 120) || 'Client';
      customerPhone = cleanText(data.customerPhone, 40) || null;
    }
  }

  // Articles : relus en base, prix figés au moment de la commande.
  const requestedItems = Array.isArray(data.items) ? data.items : [];
  if (requestedItems.length === 0) throw new HttpError(422, MESSAGES.emptyCart);
  const products = await pricing.loadProducts(requestedItems.map(pricing.productIdOf));
  const lines = requestedItems.map((item) => {
    const product = products.get(pricing.productIdOf(item));
    if (!product) throw new HttpError(422, MESSAGES.productNotFound);
    if (product.restaurantId !== restaurantId) throw new HttpError(422, MESSAGES.productOtherRestaurant);
    if (!product.isAvailable) throw new HttpError(409, MESSAGES.productUnavailable(product.name));
    const options = pricing.resolveOptions(product, item.options);
    const quantity = pricing.quantityOf(item.quantity ?? 1);
    const unit = pricing.unitPrice(product, options);
    return { product, options, quantity, unit, note: pricing.noteOf(item.note) };
  });
  const subtotal = pricing.round2(lines.reduce((sum, l) => sum + l.unit * l.quantity, 0));

  const minOrder = Number(restaurant.min_order) || 0;
  if (!staff && subtotal < minOrder) throw new HttpError(422, MESSAGES.minOrder(minOrder));

  const base = pricing.totalsFor(subtotal, restaurant);
  const promoCode = staff ? null : cleanText(data.promoCode, 40).toUpperCase() || null;
  const discount = pricing.promoDiscount(promoCode, subtotal, base.deliveryFee);
  if (discount == null) throw new HttpError(422, MESSAGES.badPromo);
  const totals = pricing.totalsFor(subtotal, restaurant, discount);
  const serviceFee = staff ? PHONE_ORDER_SERVICE_FEE : totals.serviceFee;
  const totalAmount = Math.max(0, pricing.round2(subtotal + totals.deliveryFee + serviceFee - discount));

  // Paiement en espèces à la livraison : la commande est « payée » quand le
  // livreur la remet au client (voir la synchronisation de la course).
  const paymentMethod = data.paymentMethod || 'cash';
  if (!ACCEPTED_PAYMENT_METHODS.includes(paymentMethod)) throw new HttpError(422, MESSAGES.badPayment);
  const paymentStatus = 'pending';

  const address = await deliveryAddressOf(data.deliveryAddress, { ownerId: userId, staff });
  const note = cleanNote(data.note ?? data.notes);
  const orderId = newId('ord');

  await withTransaction(async () => {
    const reference = await nextReference();
    await query(
      `INSERT INTO orders
         (id, reference, user_id, restaurant_id, courier_id, status, total_amount, delivery_fee,
          service_fee, discount, payment_method, payment_status, promo_code, delivery_address,
          delivery_lat, delivery_lng, notes, estimated_time, customer_name, customer_phone,
          created_at, updated_at)
       VALUES (?, ?, ?, ?, NULL, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderId, reference, userId, restaurantId, totalAmount, totals.deliveryFee, serviceFee,
        pricing.round2(discount), paymentMethod, paymentStatus, discount > 0 ? promoCode : null,
        JSON.stringify(address), address.latitude, address.longitude, note,
        Number(restaurant.delivery_minutes) || 30, customerName, customerPhone,
        new Date().toISOString(), new Date().toISOString(),
      ],
    );
    for (const line of lines) {
      await query(
        `INSERT INTO order_items (order_id, product_id, name, price, quantity, options, note, product_data)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId, line.product.id, line.product.name, line.unit, line.quantity,
          JSON.stringify(line.options), line.note, JSON.stringify(line.product),
        ],
      );
    }
    await query(
      'INSERT INTO order_events (order_id, status, note, actor_id, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        orderId, 'pending',
        staff ? 'Commande saisie par téléphone.' : 'Commande passée par le client.',
        actor.id, new Date().toISOString(),
      ],
    );
    // La commande reprend le panier : il est vidé.
    if (!staff && data.clearCart !== false) {
      await query('DELETE FROM cart_items WHERE user_id = ?', [actor.id]);
    }
  });

  return getOrderById(orderId);
}

// ── Cycle de vie ────────────────────────────────────────────────────────────

function livraisons() {
  // Chargé à la demande : le module livraison dépend aussi des commandes.
  return require('../../imed_livraison_livreur').livraisonService;
}

async function addEvent(orderId, status, note, actorId) {
  await query(
    'INSERT INTO order_events (order_id, status, note, actor_id, created_at) VALUES (?, ?, ?, ?, ?)',
    [orderId, status, note, actorId || null, new Date().toISOString()],
  );
}

/** Après l'acceptation : prévient les livreurs proches de la nouvelle course. */
async function announceDelivery(orderId, delivery) {
  if (!delivery?.created) return;
  const row = await findRow(orderId);
  const restaurant = await pricing.loadRestaurant(row.restaurant_id);
  const address = presentAddress(row);
  await notifyCouriersOfNewDelivery({
    order: { id: row.id, reference: row.reference },
    restaurant: restaurant || {},
    deliveryAddress: address,
    pickup: { latitude: Number(restaurant?.latitude) || 0, longitude: Number(restaurant?.longitude) || 0 },
    dropoff: { latitude: Number(address.latitude) || 0, longitude: Number(address.longitude) || 0 },
    distanceKm: delivery.distanceKm,
    fee: delivery.fee,
  });
}

/**
 * Nouveau statut (`PATCH /orders/:id/status`). Le même statut est sans
 * effet : l'application le renvoie parfois après la course de livraison.
 */
async function updateOrderStatus(actor, orderId, rawStatus, { note } = {}) {
  const next = normalizeStatus(rawStatus);
  if (!next) throw new HttpError(422, MESSAGES.badStatus(rawStatus));
  if (next === 'cancelled') return cancelOrder(actor, orderId, { reason: note });
  if (next === 'refunded') return refundOrder(actor, orderId);

  const { row, relation } = await readableRow(actor, orderId);
  const current = normalizeStatus(row.status) || 'pending';
  if (current === next) return getOrderById(orderId);
  if (!(ALLOWED_ORDER_TRANSITIONS[current] || []).includes(next)) {
    throw new HttpError(409, MESSAGES.transition(current, next));
  }
  if (!(STATUS_ROLE_PERMISSIONS[next] || []).includes(relation)) {
    throw new HttpError(403, MESSAGES.roleNotAllowed(next));
  }

  let delivery = null;
  await withTransaction(async () => {
    const sets = ['status = ?', 'updated_at = ?'];
    const params = [next, new Date().toISOString()];
    // Espèces : encaissées à la remise de la commande.
    if (next === 'delivered' && row.payment_method === 'cash' && row.payment_status === 'pending') {
      sets.push("payment_status = 'paid'");
    }
    await query(`UPDATE orders SET ${sets.join(', ')} WHERE id = ?`, [...params, orderId]);
    await addEvent(orderId, next, cleanNote(note) || `Passage au statut « ${ORDER_STATUS_LABELS[next]} ».`, actor.id);

    if (next === 'accepted') delivery = await livraisons().ensureForOrder(orderId, actor.id);
    if (next === 'delivered') await livraisons().finishForOrder(orderId, actor.id);
  });
  await announceDelivery(orderId, delivery);
  return getOrderById(orderId);
}

/**
 * Annulation : le client tant que la commande est « Nouvelle », le
 * restaurateur jusqu'à « Prête », l'admin jusqu'à la livraison.
 * La course est annulée et le livreur libéré.
 */
async function cancelOrder(actor, orderId, { reason } = {}) {
  const { row, relation } = await readableRow(actor, orderId);
  const current = normalizeStatus(row.status) || 'pending';
  if (current === 'cancelled') return getOrderById(orderId);
  const allowed = CANCELLABLE_BY[relation];
  if (!allowed) throw new HttpError(403, MESSAGES.forbidden);
  if (!allowed.includes(current)) {
    throw new HttpError(409, relation === 'client' ? MESSAGES.clientCancel : MESSAGES.cannotCancel);
  }
  const why = cleanNote(reason) || (relation === 'client' ? 'Annulée par le client' : 'Annulation demandée');

  await withTransaction(async () => {
    await query('UPDATE orders SET status = ?, cancel_reason = ?, updated_at = ? WHERE id = ?', [
      'cancelled', why, new Date().toISOString(), orderId,
    ]);
    await addEvent(orderId, 'cancelled', `Commande annulée : ${why}`, actor.id);
    await livraisons().cancelForOrder(orderId, why, actor.id);
  });
  return getOrderById(orderId);
}

/** Remboursement (admin) d'une commande payée, livrée ou annulée. */
async function refundOrder(actor, orderId) {
  if (actor.role !== 'admin') throw new HttpError(403, MESSAGES.forbidden);
  const row = await findRow(orderId);
  const current = normalizeStatus(row.status);
  if (current === 'refunded') return getOrderById(orderId);
  if (!['delivered', 'cancelled'].includes(current)) throw new HttpError(409, MESSAGES.refundState);
  if (row.payment_status !== 'paid') throw new HttpError(409, MESSAGES.nothingToRefund);

  await withTransaction(async () => {
    await query(
      "UPDATE orders SET status = 'refunded', payment_status = 'refunded', updated_at = ? WHERE id = ?",
      [new Date().toISOString(), orderId],
    );
    await addEvent(orderId, 'refunded', `Remboursement de ${Number(row.total_amount).toFixed(2)} €.`, actor.id);
  });
  return getOrderById(orderId);
}

/**
 * `PUT /orders/:id` (JSON complet de `Order`) : note et statut. Les montants,
 * articles et client d'une commande passée ne se modifient pas.
 */
async function updateOrder(actor, orderId, data = {}) {
  const { relation } = await readableRow(actor, orderId);
  if (!['admin', 'restaurant'].includes(relation)) throw new HttpError(403, MESSAGES.forbidden);
  if (data.status) {
    const row = await findRow(orderId);
    if (normalizeStatus(data.status) !== normalizeStatus(row.status)) {
      await updateOrderStatus(actor, orderId, data.status, { note: data.statusNote });
    }
  }
  if (data.note !== undefined || data.notes !== undefined) {
    await query('UPDATE orders SET notes = ?, updated_at = ? WHERE id = ?', [
      cleanNote(data.note ?? data.notes), new Date().toISOString(), orderId,
    ]);
  }
  return getOrderById(orderId);
}

/** Suppression définitive (admin) : commande, articles, historique et course. */
async function deleteOrder(actor, orderId) {
  if (actor.role !== 'admin') throw new HttpError(403, MESSAGES.forbidden);
  const row = await findRow(orderId);
  await withTransaction(async () => {
    if (!FINAL_ORDER_STATUSES.includes(normalizeStatus(row.status))) {
      await livraisons().cancelForOrder(orderId, 'Commande supprimée', actor.id);
    }
    await query('DELETE FROM order_events WHERE order_id = ?', [orderId]);
    await query('DELETE FROM order_items WHERE order_id = ?', [orderId]);
    await query(
      'DELETE FROM delivery_events WHERE delivery_id IN (SELECT id FROM deliveries WHERE order_id = ?)',
      [orderId],
    );
    await query('DELETE FROM deliveries WHERE order_id = ?', [orderId]);
    await query('DELETE FROM orders WHERE id = ?', [orderId]);
  });
  return { success: true, id: orderId };
}

module.exports = {
  MESSAGES,
  GUEST_USER_ID,
  PHONE_ORDER_SERVICE_FEE,
  createOrder,
  getOrderById,
  getOrderFor,
  readableRow,
  listOrders,
  updateOrder,
  updateOrderStatus,
  cancelOrder,
  refundOrder,
  deleteOrder,
  getOrderTimeline,
  getOrderStats,
};
