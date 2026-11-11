'use strict';

const { query } = require('../../data/db');

/**
 * Tables du module Avis & Notifications. Elles sont créées ici (et non dans
 * `data/db.js`) pour ne toucher à aucun autre module.
 */
const STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS reviews (
     id TEXT PRIMARY KEY,
     restaurant_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     user_name TEXT NOT NULL,
     user_avatar TEXT,
     order_id TEXT,
     rating INTEGER NOT NULL,
     food_rating INTEGER,
     delivery_rating INTEGER,
     packaging_rating INTEGER,
     comment TEXT NOT NULL DEFAULT '',
     photos TEXT NOT NULL DEFAULT '[]',
     status TEXT NOT NULL DEFAULT 'pending',
     reply_text TEXT,
     reply_author TEXT,
     reply_author_id TEXT,
     reply_at TEXT,
     helpful_count INTEGER NOT NULL DEFAULT 0,
     report_count INTEGER NOT NULL DEFAULT 0,
     moderated_by TEXT,
     moderated_at TEXT,
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
  'CREATE INDEX IF NOT EXISTS idx_reviews_restaurant ON reviews (restaurant_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews (user_id)',
  // Un seul avis par commande et par client.
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_order ON reviews (user_id, order_id) WHERE order_id IS NOT NULL',
  `CREATE TABLE IF NOT EXISTS review_votes (
     review_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     created_at TEXT NOT NULL,
     PRIMARY KEY (review_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS review_reports (
     review_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     reason TEXT,
     created_at TEXT NOT NULL,
     PRIMARY KEY (review_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS notifications (
     id TEXT PRIMARY KEY,
     user_id TEXT,
     audience TEXT NOT NULL DEFAULT 'all',
     title TEXT NOT NULL,
     body TEXT NOT NULL DEFAULT '',
     type TEXT NOT NULL DEFAULT 'system',
     is_read INTEGER NOT NULL DEFAULT 0,
     route TEXT,
     image_url TEXT,
     campaign_id TEXT,
     created_at TEXT NOT NULL
   )`,
  'CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, created_at)',
  // Lu / masqué par destinataire pour les notifications envoyées à tous.
  `CREATE TABLE IF NOT EXISTS notification_reads (
     notification_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     read_at TEXT NOT NULL,
     PRIMARY KEY (notification_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS notification_hidden (
     notification_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     hidden_at TEXT NOT NULL,
     PRIMARY KEY (notification_id, user_id)
   )`,
  `CREATE TABLE IF NOT EXISTS notification_campaigns (
     id TEXT PRIMARY KEY,
     title TEXT NOT NULL,
     body TEXT NOT NULL DEFAULT '',
     audience TEXT NOT NULL DEFAULT 'all',
     status TEXT NOT NULL DEFAULT 'draft',
     scheduled_at TEXT,
     sent_at TEXT,
     recipient_count INTEGER NOT NULL DEFAULT 0,
     created_by TEXT,
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
  `CREATE TABLE IF NOT EXISTS notification_settings (
     user_id TEXT PRIMARY KEY,
     types TEXT NOT NULL,
     channels TEXT NOT NULL,
     updated_at TEXT NOT NULL
   )`,
];

/** Tables à vider entre deux tests (non gérées par `db.reset()`). */
const TABLES = [
  'reviews',
  'review_votes',
  'review_reports',
  'notifications',
  'notification_reads',
  'notification_hidden',
  'notification_campaigns',
  'notification_settings',
];

let ready = false;

async function ensureSchema() {
  if (ready) return;
  for (const statement of STATEMENTS) await query(statement);
  ready = true;
}

function schemaReady(_req, _res, next) {
  ensureSchema().then(() => next(), next);
}

/** Vide les tables du module (tests). */
async function clear() {
  await ensureSchema();
  for (const table of TABLES) await query(`DELETE FROM ${table}`);
}

module.exports = { ensureSchema, schemaReady, clear, TABLES };
