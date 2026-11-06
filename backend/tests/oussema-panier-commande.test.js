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

describe('Module 3 : Panier & Commandes (Oussema)', () => {
  describe('A. Gestion du Panier (Cart CRUD & Règles Métier)', () => {
    test('1. Ajout d’articles au panier, calculs et structure conforme Flutter CartItem', async () => {
      // 1. Ajouter un premier article avec options et note
      const res1 = await request(app)
        .post('/api/cart/items')
        .query({ userId: 'u-client-1' })
        .send({
          product: {
            id: 'prod_1',
            restaurantId: 'rest_demo',
            name: 'Classic Burger',
            price: 9.9,
          },
          quantity: 2,
          options: [{ id: 'opt_bacon', name: 'Bacon croustillant', price: 1.5 }],
          note: 'Sans oignons',
        });

      expect(res1.status).toBe(201);
      expect(res1.body.id).toEqual(expect.stringMatching(/^ci_/));
      expect(res1.body.product.id).toBe('prod_1');
      expect(res1.body.product.name).toBe('Classic Burger');
      expect(res1.body.quantity).toBe(2);
      expect(res1.body.options).toHaveLength(1);
      expect(res1.body.options[0].name).toBe('Bacon croustillant');
      expect(res1.body.note).toBe('Sans oignons');

      // 2. Fusion (merge) : ajouter le même article avec les mêmes options/note incrémente la quantité
      const res2 = await request(app)
        .post('/api/cart/items')
        .query({ userId: 'u-client-1' })
        .send({
          product: { id: 'prod_1', restaurantId: 'rest_demo', price: 9.9 },
          quantity: 1,
          options: [{ id: 'opt_bacon', name: 'Bacon croustillant', price: 1.5 }],
          note: 'Sans oignons',
        });

      expect(res2.status).toBe(201);
      expect(res2.body.id).toBe(res1.body.id);
      expect(res2.body.quantity).toBe(3);

      // 3. Récupérer le panier complet (GET /api/cart/items)
      const list = await request(app)
        .get('/api/cart/items')
        .query({ userId: 'u-client-1' });

      expect(list.status).toBe(200);
      expect(list.body).toHaveLength(1);
      expect(list.body[0].id).toBe(res1.body.id);
      expect(list.body[0].quantity).toBe(3);

      // 4. Modifier la quantité (PUT /api/cart/items/:id)
      const updateRes = await request(app)
        .put(`/api/cart/items/${res1.body.id}`)
        .query({ userId: 'u-client-1' })
        .send({ quantity: 4 });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.quantity).toBe(4);

      // 5. Totaux du panier avec code promo (SUPER10 -> -10%)
      const totalsRes = await request(app)
        .get('/api/cart/totals')
        .query({ userId: 'u-client-1', promoCode: 'SUPER10' });

      expect(totalsRes.status).toBe(200);
      // Prix unitaire = 9.90 + 1.50 = 11.40. Pour 4 = 45.60
      expect(totalsRes.body.subtotal).toBe(45.6);
      expect(totalsRes.body.discount).toBe(4.56);
      expect(totalsRes.body.total).toBeGreaterThan(0);

      // 6. Supprimer une ligne
      const delRes = await request(app)
        .delete(`/api/cart/items/${res1.body.id}`)
        .query({ userId: 'u-client-1' });
      expect(delRes.status).toBe(200);

      const afterDel = await request(app)
        .get('/api/cart/items')
        .query({ userId: 'u-client-1' });
      expect(afterDel.body).toHaveLength(0);
    });

    test('2. Règle mono-restaurant et vidage complet du panier', async () => {
      // Ajouter un produit chez rest_demo
      await request(app)
        .post('/api/cart/items')
        .query({ userId: 'u-client-1' })
        .send({
          product: { id: 'prod_1', restaurantId: 'rest_demo', name: 'Burger', price: 10 },
          quantity: 1,
        });

      // Tenter d'ajouter un produit d'un autre restaurant -> 409 Conflict
      const conflict = await request(app)
        .post('/api/cart/items')
        .query({ userId: 'u-client-1' })
        .send({
          product: { id: 'prod_other', restaurantId: 'rest_other', name: 'Sushi', price: 15 },
          quantity: 1,
        });
      expect(conflict.status).toBe(409);

      // Vidage du panier (DELETE /api/cart/items)
      const clearRes = await request(app)
        .delete('/api/cart/items')
        .query({ userId: 'u-client-1' });
      expect(clearRes.status).toBe(200);

      const emptyList = await request(app)
        .get('/api/cart/items')
        .query({ userId: 'u-client-1' });
      expect(emptyList.body).toHaveLength(0);
    });
  });

  describe('B. Cycle de Vie des Commandes (Order CRUD & State Machine)', () => {
    test('3. Création avancée de commande avec panier, calculs, code promo et adresse', async () => {
      const res = await request(app)
        .post('/api/orders')
        .send({
          userId: 'u-client-1',
          restaurantId: 'rest_demo',
          deliveryAddress: {
            id: 'a-1',
            userId: 'u-client-1',
            label: 'Maison',
            street: '12 rue de la Paix',
            postalCode: '75002',
            city: 'Paris',
            type: 'home',
            instructions: 'Sonner au 3e étage',
            isDefault: true,
            latitude: 48.8686,
            longitude: 2.3312,
          },
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
      expect(res.body.deliveryAddress.city).toBe('Paris');

      // Total: (19.80 + 3.50 = 23.30) + livraison (2.50) - promo (5.00) = 20.80
      expect(res.body.totalAmount).toBe(20.8);
      expect(res.body.timeline).toHaveLength(1);
      expect(res.body.timeline[0].status).toBe('pending');

      // Vérification que la livraison liée a été automatiquement créée en statut 'waiting'
      const deliveries = await request(app)
        .get('/api/deliveries')
        .query({ status: 'waiting' });
      expect(deliveries.status).toBe(200);
      const linkedDelivery = deliveries.body.find((d) => d.orderId === res.body.id);
      expect(linkedDelivery).toBeDefined();
      expect(linkedDelivery.status).toBe('waiting');
      expect(linkedDelivery.otpCode).toHaveLength(4);
    });

    test('4. Machine d’états, mise à jour (PUT/PATCH) et timeline', async () => {
      // 1. Créer une commande
      const created = await request(app)
        .post('/api/orders')
        .send({
          userId: 'u-client-1',
          restaurantId: 'rest_demo',
          deliveryAddress: '10 rue Oberkampf, Paris',
          items: [{ productId: 'prod_1', quantity: 1 }],
        });

      const orderId = created.body.id;

      // 2. Transition valide : pending -> accepted (utilisé par le front office & back office)
      const accepted = await request(app)
        .patch(`/api/orders/${orderId}/status`)
        .send({ status: 'accepted', note: 'Commande acceptée par le restaurant' });
      expect(accepted.status).toBe(200);
      expect(accepted.body.status).toBe('accepted');

      // 3. Transition valide : accepted -> preparing (cuisine)
      const preparing = await request(app)
        .patch(`/api/orders/${orderId}/status`)
        .send({ status: 'preparing', note: 'En cours de cuisson' });
      expect(preparing.status).toBe(200);
      expect(preparing.body.status).toBe('preparing');

      // 4. Transition valide : preparing -> ready (prête)
      const ready = await request(app)
        .put(`/api/orders/${orderId}/status`)
        .send({ status: 'ready', note: 'Commande emballée et prête' });
      expect(ready.status).toBe(200);
      expect(ready.body.status).toBe('ready');

      // 5. Transition invalide : ready -> pending directement (rejetée par la machine d'état)
      const invalid = await request(app)
        .patch(`/api/orders/${orderId}/status`)
        .send({ status: 'pending' });
      expect(invalid.status).toBe(400);

      // 6. Mise à jour générale de commande (PUT /api/orders/:id)
      const updated = await request(app)
        .put(`/api/orders/${orderId}`)
        .send({ note: 'Précision sur la commande' });
      expect(updated.status).toBe(200);
      expect(updated.body.note).toBe('Précision sur la commande');

      // 7. Timeline complète
      const timeline = await request(app).get(`/api/orders/${orderId}/timeline`);
      expect(timeline.status).toBe(200);
      expect(timeline.body.length).toBeGreaterThanOrEqual(4);
      expect(timeline.body.map((e) => e.status)).toEqual(
        expect.arrayContaining(['pending', 'accepted', 'preparing', 'ready']),
      );
    });

    test('5. Filtres de liste (userId, restaurantId) et annulation (cancel) / remboursement (refund)', async () => {
      // Créer 2 commandes
      const order1 = await request(app).post('/api/orders').send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '12 rue de la Paix, Paris',
        items: [{ productId: 'prod_1', quantity: 1 }],
      });

      const order2 = await request(app).post('/api/orders').send({
        userId: 'u-client-9',
        restaurantId: 'rest_demo',
        deliveryAddress: '5 avenue Montaigne, Paris',
        items: [{ productId: 'prod_2', quantity: 1 }],
      });

      // Filtrer par userId
      const userOrders = await request(app)
        .get('/api/orders')
        .query({ userId: 'u-client-1' });
      expect(userOrders.status).toBe(200);
      expect(userOrders.body.some((o) => o.id === order1.body.id)).toBe(true);
      expect(userOrders.body.some((o) => o.id === order2.body.id)).toBe(false);

      // Filtrer par restaurantId
      const restOrders = await request(app)
        .get('/api/orders')
        .query({ restaurantId: 'rest_demo' });
      expect(restOrders.status).toBe(200);
      expect(restOrders.body.length).toBeGreaterThanOrEqual(2);

      // Annuler la commande 1 (PATCH /api/orders/:id/cancel)
      const cancelled = await request(app)
        .patch(`/api/orders/${order1.body.id}/cancel`)
        .send({ reason: 'Changement d’avis du client' });
      expect(cancelled.status).toBe(200);
      expect(cancelled.body.status).toBe('cancelled');

      // Rembourser la commande 1 (PATCH /api/orders/:id/refund)
      const refunded = await request(app)
        .patch(`/api/orders/${order1.body.id}/refund`)
        .send({ reason: 'Remboursement suite à annulation' });
      expect(refunded.status).toBe(200);
      expect(refunded.body.status).toBe('refunded');

      // Supprimer une commande (DELETE /api/orders/:id)
      const deleted = await request(app).delete(`/api/orders/${order2.body.id}`);
      expect(deleted.status).toBe(200);

      const checkDeleted = await request(app).get(`/api/orders/${order2.body.id}`);
      expect(checkDeleted.status).toBe(404);
    });

    test('6. Statistiques globales des commandes', async () => {
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

  describe('C. Intégration Livraison & Dispatching (Module 4 rattaché)', () => {
    test('7. Dispatching Haversine, télémétrie GPS et validation OTP', async () => {
      // 1. Créer une commande
      const order = await request(app).post('/api/orders').send({
        userId: 'u-client-1',
        restaurantId: 'rest_demo',
        deliveryAddress: '12 rue de la Paix, Paris',
        items: [{ productId: 'prod_1', quantity: 1 }],
      });

      const deliveries = await request(app).get('/api/deliveries');
      const delivery = deliveries.body.find((d) => d.orderId === order.body.id);
      expect(delivery).toBeDefined();

      // 2. Assigner Karim Benali (c-1)
      await request(app)
        .post(`/api/deliveries/${delivery.id}/assign`)
        .send({ courierId: 'c-1' });

      // 3. Ping GPS
      const ping = await request(app)
        .post('/api/oussema/livraisons/couriers/c-1/location')
        .send({
          deliveryId: delivery.id,
          latitude: 48.862,
          longitude: 2.345,
        });
      expect(ping.status).toBe(200);

      // 4. Suivi live tracking
      const tracking = await request(app).get(
        `/api/oussema/livraisons/${delivery.id}/tracking`,
      );
      expect(tracking.status).toBe(200);
      expect(tracking.body.delivery.courierName).toBe('Karim Benali');
      expect(tracking.body.steps).toHaveLength(5);

      // 5. Prise en charge puis livraison sécurisée par OTP
      await request(app)
        .patch(`/api/deliveries/${delivery.id}/status`)
        .send({ status: 'picked_up' });

      const finish = await request(app)
        .patch(`/api/deliveries/${delivery.id}/status`)
        .send({ status: 'delivered', otpCode: delivery.otpCode });
      expect(finish.status).toBe(200);
      expect(finish.body.status).toBe('delivered');

      // 6. Commande liée passée en 'delivered'
      const finalOrder = await request(app).get(`/api/orders/${order.body.id}`);
      expect(finalOrder.body.status).toBe('delivered');
    });
  });
});

