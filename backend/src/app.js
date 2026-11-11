require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const config = require('./config');

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const addressRoutes = require('./routes/address.routes');
const oussemaModule = require('./oussema_panier_commande');
const emptyModules = require('./routes/empty-modules.routes');
const restaurantCatalogue = require('./restaurant_catalogue');
const imedLivraisonLivreur = require('./imed_livraison_livreur');
const avisNotification = require('./avis_notification');
const messagerie = require('./messagerie');

const app = express();

// ── Middleware ──────────────────────────────────────────────────────────────
app.disable('x-powered-by');
if (config.trustProxy) app.set('trust proxy', 1);
app.use((_req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Cross-Origin-Resource-Policy': 'cross-origin',
  });
  if (config.isProduction) res.set('Strict-Transport-Security', 'max-age=15552000; includeSubDomains');
  next();
});
const allowedOrigins = config.corsOrigins;
app.use(
  cors(
    allowedOrigins.length === 0
      ? {}
      : {
          origin(origin, callback) {
            // Applications mobiles et outils serveur : pas d'en-tête Origin.
            callback(null, !origin || allowedOrigins.includes(origin));
          },
        },
  ),
);
if (process.env.NODE_ENV !== 'test') app.use(morgan('dev'));
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ extended: true, limit: '12mb' }));

// ── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);

// ── Module 5 : Avis & Notifications ────────────────────────────────────────
// Monté avant les routes existantes : sur /api/users et /api/restaurants il
// ne définit que ses sous-routes (notifications, avis), le reste retombe sur
// les modules utilisateurs et catalogue.
app.use('/api/users', avisNotification.userNotificationRoutes);
app.use('/api/restaurants', avisNotification.restaurantReviewRoutes);
app.use('/api/reviews', avisNotification.reviewRoutes);
app.use('/api/notifications', avisNotification.notificationRoutes);
app.use('/api/campaigns', avisNotification.campaignRoutes);

// ── Messagerie : conversations et messages ─────────────────────────────────
app.use('/api/chats', messagerie.chatRoutes);
app.use('/api/messages', messagerie.messageRoutes);

app.use('/api/users', userRoutes);
app.use('/api/addresses', addressRoutes);

// ── Module 4 : Livraison & Livreur (Imed) ──────────────────────────────────
// Monté avant les anciennes routes : il répond à /api/couriers et
// /api/deliveries ; ce qu'il ne définit pas retombe sur les routes suivantes.
app.use('/api/imed', imedLivraisonLivreur.router);
app.use('/api/couriers', imedLivraisonLivreur.courierRoutes);
app.use('/api/deliveries', imedLivraisonLivreur.deliveryRoutes);


// ── Module Restaurants & Catalogue ─────────────────────────────────────────
app.use('/api/restaurants', restaurantCatalogue.restaurantRoutes);
app.use('/api/products', restaurantCatalogue.productRoutes);
app.use('/api/categories', restaurantCatalogue.categoryRoutes);

// ── Module 3 : Panier & Commandes (Oussema) ────────────────────────────────
app.use('/api/oussema', oussemaModule.router);
app.use('/api/cart', oussemaModule.panierRoutes);
app.use('/api/panier', oussemaModule.panierRoutes);
app.use('/api/orders', oussemaModule.commandeRoutes);
app.use('/api/reviews', emptyModules.reviews);
app.use('/api/campaigns', emptyModules.campaigns);
app.use('/api/notifications', emptyModules.notifications);
app.use('/api/deliveries', oussemaModule.livraisonRoutes);

// ── Health check ────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', app: 'SuperFaster API' }));

// ── 404 handler ─────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));

// ── Global error handler ────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  // JSON mal formé envoyé par un client.
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Corps de requête JSON invalide.' });
  }
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Requête trop volumineuse.' });
  }
  const status = Number.isInteger(err.status) && err.status >= 400 && err.status < 600 ? err.status : 500;
  if (status >= 500 && process.env.NODE_ENV !== 'test') console.error(err.stack);
  // En production, le détail d'une erreur interne n'est jamais renvoyé.
  const message = status >= 500 && config.isProduction
    ? 'Erreur du serveur, réessayez plus tard.'
    : err.message || 'Internal Server Error';
  return res.status(status).json({ error: message });
});

const { init } = require('./data/db');

if (require.main === module) {
  let warnings;
  try {
    warnings = config.validate();
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
  for (const warning of warnings) console.warn(`⚠️  ${warning}`);
  init()
    .then(() => restaurantCatalogue.init())
    .then(() => imedLivraisonLivreur.init())
    .then(() => avisNotification.init())
    .then(() => messagerie.init())
    .then(() => {
      const PORT = process.env.PORT || 3001;
      app.listen(PORT, () => {
        console.log(`SuperFaster API running on http://localhost:${PORT}`);
      });
    })
    .catch((error) => {
      console.error(`Base SQLite indisponible : ${error.message}`);
      process.exit(1);
    });
}

module.exports = app;
