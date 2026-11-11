const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const HttpError = require('../errors/http-error');
const config = require('../config');
const { query, rounds, newId } = require('../data/db');
const { publicUser, publicCourier } = require('../domain/presenters');
const {
  ROLES,
  SPACES,
  canAccess,
  roleMismatchMessage,
  MESSAGES,
} = require('../domain/roles');
const {
  text,
  requireName,
  requireEmail,
  requirePhone,
  requirePassword,
  oneOf,
} = require('../domain/validate');
const users = require('./users.service');
const couriers = require('./couriers.service');
const mailer = require('./mailer.service');

/** Code affiché sur l'écran OTP du front (`AuthService.demoOtpCode`). */
const DEMO_OTP = '1234';
/** Le code OTP de démo n'ouvre que la session d'un compte tout juste créé. */
const OTP_WINDOW_MS = 30 * 60_000;
/** Durée de validité d'un lien « mot de passe oublié ». */
const RESET_TTL_MINUTES = 30;

const AUTH_MESSAGES = Object.freeze({
  googleDisabled: "La connexion Google n'est pas configurée sur ce serveur.",
  googleInvalid: 'Connexion Google refusée : jeton invalide ou expiré.',
  googleUnverified: "Votre adresse Google n'est pas vérifiée.",
  googleCourier:
    "Inscrivez-vous comme livreur avec le formulaire d'inscription : vos justificatifs sont nécessaires.",
  resetInvalid: 'Ce lien de réinitialisation est invalide ou a expiré. Faites une nouvelle demande.',
  wrongCurrentPassword: 'Mot de passe actuel incorrect.',
  samePassword: "Le nouveau mot de passe doit être différent de l'ancien.",
  noPassword:
    'Ce compte utilise la connexion Google. Utilisez « Mot de passe oublié » pour en définir un.',
});

let dummyHash = null;
function dummyPasswordHash() {
  if (!dummyHash) dummyHash = bcrypt.hashSync('not-a-real-password', rounds());
  return dummyHash;
}

function signToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email, tv: user.tokenVersion || 0 },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn, algorithm: 'HS256' },
  );
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

/**
 * Mêmes gardes que `AuthService._open` : compte bloqué, restaurateur
 * encore en attente, puis espace (application mobile ou Espace Pro).
 */
async function openSession(user, space) {
  if (user.status === 'blocked') {
    throw new HttpError(403, MESSAGES.blocked);
  }
  if (user.role === 'restaurant' && user.status === 'pending') {
    throw new HttpError(403, MESSAGES.pendingRestaurant);
  }
  await couriers.assertApproved(user);
  if (space != null && !canAccess(user.role, space)) {
    throw new HttpError(
      403,
      space === 'backOffice' ? MESSAGES.backOfficeOnly : MESSAGES.frontOfficeOnly,
    );
  }
  const opened = await users.touchLogin(user);
  return { token: signToken(opened), user: publicUser(opened) };
}

function optionalRole(value) {
  const role = value == null || value === '' ? null : value;
  if (role != null) oneOf(role, ROLES, MESSAGES.invalidRole);
  return role;
}

function optionalSpace(value) {
  const space = value == null || value === '' ? null : value;
  if (space != null) oneOf(space, SPACES, 'Espace invalide.');
  return space;
}

/** Un compte mobile connecté avec le mauvais rôle : message du sélecteur. */
function assertRoleMatches(user, role) {
  if (role && user.role !== role && canAccess(user.role, 'frontOffice')) {
    throw new HttpError(403, roleMismatchMessage(user.role));
  }
}

// ── Inscription ─────────────────────────────────────────────────────────────

/**
 * Inscription front office : client ou livreur uniquement.
 * La session du client s'ouvre tout de suite.
 * Un livreur reçoit un profil en attente : il ne se connecte qu'après
 * validation de ses justificatifs par un administrateur.
 */
async function register(body) {
  const role = body.role ? oneOf(body.role, ROLES, MESSAGES.invalidRole) : 'client';
  if (role !== 'client' && role !== 'courier') {
    throw new HttpError(403, MESSAGES.registerInPro);
  }

  const documents = role === 'courier'
    ? couriers.requireRegistrationPhotos(body.documents)
    : null;

  const created = await users.create(
    {
      firstName: requireName(body.firstName),
      lastName: requireName(body.lastName),
      email: requireEmail(body.email),
      phone: requirePhone(body.phone),
      password: requirePassword(body.password),
      role,
    },
    null,
  );

  const stored = await users.findById(created.id);
  if (role === 'courier') {
    const courier = publicCourier(await couriers.ensureProfile(stored, documents));
    return {
      token: null,
      pendingApproval: true,
      message: MESSAGES.courierPending,
      user: publicUser(stored),
      courier,
    };
  }
  const session = await openSession(stored, 'frontOffice');
  return { token: session.token, user: session.user, courier: null };
}

/**
 * Demande d'inscription d'un restaurant (Espace Pro) : le compte du
 * restaurateur et le restaurant sont créés « en attente », d'un seul appel.
 * L'admin les valide dans le back office (Catalogue › Restaurants).
 */
async function registerRestaurant(body) {
  const restaurants = require('../restaurant_catalogue').restaurantService;
  const email = requireEmail(body.email);
  const owner = await users.create(
    {
      firstName: requireName(body.firstName),
      lastName: requireName(body.lastName),
      email,
      phone: requirePhone(body.phone),
      password: requirePassword(body.password),
      role: 'restaurant',
      status: 'pending',
    },
    null,
  );

  let restaurant;
  try {
    restaurant = await restaurants.create(null, {
      name: body.restaurantName,
      cuisine: body.cuisine,
      address: body.address,
      phone: body.phone,
      email,
      description: text(body.description) || 'Nouveau restaurant partenaire.',
      imageUrl: body.imageUrl,
      ownerId: owner.id,
    });
  } catch (error) {
    // Le restaurant est refusé (champ invalide…) : on retire le compte créé
    // pour que la personne puisse corriger et renvoyer le formulaire.
    await query('DELETE FROM users WHERE id = ?', [owner.id]);
    throw error;
  }
  await query('UPDATE users SET restaurant_id = ? WHERE id = ?', [restaurant.id, owner.id]);
  return {
    pendingApproval: true,
    message: MESSAGES.pendingRestaurant,
    user: publicUser(await users.findById(owner.id)),
    restaurant,
  };
}

// ── Connexion ───────────────────────────────────────────────────────────────

async function login(body) {
  const password = typeof body.password === 'string' ? body.password : '';
  if (password.length < 6) throw new HttpError(401, MESSAGES.badPassword);

  const email = text(body.email);
  const user = await users.findByEmail(email);
  // Comparaison toujours faite (même sans compte) : temps de réponse constant.
  const matches = await bcrypt.compare(password, user?.passwordHash || dummyPasswordHash());
  if (!user) throw new HttpError(401, MESSAGES.unknownEmail);
  if (!user.passwordHash) throw new HttpError(401, AUTH_MESSAGES.noPassword);
  if (!matches) throw new HttpError(401, MESSAGES.badPassword);

  assertRoleMatches(user, optionalRole(body.role));
  return openSession(user, optionalSpace(body.space));
}

/**
 * Écran OTP (démonstration) : le code `1234` ouvre la session d'un compte
 * client tout juste inscrit et jamais connecté. Désactivé en production.
 */
async function verifyOtp(body) {
  if (!config.allowDemoOtp) {
    throw new HttpError(404, 'Vérification par SMS indisponible.');
  }
  const code = text(body.code);
  if (code !== DEMO_OTP) throw new HttpError(400, MESSAGES.badOtp);
  const userId = text(body.userId);
  if (!userId) throw new HttpError(422, 'userId est obligatoire');
  const user = await users.mustFind(userId);
  const fresh = !user.lastLoginAt && Date.now() - new Date(user.createdAt).getTime() < OTP_WINDOW_MS;
  if (!fresh) throw new HttpError(400, MESSAGES.badOtp);
  return openSession(user, 'frontOffice');
}

// ── Google ──────────────────────────────────────────────────────────────────

let googleClient = null;
/** Remplaçable dans les tests (aucun appel réseau vers Google). */
let googleVerifier = async (idToken) => {
  const audience = config.googleClientIds;
  if (!googleClient) {
    const { OAuth2Client } = require('google-auth-library');
    googleClient = new OAuth2Client();
  }
  const ticket = await googleClient.verifyIdToken({ idToken, audience });
  return ticket.getPayload();
};

function setGoogleVerifier(fn) {
  googleVerifier = fn;
}

/**
 * Connexion / inscription avec Google. Le front envoie l'ID token obtenu par
 * Google Sign-In ; le serveur le vérifie (signature, audience, expiration).
 * - compte déjà lié à ce Google → connexion ;
 * - compte existant avec la même adresse vérifiée → liaison puis connexion ;
 * - sinon → création d'un compte client.
 * Un livreur doit d'abord s'inscrire avec ses justificatifs.
 */
async function googleLogin(body) {
  if (config.googleClientIds.length === 0 && !config.isTest) {
    throw new HttpError(503, AUTH_MESSAGES.googleDisabled);
  }
  const idToken = text(body.idToken);
  if (!idToken) throw new HttpError(422, 'idToken est obligatoire');

  let payload;
  try {
    payload = await googleVerifier(idToken);
  } catch {
    throw new HttpError(401, AUTH_MESSAGES.googleInvalid);
  }
  if (!payload?.sub || !payload.email) throw new HttpError(401, AUTH_MESSAGES.googleInvalid);
  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw new HttpError(401, AUTH_MESSAGES.googleUnverified);
  }

  const role = optionalRole(body.role);
  const space = optionalSpace(body.space);

  let user = await users.findByGoogleId(payload.sub);
  if (!user) {
    user = await users.findByEmail(payload.email);
    if (user) {
      await users.linkGoogle(user.id, payload.sub);
      if (!user.avatarUrl && payload.picture) {
        await query('UPDATE users SET avatar_url = ? WHERE id = ?', [payload.picture, user.id]);
      }
      user = await users.findById(user.id);
    }
  }

  if (!user) {
    if (role && role !== 'client') {
      throw new HttpError(403, role === 'courier' ? AUTH_MESSAGES.googleCourier : MESSAGES.registerInPro);
    }
    if (space === 'backOffice') throw new HttpError(403, MESSAGES.backOfficeOnly);
    const id = newId('u');
    const firstName = text(payload.given_name) || text(payload.name).split(' ')[0] || 'Client';
    const lastName = text(payload.family_name) || text(payload.name).split(' ').slice(1).join(' ') || '-';
    await query(
      `INSERT INTO users
        (id, first_name, last_name, email, phone, role, status, avatar_url, restaurant_id,
         loyalty_points, password_hash, created_at, last_login_at, google_id)
       VALUES (?, ?, ?, ?, '', 'client', 'active', ?, NULL, 0, NULL, ?, NULL, ?)`,
      [id, firstName, lastName, payload.email, payload.picture || null, new Date().toISOString(), payload.sub],
    );
    user = await users.findById(id);
  }

  assertRoleMatches(user, role);
  const created = !user.lastLoginAt;
  const session = await openSession(user, space);
  return { ...session, created };
}

// ── Mot de passe ────────────────────────────────────────────────────────────

/**
 * « Mot de passe oublié » : envoie un lien à usage unique. La réponse est la
 * même que le compte existe ou non (pas de divulgation des adresses).
 */
async function forgotPassword(body = {}) {
  const email = text(body.email);
  const user = email ? await users.findByEmail(email) : null;
  if (!user || user.status === 'blocked') return;

  const token = crypto.randomBytes(32).toString('base64url');
  const now = new Date();
  const expires = new Date(now.getTime() + RESET_TTL_MINUTES * 60_000);
  // Un seul lien actif par compte.
  await query('DELETE FROM password_resets WHERE user_id = ?', [user.id]);
  await query(
    'INSERT INTO password_resets (token_hash, user_id, expires_at, used_at, created_at) VALUES (?, ?, ?, NULL, ?)',
    [sha256(token), user.id, expires.toISOString(), now.toISOString()],
  );
  const link = `${config.publicUrl}/api/auth/reset-password?token=${encodeURIComponent(token)}`;
  try {
    await mailer.sendPasswordReset({
      to: user.email,
      firstName: user.firstName,
      link,
      minutes: RESET_TTL_MINUTES,
    });
  } catch (error) {
    // L'utilisateur reçoit la même réponse ; l'erreur SMTP reste dans le journal.
    if (!config.isTest) console.error(`Envoi de l'e-mail impossible : ${error.message}`);
  }
}

async function findValidReset(token) {
  const raw = text(token);
  if (!raw) return null;
  const rows = await query('SELECT * FROM password_resets WHERE token_hash = ? LIMIT 1', [sha256(raw)]);
  const reset = rows[0];
  if (!reset || reset.used_at || new Date(reset.expires_at).getTime() < Date.now()) return null;
  return reset;
}

async function checkResetToken(token) {
  return Boolean(await findValidReset(token));
}

/** Nouveau mot de passe depuis le lien reçu par e-mail. Révoque les sessions. */
async function resetPassword(body = {}) {
  const reset = await findValidReset(body.token);
  if (!reset) throw new HttpError(400, AUTH_MESSAGES.resetInvalid);
  const password = requirePassword(body.password);
  const user = await users.findById(reset.user_id);
  if (!user || user.status === 'blocked') throw new HttpError(400, AUTH_MESSAGES.resetInvalid);
  await query('UPDATE password_resets SET used_at = ? WHERE token_hash = ?', [
    new Date().toISOString(),
    reset.token_hash,
  ]);
  await users.setPassword(user.id, password);
  return { message: 'Mot de passe modifié. Vous pouvez vous connecter.' };
}

/**
 * Changement de mot de passe depuis le compte. Les autres sessions sont
 * révoquées ; un nouveau jeton est renvoyé pour l'appareil courant.
 */
async function changePassword(actor, body = {}) {
  const user = await users.mustFind(actor.id);
  const next = requirePassword(body.newPassword);
  if (user.passwordHash) {
    const current = typeof body.currentPassword === 'string' ? body.currentPassword : '';
    if (!(await bcrypt.compare(current, user.passwordHash))) {
      throw new HttpError(403, AUTH_MESSAGES.wrongCurrentPassword);
    }
    if (await bcrypt.compare(next, user.passwordHash)) {
      throw new HttpError(422, AUTH_MESSAGES.samePassword);
    }
  }
  await users.setPassword(user.id, next);
  const updated = await users.findById(user.id);
  return { token: signToken(updated), user: publicUser(updated) };
}

/** Déconnexion de tous les appareils : tous les jetons du compte sont révoqués. */
async function logoutAll(actor) {
  await users.bumpTokenVersion(actor.id);
}

async function profile(userId) {
  return users.get(userId);
}

module.exports = {
  DEMO_OTP,
  RESET_TTL_MINUTES,
  AUTH_MESSAGES,
  register,
  registerRestaurant,
  login,
  verifyOtp,
  googleLogin,
  setGoogleVerifier,
  profile,
  forgotPassword,
  checkResetToken,
  resetPassword,
  changePassword,
  logoutAll,
  openSession,
  signToken,
};
