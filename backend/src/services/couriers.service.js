const HttpError = require('../errors/http-error');
const { query, withTransaction, newId, toIso, toSqlDate } = require('../data/db');
const { publicCourier } = require('../domain/presenters');
const { text, oneOf } = require('../domain/validate');

const DOCUMENT_TYPES = ['idCard', 'license', 'insurance'];
const DOCUMENT_STATUSES = ['pending', 'approved', 'rejected'];
const COURIER_STATUSES = ['offline', 'available', 'busy'];
const VEHICLES = ['bike', 'scooter', 'car'];

function mapCourier(row, documents) {
  return {
    id: row.id,
    userId: row.user_id,
    firstName: row.first_name,
    lastName: row.last_name,
    phone: row.phone,
    avatarUrl: row.avatar_url,
    vehicle: row.vehicle,
    plateNumber: row.plate_number,
    status: row.status,
    documents,
    rating: Number(row.rating),
    completedDeliveries: Number(row.completed_deliveries) || 0,
    totalEarnings: Number(row.total_earnings) || 0,
    zone: row.zone,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    joinedAt: toIso(row.joined_at),
  };
}

async function documentsOf(courierIds) {
  if (courierIds.length === 0) return new Map();
  const rows = await query(
    'SELECT courier_id, type, status, image_data, uploaded_at FROM courier_documents WHERE courier_id IN (?) ORDER BY id',
    [courierIds],
  );
  const grouped = new Map();
  for (const row of rows) {
    const list = grouped.get(row.courier_id) || [];
    list.push({
      type: row.type,
      status: row.status,
      imageData: row.image_data || null,
      uploadedAt: toIso(row.uploaded_at),
    });
    grouped.set(row.courier_id, list);
  }
  return grouped;
}

async function hydrate(rows) {
  const grouped = await documentsOf(rows.map((row) => row.id));
  return rows.map((row) => mapCourier(row, grouped.get(row.id) || []));
}

async function findById(id) {
  const rows = await query('SELECT * FROM couriers WHERE id = ? LIMIT 1', [id]);
  if (!rows[0]) return null;
  const [courier] = await hydrate(rows);
  return courier;
}

async function findByUser(userId) {
  const rows = await query('SELECT * FROM couriers WHERE user_id = ? LIMIT 1', [userId]);
  if (!rows[0]) return null;
  const [courier] = await hydrate(rows);
  return courier;
}

async function mustFind(id) {
  const courier = await findById(id);
  if (!courier) throw new HttpError(404, `Élément introuvable (${id}).`);
  return courier;
}

function pendingDocuments(uploadedAt) {
  return DOCUMENT_TYPES.map((type) => ({
    type,
    status: 'pending',
    imageData: null,
    uploadedAt,
  }));
}

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

function normalizeDocuments(raw, fallbackDate) {
  if (!Array.isArray(raw) || raw.length === 0) return pendingDocuments(fallbackDate);
  return raw.map((doc) => ({
    type: oneOf(doc.type, DOCUMENT_TYPES, 'Type de justificatif invalide.'),
    status: oneOf(
      doc.status || 'pending',
      DOCUMENT_STATUSES,
      'Statut de justificatif invalide.',
    ),
    imageData: cleanImage(doc.imageData),
    uploadedAt: doc.uploadedAt || fallbackDate,
  }));
}

/** Les trois photos sont obligatoires à l'inscription d'un livreur. */
function requireRegistrationPhotos(raw) {
  const now = new Date().toISOString();
  const documents = normalizeDocuments(raw, now);
  const byType = new Map(documents.map((doc) => [doc.type, doc]));
  for (const type of DOCUMENT_TYPES) {
    if (!byType.get(type)?.imageData) {
      throw new HttpError(422, 'Les photos de la pièce d\'identité, du permis et de l\'assurance sont obligatoires.');
    }
  }
  return DOCUMENT_TYPES.map((type) => ({ ...byType.get(type), status: 'pending' }));
}

function numberOr(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

async function replaceDocuments(courierId, documents, conn) {
  await query('DELETE FROM courier_documents WHERE courier_id = ?', [courierId], conn);
  for (const doc of documents) {
    await query(
      `INSERT INTO courier_documents (courier_id, type, status, image_data, uploaded_at) VALUES (?, ?, ?, ?, ?)`,
      [courierId, doc.type, doc.status, doc.imageData || null, toSqlDate(doc.uploadedAt)],
      conn,
    );
  }
}

async function insertCourier(courier) {
  await withTransaction(async (conn) => {
    await query(
      `INSERT INTO couriers
        (id, user_id, first_name, last_name, phone, avatar_url, vehicle, plate_number, status,
         rating, completed_deliveries, total_earnings, zone, latitude, longitude, joined_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        courier.id,
        courier.userId,
        courier.firstName,
        courier.lastName,
        courier.phone ?? '',
        courier.avatarUrl,
        courier.vehicle,
        courier.plateNumber,
        courier.status,
        courier.rating,
        courier.completedDeliveries,
        courier.totalEarnings,
        courier.zone,
        courier.latitude,
        courier.longitude,
        toSqlDate(courier.joinedAt),
      ],
      conn,
    );
    await replaceDocuments(courier.id, courier.documents, conn);
  });
  return courier;
}

async function saveCourier(courier) {
  await withTransaction(async (conn) => {
    await query(
      `UPDATE couriers
          SET first_name = ?, last_name = ?, phone = ?, avatar_url = ?, vehicle = ?,
              plate_number = ?, status = ?, rating = ?, completed_deliveries = ?,
              total_earnings = ?, zone = ?, latitude = ?, longitude = ?
        WHERE id = ?`,
      [
        courier.firstName,
        courier.lastName,
        courier.phone ?? '',
        courier.avatarUrl,
        courier.vehicle,
        courier.plateNumber,
        courier.status,
        courier.rating,
        courier.completedDeliveries,
        courier.totalEarnings,
        courier.zone,
        courier.latitude,
        courier.longitude,
        courier.id,
      ],
      conn,
    );
    await replaceDocuments(courier.id, courier.documents, conn);
  });
  return courier;
}

function approvalState(courier) {
  const documents = courier?.documents || [];
  if (!courier || documents.length === 0) return 'pending';
  if (documents.some((doc) => doc.status === 'rejected')) return 'rejected';
  if (documents.every((doc) => doc.status === 'approved')) return 'approved';
  return 'pending';
}

/** Un livreur ne se connecte que lorsque l'admin a validé ses justificatifs. */
async function assertApproved(user) {
  if (!user || user.role !== 'courier') return;
  const { MESSAGES } = require('../domain/roles');
  const state = approvalState(await findByUser(user.id));
  if (state === 'approved') return;
  throw new HttpError(
    403,
    state === 'rejected' ? MESSAGES.courierRejected : MESSAGES.courierPending,
  );
}

async function ensureProfile(user, documents = null) {
  const existing = await findByUser(user.id);
  if (existing) return existing;
  const now = new Date().toISOString();
  return insertCourier({
    id: newId('c'),
    userId: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    phone: user.phone ?? '',
    avatarUrl: user.avatarUrl ?? null,
    vehicle: 'scooter',
    plateNumber: null,
    status: 'offline',
    documents: documents || pendingDocuments(now),
    rating: 5,
    completedDeliveries: 0,
    totalEarnings: 0,
    zone: 'Paris',
    latitude: 48.8566,
    longitude: 2.3522,
    joinedAt: now,
  });
}

async function list({ userId, status } = {}) {
  const where = [];
  const params = [];
  if (userId != null && text(userId)) {
    where.push('user_id = ?');
    params.push(userId);
  }
  if (status) {
    where.push('status = ?');
    params.push(status);
  }
  const sql = `SELECT * FROM couriers${where.length ? ` WHERE ${where.join(' AND ')}` : ''}`;
  return (await hydrate(await query(sql, params))).map(publicCourier);
}

async function get(id) {
  return publicCourier(await mustFind(id));
}

async function create(body) {
  const userId = text(body.userId);
  if (!userId) throw new HttpError(422, 'userId est obligatoire');
  const user = await require('./users.service').findById(userId);
  if (!user) throw new HttpError(404, `Élément introuvable (${userId}).`);
  if (user.role !== 'courier') {
    throw new HttpError(422, 'Seuls les comptes livreur ont un profil livreur.');
  }
  if (await findByUser(userId)) {
    throw new HttpError(409, 'Ce livreur a déjà un profil.');
  }

  const now = new Date().toISOString();
  const requestedId = text(body.id);
  if (requestedId && (await findById(requestedId))) {
    throw new HttpError(409, 'Cet élément existe déjà.');
  }

  const courier = await insertCourier({
    id: requestedId || newId('c'),
    userId,
    firstName: text(body.firstName) || user.firstName,
    lastName: text(body.lastName) || user.lastName,
    phone: body.phone != null ? text(body.phone) : user.phone,
    avatarUrl: body.avatarUrl || null,
    vehicle: oneOf(body.vehicle || 'scooter', VEHICLES, 'Véhicule invalide.'),
    plateNumber: body.plateNumber ? text(body.plateNumber) : null,
    status: oneOf(body.status || 'offline', COURIER_STATUSES, 'Statut livreur invalide.'),
    documents: normalizeDocuments(body.documents, now),
    rating: numberOr(body.rating, 5),
    completedDeliveries: numberOr(body.completedDeliveries, 0),
    totalEarnings: numberOr(body.totalEarnings, 0),
    zone: text(body.zone) || 'Paris',
    latitude: numberOr(body.latitude, 48.8566),
    longitude: numberOr(body.longitude, 2.3522),
    joinedAt: body.joinedAt || now,
  });
  return publicCourier(courier);
}

async function update(id, body) {
  const courier = await mustFind(id);
  if (body.firstName != null) courier.firstName = text(body.firstName);
  if (body.lastName != null) courier.lastName = text(body.lastName);
  if (body.phone != null) courier.phone = text(body.phone);
  if (body.avatarUrl !== undefined) courier.avatarUrl = body.avatarUrl || null;
  if (body.vehicle != null) {
    courier.vehicle = oneOf(body.vehicle, VEHICLES, 'Véhicule invalide.');
  }
  if (body.plateNumber !== undefined) {
    courier.plateNumber = body.plateNumber ? text(body.plateNumber) : null;
  }
  if (body.status != null) {
    courier.status = oneOf(body.status, COURIER_STATUSES, 'Statut livreur invalide.');
  }
  if (body.zone != null) courier.zone = text(body.zone) || courier.zone;
  if (body.documents != null) {
    const previous = new Map(courier.documents.map((doc) => [doc.type, doc.imageData]));
    courier.documents = normalizeDocuments(body.documents, new Date().toISOString()).map((doc) => ({
      ...doc,
      imageData: doc.imageData || previous.get(doc.type) || null,
    }));
  }
  await saveCourier(courier);
  return publicCourier(courier);
}

async function setStatus(id, status) {
  const courier = await mustFind(id);
  courier.status = oneOf(status, COURIER_STATUSES, 'Statut livreur invalide.');
  await query('UPDATE couriers SET status = ? WHERE id = ?', [courier.status, courier.id]);
  return publicCourier(courier);
}

async function reviewDocuments(id, status) {
  const courier = await mustFind(id);
  const next = oneOf(status, DOCUMENT_STATUSES, 'Statut de justificatif invalide.');
  await query('UPDATE courier_documents SET status = ? WHERE courier_id = ?', [next, id]);
  courier.documents = courier.documents.map((doc) => ({ ...doc, status: next }));
  return publicCourier(courier);
}

async function remove(id) {
  await mustFind(id);
  await query('DELETE FROM couriers WHERE id = ?', [id]);
}

module.exports = {
  findByUser,
  requireRegistrationPhotos,
  assertApproved,
  ensureProfile,
  list,
  get,
  create,
  update,
  setStatus,
  reviewDocuments,
  remove,
};
