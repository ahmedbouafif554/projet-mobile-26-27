'use strict';

/**
 * Prix côté serveur, identiques aux calculs du front (`CartItem.unitPrice`,
 * `CartTotals`, `PromoCodes`) mais à partir des données en base : le prix
 * envoyé par l'application n'est jamais utilisé.
 */

const HttpError = require('../../errors/http-error');
const { query } = require('../../data/db');
const { presentProduct } = require('../../restaurant_catalogue/domain/catalogue.presenters');
const { MAX_QUANTITY_PER_ITEM, calculateServiceFee } = require('../domain/panier.constants');

function round2(value) {
  return Math.round(Number(value) * 100) / 100;
}

/** Produits en base, présentés comme `Product.fromJson`. */
async function loadProducts(ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return new Map();
  const rows = await query(
    `SELECT * FROM products WHERE id IN (${unique.map(() => '?').join(',')})`,
    unique,
  );
  return new Map(rows.map((row) => [row.id, presentProduct(row)]));
}

async function loadRestaurant(id) {
  if (!id) return null;
  const rows = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [id]);
  return rows[0] || null;
}

function productIdOf(input) {
  if (!input || typeof input !== 'object') return null;
  const id = input.product?.id ?? input.productId ?? null;
  return typeof id === 'string' && id.trim() ? id.trim() : null;
}

function quantityOf(value, { allowZero = false } = {}) {
  const quantity = Number(value);
  if (!Number.isInteger(quantity) || quantity < (allowZero ? 0 : 1)) {
    throw new HttpError(422, 'Quantité invalide.');
  }
  if (quantity > MAX_QUANTITY_PER_ITEM) {
    throw new HttpError(422, `${MAX_QUANTITY_PER_ITEM} exemplaires maximum par article.`);
  }
  return quantity;
}

function noteOf(value) {
  if (value == null) return null;
  if (typeof value !== 'string') throw new HttpError(422, 'Note invalide.');
  const note = value.trim();
  if (note.length > 300) throw new HttpError(422, 'La note est trop longue (300 caractères maximum).');
  return note || null;
}

/**
 * Options choisies, relues dans les groupes d'options du produit : nom et
 * supplément viennent de la base. Vérifie les choix obligatoires et le
 * nombre maximum de choix par groupe.
 */
function resolveOptions(product, requested) {
  const wanted = Array.isArray(requested) ? requested : [];
  const groups = Array.isArray(product.optionGroups) ? product.optionGroups : [];
  const byId = new Map();
  for (const group of groups) {
    for (const option of group.options || []) byId.set(option.id, { option, group });
  }

  const chosen = [];
  const seen = new Set();
  const perGroup = new Map();
  for (const raw of wanted) {
    const id = typeof raw === 'string' ? raw : raw?.id;
    if (typeof id !== 'string' || !byId.has(id)) {
      throw new HttpError(422, `Option indisponible pour « ${product.name} ».`);
    }
    if (seen.has(id)) continue;
    seen.add(id);
    const { option, group } = byId.get(id);
    perGroup.set(group.id, (perGroup.get(group.id) || 0) + 1);
    chosen.push({ id: option.id, name: option.name, price: round2(Number(option.price) || 0) });
  }

  for (const group of groups) {
    const count = perGroup.get(group.id) || 0;
    const max = Math.max(1, Number(group.maxChoices) || 1);
    if (count > max) {
      throw new HttpError(422, `« ${group.name} » : ${max} choix maximum.`);
    }
    if (group.isRequired && count === 0) {
      throw new HttpError(422, `« ${group.name} » est obligatoire pour « ${product.name} ».`);
    }
  }
  return chosen;
}

function unitPrice(product, options) {
  return round2(Number(product.price) + options.reduce((sum, o) => sum + Number(o.price || 0), 0));
}

/** Clé de fusion du panier (`CartItem.mergeKey`). */
function mergeKey(productId, options, note) {
  const ids = options.map((o) => o.id).sort().join(',');
  return `${productId}|${ids}|${note || ''}`;
}

/**
 * Codes promo (`PromoCodes.discountFor`). Renvoie la réduction, ou null si
 * le code est invalide ou ne s'applique pas.
 */
function promoDiscount(code, subtotal, deliveryFee) {
  if (code == null || String(code).trim() === '') return 0;
  switch (String(code).trim().toUpperCase()) {
    case 'SUPER10':
      return round2(subtotal * 0.1);
    case 'BIENVENUE':
      return subtotal >= 15 ? 5 : null;
    case 'LIVRAISON':
      return round2(deliveryFee);
    default:
      return null;
  }
}

/** Totaux (`CartTotals.of`) : frais de livraison du restaurant, service 5 %. */
function totalsFor(subtotal, restaurant, discount = 0) {
  const sub = round2(subtotal);
  const deliveryFee = sub > 0 ? round2(Number(restaurant?.delivery_fee) || 0) : 0;
  const serviceFee = round2(calculateServiceFee(sub));
  const total = Math.max(0, round2(sub + deliveryFee + serviceFee - discount));
  return { subtotal: sub, deliveryFee, serviceFee, discount: round2(discount), total };
}

module.exports = {
  round2,
  loadProducts,
  loadRestaurant,
  productIdOf,
  quantityOf,
  noteOf,
  resolveOptions,
  unitPrice,
  mergeKey,
  promoDiscount,
  totalsFor,
};
