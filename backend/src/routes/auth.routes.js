const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate } = require('../middleware/auth.middleware');
const { loginLimiter, resetLimiter, signupLimiter } = require('../middleware/rate-limit');
const { ensureReady: catalogueReady } = require('../restaurant_catalogue/catalogue.schema');
const auth = require('../services/auth.service');
const users = require('../services/users.service');
const { escapeHtml } = require('../services/mailer.service');

const router = express.Router();

const FORGOT_MESSAGE =
  'Si un compte existe pour cette adresse, vous recevrez un lien de réinitialisation dans quelques minutes.';

// Inscription client (session ouverte) ou livreur (en attente de validation).
router.post(
  '/register',
  signupLimiter,
  asyncHandler(async (req, res) => {
    res.status(201).json(await auth.register(req.body));
  }),
);

// Inscription d'un restaurant depuis l'Espace Pro : compte + restaurant en attente.
router.post(
  '/register-restaurant',
  signupLimiter,
  catalogueReady,
  asyncHandler(async (req, res) => {
    res.status(201).json(await auth.registerRestaurant(req.body));
  }),
);

router.post(
  '/login',
  loginLimiter,
  asyncHandler(async (req, res) => {
    res.json(await auth.login(req.body));
  }),
);

router.post(
  '/google',
  loginLimiter,
  asyncHandler(async (req, res) => {
    res.json(await auth.googleLogin(req.body));
  }),
);

router.post(
  '/verify-otp',
  loginLimiter,
  asyncHandler(async (req, res) => {
    res.json(await auth.verifyOtp(req.body));
  }),
);

// Les JWT sont sans état : le client oublie son jeton.
router.post('/logout', (_req, res) => {
  res.json({ message: 'Déconnexion réussie.' });
});

// Révoque toutes les sessions du compte (tous les appareils).
router.post(
  '/logout-all',
  authenticate,
  asyncHandler(async (req, res) => {
    await auth.logoutAll(req.auth);
    res.json({ message: 'Toutes les sessions ont été fermées.' });
  }),
);

router.post(
  '/forgot-password',
  resetLimiter,
  asyncHandler(async (req, res) => {
    await auth.forgotPassword(req.body);
    res.json({ message: FORGOT_MESSAGE });
  }),
);

// Page ouverte depuis le lien de l'e-mail : formulaire du nouveau mot de passe.
router.get(
  '/reset-password',
  asyncHandler(async (req, res) => {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    const valid = await auth.checkResetToken(token);
    res
      .set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'")
      .type('html')
      .send(resetPage({ token, valid }));
  }),
);

// JSON (application) ou formulaire HTML (page ci-dessus).
router.post(
  '/reset-password',
  resetLimiter,
  asyncHandler(async (req, res) => {
    const fromForm = req.is('application/x-www-form-urlencoded');
    if (!fromForm) {
      res.json(await auth.resetPassword(req.body));
      return;
    }
    const page = (options) =>
      res
        .set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'")
        .type('html')
        .send(resetPage(options));
    if (req.body.password !== req.body.confirm) {
      page({ token: req.body.token, valid: true, error: 'Les deux mots de passe ne correspondent pas.' });
      return;
    }
    try {
      await auth.resetPassword(req.body);
      page({ done: true });
    } catch (error) {
      if (!error.status || error.status >= 500) throw error;
      const valid = await auth.checkResetToken(req.body.token);
      page({ token: req.body.token, valid, error: error.message });
    }
  }),
);

router.post(
  '/change-password',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await auth.changePassword(req.auth, req.body));
  }),
);

router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await auth.profile(req.auth.id));
  }),
);

router.put(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    res.json(await users.update(req.auth, req.auth.id, req.body));
  }),
);

function resetPage({ token = '', valid = false, error = null, done = false }) {
  let body;
  if (done) {
    body = '<h1>Mot de passe modifié ✅</h1><p>Vous pouvez retourner dans l’application et vous connecter.</p>';
  } else if (!valid) {
    body =
      '<h1>Lien expiré</h1><p>Ce lien de réinitialisation est invalide ou a déjà été utilisé. ' +
      'Faites une nouvelle demande depuis l’application (« Mot de passe oublié »).</p>';
  } else {
    body = `
      <h1>Nouveau mot de passe</h1>
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
      <form method="post" action="reset-password">
        <input type="hidden" name="token" value="${escapeHtml(token)}">
        <label>Nouveau mot de passe<input type="password" name="password" minlength="6" required autocomplete="new-password"></label>
        <label>Confirmation<input type="password" name="confirm" minlength="6" required autocomplete="new-password"></label>
        <button type="submit">Enregistrer</button>
      </form>`;
  }
  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>SuperFaster — Mot de passe</title>
<style>
  body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f6f6f8;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center}
  main{background:#fff;padding:32px;border-radius:16px;max-width:380px;width:90%;box-shadow:0 8px 30px rgba(0,0,0,.08)}
  h1{font-size:22px;margin:0 0 16px} p{color:#555;line-height:1.5}
  label{display:block;margin:12px 0;font-size:14px;color:#333}
  input{display:block;width:100%;box-sizing:border-box;margin-top:6px;padding:12px;border:1px solid #ddd;border-radius:10px;font-size:16px}
  button{margin-top:16px;width:100%;padding:14px;border:0;border-radius:10px;background:#ff5a1f;color:#fff;font-size:16px;font-weight:600;cursor:pointer}
  .error{color:#c62828}
</style></head><body><main>${body}</main></body></html>`;
}

module.exports = router;
