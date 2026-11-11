'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction } = require('../../data/db');
const { publicCourier } = require('../../domain/presenters');
const { MESSAGES, documentStatusOf } = require('../domain/livreur.constants');
const { iso } = require('./time');

function mapCourier(row, documents) {
  return {
    id: row.id,
    userId: row.user_id,
    firstName: row.first_name,
    lastName: row.last_name,
    phone: row.phone || '',
    avatarUrl: row.avatar_url || null,
    vehicle: row.vehicle || 'scooter',
    plateNumber: row.plate_number || null,
    status: row.status || 'offline',
    documents,
    rating: Number(row.rating ?? 5),
    completedDeliveries: Number(row.completed_deliveries) || 0,
    totalEarnings: Math.round((Number(row.total_earnings) || 0) * 100) / 100,
    zone: row.zone || 'Paris',
    latitude: Number(row.latitude ?? 48.8566),
    longitude: Number(row.longitude ?? 2.3522),
    joinedAt: iso(row.joined_at),
  };
}

async function hydrate(rows) {
  if (rows.length === 0) return [];
  const ids = rows.map((row) => row.id);
  const docs = await query(
    `SELECT courier_id, type, status, image_data, uploaded_at FROM courier_documents
      WHERE courier_id IN (${ids.map(() => '?').join(',')}) ORDER BY id`,
    ids,
  );
  const grouped = new Map();
  for (const doc of docs) {
    const list = grouped.get(doc.courier_id) || [];
    list.push({
      type: doc.type,
      status: doc.status,
      imageData: doc.image_data || null,
      uploadedAt: iso(doc.uploaded_at),
    });
    grouped.set(doc.courier_id, list);
  }
  return rows.map((row) => mapCourier(row, grouped.get(row.id) || []));
}

async function findById(id) {
  const rows = await query('SELECT * FROM couriers WHERE id = ? LIMIT 1', [id]);
  return (await hydrate(rows))[0] || null;
}

async function findByUser(userId) {
  const rows = await query('SELECT * FROM couriers WHERE user_id = ? LIMIT 1', [userId]);
  return (await hydrate(rows))[0] || null;
}

async function mustFind(id) {
  const courier = await findById(id);
  if (!courier) throw new HttpError(404, MESSAGES.notFound(id));
  return courier;
}

async function listRaw(where = [], params = []) {
  const sql = `SELECT * FROM couriers${where.length ? ` WHERE ${where.join(' AND ')}` : ''}
               ORDER BY first_name, last_name`;
  return hydrate(await query(sql, params));
}

/** Enregistre le profil et ses justificatifs (photos conservées). */
async function save(courier) {
  await withTransaction(async () => {
    await query(
      `UPDATE couriers
          SET first_name = ?, last_name = ?, phone = ?, avatar_url = ?, vehicle = ?,
              plate_number = ?, status = ?, zone = ?, latitude = ?, longitude = ?
        WHERE id = ?`,
      [
        courier.firstName,
        courier.lastName,
        courier.phone || '',
        courier.avatarUrl || null,
        courier.vehicle,
        courier.plateNumber || null,
        courier.status,
        courier.zone,
        courier.latitude,
        courier.longitude,
        courier.id,
      ],
    );
    await query('DELETE FROM courier_documents WHERE courier_id = ?', [courier.id]);
    for (const doc of courier.documents) {
      await query(
        'INSERT INTO courier_documents (courier_id, type, status, image_data, uploaded_at) VALUES (?, ?, ?, ?, ?)',
        [courier.id, doc.type, doc.status, doc.imageData || null, doc.uploadedAt || null],
      );
    }
  });
  return courier;
}

async function setStatus(courierId, status) {
  await query('UPDATE couriers SET status = ? WHERE id = ?', [status, courierId]);
}

/** JSON public (`Courier.toJson`) + statut global des justificatifs. */
function present(courier, options) {
  return {
    ...publicCourier(courier, options),
    documentStatus: documentStatusOf(courier.documents),
  };
}

module.exports = {
  hydrate,
  findById,
  findByUser,
  mustFind,
  listRaw,
  save,
  setStatus,
  present,
};
