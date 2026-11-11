'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId } = require('../../data/db');
const { text, oneOf } = require('../../domain/validate');
const {
  REVIEW_STATUSES,
  LIMITS,
  ADMIN_REPLY_AUTHOR,
  MESSAGES,
} = require('../domain/avis.constants');
const {
  nowIso,
  iso,
  json,
  isAdmin,
  forbid,
  requireUser,
  requireAdmin,
  findUser,
  ownsRestaurant,
  ownedRestaurantIds,
} = require('./common');
const notifications = require('./notification.service');

// ── Présentation ────────────────────────────────────────────────────────────

/** Forme de `Review.toJson()`. */
function present(row) {
  return {
    id: row.id,
    restaurantId: row.restaurant_id,
    restaurantName: row.restaurant_name || null,
    userId: row.user_id,
    userName: row.user_name,
    userAvatar: row.user_avatar || null,
    orderId: row.order_id || null,
    rating: Number(row.rating),
    foodRating: row.food_rating == null ? null : Number(row.food_rating),
    deliveryRating: row.delivery_rating == null ? null : Number(row.delivery_rating),
    packagingRating: row.packaging_rating == null ? null : Number(row.packaging_rating),
    comment: row.comment || '',
    photos: json(row.photos, []),
    status: row.status,
    reply: row.reply_text
      ? { text: row.reply_text, authorName: row.reply_author || '', at: iso(row.reply_at) }
      : null,
    helpfulCount: Number(row.helpful_count) || 0,
    reportCount: Number(row.report_count) || 0,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

const SELECT = `SELECT rv.*, r.name AS restaurant_name FROM reviews rv
                LEFT JOIN restaurants r ON r.id = rv.restaurant_id`;

async function findRow(id) {
  const rows = await query(`${SELECT} WHERE rv.id = ? LIMIT 1`, [id]);
  return rows[0] || null;
}

// ── Visibilité ──────────────────────────────────────────────────────────────

/**
 * - admin : tout ;
 * - restaurateur : avis publiés + tous les avis de ses restaurants ;
 * - client / livreur : avis publiés + les siens ;
 * - sans jeton : avis publiés.
 */
async function scopeFor(actor) {
  if (isAdmin(actor)) return { where: [], params: [] };
  if (actor.anonymous) return { where: ["rv.status = 'approved'"], params: [] };
  if (actor.role === 'restaurant') {
    const owned = await ownedRestaurantIds(actor);
    if (owned.length === 0) return { where: ["rv.status = 'approved'"], params: [] };
    return {
      where: [`(rv.status = 'approved' OR rv.restaurant_id IN (${owned.map(() => '?').join(',')}))`],
      params: owned,
    };
  }
  return { where: ["(rv.status = 'approved' OR rv.user_id = ?)"], params: [actor.id] };
}

async function canSee(actor, row) {
  if (row.status === 'approved' || isAdmin(actor)) return true;
  if (actor.anonymous) return false;
  if (row.user_id === actor.id) return true;
  return ownsRestaurant(actor, row.restaurant_id);
}

async function visibleRow(id, actor) {
  const row = await findRow(id);
  // Un avis non publié n'existe pas pour qui ne peut pas le voir.
  if (!row || !(await canSee(actor, row))) throw new HttpError(404, MESSAGES.notFound(id));
  return row;
}

// ── Lecture ─────────────────────────────────────────────────────────────────

async function list(filters, actor) {
  const { where, params } = await scopeFor(actor);
  if (text(filters.restaurantId)) {
    where.push('rv.restaurant_id = ?');
    params.push(text(filters.restaurantId));
  }
  if (text(filters.userId)) {
    where.push('rv.user_id = ?');
    params.push(text(filters.userId));
  }
  if (text(filters.orderId)) {
    where.push('rv.order_id = ?');
    params.push(text(filters.orderId));
  }
  if (text(filters.status)) {
    where.push('rv.status = ?');
    params.push(oneOf(text(filters.status), REVIEW_STATUSES, MESSAGES.badStatus));
  }
  const minRating = Number(filters.minRating);
  if (Number.isInteger(minRating) && minRating >= 1 && minRating <= 5) {
    where.push('rv.rating >= ?');
    params.push(minRating);
  }
  if (filters.reported === 'true') where.push('rv.report_count > 0');
  if (filters.unanswered === 'true') where.push("rv.status = 'approved' AND rv.reply_text IS NULL");
  if (text(filters.q)) {
    where.push('(rv.comment LIKE ? OR rv.user_name LIKE ?)');
    params.push(`%${text(filters.q)}%`, `%${text(filters.q)}%`);
  }
  // Les avis signalés remontent en premier pour la modération admin.
  const order = isAdmin(actor) && filters.sort === 'reports'
    ? 'rv.report_count DESC, rv.created_at DESC'
    : 'rv.created_at DESC, rv.id DESC';
  const rows = await query(`${SELECT}${where.length ? ` WHERE ${where.join(' AND ')}` : ''} ORDER BY ${order}`, params);
  return rows.map(present);
}

async function mustFindRestaurant(id) {
  const rows = await query('SELECT id, name FROM restaurants WHERE id = ? LIMIT 1', [id]);
  if (!rows[0]) throw new HttpError(404, MESSAGES.restaurantNotFound(id));
  return rows[0];
}

/** `GET /restaurants/:id/reviews` (front office : `?status=approved`). */
async function forRestaurant(restaurantId, filters, actor) {
  await mustFindRestaurant(restaurantId);
  return list({ ...filters, restaurantId }, actor);
}

async function get(id, actor) {
  return present(await visibleRow(id, actor));
}

/** Note moyenne, répartition 1 à 5, moyennes par critère, taux de réponse. */
async function stats(restaurantId, actor) {
  const where = ["status = 'approved'"];
  const params = [];
  if (restaurantId) {
    await mustFindRestaurant(restaurantId);
    where.push('restaurant_id = ?');
    params.push(restaurantId);
  }
  const rows = await query(`SELECT * FROM reviews WHERE ${where.join(' AND ')}`, params);
  const avg = (key) => {
    const values = rows.map((r) => r[key]).filter((v) => v != null).map(Number);
    return values.length ? Math.round((values.reduce((t, v) => t + v, 0) / values.length) * 10) / 10 : null;
  };
  const result = {
    restaurantId: restaurantId || null,
    count: rows.length,
    averageRating: avg('rating') ?? 0,
    averageFood: avg('food_rating'),
    averageDelivery: avg('delivery_rating'),
    averagePackaging: avg('packaging_rating'),
    distribution: Object.fromEntries([1, 2, 3, 4, 5].map((n) => [n, rows.filter((r) => Number(r.rating) === n).length])),
    replyRate: rows.length ? Math.round((rows.filter((r) => r.reply_text).length / rows.length) * 100) / 100 : 0,
  };
  // Les avis en attente ne sont comptés que pour l'admin ou le restaurateur.
  if (isAdmin(actor) || (restaurantId && (await ownsRestaurant(actor, restaurantId)))) {
    const all = await query(
      `SELECT status, COUNT(*) AS n FROM reviews${restaurantId ? ' WHERE restaurant_id = ?' : ''} GROUP BY status`,
      restaurantId ? [restaurantId] : [],
    );
    result.byStatus = Object.fromEntries(REVIEW_STATUSES.map((s) => [s, Number(all.find((a) => a.status === s)?.n) || 0]));
    const reported = await query(
      `SELECT COUNT(*) AS n FROM reviews WHERE report_count > 0${restaurantId ? ' AND restaurant_id = ?' : ''}`,
      restaurantId ? [restaurantId] : [],
    );
    result.reported = Number(reported[0]?.n) || 0;
  }
  return result;
}

// ── Validation ──────────────────────────────────────────────────────────────

function rating(value, message, required) {
  if (value == null || value === '' || (!required && Number(value) === 0)) {
    if (required) throw new HttpError(422, message);
    return null;
  }
  const n = Number(value);
  if (!Number.isInteger(n) || n < 1 || n > 5) throw new HttpError(422, message);
  return n;
}

function cleanPhotos(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > LIMITS.photos) throw new HttpError(422, MESSAGES.badPhotos);
  return [...new Set(value.map((photo) => {
    if (typeof photo !== 'string') throw new HttpError(422, MESSAGES.badPhotos);
    const p = photo.trim();
    const ok = /^https?:\/\//i.test(p) || p.startsWith('data:image/') || p.startsWith('assets/');
    if (!ok || p.length > LIMITS.photoLength) throw new HttpError(422, MESSAGES.badPhotos);
    return p;
  }))];
}

function cleanContent(b, current = null) {
  const pick = (key, column) => (b[key] !== undefined ? b[key] : current ? current[column] : undefined);
  const comment = b.comment !== undefined ? (typeof b.comment === 'string' ? b.comment.trim() : '') : current?.comment || '';
  if (comment.length > LIMITS.comment) throw new HttpError(422, MESSAGES.commentTooLong);
  return {
    rating: rating(pick('rating', 'rating'), MESSAGES.badRating, true),
    food: rating(pick('foodRating', 'food_rating'), MESSAGES.badCriterion('plats'), false),
    delivery: rating(pick('deliveryRating', 'delivery_rating'), MESSAGES.badCriterion('livraison'), false),
    packaging: rating(pick('packagingRating', 'packaging_rating'), MESSAGES.badCriterion('emballage'), false),
    comment,
    photos: b.photos !== undefined ? cleanPhotos(b.photos) : json(current?.photos, []),
  };
}

/** « Prénom N. », comme le formulaire d'avis du front. */
function displayName(user) {
  const initial = user.last_name ? ` ${user.last_name[0]}.` : '';
  return `${user.first_name}${initial}`;
}

// ── Note du restaurant ──────────────────────────────────────────────────────

/** Note et nombre d'avis du restaurant recalculés sur les avis publiés. */
async function refreshRestaurantRating(restaurantId) {
  if (!restaurantId) return;
  const rows = await query(
    "SELECT COUNT(*) AS n, AVG(rating) AS avg FROM reviews WHERE restaurant_id = ? AND status = 'approved'",
    [restaurantId],
  );
  const count = Number(rows[0]?.n) || 0;
  if (count > 0) {
    await query('UPDATE restaurants SET rating = ?, review_count = ? WHERE id = ?', [
      Math.round(Number(rows[0].avg) * 10) / 10,
      count,
      restaurantId,
    ]);
  } else {
    await query('UPDATE restaurants SET review_count = 0 WHERE id = ?', [restaurantId]);
  }
}

// ── Création / modification / suppression ─────────────────────────────────

/**
 * `POST /reviews` (formulaire « Noter ma commande »). Réservé au client, pour
 * une commande à lui et livrée, une seule fois. L'avis part en modération.
 */
async function create(body, actor) {
  requireUser(actor);
  if (actor.role !== 'client') forbid(MESSAGES.onlyClients);
  const b = body || {};
  const user = await findUser(actor.id);
  let restaurantId = text(b.restaurantId);
  const orderId = text(b.orderId) || null;

  if (orderId) {
    const orders = await query('SELECT id, user_id, restaurant_id, status FROM orders WHERE id = ? LIMIT 1', [orderId]);
    const order = orders[0];
    if (!order) throw new HttpError(404, MESSAGES.orderNotFound(orderId));
    if (order.user_id !== actor.id) forbid(MESSAGES.notYourOrder);
    if (order.status !== 'delivered') throw new HttpError(422, MESSAGES.notDelivered);
    if (restaurantId && restaurantId !== order.restaurant_id) throw new HttpError(422, MESSAGES.restaurantMismatch);
    restaurantId = order.restaurant_id;
    const existing = await query('SELECT id FROM reviews WHERE user_id = ? AND order_id = ? LIMIT 1', [actor.id, orderId]);
    if (existing[0]) throw new HttpError(409, MESSAGES.alreadyReviewed);
  } else {
    if (!restaurantId) throw new HttpError(422, MESSAGES.restaurantRequired);
    const delivered = await query(
      "SELECT id FROM orders WHERE user_id = ? AND restaurant_id = ? AND status = 'delivered' LIMIT 1",
      [actor.id, restaurantId],
    );
    if (!delivered[0]) throw new HttpError(422, MESSAGES.noOrderAtRestaurant);
  }
  await mustFindRestaurant(restaurantId);

  const content = cleanContent(b);
  const id = newId('rev');
  const now = nowIso();
  await query(
    `INSERT INTO reviews
       (id, restaurant_id, user_id, user_name, user_avatar, order_id, rating, food_rating,
        delivery_rating, packaging_rating, comment, photos, status, helpful_count, report_count,
        created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0, 0, ?, ?)`,
    [id, restaurantId, actor.id, text(b.userName) || displayName(user), user.avatar_url || null, orderId,
      content.rating, content.food, content.delivery, content.packaging, content.comment,
      JSON.stringify(content.photos), now, now],
  );
  return present(await findRow(id));
}

/**
 * `PUT /reviews/:id` avec le JSON complet de `Review.toJson()` :
 * - l'auteur modifie son avis → il repasse en modération ;
 * - un autre utilisateur envoie `helpfulCount + 1` → vote « Utile » (une fois) ;
 * - l'admin peut aussi changer le statut.
 */
async function update(id, body, actor) {
  requireUser(actor);
  const row = await visibleRow(id, actor);
  const b = body || {};

  if (row.user_id === actor.id || isAdmin(actor)) {
    const content = cleanContent(b, row);
    const changed =
      content.rating !== Number(row.rating) ||
      content.food !== (row.food_rating == null ? null : Number(row.food_rating)) ||
      content.delivery !== (row.delivery_rating == null ? null : Number(row.delivery_rating)) ||
      content.packaging !== (row.packaging_rating == null ? null : Number(row.packaging_rating)) ||
      content.comment !== (row.comment || '') ||
      JSON.stringify(content.photos) !== JSON.stringify(json(row.photos, []));
    if (changed) {
      const status = row.user_id === actor.id ? 'pending' : row.status;
      await query(
        `UPDATE reviews SET rating = ?, food_rating = ?, delivery_rating = ?, packaging_rating = ?,
                comment = ?, photos = ?, status = ?, updated_at = ? WHERE id = ?`,
        [content.rating, content.food, content.delivery, content.packaging, content.comment,
          JSON.stringify(content.photos), status, nowIso(), id],
      );
      if (row.status === 'approved') await refreshRestaurantRating(row.restaurant_id);
    }
    if (isAdmin(actor) && b.status && b.status !== row.status) return moderate(id, b.status, actor);
    return present(await findRow(id));
  }

  // Tout autre appelant ne peut que voter « Utile ».
  if (Number(b.helpfulCount) === (Number(row.helpful_count) || 0) + 1) return markHelpful(id, actor);
  forbid('Vous ne pouvez modifier que vos propres avis.');
}

async function remove(id, actor) {
  requireUser(actor);
  const row = await visibleRow(id, actor);
  if (row.user_id !== actor.id && !isAdmin(actor)) forbid();
  await withTransaction(async () => {
    await query('DELETE FROM review_votes WHERE review_id = ?', [id]);
    await query('DELETE FROM review_reports WHERE review_id = ?', [id]);
    await query('DELETE FROM reviews WHERE id = ?', [id]);
    if (row.status === 'approved') await refreshRestaurantRating(row.restaurant_id);
  });
}

// ── Modération & réponse ────────────────────────────────────────────────────

/** `PATCH /reviews/:id/status` (admin) : publier ou refuser. L'auteur est prévenu. */
async function moderate(id, status, actor) {
  requireAdmin(actor);
  const next = oneOf(status, REVIEW_STATUSES, MESSAGES.badStatus);
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.notFound(id));
  if (row.status === next) return present(row);
  const now = nowIso();
  await withTransaction(async () => {
    await query('UPDATE reviews SET status = ?, moderated_by = ?, moderated_at = ?, updated_at = ? WHERE id = ?', [
      next, actor.id, now, now, id,
    ]);
    await refreshRestaurantRating(row.restaurant_id);
    if (next === 'approved') {
      await notifications.notify(row.user_id, {
        title: 'Votre avis est publié ⭐',
        body: `Merci ! Votre avis sur ${row.restaurant_name || 'le restaurant'} est en ligne.`,
        type: 'review',
        route: `/explore/restaurant/${row.restaurant_id}/reviews`,
      });
      // Le restaurant est prévenu d'un nouvel avis publié.
      const owners = await query(
        `SELECT u.id FROM users u WHERE u.role = 'restaurant' AND u.status = 'active'
            AND (u.restaurant_id = ? OR u.id = (SELECT owner_id FROM restaurants WHERE id = ?))`,
        [row.restaurant_id, row.restaurant_id],
      );
      for (const owner of owners) {
        await notifications.notify(owner.id, {
          title: `Nouvel avis ${'★'.repeat(Number(row.rating))}`,
          body: `${row.user_name} : ${(row.comment || 'sans commentaire').slice(0, 120)}`,
          type: 'review',
          route: '/reviews',
        });
      }
    } else if (next === 'rejected') {
      await notifications.notify(row.user_id, {
        title: "Votre avis n'a pas été publié",
        body: "Il ne respecte pas nos règles de publication. Vous pouvez le modifier et l'envoyer à nouveau.",
        type: 'review',
        route: '/account/reviews',
      });
    }
  });
  return present(await findRow(id));
}

async function assertCanReply(row, actor) {
  if (isAdmin(actor)) return;
  if (!(await ownsRestaurant(actor, row.restaurant_id))) forbid();
}

/**
 * `PATCH /reviews/:id/reply` : réponse publique (restaurateur du restaurant ou
 * admin) à un avis publié. Le nom affiché est fixé par le serveur.
 */
async function reply(id, body, actor) {
  requireUser(actor);
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.notFound(id));
  await assertCanReply(row, actor);
  if (row.status !== 'approved') throw new HttpError(422, MESSAGES.replyNotPublished);
  const content = typeof body?.text === 'string' ? body.text.trim() : '';
  if (!content) throw new HttpError(422, MESSAGES.replyEmpty);
  if (content.length > LIMITS.reply) throw new HttpError(422, MESSAGES.replyTooLong);

  let author = ADMIN_REPLY_AUTHOR;
  if (!isAdmin(actor)) {
    const user = await findUser(actor.id);
    author = `${user.first_name} ${user.last_name}`.trim();
  }
  const now = nowIso();
  const isNew = !row.reply_text;
  await query('UPDATE reviews SET reply_text = ?, reply_author = ?, reply_author_id = ?, reply_at = ?, updated_at = ? WHERE id = ?', [
    content, author, actor.id, now, now, id,
  ]);
  if (isNew) {
    await notifications.notify(row.user_id, {
      title: `${row.restaurant_name || 'Le restaurant'} vous a répondu`,
      body: content.slice(0, 200),
      type: 'review',
      route: `/explore/restaurant/${row.restaurant_id}/reviews`,
    });
  }
  return present(await findRow(id));
}

async function deleteReply(id, actor) {
  requireUser(actor);
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.notFound(id));
  await assertCanReply(row, actor);
  await query(
    'UPDATE reviews SET reply_text = NULL, reply_author = NULL, reply_author_id = NULL, reply_at = NULL, updated_at = ? WHERE id = ?',
    [nowIso(), id],
  );
  return present(await findRow(id));
}

// ── Votes & signalements ────────────────────────────────────────────────────

/** « Utile » : une voix par utilisateur, jamais sur son propre avis (sans erreur). */
async function markHelpful(id, actor) {
  requireUser(actor);
  const row = await visibleRow(id, actor);
  if (row.status !== 'approved') throw new HttpError(422, MESSAGES.notPublished);
  if (row.user_id !== actor.id) {
    await query('INSERT OR IGNORE INTO review_votes (review_id, user_id, created_at) VALUES (?, ?, ?)', [id, actor.id, nowIso()]);
    await query('UPDATE reviews SET helpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = ?) WHERE id = ?', [id, id]);
  }
  return present(await findRow(id));
}

async function unmarkHelpful(id, actor) {
  requireUser(actor);
  await visibleRow(id, actor);
  await query('DELETE FROM review_votes WHERE review_id = ? AND user_id = ?', [id, actor.id]);
  await query('UPDATE reviews SET helpful_count = (SELECT COUNT(*) FROM review_votes WHERE review_id = ?) WHERE id = ?', [id, id]);
  return present(await findRow(id));
}

/** Signalement (priorité de modération dans le back office). */
async function report(id, body, actor) {
  requireUser(actor);
  const row = await visibleRow(id, actor);
  if (row.user_id === actor.id) throw new HttpError(422, 'Vous ne pouvez pas signaler votre propre avis.');
  const reason = typeof body?.reason === 'string' ? body.reason.trim().slice(0, LIMITS.reportReason) : null;
  await query('INSERT OR IGNORE INTO review_reports (review_id, user_id, reason, created_at) VALUES (?, ?, ?, ?)', [
    id, actor.id, reason || null, nowIso(),
  ]);
  await query('UPDATE reviews SET report_count = (SELECT COUNT(*) FROM review_reports WHERE review_id = ?) WHERE id = ?', [id, id]);
  return present(await findRow(id));
}

async function reports(id, actor) {
  requireAdmin(actor);
  if (!(await findRow(id))) throw new HttpError(404, MESSAGES.notFound(id));
  const rows = await query(
    `SELECT rr.*, u.first_name || ' ' || u.last_name AS user_name FROM review_reports rr
       LEFT JOIN users u ON u.id = rr.user_id WHERE rr.review_id = ? ORDER BY rr.created_at DESC`,
    [id],
  );
  return rows.map((r) => ({ userId: r.user_id, userName: r.user_name || null, reason: r.reason || null, createdAt: iso(r.created_at) }));
}

module.exports = {
  list,
  forRestaurant,
  get,
  stats,
  create,
  update,
  remove,
  moderate,
  reply,
  deleteReply,
  markHelpful,
  unmarkHelpful,
  report,
  reports,
};
