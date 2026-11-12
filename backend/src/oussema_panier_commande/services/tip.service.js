'use strict';

/**
 * Service Pourboire – Tips pour les livreurs.
 * Les clients peuvent laisser un pourboire avant ou après livraison.
 */

const { query, newId, toIso } = require('../../data/db');
const HttpError = require('../../errors/http-error');

// Ensure the order_tips table exists
async function ensureSchema() {
  await query(`
    CREATE TABLE IF NOT EXISTS order_tips (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL,
      courier_id TEXT,
      tipper_id TEXT NOT NULL,
      amount REAL NOT NULL,
      percentage REAL,
      thank_you_message TEXT,
      paid_at TEXT,
      payment_method TEXT DEFAULT 'card',
      created_at TEXT NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders(id)
    )
  `);
}

ensureSchema().catch(() => {});

const MIN_TIP = 0.5;
const MAX_TIP = 50;

/**
 * Ajoute un pourboire pour une commande.
 */
async function addTip(tipperId, orderId, tipData) {
  await ensureSchema();
  const {
    amount,
    percentage,
    thankYouMessage,
    paymentMethod = 'card',
  } = tipData;

  if (!amount || typeof amount !== 'number' || amount < MIN_TIP) {
    throw new HttpError(400, `Le montant minimum du pourboire est ${MIN_TIP} €.`);
  }
  if (amount > MAX_TIP) {
    throw new HttpError(400, `Le montant maximum du pourboire est ${MAX_TIP} €.`);
  }

  // Verify order exists and belongs to tipper
  const orderRows = await query(
    'SELECT id, user_id, courier_id, status FROM orders WHERE id = ?',
    [orderId],
  );
  if (!orderRows.length) {
    throw new HttpError(404, `Commande introuvable (${orderId}).`);
  }

  const order = orderRows[0];

  // Only the customer who placed the order can tip
  if (order.user_id !== tipperId) {
    throw new HttpError(403, "Vous ne pouvez laisser un pourboire que pour vos propres commandes.");
  }

  // Check if tip already given for this order
  const existing = await query(
    'SELECT id FROM order_tips WHERE order_id = ? AND tipper_id = ?',
    [orderId, tipperId],
  );
  if (existing.length) {
    throw new HttpError(409, 'Vous avez déjà laissé un pourboire pour cette commande.');
  }

  const id = newId();
  const now = toIso(new Date());

  await query(
    `INSERT INTO order_tips
     (id, order_id, courier_id, tipper_id, amount, percentage,
      thank_you_message, paid_at, payment_method, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      orderId,
      order.courier_id || null,
      tipperId,
      amount,
      percentage || null,
      thankYouMessage || null,
      now, // paid immediately
      paymentMethod,
      now,
    ],
  );

  return getTipById(id);
}

/**
 * Récupère le(s) pourboire(s) pour une commande.
 */
async function getTipsForOrder(orderId) {
  await ensureSchema();
  const rows = await query(
    'SELECT * FROM order_tips WHERE order_id = ? ORDER BY created_at DESC',
    [orderId],
  );
  return rows.map(formatTip);
}

/**
 * Historique des pourboires reçus par un livreur.
 */
async function getCourierTipHistory(courierId) {
  await ensureSchema();
  const rows = await query(
    `SELECT t.*, o.reference as order_reference, o.created_at as order_date
     FROM order_tips t
     LEFT JOIN orders o ON o.id = t.order_id
     WHERE t.courier_id = ?
     ORDER BY t.created_at DESC`,
    [courierId],
  );
  const total = rows.reduce((sum, r) => sum + (r.amount || 0), 0);
  return {
    tips: rows.map((r) => ({
      ...formatTip(r),
      orderReference: r.order_reference,
      orderDate: r.order_date,
    })),
    totalEarned: Math.round(total * 100) / 100,
    count: rows.length,
  };
}

async function getTipById(id) {
  const rows = await query('SELECT * FROM order_tips WHERE id = ?', [id]);
  if (!rows.length) throw new HttpError(404, 'Pourboire introuvable.');
  return formatTip(rows[0]);
}

function formatTip(row) {
  return {
    id: row.id,
    orderId: row.order_id,
    courierId: row.courier_id,
    tipperId: row.tipper_id,
    amount: row.amount,
    percentage: row.percentage,
    thankYouMessage: row.thank_you_message,
    paidAt: row.paid_at,
    paymentMethod: row.payment_method,
    createdAt: row.created_at,
  };
}

module.exports = { addTip, getTipsForOrder, getCourierTipHistory };

