'use strict';

/** Outils partagés par les tests (jetons, adresse, commande type). */

const request = require('supertest');

function as(userId) {
  return { Authorization: `Bearer mock-token-${userId}` };
}

const ADMIN = as('u-admin');
const ALEX = as('u-client-1');
const KARIM = as('u-courier-1');

/** Adresse d'Alex (seed), au format `Address.toJson()`. */
const ADDRESS = Object.freeze({
  id: 'a-1',
  userId: 'u-client-1',
  label: 'Maison',
  street: '12 rue de la Paix',
  postalCode: '75002',
  city: 'Paris',
  type: 'home',
  instructions: 'Digicode 4521, 3e étage',
  isDefault: true,
  latitude: 48.8686,
  longitude: 2.3312,
});

/** Commande d'Alex chez le restaurant de démo (201 attendu). */
async function placeOrder(app, extra = {}, headers = ALEX) {
  return request(app)
    .post('/api/orders')
    .set(headers)
    .send({
      restaurantId: 'rest_demo',
      deliveryAddress: ADDRESS,
      items: [{ product: { id: 'prod_1' }, quantity: 1 }],
      paymentMethod: 'cash',
      ...extra,
    });
}

/** Commande acceptée par le restaurant (admin) : sa course existe. */
async function acceptedOrder(app, extra = {}) {
  const order = await placeOrder(app, extra);
  if (order.status !== 201) throw new Error(`Commande refusée : ${JSON.stringify(order.body)}`);
  await request(app).patch(`/api/orders/${order.body.id}/status`).set(ADMIN).send({ status: 'accepted' });
  const [delivery] = (await request(app).get('/api/deliveries').set(ADMIN).query({ orderId: order.body.id })).body;
  return { order: order.body, delivery };
}

/** Commande livrée par Karim (c-1). */
async function deliveredOrder(app, extra = {}) {
  const { order, delivery } = await acceptedOrder(app, extra);
  for (const status of ['preparing', 'ready']) {
    await request(app).patch(`/api/orders/${order.id}/status`).set(ADMIN).send({ status });
  }
  await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
  await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'pickedUp' });
  await request(app).patch(`/api/deliveries/${delivery.id}/status`).set(KARIM).send({ status: 'delivered' });
  return (await request(app).get(`/api/orders/${order.id}`).set(ADMIN)).body;
}

module.exports = { as, ADMIN, ALEX, KARIM, ADDRESS, placeOrder, acceptedOrder, deliveredOrder };
