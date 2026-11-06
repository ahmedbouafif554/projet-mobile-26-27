'use strict';

/**
 * Script de pré-remplissage pour le Module 3 (Panier & Commandes)
 * Permet d'insérer des commandes et articles de démonstration dans la base SQLite
 * pour une soutenance ou un test immédiat sur le Kanban de la Cuisine et le suivi.
 *
 * Utilisation : node src/oussema_panier_commande/seed/seed-demo-orders.js
 */

require('dotenv').config();
const { init, query, newId } = require('../../data/db');
const { getCart, addItem } = require('../services/panier.service');
const { createOrder, updateOrderStatus } = require('../services/commande.service');

async function seedModule3() {
  await init();
  console.log('📦 Remplissage des données de démonstration pour le Module 3...');

  // 1. Ajouter un article dans le panier du client démo u-client-1
  try {
    const existing = await getCart('u-client-1');
    if (existing.length === 0) {
      await addItem('u-client-1', {
        product: {
          id: 'prod_1',
          restaurantId: 'rest_demo',
          name: 'Classic Burger',
          price: 9.9,
          imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
          section: 'Burgers',
        },
        quantity: 2,
        options: [{ id: 'opt_cheddar', name: 'Extra Cheddar', price: 1.0 }],
        note: 'Bien chaud svp',
      });
      console.log('  🛒 1 article avec options ajouté au panier de u-client-1');
    }
  } catch (err) {
    console.log('  ⚠️ Erreur panier:', err.message);
  }

  // 2. Créer 4 commandes de démonstration à différents stades du Kanban
  const sampleOrders = [
    {
      reference: 'CMD-NOUV01',
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      statusTarget: 'pending',
      note: 'Sans sauce pimentée',
      deliveryAddress: {
        id: 'a-1',
        userId: 'u-client-1',
        label: 'Maison',
        street: '12 rue de la Paix',
        postalCode: '75002',
        city: 'Paris',
        type: 'home',
        latitude: 48.8686,
        longitude: 2.3312,
      },
      items: [{ productId: 'prod_1', quantity: 2 }, { productId: 'prod_3', quantity: 1 }],
      promoCode: 'BIENVENUE',
    },
    {
      reference: 'CMD-CUIS02',
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      statusTarget: 'preparing',
      note: 'Client fidèle',
      deliveryAddress: {
        id: 'a-2',
        userId: 'u-client-1',
        label: 'Bureau',
        street: '8 boulevard Haussmann',
        postalCode: '75009',
        city: 'Paris',
        type: 'work',
        latitude: 48.8732,
        longitude: 2.3325,
      },
      items: [{ productId: 'prod_2', quantity: 1 }, { productId: 'prod_4', quantity: 2 }],
    },
    {
      reference: 'CMD-PRET03',
      userId: 'u-client-9',
      restaurantId: 'rest_demo',
      statusTarget: 'ready',
      note: 'Emballage isotherme demandé',
      deliveryAddress: {
        id: 'a-3',
        userId: 'u-client-9',
        label: 'Appartement',
        street: '15 rue Oberkampf',
        postalCode: '75011',
        city: 'Paris',
        type: 'home',
        latitude: 48.8642,
        longitude: 2.3711,
      },
      items: [{ productId: 'prod_1', quantity: 1 }, { productId: 'prod_2', quantity: 1 }],
    },
    {
      reference: 'CMD-LIVR04',
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      statusTarget: 'delivering',
      note: 'Code porte 2341',
      deliveryAddress: {
        id: 'a-4',
        userId: 'u-client-1',
        label: 'Maison',
        street: '22 rue de Rivoli',
        postalCode: '75004',
        city: 'Paris',
        type: 'home',
        latitude: 48.8566,
        longitude: 2.3522,
      },
      items: [{ productId: 'prod_1', quantity: 1 }],
    },
  ];

  for (const sample of sampleOrders) {
    try {
      const order = await createOrder({
        ...sample,
        clearCart: false,
      });

      if (sample.statusTarget === 'preparing') {
        await updateOrderStatus(order.id, 'accepted', { note: 'Acceptée' });
        await updateOrderStatus(order.id, 'preparing', { note: 'En cours de préparation' });
      } else if (sample.statusTarget === 'ready') {
        await updateOrderStatus(order.id, 'accepted', { note: 'Acceptée' });
        await updateOrderStatus(order.id, 'preparing', { note: 'Préparation' });
        await updateOrderStatus(order.id, 'ready', { note: 'Prête pour le livreur' });
      } else if (sample.statusTarget === 'delivering') {
        await updateOrderStatus(order.id, 'accepted', { note: 'Acceptée' });
        await updateOrderStatus(order.id, 'preparing', { note: 'Préparation' });
        await updateOrderStatus(order.id, 'ready', { note: 'Prête' });
        await updateOrderStatus(order.id, 'delivering', { note: 'Livreur en route' });
      }

      console.log(`  ✅ Commande créée : ${sample.reference} (Statut: ${sample.statusTarget})`);
    } catch (err) {
      console.log(`  ⚠️ Erreur création commande ${sample.reference}:`, err.message);
    }
  }

  console.log('✨ Jeu de données de démonstration Module 3 injecté avec succès !');
  process.exit(0);
}

seedModule3().catch((err) => {
  console.error('Erreur globale seed Module 3:', err);
  process.exit(1);
});

