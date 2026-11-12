'use strict';

/**
 * Commandes de démonstration (Module 3) : une commande à chaque étape du
 * Kanban de la cuisine, et un article dans le panier d'Alex.
 * Elles passent par les mêmes services que l'API (prix, statuts, course).
 *
 * Utilisation : npm run seed:module3   (refusé en production)
 */

require('dotenv').config();
const config = require('../../config');
const { init } = require('../../data/db');
const imed = require('../../imed_livraison_livreur');
const panier = require('../services/panier.service');
const commandes = require('../services/commande.service');

const ALEX = { id: 'u-client-1', role: 'client' };
const ADMIN = { id: 'u-admin', role: 'admin' };

const ADDRESS = {
  id: 'a-1',
  userId: 'u-client-1',
  label: 'Maison',
  street: '12 rue de la Paix',
  postalCode: '75002',
  city: 'Paris',
  type: 'home',
  latitude: 48.8686,
  longitude: 2.3312,
};

const SAMPLES = [
  { target: 'pending', note: 'Sans sauce pimentée', promoCode: 'BIENVENUE', items: [['prod_1', 2], ['prod_3', 1]] },
  { target: 'preparing', note: 'Client fidèle', items: [['prod_2', 1], ['prod_4', 2]] },
  { target: 'ready', note: 'Emballage isotherme demandé', items: [['prod_1', 1], ['prod_2', 1]] },
  { target: 'delivering', note: 'Code porte 2341', items: [['prod_1', 1]], paymentMethod: 'cash' },
];

const STEPS = ['accepted', 'preparing', 'ready', 'delivering'];

async function seedModule3() {
  if (config.isProduction) {
    console.error('Données de démonstration refusées en production.');
    process.exit(1);
  }
  await init();
  await imed.init();
  console.log('📦 Données de démonstration du Module 3…');

  if ((await panier.getCart(ALEX.id)).length === 0) {
    await panier.addItem(ALEX.id, { product: { id: 'prod_1' }, quantity: 2, note: 'Bien chaud svp' });
    console.log('  🛒 Panier d’Alex : 2 × Classic Burger');
  }

  for (const sample of SAMPLES) {
    try {
      const order = await commandes.createOrder(ALEX, {
        restaurantId: 'rest_demo',
        deliveryAddress: ADDRESS,
        note: sample.note,
        promoCode: sample.promoCode,
        paymentMethod: sample.paymentMethod || 'cash',
        clearCart: false,
        items: sample.items.map(([id, quantity]) => ({ product: { id }, quantity })),
      });
      for (const step of STEPS.slice(0, STEPS.indexOf(sample.target) + 1)) {
        await commandes.updateOrderStatus(ADMIN, order.id, step);
      }
      console.log(`  ✅ #${order.reference} → ${sample.target} (${order.totalAmount.toFixed(2)} €)`);
    } catch (error) {
      console.log(`  ⚠️  ${sample.target} : ${error.message}`);
    }
  }
  console.log('Terminé.');
}

if (require.main === module) {
  seedModule3().then(
    () => process.exit(0),
    (error) => {
      console.error(error);
      process.exit(1);
    },
  );
}

module.exports = { seedModule3 };
