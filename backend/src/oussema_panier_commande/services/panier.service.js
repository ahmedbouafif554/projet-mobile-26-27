'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toIso } = require('../../data/db');
const {
  MAX_QUANTITY_PER_ITEM,
  calculateServiceFee,
  getMergeKey,
  calculatePromoDiscount,
} = require('../domain/panier.constants');

function formatProduct(rawProduct, dbRow) {
  const p = rawProduct || {};
  const db = dbRow || {};
  return {
    id: p.id || db.id || 'prod_unknown',
    restaurantId: p.restaurantId || db.restaurant_id || 'rest_demo',
    categoryId: p.categoryId || db.category || '',
    name: p.name || db.name || 'Article',
    description: p.description || db.description || '',
    price: Number(p.price ?? db.price ?? 0),
    imageUrl: p.imageUrl || db.image_url || '',
    section: p.section || db.section || '',
    optionGroups: Array.isArray(p.optionGroups)
      ? p.optionGroups
      : db.option_groups
      ? (typeof db.option_groups === 'string' ? JSON.parse(db.option_groups) : db.option_groups)
      : [],
    isAvailable: p.isAvailable !== undefined ? Boolean(p.isAvailable) : (db.is_available === undefined ? true : db.is_available === 1),
    isPopular: p.isPopular !== undefined ? Boolean(p.isPopular) : (db.is_popular === 1),
    calories: p.calories ? Number(p.calories) : (db.calories ? Number(db.calories) : null),
  };
}

function mapCartRow(row, dbProduct) {
  let savedProduct = null;
  if (row.product_data) {
    try {
      savedProduct = typeof row.product_data === 'string' ? JSON.parse(row.product_data) : row.product_data;
    } catch (_) {}
  }
  const product = formatProduct(savedProduct, dbProduct);

  let options = [];
  if (row.options) {
    try {
      options = typeof row.options === 'string' ? JSON.parse(row.options) : row.options;
    } catch (_) {}
  }

  return {
    id: row.id,
    product,
    quantity: Math.max(1, Number(row.quantity) || 1),
    options: Array.isArray(options) ? options : [],
    note: row.note || null,
    totalPrice: (() => {
      const optionsSum = (options || []).reduce((sum, o) => sum + (Number(o.price) || 0), 0);
      return Math.round((product.price + optionsSum) * (Number(row.quantity) || 1) * 100) / 100;
    })(),
  };
}

async function getCart(userId) {
  const effectiveUserId = userId || 'u-client-1';
  const rows = await query(
    'SELECT * FROM cart_items WHERE user_id = ? ORDER BY created_at ASC',
    [effectiveUserId],
  );

  if (rows.length === 0) return [];

  const productIds = rows.map((r) => r.product_id).filter(Boolean);
  let productMap = new Map();
  if (productIds.length > 0) {
    const placeholders = productIds.map(() => '?').join(',');
    const dbProducts = await query(
      `SELECT * FROM products WHERE id IN (${placeholders})`,
      productIds,
    );
    productMap = new Map(dbProducts.map((p) => [p.id, p]));
  }

  return rows.map((r) => mapCartRow(r, productMap.get(r.product_id)));
}

async function getItem(userId, itemId) {
  const effectiveUserId = userId || 'u-client-1';
  const rows = await query(
    'SELECT * FROM cart_items WHERE id = ? AND user_id = ? LIMIT 1',
    [itemId, effectiveUserId],
  );
  if (!rows[0]) {
    throw new HttpError(404, `Article du panier introuvable (${itemId}).`);
  }
  const dbProducts = await query('SELECT * FROM products WHERE id = ? LIMIT 1', [rows[0].product_id]);
  return mapCartRow(rows[0], dbProducts[0]);
}

async function addItem(userId, payload) {
  const effectiveUserId = userId || 'u-client-1';

  const productInput = payload.product || {};
  const productId = productInput.id || payload.productId || payload.id;
  if (!productId) {
    throw new HttpError(422, 'Le produit est obligatoire pour ajouter au panier.');
  }

  let dbProducts = await query('SELECT * FROM products WHERE id = ? LIMIT 1', [productId]);
  let dbProd = dbProducts[0];

  const fullProduct = formatProduct(productInput, dbProd);
  const restaurantId = fullProduct.restaurantId;

  // Règle métier : un panier ne contient que les articles d'un seul restaurant
  const existingCart = await getCart(effectiveUserId);
  if (existingCart.length > 0) {
    const currentRestId = existingCart[0].product.restaurantId;
    if (currentRestId && restaurantId && currentRestId !== restaurantId) {
      if (payload.clearExisting || payload.replace) {
        await clearCart(effectiveUserId);
      } else {
        throw new HttpError(
          409,
          `Votre panier contient déjà des produits d'un autre restaurant. Videz votre panier pour commander chez un autre établissement.`,
        );
      }
    }
  }

  const quantityToAdd = Math.max(1, Math.min(MAX_QUANTITY_PER_ITEM, parseInt(payload.quantity, 10) || 1));
  const options = Array.isArray(payload.options) ? payload.options : [];
  const note = payload.note && payload.note.trim() ? payload.note.trim() : null;

  const targetMergeKey = getMergeKey(productId, options, note);

  // Recherche d'un article existant identique
  let existingItem = null;
  for (const item of existingCart) {
    if (getMergeKey(item.product.id, item.options, item.note) === targetMergeKey) {
      existingItem = item;
      break;
    }
  }

  if (existingItem) {
    const updatedQty = Math.min(MAX_QUANTITY_PER_ITEM, existingItem.quantity + quantityToAdd);
    await query(
      'UPDATE cart_items SET quantity = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?',
      [updatedQty, existingItem.id, effectiveUserId],
    );
    return getItem(effectiveUserId, existingItem.id);
  }

  const newCartItemId = newId('ci');
  const now = new Date().toISOString();

  await query(
    `INSERT INTO cart_items (id, user_id, product_id, quantity, options, note, product_data, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      newCartItemId,
      effectiveUserId,
      productId,
      quantityToAdd,
      JSON.stringify(options),
      note,
      JSON.stringify(fullProduct),
      now,
      now,
    ],
  );

  return getItem(effectiveUserId, newCartItemId);
}

async function updateItem(userId, itemId, payload) {
  const effectiveUserId = userId || 'u-client-1';

  const rows = await query(
    'SELECT * FROM cart_items WHERE id = ? AND user_id = ? LIMIT 1',
    [itemId, effectiveUserId],
  );
  if (!rows[0]) {
    throw new HttpError(404, `Article du panier introuvable (${itemId}).`);
  }

  const newQuantity = parseInt(payload.quantity, 10);
  if (Number.isInteger(newQuantity) && newQuantity <= 0) {
    await deleteItem(effectiveUserId, itemId);
    return { id: itemId, deleted: true };
  }

  const updates = [];
  const params = [];

  if (Number.isInteger(newQuantity)) {
    updates.push('quantity = ?');
    params.push(Math.min(MAX_QUANTITY_PER_ITEM, Math.max(1, newQuantity)));
  }

  if (payload.options !== undefined) {
    updates.push('options = ?');
    params.push(JSON.stringify(Array.isArray(payload.options) ? payload.options : []));
  }

  if (payload.note !== undefined) {
    updates.push('note = ?');
    params.push(payload.note ? payload.note.trim() : null);
  }

  if (payload.product) {
    updates.push('product_data = ?');
    params.push(JSON.stringify(payload.product));
  }

  updates.push('updated_at = CURRENT_TIMESTAMP');
  params.push(itemId, effectiveUserId);

  await query(
    `UPDATE cart_items SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`,
    params,
  );

  return getItem(effectiveUserId, itemId);
}

async function deleteItem(userId, itemId) {
  const effectiveUserId = userId || 'u-client-1';
  await query('DELETE FROM cart_items WHERE id = ? AND user_id = ?', [itemId, effectiveUserId]);
  return { success: true, id: itemId };
}

async function clearCart(userId) {
  const effectiveUserId = userId || 'u-client-1';
  await query('DELETE FROM cart_items WHERE user_id = ?', [effectiveUserId]);
  return { success: true };
}

async function getTotals(userId, promoCode = null) {
  const items = await getCart(userId);
  const subtotal = items.reduce((sum, item) => sum + item.totalPrice, 0);

  let restaurant = null;
  if (items.length > 0 && items[0].product.restaurantId) {
    const rests = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [
      items[0].product.restaurantId,
    ]);
    restaurant = rests[0] || null;
  }

  const deliveryFee = items.length === 0 ? 0 : Number(restaurant?.delivery_fee ?? 2.5);
  const serviceFee = calculateServiceFee(subtotal);
  const discount = calculatePromoDiscount(promoCode, subtotal, deliveryFee);
  const total = Math.max(0, Math.round((subtotal + deliveryFee + serviceFee - discount) * 100) / 100);

  return {
    subtotal: Math.round(subtotal * 100) / 100,
    deliveryFee: Math.round(deliveryFee * 100) / 100,
    serviceFee: Math.round(serviceFee * 100) / 100,
    discount: Math.round(discount * 100) / 100,
    total,
    itemCount: items.reduce((sum, item) => sum + item.quantity, 0),
    restaurantId: restaurant?.id || null,
    restaurantName: restaurant?.name || null,
  };
}

module.exports = {
  getCart,
  getItem,
  addItem,
  updateItem,
  deleteItem,
  clearCart,
  getTotals,
};

