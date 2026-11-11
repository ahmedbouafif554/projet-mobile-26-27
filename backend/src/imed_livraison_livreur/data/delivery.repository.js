'use strict';

const HttpError = require('../../errors/http-error');
const { query } = require('../../data/db');
const {
  STATUS_LABELS,
  ACTIVE_DB_STATUSES,
  round2,
  toFront,
} = require('../domain/livraison.constants');
const { iso, nowIso } = require('./time');

/** Livraison + commande + restaurant + client + livreur. */
const SELECT = `
  SELECT d.*,
         o.reference      AS o_reference,
         o.user_id        AS o_user_id,
         o.restaurant_id  AS o_restaurant_id,
         o.status         AS o_status,
         o.delivery_address AS o_address,
         r.name           AS r_name,
         r.address        AS r_address,
         r.latitude       AS r_lat,
         r.longitude      AS r_lng,
         r.owner_id       AS r_owner_id,
         COALESCE(o.customer_name, u.first_name || ' ' || u.last_name) AS u_name,
         COALESCE(o.customer_phone, u.phone) AS u_phone,
         c.first_name || ' ' || c.last_name AS c_name,
         c.phone          AS c_phone,
         c.vehicle        AS c_vehicle,
         c.rating         AS c_rating
    FROM deliveries d
    LEFT JOIN orders o      ON o.id = d.order_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN users u       ON u.id = o.user_id
    LEFT JOIN couriers c    ON c.id = d.courier_id
`;

function num(value, fallback = null) {
  if (value == null || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/** L'adresse de commande peut être un texte ou un objet `Address` en JSON. */
function addressText(raw) {
  if (raw == null || raw === '') return '';
  const text = String(raw).trim();
  if (!text.startsWith('{')) return text;
  try {
    const a = JSON.parse(text);
    const city = [a.postalCode, a.city].filter(Boolean).join(' ');
    return [a.street, city].filter(Boolean).join(', ') || a.label || '';
  } catch (_error) {
    return text;
  }
}

function referenceOf(row) {
  if (row.o_reference) return row.o_reference;
  const orderId = row.order_id || '';
  return orderId ? `CMD-${orderId.slice(-6).toUpperCase()}` : '';
}

/**
 * Forme JSON de `Delivery.fromJson` (Flutter), plus quelques champs utiles
 * à la carte et au suivi (ignorés par le modèle).
 */
function mapDelivery(row, { showOtp = false, showContact = false } = {}) {
  if (!row) return null;
  const status = toFront(row.status);
  const fee = round2(num(row.fee, 4.5));
  const tip = round2(num(row.tip, 0));
  const json = {
    id: row.id,
    orderId: row.order_id || '',
    orderReference: referenceOf(row),
    courierId: row.courier_id || null,
    status,
    statusLabel: STATUS_LABELS[status],
    rawStatus: row.status,
    pickupName: row.r_name || row.pickup_name || 'Restaurant',
    pickupAddress: row.r_address || row.pickup_address || '',
    customerName: row.u_name || row.customer_name || 'Client',
    dropoffAddress: addressText(row.o_address) || row.dropoff_address || '',
    distanceKm: num(row.distance_km, 2),
    fee,
    tip,
    earnings: round2(fee + tip),
    estimatedMinutes: Math.round(num(row.duration_min, 25)),
    createdAt: iso(row.created_at) || nowIso(),
    assignedAt: iso(row.assigned_at) || iso(row.started_at),
    pickedUpAt: iso(row.picked_up_at),
    deliveredAt: iso(row.completed_at),
    updatedAt: iso(row.updated_at),
    cancelReason: row.cancel_reason || null,
    courierName: row.c_name || null,
    courierPhone: row.c_phone || null,
    courierVehicle: row.c_vehicle || null,
    courierRating: row.c_rating == null ? null : Number(row.c_rating),
    pickupLat: num(row.pickup_lat, num(row.r_lat)),
    pickupLng: num(row.pickup_lng, num(row.r_lng)),
    dropoffLat: num(row.dropoff_lat),
    dropoffLng: num(row.dropoff_lng),
    courierLat: num(row.courier_lat),
    courierLng: num(row.courier_lng),
  };
  if (showOtp) json.otpCode = row.otp_code || null;
  // Téléphone du client : pour son livreur (appel pendant la course) et l'admin.
  if (showContact) json.customerPhone = row.u_phone || null;
  return json;
}

async function findRow(id) {
  const rows = await query(`${SELECT} WHERE d.id = ? LIMIT 1`, [id]);
  return rows[0] || null;
}

async function mustFindRow(id) {
  const row = await findRow(id);
  if (!row) throw new HttpError(404, `Livraison introuvable (${id}).`);
  return row;
}

async function listRows(where = [], params = [], orderBy = 'd.created_at DESC') {
  const sql = `${SELECT}${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY ${orderBy}`;
  return query(sql, params);
}

/** Course en cours d'un livreur (la plus récente), ou null. */
async function activeRowOf(courierId, exceptId = null) {
  const marks = ACTIVE_DB_STATUSES.map(() => '?').join(',');
  const params = [courierId, ...ACTIVE_DB_STATUSES];
  let sql = `${SELECT} WHERE d.courier_id = ? AND d.status IN (${marks})`;
  if (exceptId) {
    sql += ' AND d.id <> ?';
    params.push(exceptId);
  }
  const rows = await query(`${sql} ORDER BY d.updated_at DESC LIMIT 1`, params);
  return rows[0] || null;
}

async function addEvent(deliveryId, status, note, actorId) {
  await query(
    'INSERT INTO delivery_events (delivery_id, status, note, actor_id, created_at) VALUES (?, ?, ?, ?, ?)',
    [deliveryId, status, note || null, actorId || null, nowIso()],
  );
}

async function eventsOf(deliveryId) {
  const rows = await query(
    'SELECT * FROM delivery_events WHERE delivery_id = ? ORDER BY id ASC',
    [deliveryId],
  );
  return rows.map((e) => ({
    id: String(e.id),
    deliveryId: e.delivery_id,
    status: e.status,
    statusLabel: STATUS_LABELS[e.status] || e.status,
    note: e.note || null,
    actorId: e.actor_id || null,
    createdAt: iso(e.created_at),
  }));
}

module.exports = {
  SELECT,
  num,
  addressText,
  mapDelivery,
  findRow,
  mustFindRow,
  listRows,
  activeRowOf,
  addEvent,
  eventsOf,
};
