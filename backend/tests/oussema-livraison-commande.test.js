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

describe('Module Oussema — Livraison & Commande (Fonctionnalités avancées)', () => {
  test('1. Création avancée de commande avec calculs, code promo et création automatique de livraison', async () => {
    const res = await request(app)
      .post('/api/oussema/commandes')
      .send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '12 rue de la Paix, 75002 Paris',
        deliveryLat: 48.8686,
        deliveryLng: 2.3312,
        notes: 'Sonner au 3e étage',
        promoCode: 'BIENVENUE',
        items: [
          { productId: 'prod_1', quantity: 2 }, // Classic Burger: 9.90 * 2 = 19.80
          { productId: 'prod_3', quantity: 1 }, // Frites: 3.50
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.id).toEqual(expect.stringMatching(/^ord_/));
    expect(res.body.reference).toEqual(expect.stringMatching(/^CMD-/));
    expect(res.body.status).toBe('pending');
    expect(res.body.customerName).toBe('Alex Martin');
    expect(res.body.restaurantName).toBe('SuperBurger Demo');
    expect(res.body.items).toHaveLength(2);

    // Total: (19.80 + 3.50 = 23.30) + livraison (2.50) - promo (5.00) = 20.80
    expect(res.body.totalAmount).toBe(20.8);

    // Vérifier l'événement initial dans la timeline
    expect(res.body.timeline).toHaveLength(1);
    expect(res.body.timeline[0].status).toBe('pending');

    // Vérifier que la course de livraison liée a été automatiquement créée en statut 'waiting'
    const deliveries = await request(app)
      .get('/api/oussema/livraisons')
      .query({ status: 'waiting' });

    expect(deliveries.status).toBe(200);
    const linkedDelivery = deliveries.body.find((d) => d.orderId === res.body.id);
    expect(linkedDelivery).toBeDefined();
    expect(linkedDelivery.status).toBe('waiting');
    expect(linkedDelivery.otpCode).toHaveLength(4);
  });

  test('2. Machine d’états et timeline d’une commande', async () => {
    // Créer une commande
    const created = await request(app)
      .post('/api/orders')
      .send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '10 rue Oberkampf, Paris',
        items: [{ productId: 'prod_1', quantity: 1 }],
      });

    const orderId = created.body.id;

    // Transition valide : pending -> confirmed
    const confirmed = await request(app)
      .patch(`/api/orders/${orderId}/status`)
      .send({ status: 'confirmed', note: 'Commande acceptée par le chef' });
    expect(confirmed.status).toBe(200);
    expect(confirmed.body.status).toBe('confirmed');

    // Transition valide : confirmed -> preparing
    const preparing = await request(app)
      .patch(`/api/orders/${orderId}/status`)
      .send({ status: 'preparing', note: 'En cours de cuisson' });
    expect(preparing.status).toBe(200);
    expect(preparing.body.status).toBe('preparing');

    // Transition invalide : preparing -> delivered directement
    const invalid = await request(app)
      .patch(`/api/orders/${orderId}/status`)
      .send({ status: 'delivered' });
    expect(invalid.status).toBe(400);

    // Vérifier la timeline complète
    const timeline = await request(app).get(`/api/orders/${orderId}/timeline`);
    expect(timeline.status).toBe(200);
    expect(timeline.body.length).toBeGreaterThanOrEqual(3);
    expect(timeline.body.map((e) => e.status)).toEqual(
      expect.arrayContaining(['pending', 'confirmed', 'preparing']),
    );
  });

  test('3. Recherche de livreurs à proximité (Dispatch Haversine) et assignation automatique', async () => {
    // 1. Rechercher les livreurs à proximité des coordonnées du resto
    const nearby = await request(app)
      .get('/api/oussema/livraisons/nearby-couriers')
      .query({ latitude: 48.8699, longitude: 2.3305, maxDistanceKm: 15 });

    expect(nearby.status).toBe(200);
    expect(nearby.body.length).toBeGreaterThanOrEqual(1);
    expect(nearby.body[0].courier.name).toBe('Karim Benali');
    expect(nearby.body[0].distanceKm).toBeGreaterThan(0);

    // 2. Créer une commande
    const order = await request(app)
      .post('/api/orders')
      .send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '12 rue de la Paix, Paris',
        items: [{ productId: 'prod_2', quantity: 1 }],
      });

    const deliveries = await request(app)
      .get('/api/deliveries')
      .query({ status: 'waiting' });
    const delivery = deliveries.body.find((d) => d.orderId === order.body.id);
    expect(delivery).toBeDefined();

    // 3. Auto-dispatch : sélectionne et assigne automatiquement Karim Benali
    const dispatch = await request(app).post(
      `/api/oussema/livraisons/${delivery.id}/auto-dispatch`,
    );
    expect(dispatch.status).toBe(200);
    expect(dispatch.body.assignedCourier.name).toBe('Karim Benali');
    expect(dispatch.body.delivery.status).toBe('assigned');
    expect(dispatch.body.delivery.courierId).toBe('c-1');
  });

  test('4. Télémétrie GPS et écran de tracking en temps réel', async () => {
    // Créer commande et assigner livreur
    const order = await request(app).post('/api/orders').send({
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      deliveryAddress: '12 rue de la Paix, Paris',
      items: [{ productId: 'prod_1', quantity: 1 }],
    });

    const deliveries = await request(app).get('/api/deliveries');
    const delivery = deliveries.body.find((d) => d.orderId === order.body.id);

    await request(app)
      .post(`/api/deliveries/${delivery.id}/assign`)
      .send({ courierId: 'c-1' });

    // Ping GPS du livreur
    const ping = await request(app)
      .post('/api/oussema/livraisons/couriers/c-1/location')
      .send({
        deliveryId: delivery.id,
        latitude: 48.862,
        longitude: 2.345,
      });
    expect(ping.status).toBe(200);
    expect(ping.body.latitude).toBe(48.862);

    // Récupérer le tracking en direct
    const tracking = await request(app).get(
      `/api/oussema/livraisons/${delivery.id}/tracking`,
    );
    expect(tracking.status).toBe(200);
    expect(tracking.body.delivery.courierName).toBe('Karim Benali');
    expect(tracking.body.telemetry.courierPosition.latitude).toBe(48.862);
    expect(tracking.body.telemetry.remainingMinutes).toBeGreaterThan(0);
    expect(tracking.body.steps).toHaveLength(5);
    expect(tracking.body.steps[0].title).toBe('Commande validée');
  });

  test('5. Finalisation de livraison avec validation OTP et versement des gains au livreur', async () => {
    // 1. Vérifier les gains initiaux de Karim
    const initialStats = await request(app).get(
      '/api/oussema/livraisons/couriers/c-1/stats',
    );
    const initialEarnings = initialStats.body.totalEarnings;
    const initialCompleted = initialStats.body.completedDeliveries;

    // 2. Créer une commande
    const order = await request(app).post('/api/orders').send({
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      deliveryAddress: '12 rue de la Paix, Paris',
      items: [{ productId: 'prod_1', quantity: 1 }],
    });

    const deliveries = await request(app).get('/api/deliveries');
    const delivery = deliveries.body.find((d) => d.orderId === order.body.id);
    const correctOtp = delivery.otpCode;

    // 3. Assigner la course
    await request(app)
      .post(`/api/deliveries/${delivery.id}/assign`)
      .send({ courierId: 'c-1' });

    // 4. Passage à picked_up
    await request(app)
      .patch(`/api/deliveries/${delivery.id}/status`)
      .send({ status: 'picked_up' });

    // 5. Mauvais code OTP -> Erreur 403
    const badOtp = await request(app)
      .patch(`/api/deliveries/${delivery.id}/status`)
      .send({ status: 'delivered', otpCode: '0000' });
    expect(badOtp.status).toBe(403);

    // 6. Bon code OTP -> Succès 200
    const success = await request(app)
      .patch(`/api/deliveries/${delivery.id}/status`)
      .send({ status: 'delivered', otpCode: correctOtp });
    expect(success.status).toBe(200);
    expect(success.body.status).toBe('delivered');

    // 7. Vérifier que la commande liée est passée à 'delivered'
    const finalOrder = await request(app).get(`/api/orders/${order.body.id}`);
    expect(finalOrder.body.status).toBe('delivered');

    // 8. Vérifier la mise à jour des statistiques et gains du livreur
    const updatedStats = await request(app).get(
      '/api/oussema/livraisons/couriers/c-1/stats',
    );
    expect(updatedStats.body.completedDeliveries).toBe(initialCompleted + 1);
    expect(updatedStats.body.totalEarnings).toBeGreaterThan(initialEarnings);
    expect(updatedStats.body.status).toBe('available'); // Libéré pour une nouvelle course
  });

  test('6. Statistiques globales et par restaurant', async () => {
    // Créer une commande
    await request(app).post('/api/orders').send({
      userId: 'u-client-1',
      restaurantId: 'rest_demo',
      deliveryAddress: '12 rue de la Paix, Paris',
      items: [{ productId: 'prod_1', quantity: 1 }],
    });

    const stats = await request(app).get('/api/oussema/commandes/stats');
    expect(stats.status).toBe(200);
    expect(stats.body.totalOrders).toBeGreaterThanOrEqual(1);
    expect(stats.body.totalRevenue).toBeGreaterThan(0);
    expect(stats.body.byStatus).toBeDefined();
  });
});
