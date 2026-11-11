'use strict';

const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const messagerie = require('../src/messagerie');
const avisNotification = require('../src/avis_notification');
const { as, ADMIN, ALEX, KARIM, acceptedOrder } = require('./helpers');

const MARC = as('u-resto-1');
const INES = as('u-client-2');

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  await messagerie.clear();
  await avisNotification.clear();
  await query("UPDATE restaurants SET owner_id = 'u-resto-1' WHERE id = 'rest_demo'");
  await query(
    `INSERT INTO users (id, first_name, last_name, email, phone, role, status, loyalty_points, created_at)
     VALUES ('u-client-2', 'Inès', 'Roy', 'ines.roy@exemple.fr', '0611111111', 'client', 'active', 0, ?)`,
    [new Date().toISOString()],
  );
});

afterAll(async () => {
  await close();
});

const openChat = (headers, body) => request(app).post('/api/chats').set(headers).send(body);
const send = (headers, chatId, text) => request(app).post('/api/messages').set(headers).send({ id: '', chatId, text, senderId: 'u-admin' });

describe('Messagerie — conversations', () => {
  test('session obligatoire', async () => {
    expect((await request(app).get('/api/chats')).status).toBe(401);
    expect((await request(app).post('/api/messages').send({ text: 'x' })).status).toBe(401);
  });

  test('support : créé une fois, message d’accueil, l’admin répond au nom du support', async () => {
    const created = await openChat(ALEX, { type: 'support', title: 'ignoré', participantIds: ['u-client-2'] });
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ type: 'support', title: 'Support SuperFaster', unreadCount: 1, isOnline: true });
    expect(created.body.participantIds).toEqual(['u-client-1', 'u-admin']);
    const again = await openChat(ALEX, { type: 'support' });
    expect(again.body.id).toBe(created.body.id);

    const welcome = (await request(app).get(`/api/chats/${created.body.id}/messages`).set(ALEX)).body;
    expect(welcome).toHaveLength(1);
    expect(welcome[0]).toMatchObject({ senderName: 'Support SuperFaster', text: 'Bonjour ! Comment pouvons-nous vous aider ?' });

    // L'expéditeur est toujours le compte connecté.
    const mine = await send(ALEX, created.body.id, '  Ma commande est en retard  ');
    expect(mine.status).toBe(201);
    expect(mine.body).toMatchObject({ senderId: 'u-client-1', senderName: 'Alex Martin', text: 'Ma commande est en retard', status: 'sent' });

    // Côté admin : le titre est le nom du client, 1 non lu.
    const adminView = (await request(app).get('/api/chats').set(ADMIN)).body.find((c) => c.id === created.body.id);
    expect(adminView).toMatchObject({ title: 'Alex Martin', unreadCount: 1, lastMessage: 'Ma commande est en retard' });
    const reply = await send(ADMIN, created.body.id, 'Nous regardons tout de suite.');
    expect(reply.body.senderName).toBe('Support SuperFaster');

    // Le client a une notification qui ouvre la conversation.
    const notes = (await request(app).get('/api/users/u-client-1/notifications').set(ALEX)).body;
    expect(notes.find((n) => n.type === 'message')).toMatchObject({
      title: 'Nouveau message de Support SuperFaster',
      route: `/account/messages/${created.body.id}`,
    });
  });

  test('client ↔ restaurant d’une commande : participants tirés de la commande', async () => {
    const { order } = await acceptedOrder(app);
    expect((await openChat(INES, { type: 'restaurant', orderId: order.id })).status).toBe(403);
    expect((await openChat(ALEX, { type: 'restaurant' })).status).toBe(422);

    const chat = (await openChat(ALEX, { type: 'restaurant', orderId: order.id, participantIds: ['u-client-1', 'u-client-2'] })).body;
    expect(chat).toMatchObject({ type: 'restaurant', title: 'SuperBurger Demo', subtitle: `Commande #${order.reference}`, orderId: order.id });
    expect(chat.participantIds).toEqual(['u-client-1', 'u-resto-1']);

    await send(ALEX, chat.id, 'Sans oignons svp');
    const marcList = (await request(app).get('/api/chats').set(MARC)).body;
    expect(marcList).toHaveLength(1);
    expect(marcList[0]).toMatchObject({ title: 'Alex Martin', unreadCount: 1 });
    // Un autre client n'y a pas accès.
    expect((await request(app).get(`/api/chats/${chat.id}/messages`).set(INES)).status).toBe(403);
    expect((await send(INES, chat.id, 'coucou')).status).toBe(403);
    expect((await request(app).get('/api/chats').set(INES).query({ userId: 'u-client-1' })).body).toEqual([]);
  });

  test('client ↔ livreur : seulement une fois le livreur assigné', async () => {
    const { order, delivery } = await acceptedOrder(app);
    const early = await openChat(ALEX, { type: 'courier', orderId: order.id });
    expect(early.status).toBe(409);
    expect(early.body.error).toBe("Aucun livreur n'est encore assigné à cette commande.");

    await request(app).patch(`/api/deliveries/${delivery.id}/assign`).set(KARIM).send({ courierId: 'c-1' });
    const chat = (await openChat(ALEX, { type: 'courier', orderId: order.id })).body;
    expect(chat).toMatchObject({ type: 'courier', title: 'Karim Benali' });
    // Le livreur retrouve la même conversation.
    expect((await openChat(KARIM, { type: 'courier', orderId: order.id })).body.id).toBe(chat.id);
    const karimView = (await request(app).get(`/api/chats/${chat.id}`).set(KARIM)).body;
    expect(karimView.title).toBe('Alex Martin');

    await send(KARIM, chat.id, 'Je suis en bas');
    const note = (await request(app).get('/api/users/u-client-1/notifications').set(ALEX)).body.find((n) => n.type === 'message');
    expect(note.route).toBe(`/account/messages/${chat.id}`);
    await send(ALEX, chat.id, "J'arrive");
    const courierNote = (await request(app).get('/api/users/u-courier-1/notifications').set(KARIM)).body.find((n) => n.type === 'message');
    expect(courierNote.route).toBe(`/courier/messages/${chat.id}`);
  });
});

describe('Messagerie — messages', () => {
  test('accusés, lu, modification par l’auteur, suppression, aperçu', async () => {
    const chat = (await openChat(ALEX, { type: 'support' })).body;
    const first = (await send(ALEX, chat.id, 'Premier')).body;
    const second = (await send(ALEX, chat.id, 'Second')).body;

    // L'admin ouvre la conversation : distribué, puis lu.
    await request(app).get(`/api/chats/${chat.id}/messages`).set(ADMIN);
    // L'admin n'est participant que s'il est l'agent du support (u-admin ici).
    const delivered = (await request(app).get(`/api/chats/${chat.id}/messages`).set(ALEX)).body;
    expect(delivered.find((m) => m.id === first.id).status).toBe('delivered');
    const read = await request(app).patch(`/api/chats/${chat.id}/read`).set(ADMIN);
    expect(read.body.unreadCount).toBe(0);
    const afterRead = (await request(app).get(`/api/chats/${chat.id}/messages`).set(ALEX)).body;
    expect(afterRead.find((m) => m.id === second.id).status).toBe('read');

    expect((await request(app).put(`/api/messages/${second.id}`).set(ADMIN).send({ text: 'piraté' })).status).toBe(403);
    const edited = await request(app).put(`/api/messages/${second.id}`).set(ALEX).send({ ...second, text: 'Second (corrigé)' });
    expect(edited.body).toMatchObject({ text: 'Second (corrigé)', editedAt: expect.any(String) });
    expect((await request(app).get(`/api/chats/${chat.id}`).set(ALEX)).body.lastMessage).toBe('Second (corrigé)');

    expect((await request(app).delete(`/api/messages/${second.id}`).set(as('u-client-2'))).status).toBe(403);
    expect((await request(app).delete(`/api/messages/${second.id}`).set(ALEX)).status).toBe(204);
    expect((await request(app).get(`/api/chats/${chat.id}`).set(ALEX)).body.lastMessage).toBe('Premier');

    expect((await send(ALEX, chat.id, '   ')).status).toBe(422);
    expect((await send(ALEX, chat.id, 'x'.repeat(2001))).status).toBe(422);
  });

  test('supervision : l’admin voit tout, signale et supprime ; le PUT du front ne falsifie rien', async () => {
    const { order } = await acceptedOrder(app);
    const chat = (await openChat(ALEX, { type: 'restaurant', orderId: order.id })).body;
    await send(ALEX, chat.id, 'Bonjour');

    const forged = await request(app).put(`/api/chats/${chat.id}`).set(ALEX).send({ ...chat, lastMessage: 'faux', unreadCount: 99, isFlagged: true });
    expect(forged.body).toMatchObject({ lastMessage: 'Bonjour', isFlagged: false });

    expect((await request(app).patch(`/api/chats/${chat.id}/flag`).set(ALEX).send({ isFlagged: true })).status).toBe(403);
    expect((await request(app).patch(`/api/chats/${chat.id}/flag`).set(ADMIN).send({ isFlagged: true })).body.isFlagged).toBe(true);
    expect((await request(app).get('/api/chats').set(ADMIN)).body.map((c) => c.id)).toContain(chat.id);

    expect((await request(app).delete(`/api/chats/${chat.id}`).set(ALEX)).status).toBe(403);
    expect((await request(app).delete(`/api/chats/${chat.id}`).set(ADMIN)).status).toBe(204);
    expect((await request(app).get(`/api/chats/${chat.id}`).set(ADMIN)).status).toBe(404);
  });
});
