'use strict';

process.env.NODE_ENV = 'test';
const request = require('supertest');
const app = require('../src/app');
const helpers = require('./helpers');
const { init, reset, close, query } = require('../src/data/db');
const { estimate, travelMinutes } = require('../src/imed_livraison_livreur/services/eta');

const { ADMIN, ALEX, KARIM } = helpers;

// Restaurant et client à ~2 km l'un de l'autre.
const RESTAURANT = { latitude: 36.8065, longitude: 10.1815 };
const CLIENT = { latitude: 36.8245, longitude: 10.1815 };

describe('Estimation du temps de livraison', () => {
  const now = Date.parse('2026-11-12T12:00:00Z');

  test('trajet : facteur routier et vitesse du véhicule', () => {
    expect(travelMinutes(2, 'scooter')).toBe(5); // 2 × 1,3 / 30 km/h
    expect(travelMinutes(2, 'bike')).toBe(10);
    expect(travelMinutes(null)).toBeNull();
  });

  test('avant le retrait : max(préparation, trajet du livreur) + trajet vers le client', () => {
    const e = estimate({
      deliveryStatus: 'assigned',
      orderStatus: 'preparing',
      courier: { latitude: 36.7885, longitude: 10.1815 }, // ~2 km du restaurant
      pickup: RESTAURANT,
      dropoff: CLIENT,
      announcedMinutes: 30,
      prepStartedAt: new Date(now - 10 * 60000).toISOString(),
      now,
    });
    expect(e.phase).toBe('toRestaurant');
    expect(e.toRestaurantMinutes).toBe(5);
    expect(e.toCustomerMinutes).toBe(5);
    // Préparation : 30 − 5 − 2 = 23 min, déjà 10 écoulées → 13 restantes.
    expect(e.prepRemainingMinutes).toBe(13);
    expect(e.remainingMinutes).toBe(13 + 5 + 2);
    expect(Date.parse(e.estimatedArrivalAt)).toBe(now + 20 * 60000);
  });

  test('après le retrait : seulement le trajet du livreur jusqu’au client', () => {
    const e = estimate({
      deliveryStatus: 'inTransit',
      orderStatus: 'delivering',
      courier: { latitude: 36.8155, longitude: 10.1815 }, // à mi-chemin
      pickup: RESTAURANT,
      dropoff: CLIENT,
      now,
    });
    expect(e.phase).toBe('toCustomer');
    expect(e.remainingDistanceKm).toBe(1);
    expect(e.remainingMinutes).toBe(3 + 2);
  });

  test('préparation en retard : il reste toujours quelques minutes', () => {
    const e = estimate({
      deliveryStatus: 'waiting',
      orderStatus: 'preparing',
      courier: null,
      pickup: RESTAURANT,
      dropoff: CLIENT,
      announcedMinutes: 20,
      prepStartedAt: new Date(now - 60 * 60000).toISOString(),
      now,
    });
    expect(e.prepRemainingMinutes).toBe(2);
    expect(e.phase).toBe('searchingCourier');
    expect(e.remainingMinutes).toBeGreaterThan(e.toCustomerMinutes);
  });

  test('livrée : plus rien à attendre', () => {
    expect(estimate({ deliveryStatus: 'delivered', pickup: RESTAURANT, dropoff: CLIENT, now }).remainingMinutes).toBe(0);
  });
});

describe('Suivi : position du livreur', () => {
  beforeAll(init);
  beforeEach(reset);
  afterAll(close);

  test('une vieille position (données de démo) n’est jamais montrée ; le GPS récent l’est', async () => {
    const { order, delivery } = await helpers.acceptedOrder(app, {
      items: [{ product: { id: 'prod_1' }, quantity: 1 }],
    });
    // Position enregistrée il y a longtemps (ex. Paris dans les données de démo).
    await query('INSERT INTO courier_locations (courier_id, latitude, longitude, created_at) VALUES (?, ?, ?, ?)', [
      'c-1', 48.8566, 2.3522, '2020-01-01T00:00:00.000Z',
    ]);
    const assigned = await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    expect(assigned.status).toBe(200);
    expect(assigned.body.courierLat).toBeNull();

    let tracking = (await request(app).get(`/api/orders/${order.id}/tracking`).set(ALEX)).body;
    expect(tracking.positions.courier).toBeNull();
    expect(tracking.remainingMinutes).toBeGreaterThan(0);
    expect(tracking.estimatedArrivalAt).toEqual(expect.any(String));

    // Le téléphone du livreur envoie sa position réelle.
    const lat = tracking.positions.pickup.latitude + 0.01;
    const lng = tracking.positions.pickup.longitude;
    const sent = await request(app).post('/api/couriers/c-1/location').set(KARIM).send({ latitude: lat, longitude: lng });
    expect(sent.status).toBeLessThan(300);

    tracking = (await request(app).get(`/api/orders/${order.id}/tracking`).set(ALEX)).body;
    expect(tracking.positions.courier).toEqual({ latitude: lat, longitude: lng });
    expect(tracking.eta.phase).toBe('toRestaurant');
    expect(tracking.eta.toRestaurantKm).toBeCloseTo(1.1, 1);
  });

  test('le livreur voit à quelle distance de lui se trouve le restaurant', async () => {
    const order = (await helpers.placeOrder(app, { items: [{ product: { id: 'prod_1' }, quantity: 1 }] })).body;
    const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.id })).body;
    await request(app).post('/api/couriers/c-1/location').set(KARIM)
      .send({ latitude: delivery.pickupLat + 0.02, longitude: delivery.pickupLng });
    const offers = (await request(app).get('/api/deliveries').set(KARIM).query({ status: 'waiting' })).body;
    const offer = offers.find((d) => d.id === delivery.id);
    expect(offer.toPickupKm).toBeCloseTo(2.2, 1);
    expect(offer.toPickupMinutes).toEqual(expect.any(Number));
  });
});
