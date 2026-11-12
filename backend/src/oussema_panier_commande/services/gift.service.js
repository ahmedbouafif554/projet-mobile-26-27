'use strict';

/**
 * Service Cadeau – Commandes envoyées en cadeau.
 * Gère la création, consultation et révélation des cadeaux.
 */

const crypto = require('crypto');
const { query, newId, toIso } = require('../../data/db');
const HttpError = require('../../errors/http-error');

// Ensure the order_gifts table exists
async function ensureSchema() {
  await query(`
    CREATE TABLE IF NOT EXISTS order_gifts (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL UNIQUE,
      recipient_name TEXT NOT NULL,
      recipient_phone TEXT,
      recipient_email TEXT,
      sender_name TEXT,
      is_anonymous INTEGER DEFAULT 0,
      message TEXT,
      gift_card_design TEXT DEFAULT 'default',
      scheduled_at TEXT,
      qr_code TEXT NOT NULL,
      revealed INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders(id)
    )
  `);
}

ensureSchema().catch(() => {});

/**
 * Crée un cadeau associé à une commande.
 */
async function createGift(orderId, giftData) {
  await ensureSchema();
  const {
    recipientName,
    recipientPhone,
    recipientEmail,
    senderName,
    isAnonymous = false,
    message,
    giftCardDesign = 'default',
    scheduledAt,
  } = giftData;

  if (!recipientName || !recipientName.trim()) {
    throw new HttpError(400, 'Le nom du destinataire est obligatoire.');
  }

  // Check if order exists
  const rows = await query('SELECT id FROM orders WHERE id = ?', [orderId]);
  if (!rows.length) {
    throw new HttpError(404, `Commande introuvable (${orderId}).`);
  }

  // Check if gift already exists for this order
  const existing = await query('SELECT id FROM order_gifts WHERE order_id = ?', [orderId]);
  if (existing.length) {
    throw new HttpError(409, 'Un cadeau existe déjà pour cette commande.');
  }

  const id = newId();
  const qrCode = crypto.randomBytes(24).toString('hex');
  const now = toIso(new Date());

  await query(
    `INSERT INTO order_gifts
     (id, order_id, recipient_name, recipient_phone, recipient_email,
      sender_name, is_anonymous, message, gift_card_design, scheduled_at,
      qr_code, revealed, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)`,
    [
      id,
      orderId,
      recipientName.trim(),
      recipientPhone || null,
      recipientEmail || null,
      isAnonymous ? null : (senderName || null),
      isAnonymous ? 1 : 0,
      message || null,
      giftCardDesign,
      scheduledAt ? toIso(new Date(scheduledAt)) : null,
      qrCode,
      now,
    ],
  );

  return getGiftByOrderId(orderId);
}

/**
 * Récupère le cadeau d'une commande.
 */
async function getGift(orderId) {
  await ensureSchema();
  const rows = await query('SELECT * FROM order_gifts WHERE order_id = ?', [orderId]);
  if (!rows.length) {
    throw new HttpError(404, `Aucun cadeau pour la commande (${orderId}).`);
  }
  return formatGift(rows[0]);
}

async function getGiftByOrderId(orderId) {
  await ensureSchema();
  const rows = await query('SELECT * FROM order_gifts WHERE order_id = ?', [orderId]);
  return rows.length ? formatGift(rows[0]) : null;
}

/**
 * Révèle un cadeau via son QR code token.
 * Retourne les infos du cadeau + commande associée.
 */
async function revealGift(qrToken) {
  await ensureSchema();
  if (!qrToken) throw new HttpError(400, 'Token QR requis.');

  const rows = await query('SELECT * FROM order_gifts WHERE qr_code = ?', [qrToken]);
  if (!rows.length) {
    throw new HttpError(404, 'Cadeau introuvable. QR code invalide.');
  }

  const gift = rows[0];

  // Mark as revealed if not already
  if (!gift.revealed) {
    await query('UPDATE order_gifts SET revealed = 1 WHERE id = ?', [gift.id]);
    gift.revealed = 1;
  }

  // Fetch order info (without prices for gift reveal)
  const orderRows = await query(
    `SELECT o.id, o.reference, o.restaurant_id, o.status,
            o.delivery_address, o.created_at,
            r.name as restaurant_name
     FROM orders o
     LEFT JOIN restaurants r ON r.id = o.restaurant_id
     WHERE o.id = ?`,
    [gift.order_id],
  );

  const order = orderRows[0] || null;

  // Fetch order items (hide prices)
  const items = await query(
    `SELECT name, quantity, options FROM order_items WHERE order_id = ?`,
    [gift.order_id],
  );

  return {
    gift: formatGift(gift),
    order: order
      ? {
          id: order.id,
          reference: order.reference,
          restaurantName: order.restaurant_name,
          status: order.status,
          createdAt: order.created_at,
        }
      : null,
    items: items.map((item) => ({
      name: item.name,
      quantity: item.quantity,
      options: safeJson(item.options, []),
    })),
  };
}

function formatGift(row) {
  return {
    id: row.id,
    orderId: row.order_id,
    recipientName: row.recipient_name,
    recipientPhone: row.recipient_phone,
    recipientEmail: row.recipient_email,
    senderName: row.sender_name,
    isAnonymous: !!row.is_anonymous,
    message: row.message,
    giftCardDesign: row.gift_card_design || 'default',
    scheduledAt: row.scheduled_at,
    qrCode: row.qr_code,
    revealed: !!row.revealed,
    createdAt: row.created_at,
  };
}

function safeJson(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

module.exports = { createGift, getGift, revealGift };

