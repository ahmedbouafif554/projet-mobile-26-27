'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId } = require('../../data/db');
const { text, oneOf } = require('../../domain/validate');
const {
  NOTIFICATION_TYPES,
  AUDIENCES,
  CHANNELS,
  DEFAULT_CHANNELS,
  ROLE_AUDIENCE,
  LIMITS,
  MESSAGES,
} = require('../domain/notification.constants');
const { nowIso, iso, parseDateInput, json, isAdmin, forbid, requireUser, findUser } = require('./common');
const campagnes = require('./campagne.service');

// ── Lecture pour un destinataire ────────────────────────────────────────────

/**
 * Une notification est pour U si elle lui est adressée, ou si elle est
 * envoyée à tous (userId null) pour son audience, et qu'il ne l'a pas masquée.
 */
function visibleTo(reader) {
  return {
    sql: `(n.user_id = ? OR (n.user_id IS NULL AND (n.audience = 'all' OR n.audience = ?)))
          AND NOT EXISTS (SELECT 1 FROM notification_hidden h WHERE h.notification_id = n.id AND h.user_id = ?)`,
    params: [reader.id, ROLE_AUDIENCE[reader.role] || '__none__', reader.id],
  };
}

function selectFor(readerId) {
  return {
    sql: `SELECT n.*, EXISTS (SELECT 1 FROM notification_reads r
                                WHERE r.notification_id = n.id AND r.user_id = ?) AS read_by_reader
            FROM notifications n`,
    params: [readerId || '__none__'],
  };
}

/** Forme de `AppNotification.toJson()` ; « lu » est propre à chaque lecteur. */
function present(row) {
  return {
    id: row.id,
    userId: row.user_id || null,
    title: row.title,
    body: row.body || '',
    type: row.type,
    isRead: row.user_id ? Boolean(row.is_read) : Boolean(row.read_by_reader),
    route: row.route || null,
    imageUrl: row.image_url || null,
    createdAt: iso(row.created_at),
    audience: row.user_id ? null : row.audience,
    campaignId: row.campaign_id || null,
  };
}

async function readerOf(userId, actor) {
  requireUser(actor);
  if (!isAdmin(actor) && actor.id !== userId) forbid();
  const user = userId === actor.id ? { id: actor.id, role: actor.role } : await findUser(userId);
  if (!user) throw new HttpError(404, `Utilisateur introuvable (${userId}).`);
  return { id: user.id, role: user.role };
}

async function findVisibleRow(id, reader) {
  const select = selectFor(reader.id);
  const visible = visibleTo(reader);
  const rows = await query(`${select.sql} WHERE n.id = ? AND ${visible.sql} LIMIT 1`, [
    ...select.params,
    id,
    ...visible.params,
  ]);
  return rows[0] || null;
}

async function findRow(id, readerId = null) {
  const select = selectFor(readerId);
  const rows = await query(`${select.sql} WHERE n.id = ? LIMIT 1`, [...select.params, id]);
  return rows[0] || null;
}

/** Ligne lisible par l'appelant (admin : toutes), sinon 404. */
async function accessibleRow(id, actor) {
  requireUser(actor);
  const row = isAdmin(actor) ? await findRow(id, actor.id) : await findVisibleRow(id, actor);
  if (!row) throw new HttpError(404, MESSAGES.notFound(id));
  return row;
}

// ── Préférences ─────────────────────────────────────────────────────────────

function defaultSettings(userId) {
  return {
    userId,
    types: Object.fromEntries(NOTIFICATION_TYPES.map((type) => [type, true])),
    channels: [...DEFAULT_CHANNELS],
    updatedAt: null,
  };
}

async function loadSettings(userId) {
  const rows = await query('SELECT * FROM notification_settings WHERE user_id = ? LIMIT 1', [userId]);
  const base = defaultSettings(userId);
  if (!rows[0]) return base;
  const types = json(rows[0].types, {});
  return {
    userId,
    types: Object.fromEntries(NOTIFICATION_TYPES.map((type) => [type, types[type] !== false])),
    channels: json(rows[0].channels, base.channels).filter((c) => CHANNELS.includes(c)),
    updatedAt: iso(rows[0].updated_at),
  };
}

async function getSettings(userId, actor) {
  const reader = await readerOf(userId, actor);
  return loadSettings(reader.id);
}

/** Écran « Préférences » : catégories activées et canaux (push, e-mail, SMS). */
async function saveSettings(userId, body, actor) {
  const reader = await readerOf(userId, actor);
  const current = await loadSettings(reader.id);
  const b = body || {};
  const types = { ...current.types };
  if (b.types !== undefined) {
    if (!b.types || typeof b.types !== 'object' || Array.isArray(b.types)) {
      throw new HttpError(422, MESSAGES.badSettings);
    }
    for (const [type, enabled] of Object.entries(b.types)) {
      oneOf(type, NOTIFICATION_TYPES, MESSAGES.badType);
      if (typeof enabled !== 'boolean') throw new HttpError(422, MESSAGES.badSettings);
      types[type] = enabled;
    }
  }
  let channels = current.channels;
  if (b.channels !== undefined) {
    if (!Array.isArray(b.channels) || b.channels.some((c) => !CHANNELS.includes(c))) {
      throw new HttpError(422, MESSAGES.badSettings);
    }
    channels = [...new Set(b.channels)];
  }
  const now = nowIso();
  await query(
    `INSERT INTO notification_settings (user_id, types, channels, updated_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET types = excluded.types, channels = excluded.channels, updated_at = excluded.updated_at`,
    [reader.id, JSON.stringify(types), JSON.stringify(channels), now],
  );
  return loadSettings(reader.id);
}

// ── Liste & compteur ────────────────────────────────────────────────────────

/**
 * `GET /users/:id/notifications` : personnelles + envoyées à tous, les plus
 * récentes d'abord, sans les catégories désactivées dans les préférences.
 */
async function forUser(userId, actor, filters = {}) {
  const reader = await readerOf(userId, actor);
  await campagnes.processDue();
  const settings = await loadSettings(reader.id);
  const disabled = NOTIFICATION_TYPES.filter((type) => settings.types[type] === false);
  const select = selectFor(reader.id);
  const visible = visibleTo(reader);
  const where = [visible.sql];
  const params = [...visible.params];
  if (disabled.length) {
    where.push(`n.type NOT IN (${disabled.map(() => '?').join(',')})`);
    params.push(...disabled);
  }
  if (text(filters.type)) {
    where.push('n.type = ?');
    params.push(oneOf(text(filters.type), NOTIFICATION_TYPES, MESSAGES.badType));
  }
  const rows = await query(
    `${select.sql} WHERE ${where.join(' AND ')} ORDER BY n.created_at DESC, n.id DESC`,
    [...select.params, ...params],
  );
  let list = rows.map(present);
  if (filters.unread === 'true') list = list.filter((n) => !n.isRead);
  return list;
}

async function unreadCount(userId, actor) {
  const list = await forUser(userId, actor);
  const byType = Object.fromEntries(NOTIFICATION_TYPES.map((type) => [type, 0]));
  for (const n of list) if (!n.isRead) byType[n.type] += 1;
  return { userId, unread: list.filter((n) => !n.isRead).length, byType };
}

/** `GET /notifications` : admin → toutes (filtres) ; sinon celles de l'appelant. */
async function list(filters, actor) {
  requireUser(actor);
  if (!isAdmin(actor)) return forUser(actor.id, actor, filters);
  await campagnes.processDue();
  const where = [];
  const params = [];
  if (text(filters.userId)) {
    where.push('n.user_id = ?');
    params.push(text(filters.userId));
  }
  if (filters.broadcast === 'true') where.push('n.user_id IS NULL');
  if (text(filters.type)) {
    where.push('n.type = ?');
    params.push(oneOf(text(filters.type), NOTIFICATION_TYPES, MESSAGES.badType));
  }
  if (text(filters.campaignId)) {
    where.push('n.campaign_id = ?');
    params.push(text(filters.campaignId));
  }
  const select = selectFor(actor.id);
  const rows = await query(
    `${select.sql}${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY n.created_at DESC, n.id DESC`,
    [...select.params, ...params],
  );
  return rows.map(present);
}

async function get(id, actor) {
  return present(await accessibleRow(id, actor));
}

// ── Création & modification ─────────────────────────────────────────────────

function cleanContent(b, current = {}) {
  const title = b.title !== undefined ? text(b.title) : current.title;
  const body = b.body !== undefined ? (typeof b.body === 'string' ? b.body.trim() : '') : current.body || '';
  if (!title) throw new HttpError(422, MESSAGES.titleRequired);
  if (title.length > LIMITS.title) throw new HttpError(422, MESSAGES.titleTooLong);
  if (body.length > LIMITS.body) throw new HttpError(422, MESSAGES.bodyTooLong);
  const type = oneOf(b.type ?? current.type ?? 'system', NOTIFICATION_TYPES, MESSAGES.badType);
  const route = b.route !== undefined ? text(b.route) || null : current.route || null;
  if (route && (!route.startsWith('/') || route.length > LIMITS.route)) throw new HttpError(422, MESSAGES.badRoute);
  const imageUrl = b.imageUrl !== undefined ? text(b.imageUrl) || null : current.image_url || null;
  if (imageUrl && imageUrl.length > LIMITS.imageUrl) throw new HttpError(422, 'Lien d’image trop long.');
  return { title, body, type, route, imageUrl };
}

/**
 * `POST /notifications`. Un utilisateur crée les siennes (confirmation de
 * commande, annulation d'une suppression avec le même id). L'admin peut
 * écrire à n'importe qui, ou à tous (`userId: null`, `audience`).
 */
async function create(body, actor) {
  requireUser(actor);
  const b = body || {};
  const admin = isAdmin(actor);
  const userId = b.userId === undefined ? actor.id : b.userId || null;
  if (!admin && userId !== actor.id) forbid(MESSAGES.ownOnly);
  if (userId && !(await findUser(userId))) throw new HttpError(404, `Utilisateur introuvable (${userId}).`);
  const content = cleanContent(b);
  const audience = userId ? 'all' : oneOf(b.audience || 'all', AUDIENCES, MESSAGES.badAudience);

  // Annulation d'une suppression : on garde l'id et la date d'origine.
  const requestedId = text(b.id);
  let id = newId('n');
  if (requestedId) {
    if (!/^[\w-]{1,64}$/.test(requestedId)) throw new HttpError(422, 'Identifiant invalide.');
    if (await findRow(requestedId)) throw new HttpError(409, MESSAGES.idTaken);
    id = requestedId;
  }
  let createdAt = parseDateInput(b.createdAt, MESSAGES.badDate) || nowIso();
  if (new Date(createdAt) > new Date()) createdAt = nowIso();

  await query(
    `INSERT INTO notifications (id, user_id, audience, title, body, type, is_read, route, image_url, campaign_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)`,
    [id, userId, audience, content.title, content.body, content.type, userId && b.isRead === true ? 1 : 0,
      content.route, content.imageUrl, createdAt],
  );
  // Une restauration de notification déjà lue reste lue pour son destinataire.
  return present(await findRow(id, actor.id));
}

/** Notification interne (avis publié, réponse…), sans contrôle d'appelant. */
async function notify(userId, { title, body = '', type = 'system', route = null, imageUrl = null }) {
  if (!userId) return null;
  const id = newId('n');
  await query(
    `INSERT INTO notifications (id, user_id, audience, title, body, type, is_read, route, image_url, campaign_id, created_at)
     VALUES (?, ?, 'all', ?, ?, ?, 0, ?, ?, NULL, ?)`,
    [id, userId, String(title).slice(0, LIMITS.title), String(body).slice(0, LIMITS.body), type, route, imageUrl, nowIso()],
  );
  return id;
}

/** `PUT /notifications/:id` : le destinataire ne change que « lu » ; l'admin, tout. */
async function update(id, body, actor) {
  const row = await accessibleRow(id, actor);
  const b = body || {};
  if (isAdmin(actor)) {
    const content = cleanContent(b, row);
    await query('UPDATE notifications SET title = ?, body = ?, type = ?, route = ?, image_url = ? WHERE id = ?', [
      content.title, content.body, content.type, content.route, content.imageUrl, id,
    ]);
  } else {
    const content = cleanContent(b, row);
    const changed =
      content.title !== row.title || content.body !== (row.body || '') || content.type !== row.type ||
      content.route !== (row.route || null) || content.imageUrl !== (row.image_url || null);
    if (changed) forbid('Seul l’état « lu » d’une notification reçue peut être modifié.');
  }
  if (typeof b.isRead === 'boolean') await setRead(row, actor.id, b.isRead);
  return present(await findRow(id, actor.id));
}

async function setRead(row, readerId, read) {
  if (row.user_id) {
    await query('UPDATE notifications SET is_read = ? WHERE id = ?', [read ? 1 : 0, row.id]);
  } else if (read) {
    await query('INSERT OR IGNORE INTO notification_reads (notification_id, user_id, read_at) VALUES (?, ?, ?)', [
      row.id, readerId, nowIso(),
    ]);
  } else {
    await query('DELETE FROM notification_reads WHERE notification_id = ? AND user_id = ?', [row.id, readerId]);
  }
}

/** `PATCH /notifications/:id/read`. */
async function markRead(id, actor) {
  const row = await accessibleRow(id, actor);
  await setRead(row, actor.id, true);
  return present(await findRow(id, actor.id));
}

/** `POST /users/:id/notifications/read-all`. */
async function markAllRead(userId, actor) {
  const reader = await readerOf(userId, actor);
  const visible = visibleTo(reader);
  const now = nowIso();
  await withTransaction(async () => {
    await query('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0', [reader.id]);
    await query(
      `INSERT OR IGNORE INTO notification_reads (notification_id, user_id, read_at)
       SELECT n.id, ?, ? FROM notifications n WHERE n.user_id IS NULL AND ${visible.sql}`,
      [reader.id, now, ...visible.params],
    );
  });
  return unreadCount(reader.id, actor);
}

/**
 * `DELETE /notifications/:id`. Notification personnelle : supprimée.
 * Envoyée à tous : supprimée par l'admin, masquée pour un destinataire.
 */
async function remove(id, actor) {
  const row = await accessibleRow(id, actor);
  if (row.user_id || isAdmin(actor)) {
    if (row.user_id && !isAdmin(actor) && row.user_id !== actor.id) forbid();
    await withTransaction(async () => {
      await query('DELETE FROM notification_reads WHERE notification_id = ?', [id]);
      await query('DELETE FROM notification_hidden WHERE notification_id = ?', [id]);
      await query('DELETE FROM notifications WHERE id = ?', [id]);
    });
    return;
  }
  await query('INSERT OR IGNORE INTO notification_hidden (notification_id, user_id, hidden_at) VALUES (?, ?, ?)', [
    id, actor.id, nowIso(),
  ]);
}

/** Supprime toutes les notifications lues de l'utilisateur (masque les campagnes lues). */
async function clearRead(userId, actor) {
  const reader = await readerOf(userId, actor);
  const visible = visibleTo(reader);
  const now = nowIso();
  await withTransaction(async () => {
    await query('DELETE FROM notifications WHERE user_id = ? AND is_read = 1', [reader.id]);
    await query(
      `INSERT OR IGNORE INTO notification_hidden (notification_id, user_id, hidden_at)
       SELECT n.id, ?, ? FROM notifications n
        WHERE n.user_id IS NULL AND ${visible.sql}
          AND EXISTS (SELECT 1 FROM notification_reads r WHERE r.notification_id = n.id AND r.user_id = ?)`,
      [reader.id, now, ...visible.params, reader.id],
    );
  });
  return forUser(reader.id, actor);
}

module.exports = {
  forUser,
  unreadCount,
  list,
  get,
  create,
  notify,
  update,
  markRead,
  markAllRead,
  remove,
  clearRead,
  getSettings,
  saveSettings,
};
