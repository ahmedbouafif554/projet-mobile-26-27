'use strict';

const crypto = require('crypto');
const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId } = require('../../data/db');
const { text } = require('../../domain/validate');
const repo = require('../data/delivery.repository');
const couriers = require('../data/courier.repository');
const { nowIso, sameLocalDay } = require('../data/time');
const {
  FRONT_STATUSES,
  STATUS_LABELS,
  ACTIVE_STATUSES,
  FINAL_STATUSES,
  TRANSITIONS,
  COURIER_STEPS,
  ORDER_STATUS_FOR,
  FINAL_ORDER_STATUSES,
  courierFeeFor,
  round2,
  toFront,
  toDb,
} = require('../domain/livraison.constants');
const { documentStatusOf } = require('../domain/livreur.constants');
const { isAdmin, isTrusted, forbid, requireAdmin, withCourier } = require('./access');
const { isCoordinate, distanceKm, etaMinutes } = require('./geo.utils');
const eta = require('./eta');
const { normalizeStatus: normalizeOrderStatus } = require('../../oussema_panier_commande/domain/commande.constants');
const livreurs = require('./livreur.service');

// ── Lecture & droits ────────────────────────────────────────────────────────

/**
 * Commandes que le livreur ne peut pas encore récupérer : le restaurant ne les
 * a pas acceptées. Une fois acceptée, la remise au livreur vaut « prête »
 * (comme sur les plateformes de livraison : le restaurant ne pense pas
 * toujours à appuyer sur « Prête »).
 */
const NOT_READY_ORDER_STATUSES = Object.freeze(['pending']);

/**
 * Dernière position GPS du livreur si elle est récente (sinon null) : une
 * vieille position (données de démo, livreur resté hors ligne) n'est jamais
 * montrée au client ni utilisée pour les estimations.
 */
async function freshCourierPosition(courierId) {
  if (!courierId) return null;
  const rows = await query(
    'SELECT latitude, longitude, created_at FROM courier_locations WHERE courier_id = ? ORDER BY created_at DESC LIMIT 1',
    [courierId],
  );
  const row = rows[0];
  if (!row || !eta.isFresh(row.created_at) || !isCoordinate(row.latitude, row.longitude)) return null;
  return { latitude: Number(row.latitude), longitude: Number(row.longitude), at: row.created_at };
}

/** Le code de remise est donné au client : jamais au livreur. */
function canSeeOtp(actor, row) {
  if (isAdmin(actor)) return true;
  return actor.role === 'client' && row.o_user_id === actor.id;
}

function canSeeContact(actor, row) {
  if (isAdmin(actor)) return true;
  return actor.role === 'courier' && Boolean(actor.courierId) && row.courier_id === actor.courierId;
}

function present(row, actor) {
  return repo.mapDelivery(row, { showOtp: canSeeOtp(actor, row), showContact: canSeeContact(actor, row) });
}

async function restaurantIdOf(userId) {
  const rows = await query('SELECT restaurant_id FROM users WHERE id = ? LIMIT 1', [userId]);
  return rows[0]?.restaurant_id || null;
}

/** Restriction SQL selon le rôle de l'appelant. */
async function scopeFor(actor) {
  if (isTrusted(actor)) return { where: [], params: [] };
  if (actor.role === 'courier') {
    return {
      where: ["(d.courier_id = ? OR (d.status = 'waiting' AND d.courier_id IS NULL))"],
      params: [actor.courierId || '__none__'],
    };
  }
  if (actor.role === 'client') return { where: ['o.user_id = ?'], params: [actor.id] };
  if (actor.role === 'restaurant') {
    return {
      where: ['(r.owner_id = ? OR o.restaurant_id = ?)'],
      params: [actor.id, (await restaurantIdOf(actor.id)) || '__none__'],
    };
  }
  return { where: ['1 = 0'], params: [] };
}

async function canRead(actor, row) {
  if (isTrusted(actor)) return true;
  if (actor.role === 'courier') {
    return row.courier_id === actor.courierId || (row.status === 'waiting' && !row.courier_id);
  }
  if (actor.role === 'client') return row.o_user_id === actor.id;
  if (actor.role === 'restaurant') {
    return row.r_owner_id === actor.id || row.o_restaurant_id === (await restaurantIdOf(actor.id));
  }
  return false;
}

async function readable(id, rawActor) {
  const actor = await withCourier(rawActor);
  const row = await repo.mustFindRow(id);
  if (!(await canRead(actor, row))) forbid();
  return { actor, row };
}

/** `?status=waiting` ou `?status=pickedUp,inTransit` (noms front ou base). */
function statusFilter(raw) {
  const wanted = text(raw).split(',').map((s) => s.trim()).filter(Boolean);
  if (wanted.length === 0) return null;
  const db = new Set();
  for (const status of wanted) {
    const front = toDb(status) ? toFront(toDb(status)) : null;
    if (!front) throw new HttpError(422, `Statut de livraison invalide : ${status}`);
    // Un statut front couvre plusieurs valeurs stockées.
    if (front === 'inTransit') ['in_transit', 'on_the_way'].forEach((s) => db.add(s));
    else if (front === 'cancelled') ['cancelled', 'failed'].forEach((s) => db.add(s));
    else db.add(toDb(front));
  }
  return [...db];
}

async function list(filters = {}, rawActor) {
  const actor = await withCourier(rawActor);
  const { where, params } = await scopeFor(actor);
  if (text(filters.courierId)) {
    if (actor.role === 'courier' && filters.courierId !== actor.courierId) forbid();
    where.push('d.courier_id = ?');
    params.push(text(filters.courierId));
  }
  const statuses = statusFilter(filters.status);
  if (statuses) {
    where.push(`d.status IN (${statuses.map(() => '?').join(',')})`);
    params.push(...statuses);
  }
  if (text(filters.orderId)) {
    where.push('d.order_id = ?');
    params.push(text(filters.orderId));
  }
  if (text(filters.restaurantId)) {
    where.push('o.restaurant_id = ?');
    params.push(text(filters.restaurantId));
  }
  if (filters.unassigned === 'true') where.push('d.courier_id IS NULL');
  const rows = await repo.listRows(where, params);
  const list = rows.map((row) => present(row, actor));
  // Livreur : distance de sa position actuelle au restaurant (« à 1,2 km »).
  if (actor.role === 'courier' && actor.courierId) {
    const me = await freshCourierPosition(actor.courierId);
    if (me) {
      for (const d of list) {
        const km = distanceKm(me.latitude, me.longitude, d.pickupLat, d.pickupLng);
        d.toPickupKm = km;
        d.toPickupMinutes = km == null ? null : eta.travelMinutes(km);
      }
    }
  }
  return list;
}

async function get(id, rawActor) {
  const { actor, row } = await readable(id, rawActor);
  return present(row, actor);
}

/**
 * Courses « à accepter » : en attente, sans livreur, hors courses déjà
 * refusées par le livreur connecté. Les mieux payées d'abord.
 */
async function available(rawActor) {
  const actor = await withCourier(rawActor);
  if (!isAdmin(actor) && actor.role !== 'courier') forbid();
  const where = ["d.status = 'waiting'", 'd.courier_id IS NULL'];
  const params = [];
  if (actor.courierId) {
    where.push('d.id NOT IN (SELECT delivery_id FROM delivery_declines WHERE courier_id = ?)');
    params.push(actor.courierId);
  }
  const rows = await repo.listRows(where, params, '(d.fee + d.tip) DESC, d.created_at ASC');
  return rows.map((row) => present(row, actor));
}

async function history(id, rawActor) {
  await readable(id, rawActor);
  return repo.eventsOf(id);
}

// ── Effets de bord : commande et livreur ────────────────────────────────────

/** La commande suit la course (sans revenir en arrière ni toucher une commande close). */
async function syncOrder(row, deliveryStatus, actorId, note) {
  if (!row.order_id || !row.o_status) return;
  const target = ORDER_STATUS_FOR[deliveryStatus];
  if (!target || row.o_status === target || FINAL_ORDER_STATUSES.includes(row.o_status)) return;
  const now = nowIso();
  await query('UPDATE orders SET status = ?, updated_at = ? WHERE id = ?', [target, now, row.order_id]);
  // Espèces : encaissées par le livreur à la remise.
  if (target === 'delivered') {
    await query(
      "UPDATE orders SET payment_status = 'paid' WHERE id = ? AND payment_method = 'cash' AND payment_status = 'pending'",
      [row.order_id],
    );
  }
  await query(
    'INSERT INTO order_events (order_id, status, note, actor_id, created_at) VALUES (?, ?, ?, ?, ?)',
    [row.order_id, target, note || `Livraison : ${STATUS_LABELS[deliveryStatus]}.`, actorId || null, now],
  );
}

/** Le livreur redevient disponible s'il n'a plus d'autre course en cours. */
async function releaseCourier(courierId, exceptDeliveryId) {
  if (!courierId) return;
  const other = await repo.activeRowOf(courierId, exceptDeliveryId);
  if (other) return;
  const courier = await couriers.findById(courierId);
  if (!courier || courier.status !== 'busy') return;
  const next = documentStatusOf(courier.documents) === 'approved' ? 'available' : 'offline';
  await couriers.setStatus(courierId, next);
}

async function creditCourier(courierId, amount) {
  await query(
    `UPDATE couriers SET completed_deliveries = completed_deliveries + 1,
            total_earnings = ROUND(total_earnings + ?, 2)
      WHERE id = ?`,
    [round2(amount), courierId],
  );
}

// ── Création / modification / suppression ─────────────────────────────────

function positive(value) {
  const n = Number(value);
  return value != null && value !== '' && Number.isFinite(n) && n > 0 ? n : null;
}

function nonNegative(value) {
  const n = Number(value);
  return value != null && value !== '' && Number.isFinite(n) && n >= 0 ? n : null;
}

function otp() {
  return String(crypto.randomInt(1000, 10000));
}

async function assertCanManageOrder(actor, order) {
  if (isTrusted(actor)) return;
  if (actor.role === 'restaurant') {
    const rows = await query('SELECT owner_id FROM restaurants WHERE id = ? LIMIT 1', [order.restaurant_id]);
    if (rows[0]?.owner_id === actor.id || (await restaurantIdOf(actor.id)) === order.restaurant_id) return;
  }
  forbid();
}

/**
 * `POST /deliveries` : course « à assigner » pour une commande (le back office
 * l'appelle quand une commande est prête). Idempotent : si la commande a déjà
 * une course non annulée, celle-ci est renvoyée.
 */
async function create(body, rawActor) {
  const actor = await withCourier(rawActor);
  const b = body || {};
  const orderId = text(b.orderId);
  if (!orderId) throw new HttpError(422, 'orderId est obligatoire.');
  const orders = await query('SELECT * FROM orders WHERE id = ? LIMIT 1', [orderId]);
  const order = orders[0];
  if (!order) throw new HttpError(404, `Commande introuvable (${orderId}).`);
  await assertCanManageOrder(actor, order);
  if (FINAL_ORDER_STATUSES.includes(order.status)) {
    throw new HttpError(409, 'Cette commande est terminée : aucune course à créer.');
  }

  const existing = await query(
    "SELECT id FROM deliveries WHERE order_id = ? AND status NOT IN ('cancelled', 'failed') LIMIT 1",
    [orderId],
  );
  if (existing[0]) {
    return { created: false, delivery: present(await repo.mustFindRow(existing[0].id), actor) };
  }

  const restaurants = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [order.restaurant_id]);
  const restaurant = restaurants[0] || {};
  const pickupLat = restaurant.latitude ?? null;
  const pickupLng = restaurant.longitude ?? null;
  const dropoffLat = order.delivery_lat ?? null;
  const dropoffLng = order.delivery_lng ?? null;
  const km = positive(b.distanceKm) ?? distanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng) ?? 2;
  const fee = nonNegative(b.fee) ?? courierFeeFor(km);
  const tip = nonNegative(b.tip) ?? 0;
  const minutes = Math.round(positive(b.estimatedMinutes) ?? etaMinutes(km));
  const id = newId('deliv');
  const now = nowIso();

  await withTransaction(async () => {
    await query(
      `INSERT INTO deliveries
         (id, order_id, courier_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
          distance_km, duration_min, fee, tip, otp_code, created_at, updated_at,
          pickup_name, pickup_address, customer_name, dropoff_address)
       VALUES (?, ?, NULL, 'waiting', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, orderId, pickupLat, pickupLng, dropoffLat, dropoffLng,
        km, minutes, round2(fee), round2(tip), otp(), now, now,
        text(b.pickupName) || null, text(b.pickupAddress) || null,
        text(b.customerName) || null, text(b.dropoffAddress) || null,
      ],
    );
    await repo.addEvent(id, 'waiting', 'Course créée, en attente d’un livreur.', actor.id);
  });

  // L'admin peut créer et assigner en une fois.
  if (isAdmin(actor) && text(b.courierId)) {
    return { created: true, delivery: await assign(id, text(b.courierId), rawActor) };
  }
  return { created: true, delivery: present(await repo.mustFindRow(id), actor) };
}

/**
 * `PUT /deliveries/:id` avec le JSON complet de `Delivery.toJson()` (admin).
 * Montants et durée sont modifiables tant que la course n'est pas terminée ;
 * un changement de livreur ou de statut passe par les mêmes règles que
 * l'assignation et le suivi.
 */
async function update(id, body, rawActor) {
  const actor = await withCourier(rawActor);
  requireAdmin(actor);
  const b = body || {};
  let row = await repo.mustFindRow(id);
  const current = repo.mapDelivery(row);

  const fields = {
    fee: nonNegative(b.fee),
    tip: nonNegative(b.tip),
    distance_km: positive(b.distanceKm),
    duration_min: positive(b.estimatedMinutes) != null ? Math.round(positive(b.estimatedMinutes)) : null,
  };
  const before = { fee: current.fee, tip: current.tip, distance_km: current.distanceKm, duration_min: current.estimatedMinutes };
  const changed = Object.entries(fields).filter(([key, value]) => value != null && round2(value) !== round2(before[key]));
  if (changed.length && FINAL_STATUSES.includes(current.status)) {
    throw new HttpError(409, 'Une course terminée ne peut plus être modifiée.');
  }
  if (changed.length) {
    await query(
      `UPDATE deliveries SET ${changed.map(([key]) => `${key} = ?`).join(', ')}, updated_at = ? WHERE id = ?`,
      [...changed.map(([, value]) => value), nowIso(), id],
    );
  }

  if (b.courierId !== undefined && (b.courierId || null) !== current.courierId) {
    if (b.courierId) await assign(id, b.courierId, rawActor);
    else if (current.status === 'assigned') await updateStatus(id, { status: 'waiting' }, rawActor);
  }
  row = await repo.mustFindRow(id);
  if (b.status && toDb(b.status) && toFront(toDb(b.status)) !== toFront(row.status)) {
    await updateStatus(id, { status: b.status, reason: b.cancelReason }, rawActor);
  }
  return present(await repo.mustFindRow(id), actor);
}

async function remove(id, rawActor) {
  const actor = await withCourier(rawActor);
  requireAdmin(actor);
  const row = await repo.mustFindRow(id);
  await withTransaction(async () => {
    await query('DELETE FROM delivery_events WHERE delivery_id = ?', [id]);
    await query('DELETE FROM delivery_declines WHERE delivery_id = ?', [id]);
    await query('DELETE FROM deliveries WHERE id = ?', [id]);
    if (row.courier_id && ACTIVE_STATUSES.includes(toFront(row.status))) {
      await query('UPDATE orders SET courier_id = NULL WHERE id = ? AND courier_id = ?', [row.order_id, row.courier_id]);
      await releaseCourier(row.courier_id, id);
    }
  });
}

// ── Assignation ─────────────────────────────────────────────────────────────

/**
 * Assigne un livreur (back office) ou accepte une course (livreur).
 * Le livreur doit être validé, en ligne et sans autre course. L'admin peut
 * réassigner une course déjà assignée (l'ancien livreur est libéré).
 */
async function assign(id, requestedCourierId, rawActor) {
  const actor = await withCourier(rawActor);
  let courierId = text(requestedCourierId);
  if (actor.role === 'courier') {
    courierId = courierId || actor.courierId;
    if (!actor.courierId || courierId !== actor.courierId) forbid();
  } else if (!isTrusted(actor)) {
    forbid();
  }
  if (!courierId) throw new HttpError(422, 'courierId est obligatoire.');

  const row = await repo.mustFindRow(id);
  const status = toFront(row.status);
  if (status === 'assigned' && row.courier_id === courierId) return present(row, actor);
  const reassign = status === 'assigned' && isTrusted(actor);
  if (status !== 'waiting' && !reassign) {
    throw new HttpError(
      409,
      status === 'assigned'
        ? 'Cette course vient d’être acceptée par un autre livreur.'
        : `Cette course ne peut plus être assignée (${STATUS_LABELS[status]}).`,
    );
  }

  const courier = await couriers.mustFind(courierId);
  const self = actor.role === 'courier';
  if (documentStatusOf(courier.documents) !== 'approved') {
    throw new HttpError(422, self
      ? 'Vos justificatifs doivent être validés avant de recevoir des courses.'
      : 'Les justificatifs de ce livreur ne sont pas encore validés.');
  }
  if (courier.status === 'offline') {
    throw new HttpError(409, self ? 'Passez en ligne pour accepter des courses.' : `${courier.firstName} est hors ligne.`);
  }
  if (courier.status === 'busy' || (await repo.activeRowOf(courierId))) {
    throw new HttpError(409, self ? 'Vous avez déjà une course en cours.' : `${courier.firstName} a déjà une course en cours.`);
  }

  const now = nowIso();
  const position = await freshCourierPosition(courierId);
  await withTransaction(async () => {
    const previous = reassign ? row.courier_id : null;
    await query(
      `UPDATE deliveries
          SET courier_id = ?, status = 'assigned', assigned_at = ?, started_at = ?,
              courier_lat = ?, courier_lng = ?, updated_at = ?
        WHERE id = ? AND (status = 'waiting' OR (status = 'assigned' AND ? = 1))`,
      [courierId, now, now, position?.latitude ?? null, position?.longitude ?? null, now, id, reassign ? 1 : 0],
    );
    const check = await query('SELECT courier_id FROM deliveries WHERE id = ?', [id]);
    if (check[0]?.courier_id !== courierId) {
      throw new HttpError(409, 'Cette course vient d’être acceptée par un autre livreur.');
    }
    await couriers.setStatus(courierId, 'busy');
    if (previous && previous !== courierId) await releaseCourier(previous, id);
    if (row.order_id) {
      await query('UPDATE orders SET courier_id = ?, updated_at = ? WHERE id = ?', [courierId, now, row.order_id]);
    }
    await query('DELETE FROM delivery_declines WHERE delivery_id = ? AND courier_id = ?', [id, courierId]);
    await repo.addEvent(
      id,
      'assigned',
      `${self ? 'Course acceptée par' : 'Course assignée à'} ${courier.firstName} ${courier.lastName}.`,
      actor.id,
    );
  });
  return present(await repo.mustFindRow(id), actor);
}

/** Le livreur refuse une course proposée : elle ne lui est plus proposée. */
async function decline(id, rawActor) {
  const actor = await withCourier(rawActor);
  if (actor.role !== 'courier' || !actor.courierId) forbid('Seul un livreur peut refuser une course.');
  const row = await repo.mustFindRow(id);
  if (row.status !== 'waiting' || row.courier_id) {
    throw new HttpError(409, 'Cette course n’est plus proposée.');
  }
  await query(
    'INSERT OR IGNORE INTO delivery_declines (delivery_id, courier_id, created_at) VALUES (?, ?, ?)',
    [id, actor.courierId, nowIso()],
  );
  return { deliveryId: id, courierId: actor.courierId, declined: true };
}

/** Assignation automatique au livreur disponible le plus proche du restaurant. */
async function autoAssign(id, rawActor) {
  const actor = await withCourier(rawActor);
  if (!isTrusted(actor)) forbid();
  const row = await repo.mustFindRow(id);
  if (row.status !== 'waiting') throw new HttpError(409, 'Seule une course à assigner peut être dispatchée.');
  const lat = row.pickup_lat ?? row.r_lat;
  const lng = row.pickup_lng ?? row.r_lng;
  if (!isCoordinate(lat, lng)) throw new HttpError(422, 'Position du restaurant inconnue.');
  const candidates = await livreurs.nearby({ latitude: lat, longitude: lng, radiusKm: 20, limit: 1 });
  if (candidates.length === 0) {
    throw new HttpError(404, 'Aucun livreur disponible à proximité pour le moment.');
  }
  const [best] = candidates;
  const delivery = await assign(id, best.courier.id, rawActor);
  return { delivery, courier: best.courier, distanceKm: best.distanceKm, etaMinutes: best.etaMinutes };
}

// ── Suivi de la course ──────────────────────────────────────────────────────

/**
 * Nouveau statut de course. Effets, comme dans les contrôleurs Flutter :
 * - récupérée / en route → la commande passe « en livraison » ;
 * - livrée → commande livrée, +1 course et gains (course + pourboire) pour le
 *   livreur, qui redevient disponible ;
 * - annulée → le livreur est libéré (la commande n'est pas annulée : une
 *   nouvelle course peut être créée) ;
 * - remise « à assigner » → le livreur est retiré et libéré.
 */
async function updateStatus(id, { status, otpCode, note, reason, courierId } = {}, rawActor) {
  const actor = await withCourier(rawActor);
  if (!status || !toDb(status)) {
    throw new HttpError(422, `Statut de livraison invalide : ${status}. Valeurs : ${FRONT_STATUSES.join(', ')}.`);
  }
  const next = toFront(toDb(status));
  const row = await repo.mustFindRow(id);
  const current = toFront(row.status);
  if (current === next) return present(row, actor);

  if (next === 'assigned') {
    if (courierId || actor.courierId) return assign(id, courierId || actor.courierId, rawActor);
    throw new HttpError(422, 'Pour assigner une course, indiquez courierId (PATCH /deliveries/:id/assign).');
  }
  if (!TRANSITIONS[current].includes(next)) {
    throw new HttpError(
      400,
      `Transition impossible de « ${STATUS_LABELS[current]} » vers « ${STATUS_LABELS[next]} ».`,
    );
  }

  if (actor.role === 'courier') {
    if (row.courier_id !== actor.courierId) forbid("Cette course n'est pas la vôtre.");
    if (!COURIER_STEPS.includes(next)) forbid('Seul le support peut annuler une course.');
    // Le livreur ne récupère la commande que lorsque le restaurant l'a
    // marquée prête (l'admin peut forcer l'étape).
    if (next === 'pickedUp' && row.o_status && NOT_READY_ORDER_STATUSES.includes(row.o_status)) {
      throw new HttpError(
        409,
        "Le restaurant n'a pas encore accepté la commande : attendez sa confirmation avant de la récupérer.",
      );
    }
  } else if (!isTrusted(actor)) {
    forbid();
  }

  if (next === 'delivered' && otpCode != null && otpCode !== '' && row.otp_code) {
    if (String(otpCode).trim() !== String(row.otp_code)) {
      throw new HttpError(403, 'Code de confirmation de livraison invalide.');
    }
  }

  const now = nowIso();
  const sets = ['status = ?', 'updated_at = ?'];
  const params = [toDb(next), now];
  if (next === 'pickedUp' || next === 'inTransit') {
    sets.push('picked_up_at = COALESCE(picked_up_at, ?)');
    params.push(now);
  }
  if (next === 'delivered') {
    sets.push('completed_at = ?', 'picked_up_at = COALESCE(picked_up_at, ?)');
    params.push(now, now);
  }
  if (next === 'cancelled') {
    sets.push('cancel_reason = ?');
    params.push(text(reason) || text(note) || null);
  }
  if (next === 'waiting') sets.push('courier_id = NULL', 'assigned_at = NULL', 'started_at = NULL');

  await withTransaction(async () => {
    await query(`UPDATE deliveries SET ${sets.join(', ')} WHERE id = ?`, [...params, id]);
    await syncOrder(row, next, actor.id, text(note) || null);

    const courierOfRow = row.courier_id;
    if (courierOfRow) {
      if (next === 'delivered') {
        await creditCourier(courierOfRow, Number(row.fee || 0) + Number(row.tip || 0));
      }
      if (['delivered', 'cancelled', 'waiting'].includes(next)) {
        if (next === 'waiting' && row.order_id) {
          await query('UPDATE orders SET courier_id = NULL WHERE id = ? AND courier_id = ?', [row.order_id, courierOfRow]);
        }
        await releaseCourier(courierOfRow, id);
      }
    }
    await repo.addEvent(id, next, text(note) || text(reason) || STATUS_LABELS[next], actor.id);
  });
  return present(await repo.mustFindRow(id), actor);
}

// ── Synchronisation pilotée par la commande ────────────────────────────────

/**
 * Commande acceptée par le restaurant : une course « à assigner » est créée
 * (si la commande n'en a pas déjà une) et les livreurs proches sont prévenus.
 * Appelé par le module commandes, dans sa transaction.
 */
async function ensureForOrder(orderId, actorId = null) {
  const existing = await query(
    "SELECT id FROM deliveries WHERE order_id = ? AND status NOT IN ('cancelled', 'failed') LIMIT 1",
    [orderId],
  );
  if (existing[0]) return { created: false, id: existing[0].id };
  const orders = await query('SELECT * FROM orders WHERE id = ? LIMIT 1', [orderId]);
  const order = orders[0];
  if (!order) return { created: false, id: null };
  const restaurants = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [order.restaurant_id]);
  const restaurant = restaurants[0] || {};
  const customers = await query('SELECT first_name, last_name FROM users WHERE id = ? LIMIT 1', [order.user_id]);
  const customer = customers[0];

  const km = distanceKm(restaurant.latitude, restaurant.longitude, order.delivery_lat, order.delivery_lng) ?? 2;
  const id = newId('deliv');
  const now = nowIso();
  await query(
    `INSERT INTO deliveries
       (id, order_id, courier_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
        distance_km, duration_min, fee, tip, otp_code, created_at, updated_at,
        pickup_name, pickup_address, customer_name, dropoff_address)
     VALUES (?, ?, NULL, 'waiting', ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id, orderId,
      restaurant.latitude ?? null, restaurant.longitude ?? null,
      order.delivery_lat ?? null, order.delivery_lng ?? null,
      km, etaMinutes(km), courierFeeFor(km), otp(), now, now,
      restaurant.name || null, restaurant.address || null,
      customer ? `${customer.first_name} ${customer.last_name}` : null,
      addressText(order.delivery_address),
    ],
  );
  await repo.addEvent(id, 'waiting', 'Course créée, en attente d’un livreur.', actorId);
  return { created: true, id, fee: courierFeeFor(km), distanceKm: km };
}

function addressText(raw) {
  if (!raw) return null;
  try {
    const address = typeof raw === 'string' && raw.startsWith('{') ? JSON.parse(raw) : raw;
    if (address && typeof address === 'object') {
      return [address.street, [address.postalCode, address.city].filter(Boolean).join(' ')]
        .filter(Boolean)
        .join(', ') || null;
    }
  } catch (_) {
    /* texte libre */
  }
  return String(raw);
}

/**
 * Commande annulée : sa course en cours est annulée et le livreur libéré.
 */
async function cancelForOrder(orderId, reason, actorId = null) {
  const rows = await query(
    "SELECT * FROM deliveries WHERE order_id = ? AND status NOT IN ('delivered', 'cancelled', 'failed')",
    [orderId],
  );
  const now = nowIso();
  for (const row of rows) {
    await query(
      'UPDATE deliveries SET status = ?, cancel_reason = ?, updated_at = ? WHERE id = ?',
      ['cancelled', reason || null, now, row.id],
    );
    await repo.addEvent(row.id, 'cancelled', reason ? `Commande annulée : ${reason}` : 'Commande annulée.', actorId);
    if (row.courier_id) await releaseCourier(row.courier_id, row.id);
  }
}

/**
 * Commande marquée livrée depuis le back office : la course assignée est
 * terminée (gains crédités, livreur libéré) ; une course jamais assignée
 * n'a plus lieu d'être et est annulée.
 */
async function finishForOrder(orderId, actorId = null) {
  const rows = await query(
    "SELECT * FROM deliveries WHERE order_id = ? AND status NOT IN ('delivered', 'cancelled', 'failed')",
    [orderId],
  );
  const now = nowIso();
  for (const row of rows) {
    if (!row.courier_id) {
      await query('UPDATE deliveries SET status = ?, cancel_reason = ?, updated_at = ? WHERE id = ?', [
        'cancelled', 'Commande livrée sans livreur de la plateforme.', now, row.id,
      ]);
      await repo.addEvent(row.id, 'cancelled', 'Commande livrée sans livreur de la plateforme.', actorId);
      continue;
    }
    await query(
      `UPDATE deliveries SET status = 'delivered', completed_at = ?,
              picked_up_at = COALESCE(picked_up_at, ?), updated_at = ? WHERE id = ?`,
      [now, now, now, row.id],
    );
    await creditCourier(row.courier_id, Number(row.fee || 0) + Number(row.tip || 0));
    await releaseCourier(row.courier_id, row.id);
    await repo.addEvent(row.id, 'delivered', 'Commande marquée livrée.', actorId);
  }
}

/** Écran de suivi : positions, distance restante et étapes. */
async function tracking(id, rawActor) {
  const { actor, row } = await readable(id, rawActor);
  const delivery = present(row, actor);
  const pickup = { latitude: delivery.pickupLat, longitude: delivery.pickupLng };
  const dropoff = { latitude: delivery.dropoffLat, longitude: delivery.dropoffLng };
  // Position du livreur : seulement si elle est récente (GPS du téléphone).
  const active = ['assigned', 'pickedUp', 'inTransit'].includes(delivery.status);
  const fresh = active ? await freshCourierPosition(delivery.courierId) : null;
  const courierPos = fresh ? { latitude: fresh.latitude, longitude: fresh.longitude } : null;

  // Délai annoncé par le restaurant et début de la préparation.
  const orderRows = row.order_id
    ? await query('SELECT status, estimated_time, created_at FROM orders WHERE id = ? LIMIT 1', [row.order_id])
    : [];
  const orderRow = orderRows[0] || {};
  const accepted = row.order_id
    ? await query(
      "SELECT created_at FROM order_events WHERE order_id = ? AND status = 'accepted' ORDER BY id ASC LIMIT 1",
      [row.order_id],
    )
    : [];
  const estimation = eta.estimate({
    deliveryStatus: delivery.status,
    orderStatus: normalizeOrderStatus(orderRow.status) || 'pending',
    courier: courierPos,
    pickup,
    dropoff,
    vehicle: delivery.courierVehicle || 'scooter',
    announcedMinutes: orderRow.estimated_time,
    prepStartedAt: accepted[0]?.created_at || null,
  });
  const order = ['waiting', 'assigned', 'pickedUp', 'inTransit', 'delivered'];
  const reached = (s) => delivery.status !== 'cancelled' && order.indexOf(delivery.status) >= order.indexOf(s);

  return {
    delivery,
    courier: delivery.courierId
      ? {
        id: delivery.courierId,
        name: delivery.courierName,
        phone: delivery.courierPhone,
        vehicle: delivery.courierVehicle,
        rating: delivery.courierRating,
      }
      : null,
    positions: { courier: courierPos, pickup, dropoff },
    remainingDistanceKm: estimation.remainingDistanceKm,
    remainingMinutes: estimation.remainingMinutes,
    estimatedArrivalAt: estimation.estimatedArrivalAt,
    eta: estimation,
    courierPositionAt: fresh?.at || null,
    steps: [
      { status: 'waiting', title: 'Recherche d’un livreur', done: true, at: delivery.createdAt },
      { status: 'assigned', title: 'Livreur assigné', done: reached('assigned'), at: delivery.assignedAt },
      { status: 'pickedUp', title: 'Commande récupérée', done: reached('pickedUp'), at: delivery.pickedUpAt },
      { status: 'inTransit', title: 'En route vers le client', done: reached('inTransit'), at: null },
      { status: 'delivered', title: 'Livrée', done: reached('delivered'), at: delivery.deliveredAt },
    ],
    events: await repo.eventsOf(id),
  };
}

/** Indicateurs du back office (page Livraisons, carte). */
async function stats(rawActor) {
  const actor = await withCourier(rawActor);
  if (!isTrusted(actor)) forbid();
  const all = (await repo.listRows()).map((row) => repo.mapDelivery(row));
  const now = new Date();
  const delivered = all.filter((d) => d.status === 'delivered');
  const todayDelivered = delivered.filter((d) => d.deliveredAt && sameLocalDay(new Date(d.deliveredAt), now));
  const durations = delivered
    .filter((d) => d.assignedAt && d.deliveredAt)
    .map((d) => (new Date(d.deliveredAt) - new Date(d.assignedAt)) / 60000)
    .filter((m) => m >= 0);
  return {
    total: all.length,
    byStatus: Object.fromEntries(FRONT_STATUSES.map((s) => [s, all.filter((d) => d.status === s).length])),
    active: all.filter((d) => ACTIVE_STATUSES.includes(d.status)).length,
    waiting: all.filter((d) => d.status === 'waiting').length,
    deliveredToday: todayDelivered.length,
    courierPayoutToday: round2(todayDelivered.reduce((t, d) => t + d.earnings, 0)),
    courierPayoutTotal: round2(delivered.reduce((t, d) => t + d.earnings, 0)),
    averageDeliveryMinutes: durations.length
      ? Math.round(durations.reduce((t, m) => t + m, 0) / durations.length)
      : null,
    averageDistanceKm: all.length
      ? Math.round((all.reduce((t, d) => t + d.distanceKm, 0) / all.length) * 10) / 10
      : 0,
  };
}

module.exports = {
  ensureForOrder,
  cancelForOrder,
  finishForOrder,
  list,
  get,
  available,
  history,
  create,
  update,
  remove,
  assign,
  decline,
  autoAssign,
  updateStatus,
  tracking,
  stats,
};
