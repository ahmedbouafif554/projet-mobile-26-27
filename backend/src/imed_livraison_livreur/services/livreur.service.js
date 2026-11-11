'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction } = require('../../data/db');
const { text, oneOf, requireName, requirePhone } = require('../../domain/validate');
const coreCouriers = require('../../services/couriers.service');
const couriers = require('../data/courier.repository');
const deliveries = require('../data/delivery.repository');
const { nowIso, iso, sameLocalDay, localDayKey } = require('../data/time');
const {
  VEHICLES,
  COURIER_STATUSES,
  DOCUMENT_TYPES,
  DOCUMENT_STATUSES,
  MESSAGES,
  documentStatusOf,
} = require('../domain/livreur.constants');
const { ACTIVE_DB_STATUSES, round2 } = require('../domain/livraison.constants');
const { isAdmin, forbid, requireAdmin } = require('./access');
const { isCoordinate, distanceKm, etaMinutes } = require('./geo.utils');

// ── Contrôles d'accès ───────────────────────────────────────────────────────

function assertOwnerOrAdmin(actor, courier) {
  if (isAdmin(actor)) return;
  if (actor.anonymous || actor.id !== courier.userId) forbid();
}

// ── Justificatifs ───────────────────────────────────────────────────────────

function cleanImage(value) {
  if (value == null || value === '') return null;
  if (typeof value !== 'string' || !value.startsWith('data:image/')) {
    throw new HttpError(422, 'Chaque justificatif doit être une photo.');
  }
  if (value.length > 2_200_000) {
    throw new HttpError(422, 'Une photo est trop lourde (1,5 Mo maximum).');
  }
  return value;
}

/**
 * Fusionne les justificatifs reçus avec ceux en base.
 * - L'admin fixe librement le statut.
 * - Le livreur ne peut pas se valider lui-même : une nouvelle photo ou un
 *   renvoi (`status: pending`) repasse « à vérifier », sinon le statut en base
 *   est conservé.
 * - Une photo absente du corps n'efface jamais la photo enregistrée.
 */
function mergeDocuments(previous, incoming, admin) {
  if (!Array.isArray(incoming)) return previous;
  const now = nowIso();
  const byType = new Map(previous.map((doc) => [doc.type, doc]));
  for (const raw of incoming) {
    if (!raw || typeof raw !== 'object') continue;
    const type = oneOf(raw.type, DOCUMENT_TYPES, MESSAGES.badDocumentType);
    const requested = oneOf(raw.status || 'pending', DOCUMENT_STATUSES, MESSAGES.badDocumentStatus);
    const old = byType.get(type);
    const image = cleanImage(raw.imageData);
    const newPhoto = Boolean(image && image !== old?.imageData);
    const resubmitted = requested === 'pending' && old && old.status !== 'pending';

    let status;
    if (admin) status = requested;
    else if (newPhoto || resubmitted || !old) status = 'pending';
    else status = old.status;

    const renewed = !old || newPhoto || (status === 'pending' && old.status !== 'pending');
    byType.set(type, {
      type,
      status,
      imageData: image || old?.imageData || null,
      uploadedAt: renewed ? iso(raw.uploadedAt) || now : old.uploadedAt || now,
    });
  }
  return DOCUMENT_TYPES.filter((type) => byType.has(type)).map((type) => byType.get(type));
}

// ── Disponibilité ───────────────────────────────────────────────────────────

async function activeDeliveryRow(courierId) {
  return deliveries.activeRowOf(courierId);
}

/**
 * Règles du front (`MyCourierController.setOnline`) appliquées côté serveur :
 * - impossible de quitter « en livraison » pendant une course ;
 * - « disponible » exige des justificatifs validés ;
 * - « en livraison » n'est posé que par l'assignation d'une course.
 */
async function assertStatusChange(courier, nextStatus, actor, documents = courier.documents) {
  oneOf(nextStatus, COURIER_STATUSES, MESSAGES.badStatus);
  if (nextStatus === courier.status) return;
  const active = await activeDeliveryRow(courier.id);
  if (active && nextStatus !== 'busy') throw new HttpError(409, MESSAGES.finishFirst);
  if (nextStatus === 'available' && documentStatusOf(documents) !== 'approved') {
    throw new HttpError(422, MESSAGES.documentsNotApproved);
  }
  if (nextStatus === 'busy' && !active && !isAdmin(actor)) {
    throw new HttpError(422, MESSAGES.busyWithoutDelivery);
  }
}

// ── CRUD ────────────────────────────────────────────────────────────────────

/**
 * Liste des livreurs : l'admin voit tout ; un livreur ne voit que son propre
 * profil (`?userId=` de `MyCourierController`). Les autres rôles n'y ont pas
 * accès (téléphones, positions et gains sont des données personnelles).
 */
async function listFor(filters = {}, actor) {
  if (isAdmin(actor)) return list(filters);
  if (actor.role !== 'courier') forbid();
  if (text(filters.userId) && text(filters.userId) !== actor.id) return [];
  return list({ ...filters, userId: actor.id });
}

async function list(filters = {}) {
  const where = [];
  const params = [];
  if (text(filters.userId)) {
    where.push('user_id = ?');
    params.push(text(filters.userId));
  }
  if (text(filters.status)) {
    const statuses = text(filters.status).split(',').map((s) => s.trim()).filter(Boolean);
    where.push(`status IN (${statuses.map(() => '?').join(',')})`);
    params.push(...statuses);
  }
  if (text(filters.vehicle)) {
    where.push('vehicle = ?');
    params.push(text(filters.vehicle));
  }
  if (text(filters.zone)) {
    where.push('zone = ? COLLATE NOCASE');
    params.push(text(filters.zone));
  }
  if (text(filters.q)) {
    where.push("(first_name || ' ' || last_name LIKE ? OR phone LIKE ? OR plate_number LIKE ?)");
    const like = `%${text(filters.q)}%`;
    params.push(like, like, like);
  }
  let result = await couriers.listRaw(where, params);
  if (text(filters.documentStatus)) {
    result = result.filter((c) => documentStatusOf(c.documents) === text(filters.documentStatus));
  }
  return result.map((c) => couriers.present(c));
}

async function get(id, actor) {
  const courier = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, courier);
  return couriers.present(courier, { includeImages: true });
}

/** Profil livreur du compte connecté (`MyCourierController.build`). */
async function me(actor) {
  if (actor.anonymous) throw new HttpError(401, 'Access token required');
  const courier = await couriers.findByUser(actor.id);
  if (!courier) throw new HttpError(404, "Ce compte n'a pas de profil livreur.");
  return couriers.present(courier, { includeImages: true });
}

/**
 * Création d'un profil (inscription livreur, ou formulaire du back office).
 * Seul l'admin peut créer un profil déjà validé ; pour tous les autres, les
 * justificatifs partent « à vérifier » et le livreur « hors ligne ».
 */
async function create(body, actor) {
  const payload = { ...(body || {}) };
  // Admin : n'importe quel compte livreur. Livreur : seulement son propre
  // profil, s'il n'en a pas encore.
  if (!isAdmin(actor)) {
    if (actor.anonymous || actor.role !== 'courier') forbid();
    if (text(payload.userId) && text(payload.userId) !== actor.id) forbid();
    payload.userId = actor.id;
  }
  if (!isAdmin(actor)) {
    payload.status = 'offline';
    payload.rating = 5;
    payload.completedDeliveries = 0;
    payload.totalEarnings = 0;
    if (Array.isArray(payload.documents)) {
      payload.documents = payload.documents.map((doc) => ({ ...doc, status: 'pending' }));
    }
  } else if (payload.status === 'available') {
    const docs = Array.isArray(payload.documents) ? payload.documents : [];
    if (documentStatusOf(docs) !== 'approved') {
      throw new HttpError(422, MESSAGES.courierNotApproved);
    }
  }
  if (payload.vehicle === 'bike') payload.plateNumber = null;
  // Le service commun garde la lecture des photos (OCR) et le dossier d'identité.
  const created = await coreCouriers.create(payload);
  return couriers.present(await couriers.mustFind(created.id));
}

/** `PUT /couriers/:id` avec le JSON complet de `Courier.toJson()`. */
async function update(id, body, actor) {
  const current = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, current);
  const b = body || {};
  const next = { ...current };

  if (b.firstName != null) next.firstName = requireName(b.firstName);
  if (b.lastName != null) next.lastName = requireName(b.lastName);
  if (b.phone != null && text(b.phone)) next.phone = requirePhone(b.phone);
  if (b.avatarUrl !== undefined) next.avatarUrl = b.avatarUrl || null;
  if (b.vehicle != null) next.vehicle = oneOf(b.vehicle, VEHICLES, MESSAGES.badVehicle);
  if (b.plateNumber !== undefined) {
    next.plateNumber = text(b.plateNumber) ? text(b.plateNumber).toUpperCase() : null;
  }
  if (next.vehicle === 'bike') next.plateNumber = null;
  if (b.zone != null && text(b.zone)) next.zone = text(b.zone);
  if (isCoordinate(b.latitude, b.longitude)) {
    next.latitude = Number(b.latitude);
    next.longitude = Number(b.longitude);
  }
  next.documents = mergeDocuments(current.documents, b.documents, isAdmin(actor));

  // Un livreur dont les pièces repassent « à vérifier » ne reçoit plus de courses.
  if (b.status != null) {
    await assertStatusChange(current, b.status, actor, next.documents);
    next.status = b.status;
  }
  if (next.status === 'available' && documentStatusOf(next.documents) !== 'approved') {
    next.status = 'offline';
  }
  // Note, courses et gains sont calculés par le serveur : ignorés ici.
  await couriers.save(next);
  return couriers.present(await couriers.mustFind(id), { includeImages: true });
}

async function setStatus(id, status, actor) {
  const courier = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, courier);
  await assertStatusChange(courier, status, actor);
  if (status !== courier.status) await couriers.setStatus(id, status);
  return couriers.present(await couriers.mustFind(id));
}

/**
 * Validation des justificatifs par l'admin. Sans `type`, tous les documents ;
 * avec `type`, un seul (idCard, license, insurance).
 */
async function reviewDocuments(id, { status, type } = {}, actor) {
  requireAdmin(actor);
  const courier = await couriers.mustFind(id);
  const next = oneOf(status, DOCUMENT_STATUSES, MESSAGES.badDocumentStatus);
  const target = type ? oneOf(type, DOCUMENT_TYPES, MESSAGES.badDocumentType) : null;
  const known = new Set(courier.documents.map((doc) => doc.type));
  const documents = [...courier.documents];
  // Un profil sans justificatif reçoit les trois lignes attendues.
  for (const docType of DOCUMENT_TYPES) {
    if (!known.has(docType)) documents.push({ type: docType, status: 'pending', imageData: null, uploadedAt: nowIso() });
  }
  courier.documents = documents.map((doc) =>
    !target || doc.type === target ? { ...doc, status: next } : doc,
  );
  // Justificatifs refusés : le livreur ne peut plus rester en ligne.
  if (documentStatusOf(courier.documents) !== 'approved' && courier.status === 'available') {
    courier.status = 'offline';
  }
  await couriers.save(courier);
  return couriers.present(await couriers.mustFind(id));
}

async function remove(id, actor) {
  requireAdmin(actor);
  await couriers.mustFind(id);
  if (await activeDeliveryRow(id)) throw new HttpError(409, MESSAGES.activeDelivery);
  await withTransaction(async () => {
    await query("UPDATE deliveries SET courier_id = NULL, status = 'waiting' WHERE courier_id = ? AND status = 'waiting'", [id]);
    await query('DELETE FROM delivery_declines WHERE courier_id = ?', [id]);
    await query('DELETE FROM courier_documents WHERE courier_id = ?', [id]);
    await query('DELETE FROM courier_identity_scans WHERE courier_id = ?', [id]);
    await query('DELETE FROM couriers WHERE id = ?', [id]);
  });
}

async function identityScan(id, actor) {
  requireAdmin(actor);
  return coreCouriers.identityScan(id);
}

// ── Position GPS ────────────────────────────────────────────────────────────

/**
 * Position du livreur : met à jour la carte du back office, l'historique du
 * tracé et, pendant une course, la position affichée au client.
 */
async function updateLocation(id, body, actor) {
  const courier = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, courier);
  const { latitude, longitude } = body || {};
  if (!isCoordinate(latitude, longitude)) throw new HttpError(422, MESSAGES.badCoordinates);
  const lat = Number(latitude);
  const lng = Number(longitude);

  let active = await activeDeliveryRow(id);
  if (body.deliveryId && (!active || active.id !== body.deliveryId)) {
    const row = await deliveries.findRow(body.deliveryId);
    if (!row || row.courier_id !== id) forbid("Cette course n'est pas assignée à ce livreur.");
    active = row;
  }

  const recordedAt = nowIso();
  await withTransaction(async () => {
    await query('UPDATE couriers SET latitude = ?, longitude = ? WHERE id = ?', [lat, lng, id]);
    await query(
      'INSERT INTO courier_locations (courier_id, delivery_id, latitude, longitude, created_at) VALUES (?, ?, ?, ?, ?)',
      [id, active?.id || null, lat, lng, recordedAt],
    );
    if (active) {
      await query(
        'UPDATE deliveries SET courier_lat = ?, courier_lng = ?, updated_at = ? WHERE id = ?',
        [lat, lng, recordedAt, active.id],
      );
    }
  });

  const result = { courierId: id, latitude: lat, longitude: lng, recordedAt, deliveryId: active?.id || null };
  if (active) {
    // Avant récupération on vise le restaurant, ensuite le client.
    const toPickup = active.status === 'assigned';
    const targetLat = toPickup ? active.pickup_lat ?? active.r_lat : active.dropoff_lat;
    const targetLng = toPickup ? active.pickup_lng ?? active.r_lng : active.dropoff_lng;
    const remaining = distanceKm(lat, lng, targetLat, targetLng);
    result.target = toPickup ? 'pickup' : 'dropoff';
    result.remainingDistanceKm = remaining;
    result.remainingMinutes = remaining == null ? null : etaMinutes(remaining, courier.vehicle);
  }
  return result;
}

async function locationHistory(id, actor, { deliveryId, limit } = {}) {
  const courier = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, courier);
  const params = [id];
  let sql = 'SELECT * FROM courier_locations WHERE courier_id = ?';
  if (deliveryId) {
    sql += ' AND delivery_id = ?';
    params.push(deliveryId);
  }
  const max = Math.min(Math.max(Number(limit) || 100, 1), 1000);
  const rows = await query(`${sql} ORDER BY id DESC LIMIT ${max}`, params);
  return rows.reverse().map((row) => ({
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    deliveryId: row.delivery_id || null,
    recordedAt: iso(row.created_at),
  }));
}

/** Livreurs disponibles et validés les plus proches d'un point. */
async function nearby({ latitude, longitude, radiusKm = 15, limit = 10 } = {}) {
  if (!isCoordinate(latitude, longitude)) throw new HttpError(422, MESSAGES.badCoordinates);
  const radius = Number(radiusKm) > 0 ? Number(radiusKm) : 15;
  const max = Math.min(Math.max(Number(limit) || 10, 1), 50);
  const candidates = await couriers.listRaw(['status = ?'], ['available']);
  const busyIds = new Set(
    (await query(
      `SELECT DISTINCT courier_id FROM deliveries WHERE courier_id IS NOT NULL
        AND status IN (${ACTIVE_DB_STATUSES.map(() => '?').join(',')})`,
      ACTIVE_DB_STATUSES,
    )).map((row) => row.courier_id),
  );
  return candidates
    .filter((c) => documentStatusOf(c.documents) === 'approved' && !busyIds.has(c.id))
    .map((c) => {
      const km = distanceKm(latitude, longitude, c.latitude, c.longitude);
      return { courier: couriers.present(c), distanceKm: km, etaMinutes: etaMinutes(km ?? 0, c.vehicle) };
    })
    .filter((entry) => entry.distanceKm != null && entry.distanceKm <= radius)
    .sort((a, b) => a.distanceKm - b.distanceKm || b.courier.rating - a.courier.rating)
    .slice(0, max);
}

// ── Gains & statistiques ────────────────────────────────────────────────────

/**
 * Tableau de bord et page « Gains » du livreur : mêmes calculs que
 * `earningsByDay` / `isToday` du front, faits côté serveur.
 */
async function stats(id, actor) {
  const courier = await couriers.mustFind(id);
  assertOwnerOrAdmin(actor, courier);
  const rows = await deliveries.listRows(['d.courier_id = ?'], [id]);
  const list = rows.map((row) => deliveries.mapDelivery(row));
  const delivered = list.filter((d) => d.status === 'delivered');
  const dayOf = (d) => new Date(d.deliveredAt || d.createdAt);

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const weekStart = new Date(today);
  weekStart.setDate(weekStart.getDate() - 6);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

  const sum = (items) => round2(items.reduce((total, d) => total + d.earnings, 0));
  const todays = delivered.filter((d) => sameLocalDay(dayOf(d), now));
  const week = delivered.filter((d) => dayOf(d) >= weekStart);
  const month = delivered.filter((d) => dayOf(d) >= monthStart);

  const earningsByDay = [];
  for (let i = 6; i >= 0; i -= 1) {
    const day = new Date(today);
    day.setDate(day.getDate() - i);
    const items = delivered.filter((d) => sameLocalDay(dayOf(d), day));
    earningsByDay.push({ date: localDayKey(day), total: sum(items), deliveries: items.length });
  }

  const active = list.find((d) => ['assigned', 'pickedUp', 'inTransit'].includes(d.status)) || null;
  return {
    courierId: courier.id,
    status: courier.status,
    documentStatus: documentStatusOf(courier.documents),
    rating: courier.rating,
    completedDeliveries: courier.completedDeliveries,
    totalEarnings: courier.totalEarnings,
    deliveredCount: delivered.length,
    cancelledCount: list.filter((d) => d.status === 'cancelled').length,
    todayDeliveries: todays.length,
    todayEarnings: sum(todays),
    weekDeliveries: week.length,
    weekEarnings: sum(week),
    monthEarnings: sum(month),
    totalTips: round2(delivered.reduce((total, d) => total + d.tip, 0)),
    averageEarnings: delivered.length ? round2(sum(delivered) / delivered.length) : 0,
    totalDistanceKm: Math.round(delivered.reduce((total, d) => total + d.distanceKm, 0) * 10) / 10,
    earningsByDay,
    activeDelivery: active,
  };
}

/** Synthèse pour le back office (liste des livreurs, carte). */
async function overview(actor) {
  requireAdmin(actor);
  const all = await couriers.listRaw();
  const count = (fn) => all.filter(fn).length;
  return {
    total: all.length,
    byStatus: Object.fromEntries(COURIER_STATUSES.map((s) => [s, count((c) => c.status === s)])),
    byVehicle: Object.fromEntries(VEHICLES.map((v) => [v, count((c) => c.vehicle === v)])),
    documentsPending: count((c) => documentStatusOf(c.documents) === 'pending'),
    documentsRejected: count((c) => documentStatusOf(c.documents) === 'rejected'),
    online: count((c) => c.status !== 'offline'),
    averageRating: all.length ? Math.round((all.reduce((t, c) => t + c.rating, 0) / all.length) * 10) / 10 : 0,
  };
}

module.exports = {
  list,
  listFor,
  get,
  me,
  create,
  update,
  setStatus,
  reviewDocuments,
  remove,
  identityScan,
  updateLocation,
  locationHistory,
  nearby,
  stats,
  overview,
  // Exposés pour les tests unitaires.
  mergeDocuments,
};
