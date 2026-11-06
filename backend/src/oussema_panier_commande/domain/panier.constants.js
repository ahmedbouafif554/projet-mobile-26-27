'use strict';

/**
 * Constantes et règles de calcul pour le Panier (Module 3)
 */

const MAX_QUANTITY_PER_ITEM = 99;

// Calcul des frais de service : 5 % du sous-total, entre 0,49 € et 1,99 € (identique à Flutter CartTotals.serviceFor)
function calculateServiceFee(subtotal) {
  if (!subtotal || subtotal <= 0) return 0;
  const raw = subtotal * 0.05;
  return Math.round(Math.min(1.99, Math.max(0.49, raw)) * 100) / 100;
}

// Calcul de la clé de fusion de deux articles du panier (identique à Flutter CartItem.mergeKey)
function getMergeKey(productId, options = [], note = null) {
  const optIds = (options || [])
    .map((o) => (typeof o === 'string' ? o : o.id || o.name))
    .filter(Boolean)
    .sort()
    .join(',');
  return `${productId}|${optIds}|${(note || '').trim()}`;
}

// Codes promo supportés (identique à Flutter PromoCodes)
function calculatePromoDiscount(code, subtotal, deliveryFee = 2.5) {
  if (!code) return 0;
  const clean = String(code).trim().toUpperCase();
  switch (clean) {
    case 'SUPER10':
      return Math.round(subtotal * 0.10 * 100) / 100;
    case 'BIENVENUE':
    case 'SUPER5':
      return subtotal >= 15 ? 5.0 : 0;
    case 'LIVRAISON':
      return deliveryFee;
    default:
      return 0;
  }
}

module.exports = {
  MAX_QUANTITY_PER_ITEM,
  calculateServiceFee,
  getMergeKey,
  calculatePromoDiscount,
};

