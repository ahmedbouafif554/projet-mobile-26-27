'use strict';

/**
 * Parcours complet, avec les appels exacts des dépôts Flutter
 * (ApiCartRepository, ApiOrderRepository, ApiDeliveryRepository,
 * ApiCourierRepository) et de vraies sessions JWT (POST /auth/login).
 */

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const { ADDRESS } = require('./helpers');

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await query("UPDATE restaurants SET owner_id = 'u-resto-1' WHERE id = 'rest_demo'");
});

afterAll(async () => {
  await close();
});

async function session(email, space, role) {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ email, password: 'demo1234', space, ...(role ? { role } : {}) });
  expect(res.status).toBe(200);
  return { Authorization: `Bearer ${res.body.token}` };
}

describe('E2E Front Office ↔ Back Office : panier → commande → cuisine → livraison', () => {
  test('parcours complet avec de vraies sessions', async () => {
    const alex = await session('alex.martin@exemple.fr', 'frontOffice', 'client');
    const marc = await session('contact@burgerfactory.fr', 'backOffice');
    const karim = await session('karim.benali@superfaster.fr', 'frontOffice', 'courier');
    const admin = await session('admin@superfaster.fr', 'backOffice');

    // ── 1. Client : panier (CartController.add) ────────────────────────────
    expect((await request(app).get('/api/cart/items').set(alex)).body).toEqual([]);
    const burger = await request(app)
      .post('/api/cart/items')
      .set(alex)
      .send({ id: '', product: { id: 'prod_1', restaurantId: 'rest_demo', name: 'Classic Burger', price: 9.9 }, quantity: 2, options: [], note: 'Bien cuit' });
    expect(burger.status).toBe(201);
    await request(app).post('/api/cart/items').set(alex).send({ id: '', product: { id: 'prod_3' }, quantity: 1, options: [], note: null });
    const cart = (await request(app).get('/api/cart/items').set(alex)).body;
    expect(cart).toHaveLength(2);

    // ── 2. Client : commande (MyOrdersController.place → Order.toJson) ──────
    const placed = await request(app)
      .post('/api/orders')
      .set(alex)
      .send({
        id: '',
        reference: '',
        userId: 'u-client-1',
        customerName: 'Alex Martin',
        restaurantId: 'rest_demo',
        restaurantName: 'SuperBurger Demo',
        items: cart,
        deliveryAddress: ADDRESS,
        deliveryFee: 2.5,
        serviceFee: 1.17,
        discount: 5,
        status: 'pending',
        paymentMethod: 'cash',
        paymentStatus: 'pending',
        promoCode: 'BIENVENUE',
        note: 'Livrer sans sonner',
        history: [{ status: 'pending', at: new Date().toISOString(), note: null }],
        createdAt: new Date().toISOString(),
      });
    expect(placed.status).toBe(201);
    const order = placed.body;
    // 2 × 9,90 + 3,50 = 23,30 ; + 2,50 livraison + 1,17 service − 5 promo.
    expect(order).toMatchObject({ status: 'pending', subtotal: 23.3, discount: 5, totalAmount: 21.97 });
    expect((await request(app).get('/api/cart/items').set(alex)).body).toEqual([]);
    expect((await request(app).get('/api/orders').set(alex).query({ userId: 'u-client-1' })).body.map((o) => o.id)).toEqual([order.id]);

    // ── 3. Restaurateur : cuisine (OrdersController.updateStatus) ───────────
    const kitchen = await request(app).get('/api/orders').set(marc).query({ restaurantId: 'rest_demo' });
    expect(kitchen.body.map((o) => o.id)).toContain(order.id);
    for (const status of ['accepted', 'preparing']) {
      const res = await request(app).patch(`/api/orders/${order.id}/status`).set(marc).send({ status, note: null });
      expect(res.status).toBe(200);
    }

    // ── 4. Livreur : course proposée, acceptée (AvailableDeliveriesController) ──
    const offers = await request(app).get('/api/deliveries').set(karim).query({ status: 'waiting' });
    const offer = offers.body.find((d) => d.orderId === order.id);
    expect(offer).toBeDefined();
    expect(offer.otpCode).toBeUndefined();
    expect((await request(app).patch(`/api/deliveries/${offer.id}/assign`).set(karim).send({ courierId: 'c-1' })).status).toBe(200);
    expect((await request(app).patch('/api/couriers/c-1/status').set(karim).send({ status: 'busy' })).status).toBe(200);

    // Le restaurant termine la préparation ; le back office appelle aussi
    // _ensureDelivery (POST /deliveries) : la course existante est renvoyée.
    expect((await request(app).patch(`/api/orders/${order.id}/status`).set(marc).send({ status: 'ready' })).status).toBe(200);
    const ensured = await request(app).post('/api/deliveries').set(marc).send({ orderId: order.id, fee: 99 });
    expect(ensured.status).toBe(200);
    expect(ensured.body.id).toBe(offer.id);

    // ── 5. Livreur : récupérée → en route → livrée (MyDeliveriesController.advance) ──
    for (const [deliveryStatus, orderStatus] of [['pickedUp', 'delivering'], ['inTransit', 'delivering'], ['delivered', 'delivered']]) {
      const step = await request(app).patch(`/api/deliveries/${offer.id}/status`).set(karim).send({ status: deliveryStatus });
      expect(step.status).toBe(200);
      // Le front renvoie ensuite le statut de la commande : sans effet.
      const echo = await request(app).patch(`/api/orders/${order.id}/status`).set(karim).send({ status: orderStatus });
      expect(echo.status).toBe(200);
    }

    // ── 6. Résultat visible par chacun ───────────────────────────────────────
    const tracked = (await request(app).get(`/api/orders/${order.id}`).set(alex)).body;
    expect(tracked.status).toBe('delivered');
    // Espèces encaissées par le livreur à la remise.
    expect(tracked.paymentStatus).toBe('paid');
    expect(tracked.history.map((e) => e.status)).toEqual(['pending', 'accepted', 'preparing', 'ready', 'delivering', 'delivered']);
    const me = (await request(app).get('/api/couriers').set(karim).query({ userId: 'u-courier-1' })).body[0];
    expect(me.status).toBe('available');
    const stats = (await request(app).get('/api/orders/stats').set(admin)).body;
    expect(stats.byStatus.delivered).toBe(1);
  });
});
