'use strict';

const { query, withTransaction, toSqlDate } = require('../data/db');
const {
  RESTAURANT_STATUSES,
  GEO_STATUSES,
  NUTRI_SCORES,
  DEFAULT_CATEGORIES,
} = require('./domain/catalogue.constants');

/**
 * Tables SQLite du module Restaurants & Catalogue.
 *
 * Migration additive et idempotente, lancée au démarrage (et à la première
 * requête du module si besoin) :
 *  - crée `restaurants` / `products` si le schéma commun ne les a pas créées
 *    (mêmes colonnes que le schéma de l'équipe) ;
 *  - ajoute les colonnes du module qui manquent ; les colonnes déjà lues par
 *    le module Commandes ne sont jamais modifiées ;
 *  - crée `categories` (remplie avec les catégories par défaut),
 *    `restaurant_categories`, les caches des API externes (`geocode_cache`,
 *    `barcode_lookups`) et les index.
 *
 * Le schéma est lu avec des SELECT (`sqlite_master`, `pragma_table_info`) :
 * ils renvoient des lignes quel que soit le pilote utilisé par db.js.
 */

const NOW = "(strftime('%Y-%m-%dT%H:%M:%fZ','now'))";
const quoted = (values) => values.map((value) => `'${value}'`).join(',');
const STATUSES = quoted(RESTAURANT_STATUSES);
const GEO = quoted(GEO_STATUSES);
const SCORES = quoted(NUTRI_SCORES);

const BASE_COLUMNS = {
  restaurants: [
    'id          TEXT    NOT NULL PRIMARY KEY',
    'name        TEXT    NOT NULL',
    'description TEXT',
    'address     TEXT',
    'phone       TEXT',
    'email       TEXT',
    'category    TEXT',
    'image_url   TEXT',
    'latitude    REAL    NOT NULL DEFAULT 48.8566',
    'longitude   REAL    NOT NULL DEFAULT 2.3522',
    'rating      REAL    NOT NULL DEFAULT 0.0',
    'is_open     INTEGER NOT NULL DEFAULT 1',
    'owner_id    TEXT',
    `created_at  TEXT    NOT NULL DEFAULT ${NOW}`,
  ],
  products: [
    'id            TEXT    NOT NULL PRIMARY KEY',
    'restaurant_id TEXT    NOT NULL',
    'name          TEXT    NOT NULL',
    'description   TEXT',
    'price         REAL    NOT NULL DEFAULT 0.0',
    'category      TEXT',
    'image_url     TEXT',
    'is_available  INTEGER NOT NULL DEFAULT 1',
    `created_at    TEXT    NOT NULL DEFAULT ${NOW}`,
  ],
};

/** Contraintes de table, placées après toutes les colonnes. */
const BASE_CONSTRAINTS = {
  restaurants: [],
  products: ['FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE'],
};

/** Colonnes propres au module, ajoutées aux tables existantes si besoin. */
const MODULE_COLUMNS = {
  restaurants: [
    // Les restaurants déjà présents avant le module étaient en ligne : validés.
    ['status', `TEXT NOT NULL DEFAULT 'approved' CHECK(status IN (${STATUSES}))`],
    ['cuisine', 'TEXT'],
    ['review_count', 'INTEGER NOT NULL DEFAULT 0 CHECK(review_count >= 0)'],
    ['delivery_minutes', 'INTEGER NOT NULL DEFAULT 30 CHECK(delivery_minutes > 0)'],
    ['delivery_fee', 'REAL NOT NULL DEFAULT 0.0 CHECK(delivery_fee >= 0)'],
    ['min_order', 'REAL NOT NULL DEFAULT 10.0 CHECK(min_order >= 0)'],
    ['distance_km', 'REAL NOT NULL DEFAULT 1.0 CHECK(distance_km >= 0)'],
    ['menu_sections', "TEXT NOT NULL DEFAULT '[]'"],
    ['is_popular', 'INTEGER NOT NULL DEFAULT 0 CHECK(is_popular IN (0,1))'],
    ['promo', 'TEXT'],
    // Photo de la carte importée depuis le téléphone (data URI) ou lien web.
    ['menu_image_url', 'TEXT'],
    // Localisation de l'adresse (OpenStreetMap) : voir GEO_STATUSES.
    ['geo_status', `TEXT NOT NULL DEFAULT 'pending' CHECK(geo_status IN (${GEO}))`],
    ['geocoded_at', 'TEXT'],
  ],
  products: [
    // NULL pour les produits d'avant le module : l'onglet reprend `category`.
    ['section', 'TEXT'],
    ['option_groups', "TEXT NOT NULL DEFAULT '[]'"],
    ['is_popular', 'INTEGER NOT NULL DEFAULT 0 CHECK(is_popular IN (0,1))'],
    ['calories', 'INTEGER CHECK(calories IS NULL OR calories >= 0)'],
    // Code-barres GS1 (EAN-8, UPC-A, EAN-13, GTIN-14), surtout pour l'épicerie.
    [
      'barcode',
      "TEXT CHECK(barcode IS NULL OR (length(barcode) IN (8,12,13,14) AND barcode NOT GLOB '*[^0-9]*'))",
    ],
    ['nutri_score', `TEXT CHECK(nutri_score IS NULL OR nutri_score IN (${SCORES}))`],
    // Liste JSON des allergènes (identifiants Open Food Facts).
    ['allergens', "TEXT NOT NULL DEFAULT '[]'"],
  ],
};

const CATEGORY_COLUMNS = [
  'id          TEXT    NOT NULL PRIMARY KEY',
  'name        TEXT    NOT NULL',
  'emoji       TEXT    NOT NULL',
  'color_value INTEGER NOT NULL CHECK(color_value BETWEEN 0 AND 4294967295)',
  'position    INTEGER NOT NULL DEFAULT 0',
  'is_active   INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))',
  `created_at  TEXT    NOT NULL DEFAULT ${NOW}`,
];

const LINK_COLUMNS = [
  'restaurant_id TEXT NOT NULL',
  'category_id   TEXT NOT NULL',
  'PRIMARY KEY (restaurant_id, category_id)',
  'FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE',
  'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE',
];

/** Réponses d'OpenStreetMap, par adresse normalisée. */
const GEOCODE_CACHE_COLUMNS = [
  'address_key TEXT    NOT NULL PRIMARY KEY',
  'found       INTEGER NOT NULL CHECK(found IN (0,1))',
  'latitude    REAL',
  'longitude   REAL',
  'fetched_at  TEXT    NOT NULL',
];

/** Fiches Open Food Facts, par code-barres. */
const BARCODE_CACHE_COLUMNS = [
  'barcode    TEXT    NOT NULL PRIMARY KEY',
  'found      INTEGER NOT NULL CHECK(found IN (0,1))',
  'payload    TEXT',
  'fetched_at TEXT    NOT NULL',
];

const INDEXES = [
  'CREATE INDEX IF NOT EXISTS idx_restaurants_owner ON restaurants (owner_id)',
  'CREATE INDEX IF NOT EXISTS idx_products_restaurant ON products (restaurant_id)',
  'CREATE INDEX IF NOT EXISTS idx_restaurant_categories_category ON restaurant_categories (category_id)',
  // Un code-barres n'apparaît qu'une fois dans le menu d'un restaurant.
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_products_restaurant_barcode
     ON products (restaurant_id, barcode) WHERE barcode IS NOT NULL`,
];

async function tableExists(table) {
  const rows = await query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?", [
    table,
  ]);
  return rows.length > 0;
}

/** Crée la table si elle n'existe pas. Renvoie `true` si elle vient d'être créée. */
async function createTable(table, columns) {
  if (await tableExists(table)) return false;
  await query(`CREATE TABLE ${table} (\n  ${columns.join(',\n  ')}\n)`);
  return true;
}

async function addMissingColumns(table) {
  const existing = new Set(
    (await query('SELECT name FROM pragma_table_info(?)', [table])).map((row) => row.name),
  );
  for (const [column, definition] of MODULE_COLUMNS[table]) {
    if (!existing.has(column)) {
      await query(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
    }
  }
}

async function seedCategories() {
  const now = toSqlDate(new Date().toISOString());
  await withTransaction(async () => {
    for (const [position, category] of DEFAULT_CATEGORIES.entries()) {
      await query(
        `INSERT INTO categories (id, name, emoji, color_value, position, is_active, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          category.id,
          category.name,
          category.emoji,
          category.colorValue,
          position,
          category.isActive ? 1 : 0,
          now,
        ],
      );
    }
  });
}

async function migrate() {
  for (const table of ['restaurants', 'products']) {
    const columns = [
      ...BASE_COLUMNS[table],
      ...MODULE_COLUMNS[table].map(([column, definition]) => `${column} ${definition}`),
      ...BASE_CONSTRAINTS[table],
    ];
    if (!(await createTable(table, columns))) await addMissingColumns(table);
  }

  if (await createTable('categories', CATEGORY_COLUMNS)) await seedCategories();
  await createTable('restaurant_categories', LINK_COLUMNS);
  await createTable('geocode_cache', GEOCODE_CACHE_COLUMNS);
  await createTable('barcode_lookups', BARCODE_CACHE_COLUMNS);

  for (const sql of INDEXES) await query(sql);
}

let ready = null;

/** Lance (ou relance) la migration. Appelé au démarrage de l'API. */
function init() {
  ready = migrate().catch((error) => {
    ready = null;
    throw error;
  });
  return ready;
}

/** Middleware : garantit que la migration a tourné avant de servir le module. */
async function ensureReady(_req, _res, next) {
  try {
    await (ready || init());
    next();
  } catch (error) {
    next(error);
  }
}

module.exports = { init, ensureReady };
