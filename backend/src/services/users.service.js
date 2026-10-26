const bcrypt = require('bcryptjs');
const HttpError = require('../errors/http-error');
const { query, newId, rounds, toIso, toSqlDate } = require('../data/db');
const { publicUser } = require('../domain/presenters');
const { ROLES, USER_STATUSES, MESSAGES } = require('../domain/roles');
const {
  text,
  requireName,
  requireEmail,
  requirePhone,
  optionalPassword,
  oneOf,
} = require('../domain/validate');
const couriers = require('./couriers.service');

function mapUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    firstName: row.first_name,
    lastName: row.last_name,
    email: row.email,
    phone: row.phone,
    role: row.role,
    status: row.status,
    avatarUrl: row.avatar_url,
    restaurantId: row.restaurant_id,
    loyaltyPoints: Number(row.loyalty_points) || 0,
    passwordHash: row.password_hash,
    createdAt: toIso(row.created_at),
    lastLoginAt: toIso(row.last_login_at),
  };
}

async function findById(id) {
  const rows = await query('SELECT * FROM users WHERE id = ? LIMIT 1', [id]);
  return mapUser(rows[0]);
}

async function findByEmail(email) {
  const key = text(email).toLowerCase();
  if (!key) return null;
  const rows = await query(
    'SELECT * FROM users WHERE LOWER(email) = ? LIMIT 1',
    [key],
  );
  return mapUser(rows[0]);
}

async function mustFind(id) {
  const user = await findById(id);
  if (!user) throw new HttpError(404, `Élément introuvable (${id}).`);
  return user;
}

async function assertUniqueEmail(email, exceptId) {
  const existing = await findByEmail(email);
  if (existing && existing.id !== exceptId) {
    throw new HttpError(409, MESSAGES.duplicateEmail);
  }
}

async function saveUser(user) {
  await query(
    `UPDATE users
        SET first_name = ?, last_name = ?, email = ?, phone = ?, role = ?, status = ?,
            avatar_url = ?, restaurant_id = ?, loyalty_points = ?, last_login_at = ?
      WHERE id = ?`,
    [
      user.firstName,
      user.lastName,
      user.email,
      user.phone,
      user.role,
      user.status,
      user.avatarUrl,
      user.restaurantId,
      user.loyaltyPoints,
      user.lastLoginAt ? toSqlDate(user.lastLoginAt) : null,
      user.id,
    ],
  );
}

async function setPassword(userId, password) {
  const hash = await bcrypt.hash(password, rounds());
  await query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, userId]);
}

async function create(body, actor) {
  const isAdmin = actor?.role === 'admin';
  const role = body.role ? oneOf(body.role, ROLES, MESSAGES.invalidRole) : 'client';

  if (!isAdmin && role === 'admin') {
    throw new HttpError(403, MESSAGES.registerInPro);
  }
  if (!isAdmin && role === 'restaurant' && body.status && body.status !== 'pending') {
    throw new HttpError(403, MESSAGES.registerInPro);
  }

  const firstName = requireName(body.firstName);
  const lastName = requireName(body.lastName);
  const email = requireEmail(body.email);
  const phone = requirePhone(body.phone);
  const password = optionalPassword(body.password);
  await assertUniqueEmail(email);

  let status = 'active';
  if (isAdmin && body.status) {
    status = oneOf(body.status, USER_STATUSES, MESSAGES.invalidStatus);
  } else if (role === 'restaurant') {
    status = 'pending';
  }

  const requestedId = text(body.id);
  if (requestedId && (await findById(requestedId))) {
    throw new HttpError(409, 'Cet élément existe déjà.');
  }

  const user = {
    id: requestedId || newId('u'),
    firstName,
    lastName,
    email,
    phone,
    role,
    status,
    avatarUrl: body.avatarUrl || null,
    restaurantId: role === 'restaurant' ? body.restaurantId || null : null,
    loyaltyPoints: Number.isFinite(body.loyaltyPoints) ? body.loyaltyPoints : 0,
    createdAt: body.createdAt || new Date().toISOString(),
    lastLoginAt: null,
  };
  const passwordHash = password ? await bcrypt.hash(password, rounds()) : null;
  try {
    await query(
      `INSERT INTO users
        (id, first_name, last_name, email, phone, role, status, avatar_url, restaurant_id,
         loyalty_points, password_hash, created_at, last_login_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)`,
      [
        user.id,
        user.firstName,
        user.lastName,
        user.email,
        user.phone,
        user.role,
        user.status,
        user.avatarUrl,
        user.restaurantId,
        user.loyaltyPoints,
        passwordHash,
        toSqlDate(user.createdAt),
      ],
    );
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      throw new HttpError(409, MESSAGES.duplicateEmail);
    }
    throw error;
  }
  return publicUser(user);
}

async function list({ email, role } = {}) {
  const where = [];
  const params = [];
  if (email != null && text(email)) {
    where.push('LOWER(email) = ?');
    params.push(text(email).toLowerCase());
  }
  if (role) {
    where.push('role = ?');
    params.push(role);
  }
  const sql = `SELECT * FROM users${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY created_at DESC`;
  const rows = await query(sql, params);
  return rows.map((row) => publicUser(mapUser(row)));
}

async function get(id) {
  return publicUser(await mustFind(id));
}

async function update(actor, id, body) {
  const user = await mustFind(id);
  if (!actor) return linkPendingRestaurant(user, body);

  const isAdmin = actor.role === 'admin';
  const isSelf = actor.id === user.id;
  if (!isAdmin && !isSelf) throw new HttpError(403, MESSAGES.forbidden);

  if (body.firstName != null) user.firstName = requireName(body.firstName);
  if (body.lastName != null) user.lastName = requireName(body.lastName);
  if (body.email != null) {
    user.email = requireEmail(body.email);
    await assertUniqueEmail(user.email, user.id);
  }
  if (body.phone != null) user.phone = requirePhone(body.phone);
  if (body.avatarUrl !== undefined) {
    user.avatarUrl = body.avatarUrl ? text(body.avatarUrl) || null : null;
  }

  if (isAdmin) {
    if (body.role != null && body.role !== user.role) {
      if (isSelf) throw new HttpError(403, MESSAGES.ownRole);
      user.role = oneOf(body.role, ROLES, MESSAGES.invalidRole);
    }
    if (body.status != null && body.status !== user.status) {
      const nextStatus = oneOf(body.status, USER_STATUSES, MESSAGES.invalidStatus);
      if (isSelf && nextStatus === 'blocked') throw new HttpError(403, MESSAGES.ownBlock);
      user.status = nextStatus;
    }
    if (body.loyaltyPoints != null) {
      const points = Number(body.loyaltyPoints);
      if (!Number.isInteger(points) || points < 0) {
        throw new HttpError(422, 'Points de fidélité invalides');
      }
      user.loyaltyPoints = points;
    }
    if (body.restaurantId !== undefined && user.role === 'restaurant') {
      user.restaurantId = body.restaurantId ? text(body.restaurantId) : null;
    } else if (body.role != null && user.role !== 'restaurant') {
      user.restaurantId = null;
    }
  }

  await saveUser(user);
  if (user.role === 'courier') await couriers.ensureProfile(user);
  const password = isAdmin ? optionalPassword(body.password) : null;
  if (password) await setPassword(user.id, password);
  return publicUser(user);
}

async function linkPendingRestaurant(user, body) {
  if (user.role !== 'restaurant' || user.status !== 'pending' || user.restaurantId) {
    throw new HttpError(401, 'Access token required');
  }
  const restaurantId = text(body.restaurantId);
  if (!restaurantId) throw new HttpError(422, 'restaurantId est obligatoire');

  const identity = ['firstName', 'lastName', 'email', 'phone', 'role', 'status'];
  for (const key of identity) {
    if (body[key] != null && String(body[key]) !== String(user[key])) {
      throw new HttpError(401, 'Access token required');
    }
  }
  user.restaurantId = restaurantId;
  await saveUser(user);
  return publicUser(user);
}

async function setStatus(actor, id, status) {
  if (actor?.role !== 'admin') throw new HttpError(403, MESSAGES.forbidden);
  const user = await mustFind(id);
  const next = oneOf(status, USER_STATUSES, MESSAGES.invalidStatus);
  if (actor.id === user.id && next === 'blocked') {
    throw new HttpError(403, MESSAGES.ownBlock);
  }
  user.status = next;
  await saveUser(user);
  return publicUser(user);
}

async function setRole(actor, id, role) {
  if (actor?.role !== 'admin') throw new HttpError(403, MESSAGES.forbidden);
  const user = await mustFind(id);
  const next = oneOf(role, ROLES, MESSAGES.invalidRole);
  if (actor.id === user.id && next !== user.role) {
    throw new HttpError(403, MESSAGES.ownRole);
  }
  user.role = next;
  await saveUser(user);
  if (next === 'courier') await couriers.ensureProfile(user);
  return publicUser(user);
}

async function remove(actor, id) {
  if (actor?.role !== 'admin') throw new HttpError(403, MESSAGES.forbidden);
  const user = await mustFind(id);
  if (actor.id === user.id) {
    throw new HttpError(403, 'Vous ne pouvez pas supprimer votre propre compte.');
  }
  await query('DELETE FROM users WHERE id = ?', [id]);
}

async function touchLogin(user) {
  user.lastLoginAt = new Date().toISOString();
  await query('UPDATE users SET last_login_at = ? WHERE id = ?', [
    toSqlDate(user.lastLoginAt),
    user.id,
  ]);
  return user;
}

async function favoritesOf(userId) {
  await mustFind(userId);
  const rows = await query(
    'SELECT restaurant_id FROM favorites WHERE user_id = ? ORDER BY restaurant_id',
    [userId],
  );
  return rows.map((row) => row.restaurant_id);
}

async function addFavorite(actor, userId, restaurantId) {
  assertSelfOrAdmin(actor, userId);
  await mustFind(userId);
  const id = text(restaurantId);
  if (!id) throw new HttpError(422, 'restaurantId est obligatoire');
  await query(
    'INSERT IGNORE INTO favorites (user_id, restaurant_id) VALUES (?, ?)',
    [userId, id],
  );
}

async function removeFavorite(actor, userId, restaurantId) {
  assertSelfOrAdmin(actor, userId);
  await query('DELETE FROM favorites WHERE user_id = ? AND restaurant_id = ?', [
    userId,
    restaurantId,
  ]);
}

function assertSelfOrAdmin(actor, userId) {
  if (!actor) throw new HttpError(401, 'Access token required');
  if (actor.role !== 'admin' && actor.id !== userId) {
    throw new HttpError(403, MESSAGES.forbidden);
  }
}

module.exports = {
  findById,
  findByEmail,
  mustFind,
  setPassword,
  create,
  list,
  get,
  update,
  setStatus,
  setRole,
  remove,
  touchLogin,
  favoritesOf,
  addFavorite,
  removeFavorite,
  assertSelfOrAdmin,
};
