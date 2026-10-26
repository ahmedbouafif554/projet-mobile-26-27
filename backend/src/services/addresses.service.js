const HttpError = require('../errors/http-error');
const { query, newId } = require('../data/db');
const { publicAddress } = require('../domain/presenters');
const { text, requirePostalCode, oneOf } = require('../domain/validate');
const users = require('./users.service');

const ADDRESS_TYPES = ['home', 'work', 'other'];

function mapAddress(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    label: row.label,
    street: row.street,
    postalCode: row.postal_code,
    city: row.city,
    type: row.type,
    instructions: row.instructions,
    isDefault: Boolean(row.is_default),
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
  };
}

async function findById(id) {
  const rows = await query('SELECT * FROM addresses WHERE id = ? LIMIT 1', [id]);
  return mapAddress(rows[0]);
}

async function mustFind(id) {
  const address = await findById(id);
  if (!address) throw new HttpError(404, `Élément introuvable (${id}).`);
  return address;
}

async function forUser(userId) {
  await users.mustFind(userId);
  const rows = await query(
    'SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, id',
    [userId],
  );
  return rows.map((row) => publicAddress(mapAddress(row)));
}

async function clearDefault(userId, exceptId) {
  await query('UPDATE addresses SET is_default = 0 WHERE user_id = ? AND id <> ?', [
    userId,
    exceptId,
  ]);
}

function build(body, current) {
  const type = oneOf(body.type || current?.type || 'home', ADDRESS_TYPES, "Type d'adresse invalide.");
  const label = text(body.label) || current?.label || type;
  if (!label) throw new HttpError(422, "Le nom de l'adresse est obligatoire");
  const street = text(body.street ?? current?.street);
  if (!street) throw new HttpError(422, "L'adresse est obligatoire");
  const city = text(body.city ?? current?.city);
  if (!city) throw new HttpError(422, 'La ville est obligatoire');
  const latitude = Number(body.latitude ?? current?.latitude ?? 48.8566);
  const longitude = Number(body.longitude ?? current?.longitude ?? 2.3522);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpError(422, 'Coordonnées invalides');
  }
  return {
    label,
    street,
    postalCode: requirePostalCode(body.postalCode ?? current?.postalCode),
    city,
    type,
    instructions: body.instructions ? text(body.instructions) : null,
    isDefault: body.isDefault != null ? Boolean(body.isDefault) : Boolean(current?.isDefault),
    latitude,
    longitude,
  };
}

async function insertAddress(address) {
  await query(
    `INSERT INTO addresses
      (id, user_id, label, street, postal_code, city, type, instructions, is_default, latitude, longitude)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      address.id,
      address.userId,
      address.label,
      address.street,
      address.postalCode,
      address.city,
      address.type,
      address.instructions,
      address.isDefault ? 1 : 0,
      address.latitude,
      address.longitude,
    ],
  );
}

async function saveAddress(address) {
  await query(
    `UPDATE addresses
        SET user_id = ?, label = ?, street = ?, postal_code = ?, city = ?, type = ?,
            instructions = ?, is_default = ?, latitude = ?, longitude = ?
      WHERE id = ?`,
    [
      address.userId,
      address.label,
      address.street,
      address.postalCode,
      address.city,
      address.type,
      address.instructions,
      address.isDefault ? 1 : 0,
      address.latitude,
      address.longitude,
      address.id,
    ],
  );
}

async function create(actor, body) {
  const userId = text(body.userId);
  if (!userId) throw new HttpError(422, 'userId est obligatoire');
  users.assertSelfOrAdmin(actor, userId);
  await users.mustFind(userId);

  const requestedId = text(body.id);
  if (requestedId && (await findById(requestedId))) {
    throw new HttpError(409, 'Cet élément existe déjà.');
  }

  const address = {
    id: requestedId || newId('a'),
    userId,
    ...build(body),
  };
  if (address.isDefault) await clearDefault(userId, address.id);
  await insertAddress(address);
  return publicAddress(address);
}

async function update(actor, id, body) {
  const address = await mustFind(id);
  users.assertSelfOrAdmin(actor, address.userId);
  if (body.userId && text(body.userId) !== address.userId && actor.role !== 'admin') {
    throw new HttpError(403, "Vous n'avez pas accès à cette ressource.");
  }
  Object.assign(address, build({ ...address, ...body }, address));
  if (body.userId && actor.role === 'admin') address.userId = text(body.userId);
  if (address.isDefault) await clearDefault(address.userId, address.id);
  await saveAddress(address);
  return publicAddress(address);
}

async function remove(actor, id) {
  const address = await mustFind(id);
  users.assertSelfOrAdmin(actor, address.userId);
  await query('DELETE FROM addresses WHERE id = ?', [id]);
}

async function setDefault(actor, id) {
  const address = await mustFind(id);
  users.assertSelfOrAdmin(actor, address.userId);
  await clearDefault(address.userId, address.id);
  await query('UPDATE addresses SET is_default = 1 WHERE id = ?', [address.id]);
  return forUser(address.userId);
}

module.exports = { forUser, create, update, remove, setDefault };
