require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const addressRoutes = require('./routes/address.routes');
const courierRoutes = require('./routes/courier.routes');
const restaurantRoutes = require('./routes/restaurant.routes');
const oussemaModule = require('./oussema_livraison_commande');
const productRoutes = require('./routes/product.routes');

const app = express();

// ── Middleware ──────────────────────────────────────────────────────────────
app.use(cors());
if (process.env.NODE_ENV !== 'test') app.use(morgan('dev'));
app.use(express.json({ limit: '12mb' }));
app.use(express.urlencoded({ extended: true, limit: '12mb' }));

// ── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/addresses', addressRoutes);
app.use('/api/couriers', courierRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/products', productRoutes);

// ── Module Oussema : Livraison & Commande ──────────────────────────────────
app.use('/api/oussema', oussemaModule.router);
app.use('/api/orders', oussemaModule.commandeRoutes);
app.use('/api/deliveries', oussemaModule.livraisonRoutes);

// ── Health check ────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok', app: 'SuperFaster API' }));

// ── 404 handler ─────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));

// ── Global error handler ────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  if (process.env.NODE_ENV !== 'test') console.error(err.stack);
  res.status(err.status || 500).json({ error: err.message || 'Internal Server Error' });
});

const { init } = require('./data/db');

if (require.main === module) {
  init()
    .then(() => {
      const PORT = process.env.PORT || 3001;
      app.listen(PORT, () => {
        console.log(`SuperFaster API running on http://localhost:${PORT}`);
      });
    })
    .catch((error) => {
      console.error(`MySQL indisponible : ${error.message}`);
      process.exit(1);
    });
}

module.exports = app;
