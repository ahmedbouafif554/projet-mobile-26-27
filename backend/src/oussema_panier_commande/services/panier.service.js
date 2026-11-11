'use strict';

/**
 * Panier de l'utilisateur connecté (`ApiCartRepository`, `/api/cart/items`).
 *
 * Règles :
 * - le panier appartient au compte du jeton (jamais à un `userId` envoyé) ;
 * - produit, prix et options sont relus en base à chaque lecture : le
 *   produit envoyé par l'application ne sert qu'à connaître son id ;
 * - un panier ne contient que les produits d'un seul restaurant ;
 * - deux lignes identiques (produit, options, note) sont fusionnées.
 */

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId } = require('../../data/db');
const pricing = require('./pricing');
const { MAX_QUANTITY_PER_ITEM } = require('../domain/panier.constants');

const MESSAGES = Object.freeze({
  notFound: (id) => `Article du panier introuvable (${id}).`,
  productRequired: 'Le produit est obligatoire pour ajouter au panier.',
  productNotFound: "Ce produit n'existe plus.",
  unavailable: (name) => `« ${name} » n'est plus disponible.`,
  restaurantUnavailable: "Ce restaurant n'accepte pas de commandes pour le moment.",
  otherRestaurant:
    "Votre panier contient déjà des produits d'un autre restaurant. Videz votre panier pour commander chez un autre établissement.",
});

function parseJson(value, fallback) {
  if (value == null) return fallback;
  if (typeof value !== 'string') return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

/**
 * Ligne du panier au format `CartItem.toJson()`. Le produit et les options
 * sont ceux de la base ; un produit supprimé garde sa dernière copie et
 * apparaît indisponible.
 */
function present(row, product) {
  const stored = parseJson(row.options, []);
  const snapshot = parseJson(row.product_data, null);
  const current = product || (snapshot ? { ...snapshot, isAvailable: false } : null);
  let options = Array.isArray(stored) ? stored : [];
  if (product) {
    // Suppléments au prix actuel ; une option retirée du menu disparaît.
    const live = new Map();
    for (const group of product.optionGroups || []) {
      for (const option of group.options || []) live.set(option.id, option);
    }
    options = options
      .filter((o) => live.has(o.id))
      .map((o) => ({ id: o.id, name: live.get(o.id).name, price: pricing.round2(live.get(o.id).price || 0) }));
  }
  const quantity = Math.max(1, Number(row.quantity) || 1);
  const unit = current ? pricing.unitPrice(current, options) : 0;
  return {
    id: row.id,
    product: current,
    quantity,
    options,
    note: row.note || null,
    unitPrice: unit,
    totalPrice: pricing.round2(unit * quantity),
  };
}

async function rowsOf(userId) {
  return query('SELECT * FROM cart_items WHERE user_id = ? ORDER BY created_at ASC, id ASC', [userId]);
}

async function getCart(userId) {
  const rows = await rowsOf(userId);
  if (rows.length === 0) return [];
  const products = await pricing.loadProducts(rows.map((r) => r.product_id));
  return rows.map((row) => present(row, products.get(row.product_id))).filter((item) => item.product);
}

async function findRow(userId, itemId) {
  const rows = await query('SELECT * FROM cart_items WHERE id = ? AND user_id = ? LIMIT 1', [itemId, userId]);
  if (!rows[0]) throw new HttpError(404, MESSAGES.notFound(itemId));
  return rows[0];
}

async function getItem(userId, itemId) {
  const row = await findRow(userId, itemId);
  const products = await pricing.loadProducts([row.product_id]);
  return present(row, products.get(row.product_id));
}

/** Produit commandable : existe, disponible, restaurant validé. */
async function orderableProduct(productId) {
  const products = await pricing.loadProducts([productId]);
  const product = products.get(productId);
  if (!product) throw new HttpError(404, MESSAGES.productNotFound);
  if (!product.isAvailable) throw new HttpError(409, MESSAGES.unavailable(product.name));
  const restaurant = await pricing.loadRestaurant(product.restaurantId);
  if (!restaurant || restaurant.status !== 'approved') {
    throw new HttpError(409, MESSAGES.restaurantUnavailable);
  }
  return product;
}

async function addItem(userId, payload = {}) {
  const productId = pricing.productIdOf(payload);
  if (!productId) throw new HttpError(422, MESSAGES.productRequired);
  const product = await orderableProduct(productId);
  const quantity = pricing.quantityOf(payload.quantity ?? 1);
  const options = pricing.resolveOptions(product, payload.options);
  const note = pricing.noteOf(payload.note);
  const key = pricing.mergeKey(product.id, options, note);

  const id = await withTransaction(async () => {
    const existing = await getCart(userId);
    const otherRestaurant = existing.find((item) => item.product.restaurantId !== product.restaurantId);
    if (otherRestaurant) {
      if (!(payload.clearExisting || payload.replace)) throw new HttpError(409, MESSAGES.otherRestaurant);
      await query('DELETE FROM cart_items WHERE user_id = ?', [userId]);
    }

    const same = otherRestaurant
      ? null
      : existing.find((item) => pricing.mergeKey(item.product.id, item.options, item.note) === key);
    if (same) {
      const merged = Math.min(MAX_QUANTITY_PER_ITEM, same.quantity + quantity);
      await query(
        'UPDATE cart_items SET quantity = ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [merged, new Date().toISOString(), same.id, userId],
      );
      return same.id;
    }

    const itemId = newId('ci');
    const now = new Date().toISOString();
    await query(
      `INSERT INTO cart_items (id, user_id, product_id, quantity, options, note, product_data, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [itemId, userId, product.id, quantity, JSON.stringify(options), note, JSON.stringify(product), now, now],
    );
    return itemId;
  });
  return getItem(userId, id);
}

/**
 * `PUT /cart/items/:id` (JSON complet de `CartItem`) : quantité, options et
 * note. Une quantité de 0 retire la ligne.
 */
async function updateItem(userId, itemId, payload = {}) {
  const row = await findRow(userId, itemId);
  const sets = [];
  const params = [];

  if (payload.quantity !== undefined) {
    const quantity = pricing.quantityOf(payload.quantity, { allowZero: true });
    if (quantity === 0) {
      await deleteItem(userId, itemId);
      return { id: itemId, deleted: true };
    }
    sets.push('quantity = ?');
    params.push(quantity);
  }
  if (payload.options !== undefined) {
    const products = await pricing.loadProducts([row.product_id]);
    const product = products.get(row.product_id);
    if (!product) throw new HttpError(404, MESSAGES.productNotFound);
    sets.push('options = ?');
    params.push(JSON.stringify(pricing.resolveOptions(product, payload.options)));
  }
  if (payload.note !== undefined) {
    sets.push('note = ?');
    params.push(pricing.noteOf(payload.note));
  }
  if (sets.length) {
    sets.push('updated_at = ?');
    params.push(new Date().toISOString(), itemId, userId);
    await query(`UPDATE cart_items SET ${sets.join(', ')} WHERE id = ? AND user_id = ?`, params);
  }
  return getItem(userId, itemId);
}

async function deleteItem(userId, itemId) {
  await query('DELETE FROM cart_items WHERE id = ? AND user_id = ?', [itemId, userId]);
  return { success: true, id: itemId };
}

async function clearCart(userId) {
  await query('DELETE FROM cart_items WHERE user_id = ?', [userId]);
  return { success: true };
}

/** Totaux du panier (`CartTotals.of`), avec un code promo éventuel. */
async function getTotals(userId, promoCode = null) {
  const items = await getCart(userId);
  const subtotal = items.reduce((sum, item) => sum + item.totalPrice, 0);
  const restaurant = items.length ? await pricing.loadRestaurant(items[0].product.restaurantId) : null;
  const base = pricing.totalsFor(subtotal, restaurant);
  const discount = pricing.promoDiscount(promoCode, base.subtotal, base.deliveryFee);
  const totals = pricing.totalsFor(subtotal, restaurant, discount || 0);
  return {
    ...totals,
    promoCode: promoCode && discount != null ? String(promoCode).trim().toUpperCase() : null,
    promoValid: promoCode ? discount != null : null,
    itemCount: items.reduce((sum, item) => sum + item.quantity, 0),
    restaurantId: restaurant?.id || null,
    restaurantName: restaurant?.name || null,
    minOrder: restaurant ? Number(restaurant.min_order) || 0 : 0,
    isOpen: restaurant ? Number(restaurant.is_open) === 1 : null,
  };
}

module.exports = {
  MESSAGES,
  getCart,
  getItem,
  addItem,
  updateItem,
  deleteItem,
  clearCart,
  getTotals,
};
