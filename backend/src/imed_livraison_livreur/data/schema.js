'use strict';

const { query } = require('../../data/db');

/**
 * Colonnes et tables propres au module livraison & livreur.
 * La table `deliveries` est créée par `data/db.js` ; on y ajoute seulement
 * des colonnes (rien n'est supprimé ni renommé), et deux tables à nous.
 */
const DELIVERY_COLUMNS = [
  ['assigned_at', 'TEXT'],
  ['picked_up_at', 'TEXT'],
  ['cancel_reason', 'TEXT'],
  // Copie des libellés envoyés par le front (si la commande n'a pas de jointure).
  ['pickup_name', 'TEXT'],
  ['pickup_address', 'TEXT'],
  ['customer_name', 'TEXT'],
  ['dropoff_address', 'TEXT'],
];

const TABLES = `
  CREATE TABLE IF NOT EXISTS delivery_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    delivery_id TEXT NOT NULL,
    status TEXT NOT NULL,
    note TEXT,
    actor_id TEXT,
    created_at TEXT NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_delivery_events_delivery ON delivery_events (delivery_id);

  CREATE TABLE IF NOT EXISTS delivery_declines (
    delivery_id TEXT NOT NULL,
    courier_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (delivery_id, courier_id)
  );
`;

let ready = false;

async function ensureSchema() {
  if (ready) return;
  for (const statement of TABLES.split(';').map((s) => s.trim()).filter(Boolean)) {
    await query(statement);
  }
  for (const [column, type] of DELIVERY_COLUMNS) {
    try {
      await query(`ALTER TABLE deliveries ADD COLUMN ${column} ${type}`);
    } catch (error) {
      if (!/duplicate column/i.test(String(error.message))) throw error;
    }
  }
  ready = true;
}

/** Middleware Express : garantit le schéma avant la première requête. */
function schemaReady(_req, _res, next) {
  ensureSchema().then(() => next(), next);
}

/** À appeler si la base est fermée puis rouverte sur un autre fichier. */
function invalidate() {
  ready = false;
}

module.exports = { ensureSchema, schemaReady, invalidate };
