'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { DatabaseSync } = require('node:sqlite');
const { AsyncLocalStorage } = require('node:async_hooks');
const config = require('../config');

const DATA_DIR = path.join(__dirname, '..', '..', 'data');

let db = null;

function rounds() {
  const value = Number(process.env.BCRYPT_ROUNDS);
  return Number.isInteger(value) && value > 0 ? value : 10;
}

function databasePath() {
  const name = process.env.DB_NAME || 'superfaster';
  const worker = process.env.JEST_WORKER_ID ? `-w${process.env.JEST_WORKER_ID}` : '';
  return path.join(DATA_DIR, `${name}${worker}.sqlite`);
}

function toSqlDate(value) {
  if (value == null || value === '') return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toISOString();
}

function toIso(value) {
  if (value == null || value === '') return null;
  if (value instanceof Date) return value.toISOString();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? String(value) : date.toISOString();
}

function newId(prefix) {
  return `${prefix}_${crypto.randomBytes(8).toString('hex')}`;
}

function query(sql, params = [], _conn) {
  const statement = db.prepare(sql);
  const values = params || [];
  const verb = sql.trim().slice(0, 6).toUpperCase();
  if (verb === 'SELECT' || verb === 'PRAGMA' || sql.trim().toUpperCase().startsWith('WITH')) {
    return Promise.resolve(statement.all(...values));
  }
  statement.run(...values);
  return Promise.resolve([]);
}

/**
 * Une seule transaction à la fois. Les requêtes sont asynchrones : sans ce
 * verrou, deux requêtes HTTP simultanées mélangeraient leurs écritures dans
 * le même BEGIN…COMMIT (et un ROLLBACK annulerait le travail de l'autre).
 * Un appel imbriqué (dans la même chaîne asynchrone) réutilise la transaction
 * en cours.
 */
const transactionScope = new AsyncLocalStorage();
let transactionQueue = Promise.resolve();

async function withTransaction(work) {
  if (transactionScope.getStore()) return work(db);
  const previous = transactionQueue;
  let release;
  transactionQueue = new Promise((resolve) => {
    release = resolve;
  });
  await previous;
  try {
    return await transactionScope.run(true, async () => {
      db.exec('BEGIN');
      try {
        const result = await work(db);
        db.exec('COMMIT');
        return result;
      } catch (error) {
        try {
          db.exec('ROLLBACK');
        } catch (_rollback) {
          /* déjà annulée */
        }
        throw error;
      }
    });
  } finally {
    release();
  }
}

function createSchema() {
  db.exec(`
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE COLLATE NOCASE,
      phone TEXT NOT NULL,
      role TEXT NOT NULL,
      status TEXT NOT NULL,
      avatar_url TEXT,
      restaurant_id TEXT,
      loyalty_points INTEGER NOT NULL DEFAULT 0,
      password_hash TEXT,
      created_at TEXT NOT NULL,
      last_login_at TEXT
    );

    CREATE TABLE IF NOT EXISTS addresses (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      label TEXT NOT NULL,
      street TEXT NOT NULL,
      postal_code TEXT NOT NULL,
      city TEXT NOT NULL,
      type TEXT NOT NULL,
      instructions TEXT,
      is_default INTEGER NOT NULL DEFAULT 0,
      latitude REAL,
      longitude REAL
    );

    CREATE TABLE IF NOT EXISTS favorites (
      user_id TEXT NOT NULL,
      restaurant_id TEXT NOT NULL,
      PRIMARY KEY (user_id, restaurant_id)
    );

    CREATE TABLE IF NOT EXISTS couriers (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      phone TEXT,
      avatar_url TEXT,
      vehicle TEXT,
      plate_number TEXT,
      status TEXT NOT NULL,
      rating REAL NOT NULL DEFAULT 5,
      completed_deliveries INTEGER NOT NULL DEFAULT 0,
      total_earnings REAL NOT NULL DEFAULT 0,
      zone TEXT,
      latitude REAL,
      longitude REAL,
      joined_at TEXT
    );

    CREATE TABLE IF NOT EXISTS courier_identity_scans (
      courier_id TEXT PRIMARY KEY,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      id_card_format TEXT,
      id_card_bytes INTEGER NOT NULL DEFAULT 0,
      license_format TEXT,
      license_bytes INTEGER NOT NULL DEFAULT 0,
      insurance_format TEXT,
      insurance_bytes INTEGER NOT NULL DEFAULT 0,
      id_card_text TEXT,
      license_text TEXT,
      insurance_text TEXT,
      scanned_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS courier_documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      courier_id TEXT NOT NULL,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      image_data TEXT,
      uploaded_at TEXT
    );

    CREATE TABLE IF NOT EXISTS cart_items (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      options TEXT NOT NULL DEFAULT '[]',
      note TEXT,
      product_data TEXT,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );

    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      reference TEXT,
      user_id TEXT,
      restaurant_id TEXT,
      courier_id TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      total_amount REAL NOT NULL DEFAULT 0,
      delivery_fee REAL NOT NULL DEFAULT 0,
      service_fee REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      payment_method TEXT NOT NULL DEFAULT 'card',
      payment_status TEXT NOT NULL DEFAULT 'paid',
      promo_code TEXT,
      cancel_reason TEXT,
      delivery_address TEXT,
      delivery_lat REAL,
      delivery_lng REAL,
      notes TEXT,
      estimated_time INTEGER,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );

    CREATE TABLE IF NOT EXISTS order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL,
      product_id TEXT,
      name TEXT,
      price REAL NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 1,
      options TEXT NOT NULL DEFAULT '[]',
      note TEXT,
      product_data TEXT
    );

    CREATE TABLE IF NOT EXISTS order_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL,
      status TEXT,
      note TEXT,
      actor_id TEXT,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );

    CREATE TABLE IF NOT EXISTS deliveries (
      id TEXT PRIMARY KEY,
      order_id TEXT,
      courier_id TEXT,
      status TEXT NOT NULL DEFAULT 'waiting',
      pickup_lat REAL,
      pickup_lng REAL,
      dropoff_lat REAL,
      dropoff_lng REAL,
      courier_lat REAL,
      courier_lng REAL,
      distance_km REAL,
      duration_min INTEGER,
      fee REAL NOT NULL DEFAULT 0,
      tip REAL NOT NULL DEFAULT 0,
      otp_code TEXT,
      started_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );

    CREATE TABLE IF NOT EXISTS restaurants (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      address TEXT,
      phone TEXT,
      email TEXT,
      category TEXT,
      image_url TEXT,
      latitude REAL NOT NULL DEFAULT 48.8566,
      longitude REAL NOT NULL DEFAULT 2.3522,
      rating REAL NOT NULL DEFAULT 0,
      is_open INTEGER NOT NULL DEFAULT 1,
      owner_id TEXT,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      status TEXT NOT NULL DEFAULT 'approved',
      cuisine TEXT,
      review_count INTEGER NOT NULL DEFAULT 0,
      delivery_minutes INTEGER NOT NULL DEFAULT 30,
      delivery_fee REAL NOT NULL DEFAULT 0,
      min_order REAL NOT NULL DEFAULT 10,
      distance_km REAL NOT NULL DEFAULT 1,
      menu_sections TEXT NOT NULL DEFAULT '[]',
      is_popular INTEGER NOT NULL DEFAULT 0,
      promo TEXT
    );

    CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY,
      restaurant_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      price REAL NOT NULL DEFAULT 0,
      category TEXT,
      image_url TEXT,
      is_available INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      section TEXT,
      option_groups TEXT NOT NULL DEFAULT '[]',
      is_popular INTEGER NOT NULL DEFAULT 0,
      calories INTEGER
    );

    CREATE TABLE IF NOT EXISTS courier_locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      courier_id TEXT,
      delivery_id TEXT,
      latitude REAL,
      longitude REAL,
      created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    );
  `);

  const migrations = [
    ['orders', 'reference', 'TEXT'],
    ['orders', 'service_fee', 'REAL NOT NULL DEFAULT 0'],
    ['orders', 'discount', 'REAL NOT NULL DEFAULT 0'],
    ['orders', 'payment_method', "TEXT NOT NULL DEFAULT 'card'"],
    ['orders', 'payment_status', "TEXT NOT NULL DEFAULT 'paid'"],
    ['orders', 'promo_code', 'TEXT'],
    ['orders', 'cancel_reason', 'TEXT'],
    ['order_items', 'options', "TEXT NOT NULL DEFAULT '[]'"],
    ['order_items', 'note', 'TEXT'],
    ['order_items', 'product_data', 'TEXT'],
    // Commandes saisies par téléphone (client sans compte).
    ['orders', 'customer_name', 'TEXT'],
    ['orders', 'customer_phone', 'TEXT'],
    // Authentification : révocation des jetons et connexion Google.
    ['users', 'token_version', 'INTEGER NOT NULL DEFAULT 0'],
    ['users', 'google_id', 'TEXT'],
    ['users', 'password_changed_at', 'TEXT'],
  ];
  for (const [table, col, type] of migrations) {
    try {
      db.exec(`ALTER TABLE ${table} ADD COLUMN ${col} ${type}`);
    } catch (_err) {
      // Column already exists
    }
  }

  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_id ON users (google_id) WHERE google_id IS NOT NULL;

    -- Liens « mot de passe oublié » : seul le hash du jeton est stocké.
    CREATE TABLE IF NOT EXISTS password_resets (
      token_hash TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      used_at TEXT,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_password_resets_user ON password_resets (user_id);

    CREATE INDEX IF NOT EXISTS idx_cart_items_user ON cart_items (user_id);
    CREATE INDEX IF NOT EXISTS idx_orders_user ON orders (user_id);
    CREATE INDEX IF NOT EXISTS idx_orders_restaurant ON orders (restaurant_id);
    CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items (order_id);
    CREATE INDEX IF NOT EXISTS idx_order_events_order ON order_events (order_id);
    CREATE INDEX IF NOT EXISTS idx_deliveries_order ON deliveries (order_id);
    CREATE INDEX IF NOT EXISTS idx_deliveries_courier ON deliveries (courier_id);
  `);
}

/**
 * Production : crée le premier administrateur à partir de ADMIN_EMAIL /
 * ADMIN_PASSWORD s'il n'existe encore aucun compte admin.
 */
function bootstrapAdmin() {
  const admin = config.bootstrapAdmin;
  if (!admin.email || !admin.password) return;
  const [{ n }] = db.prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'admin'").all();
  if (n > 0) return;
  if (admin.password.length < 8) {
    throw new Error('ADMIN_PASSWORD doit faire au moins 8 caractères.');
  }
  db.prepare(
    `INSERT INTO users
      (id, first_name, last_name, email, phone, role, status, loyalty_points, password_hash, created_at)
     VALUES (?, ?, ?, ?, ?, 'admin', 'active', 0, ?, ?)`,
  ).run(
    newId('u'),
    admin.firstName,
    admin.lastName,
    admin.email,
    admin.phone,
    bcrypt.hashSync(admin.password, rounds()),
    new Date().toISOString(),
  );
}

const DEMO_USERS = [
  ['u-admin', 'Sophie', 'Laurent', 'admin@superfaster.fr', '+33 6 59 81 03 57', 'admin', 'active', null, 0],
  ['u-client-1', 'Alex', 'Martin', 'alex.martin@exemple.fr', '+33 6 24 46 56 22', 'client', 'active', null, 340],
  ['u-client-9', 'Thomas', 'Bonnet', 'thomas.bonnet@exemple.fr', '+33 6 45 67 89 43', 'client', 'blocked', null, 0],
  ['u-resto-1', 'Marc', 'Dubois', 'contact@burgerfactory.fr', '+33 6 64 86 08 62', 'restaurant', 'active', 'r1', 0],
  ['u-resto-9', 'Minh', 'Nguyen', 'minh@wokexpress.fr', '+33 6 73 95 17 71', 'restaurant', 'pending', 'r9', 0],
  ['u-courier-1', 'Karim', 'Benali', 'karim.benali@superfaster.fr', '+33 6 23 45 67 21', 'courier', 'active', null, 0],
  ['u-courier-6', 'Mehdi', 'Ziani', 'mehdi.ziani@superfaster.fr', '+33 6 20 42 64 18', 'courier', 'pending', null, 0],
];

function seed() {
  const hash = bcrypt.hashSync('demo1234', rounds());
  const now = new Date().toISOString();
  const insertUser = db.prepare(
    `INSERT INTO users
      (id, first_name, last_name, email, phone, role, status, avatar_url, restaurant_id,
       loyalty_points, password_hash, created_at, last_login_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, NULL)`,
  );
  for (const user of DEMO_USERS) insertUser.run(...user, hash, now);

  db.prepare(
    `INSERT INTO addresses
      (id, user_id, label, street, postal_code, city, type, instructions, is_default, latitude, longitude)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(
    'a-1',
    'u-client-1',
    'Maison',
    'Avenue Habib Bourguiba',
    '2080',
    'Ariana',
    'home',
    'Étage 2, Appt 5',
    1,
    36.9068,
    10.1836,
  );

  const insertCourier = db.prepare(
    `INSERT INTO couriers
      (id, user_id, first_name, last_name, phone, avatar_url, vehicle, plate_number, status,
       rating, completed_deliveries, total_earnings, zone, latitude, longitude, joined_at)
     VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, 0, 'Ariana', ?, ?, ?)`,
  );
  insertCourier.run('c-1', 'u-courier-1', 'Karim', 'Benali', '+216 23 456 721', 'scooter', 'GH-482-PK', 'available', 4.9, 280, 36.9034, 10.1838, now);
  insertCourier.run('c-6', 'u-courier-6', 'Mehdi', 'Ziani', '+216 20 426 418', 'bike', null, 'offline', 5, 0, 36.9020, 10.1850, now);

  const insertDoc = db.prepare(
    `INSERT INTO courier_documents (courier_id, type, status, image_data, uploaded_at) VALUES (?, ?, ?, NULL, ?)`,
  );
  for (const type of ['idCard', 'license', 'insurance']) {
    insertDoc.run('c-1', type, 'approved', now);
    insertDoc.run('c-6', type, 'pending', now);
  }

  db.prepare(
    `INSERT INTO restaurants
      (id, name, description, address, phone, email, category, latitude, longitude, rating,
       is_open, owner_id, created_at, status, cuisine, min_order, delivery_fee)
     VALUES ('rest_demo', 'SuperBurger Demo', 'Burgers de démonstration', 'Av. Hédi Nouira, Ennasr 2', '71800000',
             'demo@superburger.tn', 'burgers', 36.9015, 10.1865, 4.6, 1, NULL, ?, 'approved', 'burgers', 5, 2.5)`,
  ).run(now);

  const insertProduct = db.prepare(
    `INSERT INTO products
      (id, restaurant_id, name, description, price, category, is_available, created_at, section)
     VALUES (?, 'rest_demo', ?, '', ?, ?, 1, ?, ?)`,
  );
  insertProduct.run('prod_1', 'Classic Burger', 9.9, 'burgers', now, 'burgers');
  insertProduct.run('prod_2', 'Cheeseburger', 10.9, 'burgers', now, 'burgers');
  insertProduct.run('prod_3', 'Frites', 3.5, 'sides', now, 'sides');
  insertProduct.run('prod_4', 'Soda', 2.5, 'drinks', now, 'drinks');
}

function clearRows() {
  const present = new Set(
    db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((row) => row.name),
  );
  const tables = [
    'password_resets',
    'cart_items',
    'courier_locations',
    'deliveries',
    'order_events',
    'order_items',
    'orders',
    'courier_identity_scans',
    'courier_documents',
    'couriers',
    'favorites',
    'addresses',
    'restaurant_categories',
    'products',
    'restaurants',
    'users',
  ];
  db.exec('PRAGMA foreign_keys = OFF');
  for (const table of tables) {
    if (present.has(table)) db.exec(`DELETE FROM ${table}`);
  }
  db.exec('PRAGMA foreign_keys = ON');
}

async function init() {
  if (db) return;
  fs.mkdirSync(DATA_DIR, { recursive: true });
  db = new DatabaseSync(databasePath());
  createSchema();
  const [{ n }] = db.prepare('SELECT COUNT(*) AS n FROM users').all();
  if (n === 0 && config.seedDemo) seed();
  bootstrapAdmin();
}

async function reset() {
  if (!db) await init();
  clearRows();
  seed();
}

function close() {
  if (!db) return Promise.resolve();
  db.close();
  db = null;
  return Promise.resolve();
}

module.exports = {
  init,
  reset,
  close,
  query,
  withTransaction,
  newId,
  rounds,
  toIso,
  toSqlDate,
};
