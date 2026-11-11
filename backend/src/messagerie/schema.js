'use strict';

const { query } = require('../data/db');

/**
 * Messagerie : conversations, participants (non lus par personne) et messages.
 */
const STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS chats (
     id TEXT PRIMARY KEY,
     type TEXT NOT NULL,
     title TEXT NOT NULL,
     subtitle TEXT,
     avatar_url TEXT,
     order_id TEXT,
     created_by TEXT NOT NULL,
     last_message TEXT,
     last_message_at TEXT NOT NULL,
     is_flagged INTEGER NOT NULL DEFAULT 0,
     created_at TEXT NOT NULL
   )`,
  'CREATE INDEX IF NOT EXISTS idx_chats_order ON chats (order_id)',
  `CREATE TABLE IF NOT EXISTS chat_participants (
     chat_id TEXT NOT NULL,
     user_id TEXT NOT NULL,
     unread_count INTEGER NOT NULL DEFAULT 0,
     last_seen_at TEXT,
     PRIMARY KEY (chat_id, user_id)
   )`,
  'CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants (user_id)',
  `CREATE TABLE IF NOT EXISTS chat_messages (
     id TEXT PRIMARY KEY,
     chat_id TEXT NOT NULL,
     sender_id TEXT NOT NULL,
     sender_name TEXT NOT NULL,
     text TEXT NOT NULL,
     status TEXT NOT NULL DEFAULT 'sent',
     is_system INTEGER NOT NULL DEFAULT 0,
     sent_at TEXT NOT NULL,
     edited_at TEXT
   )`,
  'CREATE INDEX IF NOT EXISTS idx_chat_messages_chat ON chat_messages (chat_id, sent_at)',
];

let ready = null;

function ensureSchema() {
  if (!ready) {
    ready = (async () => {
      for (const sql of STATEMENTS) await query(sql);
    })().catch((error) => {
      ready = null;
      throw error;
    });
  }
  return ready;
}

function schemaReady(_req, _res, next) {
  ensureSchema().then(() => next(), next);
}

async function clear() {
  await ensureSchema();
  for (const table of ['chat_messages', 'chat_participants', 'chats']) {
    await query(`DELETE FROM ${table}`);
  }
}

module.exports = { ensureSchema, schemaReady, clear };
