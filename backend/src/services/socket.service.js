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

  _io.on('connection', (socket) => {
    if (process.env.NODE_ENV !== 'test') {
      console.log(`[Socket.IO] Client connecté : ${socket.id}`);
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

module.exports = { init, getIO, emitDeliveryStatus, emitDeliveryAssigned };

