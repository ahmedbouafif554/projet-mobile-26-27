'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId } = require('../../data/db');
const { text, oneOf } = require('../../domain/validate');
const {
  AUDIENCES,
  CAMPAIGN_STATUSES,
  AUDIENCE_ROLE,
  LIMITS,
  MESSAGES,
} = require('../domain/notification.constants');
const { nowIso, iso, parseDateInput, requireAdmin } = require('./common');

// ── Présentation ────────────────────────────────────────────────────────────

/** Forme de `NotificationCampaign.toJson()` ; taux d'ouverture calculé en direct. */
function present(row, opened = 0) {
  const recipients = Number(row.recipient_count) || 0;
  return {
    id: row.id,
    title: row.title,
    body: row.body || '',
    audience: row.audience,
    status: row.status,
    scheduledAt: iso(row.scheduled_at),
    sentAt: iso(row.sent_at),
    recipientCount: recipients,
    openedCount: opened,
    openRate: recipients > 0 ? Math.min(1, Math.round((opened / recipients) * 1000) / 1000) : 0,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
  };
}

async function openedCounts(ids) {
  if (ids.length === 0) return new Map();
  const rows = await query(
    `SELECT n.campaign_id AS id, COUNT(r.user_id) AS opened
       FROM notifications n JOIN notification_reads r ON r.notification_id = n.id
      WHERE n.campaign_id IN (${ids.map(() => '?').join(',')})
      GROUP BY n.campaign_id`,
    ids,
  );
  return new Map(rows.map((row) => [row.id, Number(row.opened) || 0]));
}

async function presentRows(rows) {
  const opened = await openedCounts(rows.map((row) => row.id));
  return rows.map((row) => present(row, opened.get(row.id) || 0));
}

async function findRow(id) {
  const rows = await query('SELECT * FROM notification_campaigns WHERE id = ? LIMIT 1', [id]);
  return rows[0] || null;
}

async function mustFindRow(id) {
  const row = await findRow(id);
  if (!row) throw new HttpError(404, MESSAGES.campaignNotFound(id));
  return row;
}

// ── Envoi ───────────────────────────────────────────────────────────────────

/** Comptes actifs visés par une audience. */
async function countRecipients(audience) {
  const role = AUDIENCE_ROLE[audience];
  const rows = role
    ? await query("SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND role = ?", [role])
    : await query("SELECT COUNT(*) AS n FROM users WHERE status = 'active' AND role <> 'admin'");
  return Number(rows[0]?.n) || 0;
}

/**
 * Envoi : une notification « à tous » (userId null) limitée à l'audience,
 * lue et masquée par destinataire. La campagne passe « envoyée ».
 */
async function deliver(row) {
  const now = nowIso();
  const recipients = await countRecipients(row.audience);
  await withTransaction(async () => {
    const fresh = await query('SELECT status FROM notification_campaigns WHERE id = ?', [row.id]);
    if (!fresh[0] || fresh[0].status === 'sent') return;
    await query(
      `UPDATE notification_campaigns
          SET status = 'sent', sent_at = ?, recipient_count = ?, updated_at = ?
        WHERE id = ? AND status <> 'sent'`,
      [now, recipients, now, row.id],
    );
    await query(
      `INSERT INTO notifications (id, user_id, audience, title, body, type, is_read, route, image_url, campaign_id, created_at)
       VALUES (?, NULL, ?, ?, ?, 'promo', 0, NULL, NULL, ?, ?)`,
      [newId('n'), row.audience, row.title, row.body || '', row.id, now],
    );
  });
}

let processing = null;

/** Envoie les campagnes programmées dont l'heure est passée. */
async function processDue() {
  if (processing) return processing;
  processing = (async () => {
    const due = await query(
      "SELECT * FROM notification_campaigns WHERE status = 'scheduled' AND scheduled_at IS NOT NULL AND scheduled_at <= ?",
      [nowIso()],
    );
    for (const row of due) await deliver(row);
  })();
  try {
    await processing;
  } finally {
    processing = null;
  }
}

// ── Validation ──────────────────────────────────────────────────────────────

function cleanFields(body, current = {}) {
  const title = body.title !== undefined ? text(body.title) : current.title;
  const content = body.body !== undefined ? text(body.body) : current.body;
  if (!title) throw new HttpError(422, MESSAGES.titleRequired);
  if (title.length > LIMITS.title) throw new HttpError(422, MESSAGES.titleTooLong);
  if (!content) throw new HttpError(422, MESSAGES.bodyRequired);
  if (content.length > LIMITS.body) throw new HttpError(422, MESSAGES.bodyTooLong);
  const audience = oneOf(body.audience ?? current.audience ?? 'all', AUDIENCES, MESSAGES.badAudience);
  const scheduledAt =
    body.scheduledAt !== undefined
      ? parseDateInput(body.scheduledAt, MESSAGES.badDate)
      : iso(current.scheduled_at);
  const status = oneOf(body.status ?? current.status ?? 'draft', CAMPAIGN_STATUSES, MESSAGES.badCampaignStatus);
  // Le formulaire envoie « programmée » avec une date, « brouillon » sans.
  if (status === 'scheduled' && !scheduledAt) throw new HttpError(422, MESSAGES.scheduleRequired);
  if (status === 'scheduled' && new Date(scheduledAt) <= new Date()) {
    throw new HttpError(422, MESSAGES.scheduleInPast);
  }
  return { title, body: content, audience, scheduledAt, status };
}

// ── CRUD ────────────────────────────────────────────────────────────────────

async function list(filters, actor) {
  requireAdmin(actor);
  await processDue();
  const where = [];
  const params = [];
  if (text(filters.status)) {
    where.push('status = ?');
    params.push(oneOf(text(filters.status), CAMPAIGN_STATUSES, MESSAGES.badCampaignStatus));
  }
  if (text(filters.audience)) {
    where.push('audience = ?');
    params.push(oneOf(text(filters.audience), AUDIENCES, MESSAGES.badAudience));
  }
  const rows = await query(
    `SELECT * FROM notification_campaigns${where.length ? ` WHERE ${where.join(' AND ')}` : ''}
      ORDER BY COALESCE(sent_at, scheduled_at, created_at) DESC`,
    params,
  );
  return presentRows(rows);
}

async function get(id, actor) {
  requireAdmin(actor);
  await processDue();
  return (await presentRows([await mustFindRow(id)]))[0];
}

/**
 * `POST /campaigns` (formulaire ou « dupliquer »). Une campagne créée
 * directement « envoyée » part tout de suite.
 */
async function create(body, actor) {
  requireAdmin(actor);
  const fields = cleanFields(body || {});
  const id = newId('camp');
  const now = nowIso();
  await query(
    `INSERT INTO notification_campaigns
       (id, title, body, audience, status, scheduled_at, sent_at, recipient_count, created_by, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, NULL, 0, ?, ?, ?)`,
    [id, fields.title, fields.body, fields.audience, fields.status === 'sent' ? 'draft' : fields.status,
      fields.scheduledAt, actor.id, now, now],
  );
  if (fields.status === 'sent') await deliver(await mustFindRow(id));
  return get(id, actor);
}

/** `PUT /campaigns/:id` : impossible une fois envoyée. */
async function update(id, body, actor) {
  requireAdmin(actor);
  await processDue();
  const current = await mustFindRow(id);
  const b = body || {};
  if (current.status === 'sent') {
    const unchanged =
      (b.title === undefined || text(b.title) === current.title) &&
      (b.body === undefined || text(b.body) === current.body) &&
      (b.audience === undefined || b.audience === current.audience);
    if (!unchanged) throw new HttpError(409, MESSAGES.sentLocked);
    return get(id, actor);
  }
  const fields = cleanFields(b, current);
  await query(
    `UPDATE notification_campaigns
        SET title = ?, body = ?, audience = ?, status = ?, scheduled_at = ?, updated_at = ?
      WHERE id = ?`,
    [fields.title, fields.body, fields.audience, fields.status === 'sent' ? current.status : fields.status,
      fields.scheduledAt, nowIso(), id],
  );
  if (fields.status === 'sent') await deliver(await mustFindRow(id));
  return get(id, actor);
}

/** Supprime la campagne ; les notifications déjà reçues restent chez les destinataires. */
async function remove(id, actor) {
  requireAdmin(actor);
  await mustFindRow(id);
  await query('DELETE FROM notification_campaigns WHERE id = ?', [id]);
}

/** `PATCH /campaigns/:id/send` : envoi immédiat. */
async function send(id, actor) {
  requireAdmin(actor);
  const row = await mustFindRow(id);
  if (row.status === 'sent') throw new HttpError(409, MESSAGES.alreadySent);
  await deliver(row);
  return get(id, actor);
}

module.exports = {
  list,
  get,
  create,
  update,
  remove,
  send,
  processDue,
  countRecipients,
};
