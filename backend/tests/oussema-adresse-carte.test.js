'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close } = require('../src/data/db');
const avisNotification = require('../src/avis_notification');

const ALEX = { Authorization: 'Bearer mock-token-u-client-1' };
const KARIM = { Authorization: 'Bearer mock-token-u-courier-1' }; // c-1, disponible
// u-courier-6 (c-6) est hors ligne : il ne doit pas être prévenu.

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await avisNotification.clear();
});

afterAll(async () => {
  await close();
});

/** Adresse placée sur la carte par le client (objet `Address` du front). */
const placedAddress = {
  id: 'addr-1',
  userId: 'u-client-1',
  label: 'Maison',
  street: '24 Rue de Rivoli',
  postalCode: '75004',
  city: 'Paris',
  type: 'home',
  instructions: 'Digicode 1234',
  isDefault: true,
  latitude: 48.85561,
  longitude: 2.35912,
};

const ADMIN = { Authorization: 'Bearer mock-token-u-admin' };

function order(address) {
  return request(app)
    .post('/api/orders')
    .set(ALEX)
    .send({
      restaurantId: 'rest_demo',
      deliveryAddress: address,
      items: [{ product: { id: 'prod_1' }, quantity: 2 }],
    });
}

/** Le restaurant accepte : la course est créée et les livreurs prévenus. */
function accept(orderId) {
  return request(app).patch(`/api/orders/${orderId}/status`).set(ADMIN).send({ status: 'accepted' });
}

describe('Module 3 (Oussema) : adresse placée sur la carte et livreurs prévenus', () => {
  test('la position exacte est enregistrée sur la commande et la course', async () => {
    const res = await order(placedAddress);
    expect(res.status).toBe(201);
    expect(res.body.deliveryAddress.latitude).toBeCloseTo(48.85561, 5);
    expect(res.body.deliveryAddress.longitude).toBeCloseTo(2.35912, 5);
    expect((await accept(res.body.id)).status).toBe(200);

    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: res.body.id })).body;
    expect(delivery.dropoffLat).toBeCloseTo(48.85561, 5);
    expect(delivery.dropoffLng).toBeCloseTo(2.35912, 5);
  });

  test('les livreurs disponibles reçoivent une notification avec l’adresse et le GPS', async () => {
    const res = await order(placedAddress);
    expect(res.status).toBe(201);
    // Pas de course proposée tant que le restaurant n'a pas accepté.
    const before = await request(app).get('/api/users/u-courier-1/notifications').set(KARIM);
    expect(before.body.some((n) => n.title.startsWith('Nouvelle course'))).toBe(false);
    expect((await accept(res.body.id)).status).toBe(200);

    const karim = await request(app).get('/api/users/u-courier-1/notifications').set(KARIM);
    const course = karim.body.find((n) => n.title.startsWith('Nouvelle course'));
    expect(course).toBeDefined();
    expect(course).toMatchObject({ type: 'order', route: '/courier/deliveries', isRead: false });
    expect(course.body).toContain('24 Rue de Rivoli, 75004 Paris');
    expect(course.body).toContain('GPS 48.85561, 2.35912');
    expect(course.body).toContain(res.body.reference);

    // Un livreur hors ligne n'est pas dérangé.
    const mehdi = await request(app)
      .get('/api/notifications')
      .set(ADMIN)
      .query({ userId: 'u-courier-6' });
    expect(mehdi.status).toBe(200);
    expect(mehdi.body.some((n) => n.title.startsWith('Nouvelle course'))).toBe(false);

    // Le client, lui, ne reçoit pas la notification de course.
    const alex = await request(app).get('/api/users/u-client-1/notifications').set(ALEX);
    expect(alex.body.some((n) => n.title.startsWith('Nouvelle course'))).toBe(false);
  });

  test('une position hors limites est refusée (422) et aucune commande n’est créée', async () => {
    const res = await order({ ...placedAddress, latitude: 123, longitude: 2.35 });
    expect(res.status).toBe(422);
    expect(res.body.message || res.body.error).toMatch(/carte/);
    const karim = await request(app).get('/api/users/u-courier-1/notifications').set(KARIM);
    expect(karim.body).toHaveLength(0);
  });

  test('enregistrer une adresse avec sa position exacte', async () => {
    const created = await request(app)
      .post('/api/addresses')
      .set(ALEX)
      .send({ ...placedAddress, id: '' });
    expect(created.status).toBe(201);
    expect(created.body.latitude).toBeCloseTo(48.85561, 5);
    expect(created.body.longitude).toBeCloseTo(2.35912, 5);

    const bad = await request(app)
      .post('/api/addresses')
      .set(ALEX)
      .send({ ...placedAddress, id: '', longitude: 500 });
    expect(bad.status).toBe(422);
  });
});
