'use strict';

/**
 * Service Socket.IO — Suivi GPS en temps réel des livraisons SuperFaster.
 *
 * Rooms :
 *   delivery:{id}  → client, admin, restaurant suivant une course
 *
 * Événements client → serveur :
 *   'join:delivery'    { deliveryId }                             → rejoindre la room
 *   'leave:delivery'   { deliveryId }                             → quitter la room
 *   'courier:location' { deliveryId, latitude, longitude, accuracy? } → position GPS
 *
 * Événements serveur → client :
 *   'delivery:location'  { deliveryId, latitude, longitude, remainingKm, remainingMin, updatedAt }
 *   'delivery:status'    { deliveryId, status, statusLabel, updatedAt }
 *   'delivery:assigned'  { deliveryId, courierName, courierPhone, courierVehicle, assignedAt }
 */

let _io = null;

function init(httpServer) {
  const { Server } = require('socket.io');
  _io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
    transports: ['websocket', 'polling'],
  });

  // Authentification par le JWT de l'application (handshake `auth.token`).
  // Un socket sans jeton valide reste connecté mais ne reçoit que les rooms
  // de suivi qu'il rejoint explicitement (compatibilité).
  _io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token || '';
      if (!token) return next();
      const user = await userFromToken(token);
      if (user) socket.data.user = user;
      return next();
    } catch {
      return next();
    }
  });

  _io.on('connection', (socket) => {
    const user = socket.data.user;
    if (user) {
      socket.join(`user:${user.id}`);
      socket.join(`role:${user.role}`);
      socket.join('authenticated');
    }
    if (process.env.NODE_ENV !== 'test') {
      console.log(`[Socket.IO] Client connecté : ${socket.id}${user ? ` (${user.role} ${user.id})` : ''}`);
    }

    socket.on('join:delivery', ({ deliveryId } = {}) => {
      if (!deliveryId) return;
      socket.join(`delivery:${deliveryId}`);
    });

    socket.on('leave:delivery', ({ deliveryId } = {}) => {
      if (!deliveryId) return;
      socket.leave(`delivery:${deliveryId}`);
    });

    // Le livreur émet sa position GPS en temps réel
    socket.on('courier:location', async ({ deliveryId, latitude, longitude, accuracy } = {}) => {
      if (!deliveryId || latitude == null || longitude == null) return;
      try {
        const { query } = require('../data/db');
        const { haversineDistance, estimateDurationMinutes } = require('../oussema_panier_commande/services/geo.utils');

        const rows = await query(
          'SELECT dropoff_lat, dropoff_lng FROM deliveries WHERE id = ? LIMIT 1',
          [deliveryId],
        );
        if (!rows[0]) return;

        const remainingKm = rows[0].dropoff_lat
          ? haversineDistance(latitude, longitude, Number(rows[0].dropoff_lat), Number(rows[0].dropoff_lng))
          : null;
        const remainingMin = remainingKm ? estimateDurationMinutes(remainingKm, 'scooter') : null;

        await query(
          'UPDATE deliveries SET courier_lat = ?, courier_lng = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [latitude, longitude, deliveryId],
        );

        // Broadcaster à tous les membres de la room (sauf le livreur émetteur)
        socket.to(`delivery:${deliveryId}`).emit('delivery:location', {
          deliveryId,
          latitude,
          longitude,
          accuracy: accuracy || null,
          remainingKm,
          remainingMin,
          updatedAt: new Date().toISOString(),
        });
      } catch (err) {
        if (process.env.NODE_ENV !== 'test') {
          console.error('[Socket.IO] Erreur mise à jour position :', err.message);
        }
      }
    });

    socket.on('disconnect', () => {
      if (process.env.NODE_ENV !== 'test') {
        console.log(`[Socket.IO] Client déconnecté : ${socket.id}`);
      }
    });
  });

  if (process.env.NODE_ENV !== 'test') {
    console.log('[Socket.IO] Serveur initialisé.');
  }
  return _io;
}

/** Utilisateur d'un JWT (mêmes règles que le middleware HTTP). */
async function userFromToken(token) {
  const config = require('../config');
  const users = require('./users.service');
  let userId;
  let tokenVersion = null;
  if (token.startsWith('mock-token-')) {
    if (!config.allowMockTokens) return null;
    userId = token.slice('mock-token-'.length);
  } else {
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
    userId = decoded.sub;
    tokenVersion = Number(decoded.tv) || 0;
  }
  const user = await users.findById(userId);
  if (!user || user.status === 'blocked') return null;
  if (tokenVersion != null && tokenVersion !== user.tokenVersion) return null;
  return { id: user.id, role: user.role };
}

/**
 * Signal « données modifiées » : les applications rechargent les écrans
 * concernés (commandes, courses, livreurs…). Seul le sujet est diffusé,
 * jamais les données : chaque app relit via l'API, qui applique les droits.
 */
function emitSync(topic, extra = {}) {
  if (!_io) return;
  _io.to('authenticated').emit('sync', { topic, ...extra, at: new Date().toISOString() });
}

/**
 * Nouvelle position d'un livreur : envoyée au client de la commande et aux
 * administrateurs (pas à tout le monde).
 */
async function emitCourierLocation({ deliveryId, latitude, longitude }) {
  if (!_io || !deliveryId) return;
  try {
    const { query } = require('../data/db');
    const rows = await query(
      'SELECT o.id AS order_id, o.user_id FROM deliveries d LEFT JOIN orders o ON o.id = d.order_id WHERE d.id = ? LIMIT 1',
      [deliveryId],
    );
    const row = rows[0];
    if (!row) return;
    const payload = {
      topic: 'location',
      deliveryId,
      orderId: row.order_id,
      latitude,
      longitude,
      at: new Date().toISOString(),
    };
    let target = _io.to('role:admin').to(`delivery:${deliveryId}`);
    if (row.user_id) target = target.to(`user:${row.user_id}`);
    target.emit('sync', payload);
  } catch (err) {
    if (process.env.NODE_ENV !== 'test') console.error('[Socket.IO] position :', err.message);
  }
}

/** Accès global à l'instance io. */
function getIO() {
  return _io;
}

/**
 * Émet un changement de statut à tous les membres de la room de suivi.
 * Appelé depuis livraison.service quand le statut change.
 */
function emitDeliveryStatus(deliveryId, status, statusLabel) {
  if (!_io) return;
  _io.to(`delivery:${deliveryId}`).emit('delivery:status', {
    deliveryId,
    status,
    statusLabel,
    updatedAt: new Date().toISOString(),
  });
}

/**
 * Émet l'assignation d'un livreur à tous les watchers de la room.
 */
function emitDeliveryAssigned(deliveryId, { courierName, courierPhone, courierVehicle }) {
  if (!_io) return;
  _io.to(`delivery:${deliveryId}`).emit('delivery:assigned', {
    deliveryId,
    courierName,
    courierPhone,
    courierVehicle,
    assignedAt: new Date().toISOString(),
  });
}

module.exports = {
  init,
  getIO,
  emitDeliveryStatus,
  emitDeliveryAssigned,
  emitSync,
  emitCourierLocation,
};

