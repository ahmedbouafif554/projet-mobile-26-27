'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close } = require('../src/data/db');

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
});

afterAll(async () => {
  await close();
});

describe('E2E Frontend <-> Backend Link : Module 3 (Panier & Commandes)', () => {
  test('Flux complet Front Office & Back Office : Panier -> Validation -> Commande -> Cuisine -> Suivi', async () => {
    const userId = 'u-client-1';
    const restaurantId = 'rest_demo';

    // ── 1. FRONT OFFICE : Consultation du panier initial ─────────────────────
    const emptyCart = await request(app)
      .get('/api/cart/items')
      .query({ userId });
    expect(emptyCart.status).toBe(200);
    expect(emptyCart.body).toEqual([]);

    // ── 2. FRONT OFFICE : Ajout d'articles au panier ─────────────────────────
    // Ajout d'un burger avec options et note
    const item1 = await request(app)
      .post('/api/cart/items')
      .query({ userId })
      .send({
        product: {
          id: 'prod_1',
          restaurantId: 'rest_demo',
          name: 'Classic Burger',
          price: 9.9,
          imageUrl: 'https://images.unsplash.com/photo-burger',
          section: 'Burgers',
        },
        quantity: 1,
        options: [{ id: 'opt_cheddar', name: 'Extra Cheddar', price: 1.0 }],
        note: 'Bien cuit svp',
      });
    expect(item1.status).toBe(201);
    expect(item1.body.id).toMatch(/^ci_/);
    expect(item1.body.product.name).toBe('Classic Burger');
    expect(item1.body.options).toHaveLength(1);

    // Ajout du même article pour tester la fusion automatique
    const item1Duplicate = await request(app)
      .post('/api/cart/items')
      .query({ userId })
      .send({
        product: { id: 'prod_1', restaurantId: 'rest_demo', price: 9.9 },
        quantity: 1,
        options: [{ id: 'opt_cheddar', name: 'Extra Cheddar', price: 1.0 }],
        note: 'Bien cuit svp',
      });
    expect(item1Duplicate.status).toBe(201);
    expect(item1Duplicate.body.id).toBe(item1.body.id);
    expect(item1Duplicate.body.quantity).toBe(2);

    // Ajout d'une portion de frites
    const item2 = await request(app)
      .post('/api/cart/items')
      .query({ userId })
      .send({
        product: {
          id: 'prod_3',
          restaurantId: 'rest_demo',
          name: 'Frites',
          price: 3.5,
          section: 'Accompagnements',
        },
        quantity: 1,
      });
    expect(item2.status).toBe(201);

    // ── 3. FRONT OFFICE : Vérification des articles & calcul des totaux ──────
    const cartList = await request(app)
      .get('/api/cart/items')
      .query({ userId });
    expect(cartList.status).toBe(200);
    expect(cartList.body).toHaveLength(2);

    // Totaux : 2 * (9.9 + 1.0) + 1 * 3.5 = 21.80 + 3.50 = 25.30
    const totals = await request(app)
      .get('/api/cart/totals')
      .query({ userId, promoCode: 'BIENVENUE' });
    expect(totals.status).toBe(200);
    expect(totals.body.subtotal).toBe(25.3);
    expect(totals.body.discount).toBe(5.0); // -5 € BIENVENUE car subtotal >= 15 €
    expect(totals.body.total).toBeGreaterThan(0);

    // ── 4. FRONT OFFICE : Validation de la commande (Checkout) ───────────────
    const checkoutRes = await request(app)
      .post('/api/orders')
      .send({
        userId,
        restaurantId,
        customerName: 'Alex Martin',
        deliveryAddress: {
          id: 'a-1',
          userId,
          label: 'Maison',
          street: '12 rue de la Paix',
          postalCode: '75002',
          city: 'Paris',
          type: 'home',
          instructions: 'Digicode 4521, 3e étage',
          isDefault: true,
          latitude: 48.8686,
          longitude: 2.3312,
        },
        items: cartList.body,
        deliveryFee: totals.body.deliveryFee,
        serviceFee: totals.body.serviceFee,
        discount: totals.body.discount,
        promoCode: 'BIENVENUE',
        paymentMethod: 'card',
        paymentStatus: 'paid',
        note: 'Livrer sans sonner svp',
      });

    expect(checkoutRes.status).toBe(201);
    const order = checkoutRes.body;
    expect(order.id).toMatch(/^ord_/);
    expect(order.reference).toMatch(/^CMD-/);
    expect(order.status).toBe('pending');
    expect(order.items).toHaveLength(2);
    expect(order.deliveryAddress.street).toBe('12 rue de la Paix');

    // Vérifier que le panier a été automatiquement vidé suite à la commande
    const cartAfterOrder = await request(app)
      .get('/api/cart/items')
      .query({ userId });
    expect(cartAfterOrder.status).toBe(200);
    expect(cartAfterOrder.body).toHaveLength(0);

    // ── 5. BACK OFFICE : Réception par le restaurateur en Cuisine (Kanban) ───
    // Le restaurateur consulte ses commandes reçues
    const kitchenOrders = await request(app)
      .get('/api/orders')
      .query({ restaurantId });
    expect(kitchenOrders.status).toBe(200);
    const foundInKitchen = kitchenOrders.body.find((o) => o.id === order.id);
    expect(foundInKitchen).toBeDefined();
    expect(foundInKitchen.status).toBe('pending');

    // ── 6. BACK OFFICE : Transition vers "accepted" (Acceptée) ───────────────
    const accepted = await request(app)
      .patch(`/api/orders/${order.id}/status`)
      .send({ status: 'accepted', note: 'Commande acceptée par le restaurant' });
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('accepted');

    // ── 7. BACK OFFICE : Transition vers "preparing" (En préparation) ────────
    const preparing = await request(app)
      .patch(`/api/orders/${order.id}/status`)
      .send({ status: 'preparing', note: 'Cuisson des steaks en cours' });
    expect(preparing.status).toBe(200);
    expect(preparing.body.status).toBe('preparing');

    // ── 8. BACK OFFICE : Transition vers "ready" (Prête pour livreur) ────────
    const ready = await request(app)
      .patch(`/api/orders/${order.id}/status`)
      .send({ status: 'ready', note: 'Commande prête au comptoir' });
    expect(ready.status).toBe(200);
    expect(ready.body.status).toBe('ready');

    // ── 9. FRONT OFFICE : Suivi en direct (Live Tracking & Timeline) ─────────
    const tracking = await request(app).get(`/api/orders/${order.id}/tracking`);
    expect(tracking.status).toBe(200);
    expect(tracking.body.delivery).toBeDefined();
    expect(tracking.body.steps).toHaveLength(5);

    const timeline = await request(app).get(`/api/orders/${order.id}/timeline`);
    expect(timeline.status).toBe(200);
    expect(timeline.body.length).toBeGreaterThanOrEqual(4);
    expect(timeline.body.map((e) => e.status)).toEqual(
      expect.arrayContaining(['pending', 'accepted', 'preparing', 'ready']),
    );

    // ── 10. BACK OFFICE : Statistiques du restaurant mises à jour ────────────
    const stats = await request(app)
      .get('/api/oussema/commandes/stats')
      .query({ restaurantId });
    expect(stats.status).toBe(200);
    expect(stats.body.totalOrders).toBeGreaterThanOrEqual(1);
    expect(stats.body.totalRevenue).toBeGreaterThan(0);
  });
});

