'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const helpers = require('./helpers');

const { ALEX, ADMIN, KARIM, ADDRESS } = helpers;

const OPTION_GROUPS = [
  {
    id: 'g-size',
    name: 'Taille',
    isRequired: true,
    maxChoices: 1,
    options: [
      { id: 'o-normal', name: 'Normal', price: 0 },
      { id: 'o-xl', name: 'XL', price: 2 },
    ],
  },
];

function placeOrder(appInstance, extra = {}, headers = ALEX) {
  return helpers.placeOrder(
    appInstance,
    { items: [{ product: { id: 'prod_1' }, quantity: 1, options: [{ id: 'o-normal' }] }], ...extra },
    headers,
  );
}

describe('Module 3 — Order as a Gift & Livreur Tips', () => {
  let testOrderId;
  let qrToken;

  beforeAll(async () => {
    await init();
    await reset();
    await query('UPDATE products SET option_groups = ? WHERE id = ?', [JSON.stringify(OPTION_GROUPS), 'prod_1']);
    const res = await placeOrder(app);
    testOrderId = res.body.id;
  }, 30000);

  afterAll(async () => {
    await close();
  });

  describe('Order as a Gift (Cadeau)', () => {
    test('Création d’un cadeau avec destinataire, message et carte numérique', async () => {
      const res = await request(app)
        .post(`/api/orders/${testOrderId}/gift`)
        .set(ALEX)
        .send({
          recipientName: 'Sophie Martin',
          recipientPhone: '0612345678',
          recipientEmail: 'sophie@example.com',
          senderName: 'Alex Test',
          isAnonymous: false,
          message: 'Bon anniversaire Sophie ! Régales-toi bien.',
          giftCardDesign: 'birthday',
          scheduledAt: new Date(Date.now() + 3600000).toISOString(),
        });

      expect(res.status).toBe(201);
      expect(res.body.recipientName).toBe('Sophie Martin');
      expect(res.body.isAnonymous).toBe(false);
      expect(res.body.senderName).toBe('Alex Test');
      expect(res.body.giftCardDesign).toBe('birthday');
      expect(res.body.qrCode).toBeDefined();
      expect(res.body.revealed).toBe(false);
      qrToken = res.body.qrCode;
    });

    test('Lecture du cadeau rattaché à la commande', async () => {
      const res = await request(app)
        .get(`/api/orders/${testOrderId}/gift`)
        .set(ALEX);

      expect(res.status).toBe(200);
      expect(res.body.recipientName).toBe('Sophie Martin');
      expect(res.body.message).toContain('Bon anniversaire');
    });

    test('Révélation du cadeau via son QR token (avec prix masqués)', async () => {
      const res = await request(app)
        .post('/api/orders/gifts/reveal')
        .send({ qrToken });

      expect(res.status).toBe(200);
      expect(res.body.gift).toBeDefined();
      expect(res.body.gift.revealed).toBe(true);
      expect(res.body.order).toBeDefined();
      expect(res.body.items).toBeDefined();
      expect(Array.isArray(res.body.items)).toBe(true);
      if (res.body.items.length > 0) {
        expect(res.body.items[0].price).toBeUndefined();
      }
    });
  });

  describe('Livreur Tips (Pourboires)', () => {
    test('Ajout d’un pourboire (pourcentage et message de remerciement)', async () => {
      const res = await request(app)
        .post(`/api/orders/${testOrderId}/tip`)
        .set(ALEX)
        .send({
          amount: 2.50,
          percentage: 10,
          thankYouMessage: 'Merci beaucoup pour la rapidité !',
          paymentMethod: 'card',
        });

      expect(res.status).toBe(201);
      expect(res.body.amount).toBe(2.50);
      expect(res.body.percentage).toBe(10);
      expect(res.body.thankYouMessage).toBe('Merci beaucoup pour la rapidité !');
    });

    test('Consultation des pourboires pour une commande', async () => {
      const res = await request(app)
        .get(`/api/orders/${testOrderId}/tip`)
        .set(ALEX);

      expect(res.status).toBe(200);
      expect(res.body.count).toBe(1);
      expect(res.body.tips[0].amount).toBe(2.50);
    });

    test('Consultation de l’historique des pourboires d’un coursier (admin)', async () => {
      const res = await request(app)
        .get('/api/orders/couriers/u-courier-1/tips')
        .set(ADMIN);

      expect(res.status).toBe(200);
      expect(res.body.totalEarned).toBeDefined();
      expect(res.body.tips).toBeDefined();
    });
  });
});
