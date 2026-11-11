'use strict';

const jwt = require('jsonwebtoken');
const request = require('supertest');
const app = require('../src/app');
const { init, reset, close, query } = require('../src/data/db');
const auth = require('../src/services/auth.service');
const mailer = require('../src/services/mailer.service');
const { loginLimiter } = require('../src/middleware/rate-limit');

const PASSWORD = 'demo1234';

beforeAll(async () => {
  await init();
}, 30000);

beforeEach(async () => {
  await reset();
  mailer.outbox.length = 0;
});

afterAll(async () => {
  await close();
});

const bearer = (token) => ({ Authorization: `Bearer ${token}` });

async function login(email, password = PASSWORD, extra = {}) {
  return request(app).post('/api/auth/login').send({ email, password, ...extra });
}

function resetTokenFromOutbox() {
  const mail = mailer.outbox.at(-1);
  const match = /token=([^\s"&]+)/.exec(mail.text);
  return decodeURIComponent(match[1]);
}

describe('jetons', () => {
  test('jeton absent, faux, expiré ou signé avec un autre secret : 401', async () => {
    expect((await request(app).get('/api/auth/me')).status).toBe(401);
    expect((await request(app).get('/api/auth/me').set(bearer('n-importe-quoi'))).status).toBe(401);
    const forged = jwt.sign({ sub: 'u-admin', role: 'admin', tv: 0 }, 'autre-secret');
    expect((await request(app).get('/api/auth/me').set(bearer(forged))).status).toBe(401);
    const expired = jwt.sign({ sub: 'u-admin', tv: 0 }, process.env.JWT_SECRET, { expiresIn: -10 });
    const res = await request(app).get('/api/auth/me').set(bearer(expired));
    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Session expirée, reconnectez-vous.');
    const none = jwt.sign({ sub: 'u-admin', tv: 0 }, '', { algorithm: 'none' });
    expect((await request(app).get('/api/auth/me').set(bearer(none))).status).toBe(401);
  });

  test('les jetons mock-token ne sont acceptés que pendant les tests', async () => {
    expect((await request(app).get('/api/auth/me').set(bearer('mock-token-u-admin'))).status).toBe(200);
    const previous = process.env.NODE_ENV;
    try {
      for (const env of ['development', 'production']) {
        process.env.NODE_ENV = env;
        expect((await request(app).get('/api/auth/me').set(bearer('mock-token-u-admin'))).status).toBe(401);
      }
    } finally {
      process.env.NODE_ENV = previous;
    }
  });

  test('un compte bloqué après la connexion perd l’accès immédiatement', async () => {
    const session = await login('alex.martin@exemple.fr');
    await query("UPDATE users SET status = 'blocked' WHERE id = 'u-client-1'");
    const res = await request(app).get('/api/auth/me').set(bearer(session.body.token));
    expect(res.status).toBe(403);
    expect(res.body.error).toBe('Ce compte est bloqué. Contactez le support.');
  });

  test('déconnexion de tous les appareils', async () => {
    const a = (await login('alex.martin@exemple.fr')).body.token;
    const b = (await login('alex.martin@exemple.fr')).body.token;
    expect((await request(app).post('/api/auth/logout-all').set(bearer(a))).status).toBe(200);
    expect((await request(app).get('/api/auth/me').set(bearer(a))).status).toBe(401);
    expect((await request(app).get('/api/auth/me').set(bearer(b))).status).toBe(401);
    expect((await login('alex.martin@exemple.fr')).status).toBe(200);
  });
});

describe('mot de passe', () => {
  test('changement : mot de passe actuel exigé, autres sessions révoquées', async () => {
    const other = (await login('alex.martin@exemple.fr')).body.token;
    const current = (await login('alex.martin@exemple.fr')).body.token;
    const change = (body) => request(app).post('/api/auth/change-password').set(bearer(current)).send(body);

    expect((await change({ currentPassword: 'mauvais', newPassword: 'nouveau123' })).status).toBe(403);
    expect((await change({ currentPassword: PASSWORD, newPassword: '123' })).status).toBe(422);
    expect((await change({ currentPassword: PASSWORD, newPassword: PASSWORD })).status).toBe(422);

    const ok = await change({ currentPassword: PASSWORD, newPassword: 'nouveau123' });
    expect(ok.status).toBe(200);
    expect(ok.body.user.id).toBe('u-client-1');
    // Le nouveau jeton fonctionne ; les anciens non.
    expect((await request(app).get('/api/auth/me').set(bearer(ok.body.token))).status).toBe(200);
    expect((await request(app).get('/api/auth/me').set(bearer(other))).status).toBe(401);
    expect((await login('alex.martin@exemple.fr')).status).toBe(401);
    expect((await login('alex.martin@exemple.fr', 'nouveau123')).status).toBe(200);
  });

  test('oublié : même réponse pour tous, lien à usage unique, sessions révoquées', async () => {
    const before = (await login('alex.martin@exemple.fr')).body.token;
    const unknown = await request(app).post('/api/auth/forgot-password').send({ email: 'personne@exemple.fr' });
    const known = await request(app).post('/api/auth/forgot-password').send({ email: 'ALEX.martin@exemple.fr' });
    expect(unknown.status).toBe(200);
    expect(known.body).toEqual(unknown.body);
    expect(mailer.outbox).toHaveLength(1);
    expect(mailer.outbox[0].to).toBe('alex.martin@exemple.fr');
    expect(mailer.outbox[0].text).toContain('/api/auth/reset-password?token=');

    const token = resetTokenFromOutbox();
    // Seul le hash est stocké en base.
    const stored = await query('SELECT token_hash FROM password_resets');
    expect(stored[0].token_hash).not.toBe(token);

    expect((await request(app).post('/api/auth/reset-password').send({ token, password: '123' })).status).toBe(422);
    const done = await request(app).post('/api/auth/reset-password').send({ token, password: 'choisi456' });
    expect(done.status).toBe(200);
    expect((await request(app).post('/api/auth/reset-password').send({ token, password: 'encore789' })).status).toBe(400);
    expect((await request(app).get('/api/auth/me').set(bearer(before))).status).toBe(401);
    expect((await login('alex.martin@exemple.fr', 'choisi456')).status).toBe(200);
  });

  test('lien expiré, et un nouveau lien annule le précédent', async () => {
    await request(app).post('/api/auth/forgot-password').send({ email: 'alex.martin@exemple.fr' });
    const first = resetTokenFromOutbox();
    await request(app).post('/api/auth/forgot-password').send({ email: 'alex.martin@exemple.fr' });
    const second = resetTokenFromOutbox();
    expect((await request(app).post('/api/auth/reset-password').send({ token: first, password: 'choisi456' })).status).toBe(400);

    await query('UPDATE password_resets SET expires_at = ?', [new Date(Date.now() - 1000).toISOString()]);
    expect((await request(app).post('/api/auth/reset-password').send({ token: second, password: 'choisi456' })).status).toBe(400);
  });

  test('page web du lien : formulaire, confirmation, lien invalide', async () => {
    await request(app).post('/api/auth/forgot-password').send({ email: 'alex.martin@exemple.fr' });
    const token = resetTokenFromOutbox();

    const page = await request(app).get('/api/auth/reset-password').query({ token });
    expect(page.status).toBe(200);
    expect(page.headers['content-type']).toMatch(/html/);
    expect(page.text).toContain('Nouveau mot de passe');
    expect(page.headers['content-security-policy']).toContain("default-src 'none'");

    const mismatch = await request(app).post('/api/auth/reset-password').type('form').send({ token, password: 'abcdef1', confirm: 'abcdef2' });
    expect(mismatch.text).toContain('ne correspondent pas');
    const done = await request(app).post('/api/auth/reset-password').type('form').send({ token, password: 'abcdef1', confirm: 'abcdef1' });
    expect(done.text).toContain('Mot de passe modifié');
    expect((await login('alex.martin@exemple.fr', 'abcdef1')).status).toBe(200);

    const invalid = await request(app).get('/api/auth/reset-password').query({ token: '<script>' });
    expect(invalid.text).toContain('Lien expiré');
    expect(invalid.text).not.toContain('<script>');
  });

  test('un compte Google sans mot de passe reçoit un message clair', async () => {
    await query("UPDATE users SET password_hash = NULL WHERE id = 'u-client-1'");
    const res = await login('alex.martin@exemple.fr');
    expect(res.status).toBe(401);
    expect(res.body.error).toBe(auth.AUTH_MESSAGES.noPassword);
  });
});

describe('connexion Google', () => {
  const payloads = new Map();
  beforeAll(() => {
    auth.setGoogleVerifier(async (idToken) => {
      if (!payloads.has(idToken)) throw new Error('invalid');
      return payloads.get(idToken);
    });
  });
  beforeEach(() => payloads.clear());

  const google = (idToken, extra = {}) => request(app).post('/api/auth/google').send({ idToken, ...extra });

  test('nouveau compte client, puis reconnexion avec le même compte Google', async () => {
    payloads.set('tok-new', {
      sub: 'g-123',
      email: 'nadia@gmail.com',
      email_verified: true,
      given_name: 'Nadia',
      family_name: 'Belkacem',
      picture: 'https://lh3.googleusercontent.com/a/photo',
    });
    const first = await google('tok-new', { role: 'client', space: 'frontOffice' });
    expect(first.status).toBe(200);
    expect(first.body.created).toBe(true);
    expect(first.body.user).toMatchObject({ email: 'nadia@gmail.com', firstName: 'Nadia', lastName: 'Belkacem', role: 'client' });
    expect((await request(app).get('/api/auth/me').set(bearer(first.body.token))).body.id).toBe(first.body.user.id);

    const again = await google('tok-new', { role: 'client' });
    expect(again.body.user.id).toBe(first.body.user.id);
    expect(again.body.created).toBe(false);
  });

  test('compte existant (même adresse vérifiée) : lié, rôle et espace contrôlés', async () => {
    payloads.set('tok-alex', { sub: 'g-alex', email: 'alex.martin@exemple.fr', email_verified: true });
    const res = await google('tok-alex', { role: 'client', space: 'frontOffice' });
    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe('u-client-1');
    const [row] = await query("SELECT google_id FROM users WHERE id = 'u-client-1'");
    expect(row.google_id).toBe('g-alex');

    expect((await google('tok-alex', { role: 'courier' })).status).toBe(403);
    payloads.set('tok-admin', { sub: 'g-admin', email: 'admin@superfaster.fr', email_verified: true });
    expect((await google('tok-admin', { space: 'frontOffice' })).status).toBe(403);
    expect((await google('tok-admin', { space: 'backOffice' })).status).toBe(200);
  });

  test('refus : jeton invalide, adresse non vérifiée, livreur sans dossier', async () => {
    expect((await google('')).status).toBe(422);
    expect((await google('faux')).status).toBe(401);
    payloads.set('tok-unverified', { sub: 'g-x', email: 'x@gmail.com', email_verified: false });
    expect((await google('tok-unverified')).status).toBe(401);
    payloads.set('tok-courier', { sub: 'g-c', email: 'c@gmail.com', email_verified: true });
    const courier = await google('tok-courier', { role: 'courier' });
    expect(courier.status).toBe(403);
    expect(courier.body.error).toBe(auth.AUTH_MESSAGES.googleCourier);
  });
});

describe('inscription restaurant (Espace Pro)', () => {
  const body = {
    restaurantName: 'Le Petit Bistrot',
    cuisine: 'Française',
    address: '4 rue des Martyrs, 75009 Paris',
    phone: '0612345678',
    firstName: 'Claire',
    lastName: 'Morel',
    email: 'claire@bistrot.fr',
    password: 'bistrot123',
  };

  test('compte et restaurant créés en attente, en un seul appel', async () => {
    const res = await request(app).post('/api/auth/register-restaurant').send(body);
    expect(res.status).toBe(201);
    expect(res.body.user).toMatchObject({ role: 'restaurant', status: 'pending', restaurantId: res.body.restaurant.id });
    expect(res.body.restaurant).toMatchObject({ name: 'Le Petit Bistrot', status: 'pending', ownerId: res.body.user.id });

    const blocked = await login('claire@bistrot.fr', 'bistrot123', { space: 'backOffice' });
    expect(blocked.status).toBe(403);
    expect(blocked.body.error).toBe('Votre inscription est en cours de validation par notre équipe.');

    expect((await request(app).post('/api/auth/register-restaurant').send(body)).status).toBe(409);
  });

  test('restaurant invalide : aucun compte orphelin', async () => {
    const res = await request(app).post('/api/auth/register-restaurant').send({ ...body, cuisine: '' });
    expect(res.status).toBe(422);
    expect(await query("SELECT id FROM users WHERE email = 'claire@bistrot.fr'")).toEqual([]);
    expect((await request(app).post('/api/auth/register-restaurant').send(body)).status).toBe(201);
  });
});

describe('annuaire et OTP', () => {
  test('GET /users : contacts masqués pour les non-admins', async () => {
    const alex = bearer('mock-token-u-client-1');
    const list = (await request(app).get('/api/users').set(alex)).body;
    const admin = list.find((u) => u.id === 'u-admin');
    expect(admin).toMatchObject({ firstName: 'Sophie', email: '', phone: '' });
    expect(list.find((u) => u.id === 'u-client-1').email).toBe('alex.martin@exemple.fr');
    expect((await request(app).get('/api/users').set(alex).query({ email: 'admin@superfaster.fr' })).body).toEqual([]);
    expect((await request(app).get('/api/users/u-admin').set(alex)).body.email).toBe('');
    expect((await request(app).get('/api/users/u-admin').set(bearer('mock-token-u-admin'))).body.email).toBe('admin@superfaster.fr');
  });

  test('code de démo : seulement pour un compte tout juste créé, jamais en production', async () => {
    // Alex s'est déjà connecté / existe depuis longtemps : le code ne suffit pas.
    await query("UPDATE users SET last_login_at = ? WHERE id = 'u-client-1'", [new Date().toISOString()]);
    expect((await request(app).post('/api/auth/verify-otp').send({ userId: 'u-client-1', code: '1234' })).status).toBe(400);

    const created = await request(app).post('/api/users').set(bearer('mock-token-u-admin')).send({
      firstName: 'Nouveau', lastName: 'Client', email: 'nouveau@exemple.fr', phone: '0612345678', role: 'client',
    });
    expect((await request(app).post('/api/auth/verify-otp').send({ userId: created.body.id, code: '0000' })).status).toBe(400);
    const ok = await request(app).post('/api/auth/verify-otp').send({ userId: created.body.id, code: '1234' });
    expect(ok.status).toBe(200);
    expect(ok.body.token).toEqual(expect.any(String));
    // Code utilisé : le compte a maintenant une connexion.
    expect((await request(app).post('/api/auth/verify-otp').send({ userId: created.body.id, code: '1234' })).status).toBe(400);

    const previous = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      expect((await request(app).post('/api/auth/verify-otp').send({ userId: created.body.id, code: '1234' })).status).toBe(404);
    } finally {
      process.env.NODE_ENV = previous;
    }
  });
});

describe('limitation des essais', () => {
  afterEach(() => {
    loginLimiter.enabledInTests = false;
    loginLimiter.reset();
  });

  test('connexion : 429 après 10 essais pour la même adresse', async () => {
    loginLimiter.enabledInTests = true;
    for (let i = 0; i < 10; i += 1) {
      expect((await login('alex.martin@exemple.fr', 'mauvais1')).status).toBe(401);
    }
    const blocked = await login('alex.martin@exemple.fr');
    expect(blocked.status).toBe(429);
    expect(blocked.headers['retry-after']).toEqual(expect.any(String));
    // Une autre adresse n'est pas concernée.
    expect((await login('admin@superfaster.fr')).status).toBe(200);
  });
});

describe('robustesse', () => {
  test('JSON invalide : 400 lisible ; en-têtes de sécurité présents', async () => {
    const res = await request(app).post('/api/auth/login').set('Content-Type', 'application/json').send('{"email":');
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('Corps de requête JSON invalide.');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});
