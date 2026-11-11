'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close } = require('../src/data/db');
const { ADMIN, ALEX, KARIM, acceptedOrder } = require('./helpers');

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
});

afterAll(async () => {
  await close();
});

describe('Outils de dispatch du back office (/api/oussema/livraisons)', () => {
  test('réservés à l’administrateur', async () => {
    expect((await request(app).get('/api/oussema/livraisons')).status).toBe(401);
    expect((await request(app).get('/api/oussema/livraisons').set(ALEX)).status).toBe(403);
    expect((await request(app).get('/api/oussema/livraisons/nearby-couriers').set(KARIM)).status).toBe(403);
    // Repli de /api/deliveries : mêmes droits.
    expect((await request(app).post('/api/deliveries/couriers/c-1/location').send({ latitude: 1, longitude: 1 })).status).toBe(401);
  });

  test('livreurs proches puis dispatch automatique selon les règles du module livraison', async () => {
    const nearby = await request(app)
      .get('/api/oussema/livraisons/nearby-couriers')
      .set(ADMIN)
      .query({ latitude: 48.8699, longitude: 2.3305, maxDistanceKm: 15 });
    expect(nearby.status).toBe(200);
    expect(nearby.body[0].courier.name).toBe('Karim Benali');

    const { order, delivery } = await acceptedOrder(app, { items: [{ product: { id: 'prod_2' }, quantity: 1 }] });
    const dispatch = await request(app).post(`/api/oussema/livraisons/${delivery.id}/auto-dispatch`).set(ADMIN);
    expect(dispatch.status).toBe(200);
    expect(dispatch.body.delivery).toMatchObject({ status: 'assigned', courierId: 'c-1' });
    expect(dispatch.body.courier.id).toBe('c-1');
    expect((await request(app).get('/api/couriers/c-1').set(ADMIN)).body.status).toBe('busy');

    // Plus aucun livreur libre : le dispatch suivant échoue proprement.
    const second = await acceptedOrder(app, { items: [{ product: { id: 'prod_2' }, quantity: 1 }] });
    const none = await request(app).post(`/api/oussema/livraisons/${second.delivery.id}/auto-dispatch`).set(ADMIN);
    expect(none.status).toBe(404);

    // Le suivi de la commande montre la course et le livreur.
    const tracking = await request(app).get(`/api/orders/${order.id}/tracking`).set(ALEX);
    expect(tracking.status).toBe(200);
    expect(tracking.body.delivery.status).toBe('assigned');
    expect(tracking.body.courier.id).toBe('c-1');
    expect(tracking.body.delivery.otpCode).toHaveLength(4);
  });

  test('statut via l’outil admin : mêmes effets (commande, gains, livreur libéré)', async () => {
    const { order, delivery } = await acceptedOrder(app);
    await request(app).patch(`/api/oussema/livraisons/${delivery.id}/assign`).set(ADMIN).send({ courierId: 'c-1' });
    const before = (await request(app).get('/api/couriers/c-1').set(ADMIN)).body;

    await request(app).patch(`/api/oussema/livraisons/${delivery.id}/status`).set(ADMIN).send({ status: 'pickedUp' });
    expect((await request(app).get(`/api/orders/${order.id}`).set(ALEX)).body.status).toBe('delivering');
    const done = await request(app).patch(`/api/oussema/livraisons/${delivery.id}/status`).set(ADMIN).send({ status: 'delivered' });
    expect(done.body.status).toBe('delivered');
    expect((await request(app).get(`/api/orders/${order.id}`).set(ALEX)).body.status).toBe('delivered');

    const after = (await request(app).get('/api/couriers/c-1').set(ADMIN)).body;
    expect(after.status).toBe('available');
    expect(after.completedDeliveries).toBe(before.completedDeliveries + 1);
  });
});
