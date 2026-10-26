'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toIso } = require('../../data/db');
const {
  DELIVERY_STATUSES,
  DELIVERY_STATUS_LABELS,
  ALLOWED_DELIVERY_TRANSITIONS,
  COURIER_FEE_SHARE,
} = require('../domain/livraison.constants');
const { haversineDistance, estimateDurationMinutes } = require('./geo.utils');

function mapDelivery(row) {
  if (!row) return null;
  return {
    id: row.id,
    orderId: row.order_id,
    orderReference: `CMD-${(row.order_id || '').slice(-6).toUpperCase()}`,
    courierId: row.courier_id || null,
    courierName: row.courier_name || null,
    courierPhone: row.courier_phone || null,
    courierVehicle: row.courier_vehicle || 'scooter',
    courierLat: row.courier_lat ? Number(row.courier_lat) : null,
    courierLng: row.courier_lng ? Number(row.courier_lng) : null,
    status: row.status || 'waiting',
    statusLabel: DELIVERY_STATUS_LABELS[row.status] || row.status,
    pickupName: row.pickup_name || 'Restaurant',
    pickupAddress: row.pickup_address || '',
    pickupLat: row.pickup_lat ? Number(row.pickup_lat) : 48.8699,
    pickupLng: row.pickup_lng ? Number(row.pickup_lng) : 2.3305,
    customerName: row.customer_name || 'Client',
    dropoffAddress: row.dropoff_address || row.delivery_address || '',
    dropoffLat: row.dropoff_lat ? Number(row.dropoff_lat) : 48.8686,
    dropoffLng: row.dropoff_lng ? Number(row.dropoff_lng) : 2.3312,
    distanceKm: Number(row.distance_km) || 2.5,
    durationMin: Number(row.duration_min) || 25,
    fee: Number(row.fee) || 4.5,
    tip: Number(row.tip) || 0.0,
    totalCourierEarnings: Math.round((Number(row.fee || 4.5) * COURIER_FEE_SHARE + Number(row.tip || 0)) * 100) / 100,
    otpCode: row.otp_code || null,
    startedAt: toIso(row.started_at),
    completedAt: toIso(row.completed_at),
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  };
}

/**
 * Récupère une livraison par son ID.
 */
async function getDeliveryById(deliveryId) {
  const sql = `
    SELECT d.*,
           o.delivery_address,
           r.name AS pickup_name,
           r.address AS pickup_address,
           u.first_name || ' ' || u.last_name AS customer_name,
           c.first_name || ' ' || c.last_name AS courier_name,
           c.phone AS courier_phone,
           c.vehicle AS courier_vehicle
    FROM deliveries d
    LEFT JOIN orders o ON o.id = d.order_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN users u ON u.id = o.user_id
    LEFT JOIN couriers c ON c.id = d.courier_id
    WHERE d.id = ? LIMIT 1
  `;
  const rows = await query(sql, [deliveryId]);
  if (!rows[0]) throw new HttpError(404, `Livraison introuvable (${deliveryId}).`);
  return mapDelivery(rows[0]);
}

/**
 * Liste les livraisons avec filtres (courierId, status).
 */
async function listDeliveries(filters = {}) {
  let sql = `
    SELECT d.*,
           o.delivery_address,
           r.name AS pickup_name,
           r.address AS pickup_address,
           u.first_name || ' ' || u.last_name AS customer_name,
           c.first_name || ' ' || c.last_name AS courier_name,
           c.phone AS courier_phone,
           c.vehicle AS courier_vehicle
    FROM deliveries d
    LEFT JOIN orders o ON o.id = d.order_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN users u ON u.id = o.user_id
    LEFT JOIN couriers c ON c.id = d.courier_id
  `;
  const params = [];
  const conditions = [];

  if (filters.courierId) {
    conditions.push('d.courier_id = ?');
    params.push(filters.courierId);
  }
  if (filters.status) {
    conditions.push('d.status = ?');
    params.push(filters.status);
  }
  if (conditions.length > 0) {
    sql += ' WHERE ' + conditions.join(' AND ');
  }
  sql += ' ORDER BY d.created_at DESC';

  const rows = await query(sql, params);
  return rows.map(mapDelivery);
}

/**
 * Trouve les livreurs disponibles les plus proches d'une position GPS (Dispatch Haversine).
 */
async function findNearbyAvailableCouriers({ latitude, longitude, maxDistanceKm = 15, limit = 5 }) {
  const couriers = await query(
    "SELECT * FROM couriers WHERE status = 'available' ORDER BY rating DESC",
  );

  const scored = [];
  for (const c of couriers) {
    const dist = haversineDistance(latitude, longitude, c.latitude, c.longitude);
    if (dist <= maxDistanceKm) {
      scored.push({
        courier: {
          id: c.id,
          userId: c.user_id,
          name: `${c.first_name} ${c.last_name}`,
          phone: c.phone,
          vehicle: c.vehicle,
          rating: Number(c.rating),
          latitude: Number(c.latitude),
          longitude: Number(c.longitude),
        },
        distanceKm: dist,
        estimatedPickupMinutes: estimateDurationMinutes(dist, c.vehicle),
      });
    }
  }

  // Trier par distance croissante puis note décroissante
  scored.sort((a, b) => a.distanceKm - b.distanceKm || b.courier.rating - a.courier.rating);
  return scored.slice(0, limit);
}

/**
 * Assigne automatiquement le livreur disponible le plus proche à la livraison.
 */
async function autoDispatchDelivery(deliveryId) {
  const delivery = await getDeliveryById(deliveryId);
  if (delivery.status !== 'waiting' && delivery.status !== 'assigned') {
    throw new HttpError(400, 'Cette livraison ne peut plus être réassignée.');
  }

  const nearby = await findNearbyAvailableCouriers({
    latitude: delivery.pickupLat,
    longitude: delivery.pickupLng,
    maxDistanceKm: 20,
    limit: 1,
  });

  if (nearby.length === 0) {
    throw new HttpError(404, 'Aucun livreur disponible à proximité pour le moment.');
  }

  const selectedCourier = nearby[0].courier;
  await assignCourier(deliveryId, selectedCourier.id);

  return {
    delivery: await getDeliveryById(deliveryId),
    assignedCourier: selectedCourier,
    distanceToPickup: nearby[0].distanceKm,
    estimatedPickupMinutes: nearby[0].estimatedPickupMinutes,
  };
}

/**
 * Assigne manuellement un livreur à une course.
 */
async function assignCourier(deliveryId, courierId) {
  const delivery = await getDeliveryById(deliveryId);
  const couriers = await query('SELECT * FROM couriers WHERE id = ? LIMIT 1', [courierId]);
  const courier = couriers[0];
  if (!courier) throw new HttpError(404, `Livreur introuvable (${courierId}).`);

  await withTransaction(async () => {
    // Mettre à jour la livraison
    await query(
      `UPDATE deliveries SET 
         courier_id = ?, 
         status = 'assigned', 
         courier_lat = ?, 
         courier_lng = ?, 
         started_at = CURRENT_TIMESTAMP, 
         updated_at = CURRENT_TIMESTAMP 
       WHERE id = ?`,
      [courierId, courier.latitude, courier.longitude, deliveryId],
    );

    // Mettre à jour la commande associée
    await query('UPDATE orders SET courier_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
      courierId,
      delivery.orderId,
    ]);

    // Mettre à jour le statut du livreur à 'busy'
    await query("UPDATE couriers SET status = 'busy' WHERE id = ?", [courierId]);

    // Journaliser l'assignation
    await query(
      `INSERT INTO order_events (order_id, status, note, actor_id) 
       VALUES (?, 'confirmed', ?, ?)`,
      [
        delivery.orderId,
        `Livreur ${courier.first_name} ${courier.last_name} assigné à la course.`,
        courierId,
      ],
    );
  });

  return getDeliveryById(deliveryId);
}

/**
 * Met à jour le statut de la livraison (suivi de course).
 */
async function updateDeliveryStatus(deliveryId, nextStatus, { courierId = null, otpCode = null, note = null } = {}) {
  if (!DELIVERY_STATUSES.includes(nextStatus)) {
    throw new HttpError(422, `Statut de livraison invalide: ${nextStatus}`);
  }

  const delivery = await getDeliveryById(deliveryId);
  const currentStatus = delivery.status;

  if (currentStatus === nextStatus) return delivery;

  const allowed = ALLOWED_DELIVERY_TRANSITIONS[currentStatus] || [];
  if (!allowed.includes(nextStatus)) {
    throw new HttpError(
      400,
      `Transition impossible de « ${DELIVERY_STATUS_LABELS[currentStatus] || currentStatus} » vers « ${DELIVERY_STATUS_LABELS[nextStatus] || nextStatus} ».`,
    );
  }

  // Vérification de sécurité lors de la livraison finale
  if (nextStatus === 'delivered') {
    if (delivery.otpCode && otpCode && delivery.otpCode !== String(otpCode).trim()) {
      throw new HttpError(403, 'Code OTP de confirmation de livraison invalide.');
    }
  }

  await withTransaction(async () => {
    // 1. Mettre à jour la livraison
    const isCompleted = nextStatus === 'delivered';
    await query(
      `UPDATE deliveries SET 
         status = ?, 
         completed_at = ${isCompleted ? 'CURRENT_TIMESTAMP' : 'completed_at'}, 
         updated_at = CURRENT_TIMESTAMP 
       WHERE id = ?`,
      [nextStatus, deliveryId],
    );

    // 2. Mettre à jour la commande liée
    let targetOrderStatus = null;
    if (nextStatus === 'picked_up' || nextStatus === 'in_transit' || nextStatus === 'on_the_way') {
      targetOrderStatus = 'delivering';
    } else if (nextStatus === 'delivered') {
      targetOrderStatus = 'delivered';
    } else if (nextStatus === 'cancelled') {
      targetOrderStatus = 'cancelled';
    }

    if (targetOrderStatus) {
      await query('UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
        targetOrderStatus,
        delivery.orderId,
      ]);

      await query(
        'INSERT INTO order_events (order_id, status, note, actor_id) VALUES (?, ?, ?, ?)',
        [
          delivery.orderId,
          targetOrderStatus,
          note || `Livraison: ${DELIVERY_STATUS_LABELS[nextStatus] || nextStatus}.`,
          courierId || delivery.courierId,
        ],
      );
    }

    // 3. Rémunération du livreur et libération s'il a terminé
    if (isCompleted && delivery.courierId) {
      const courierShare = Math.round((delivery.fee * COURIER_FEE_SHARE + delivery.tip) * 100) / 100;
      await query(
        `UPDATE couriers SET 
           completed_deliveries = completed_deliveries + 1,
           total_earnings = total_earnings + ?,
           status = 'available'
         WHERE id = ?`,
        [courierShare, delivery.courierId],
      );
    }
  });

  return getDeliveryById(deliveryId);
}

/**
 * Télémétrie GPS en temps réel : met à jour la position du livreur et recalcule l'ETA.
 */
async function updateCourierLocation(courierId, { deliveryId = null, latitude, longitude }) {
  if (latitude == null || longitude == null) {
    throw new HttpError(422, 'Coordonnées GPS obligatoires (latitude, longitude).');
  }

  const lat = Number(latitude);
  const lng = Number(longitude);

  await withTransaction(async () => {
    // 1. Mettre à jour la position courante du livreur
    await query('UPDATE couriers SET latitude = ?, longitude = ? WHERE id = ?', [lat, lng, courierId]);

    // 2. Enregistrer l'historique du tracé GPS
    await query(
      'INSERT INTO courier_locations (courier_id, delivery_id, latitude, longitude) VALUES (?, ?, ?, ?)',
      [courierId, deliveryId, lat, lng],
    );

    // 3. Si associé à une livraison en cours, mettre à jour la distance et l'ETA
    if (deliveryId) {
      const delivs = await query('SELECT * FROM deliveries WHERE id = ? LIMIT 1', [deliveryId]);
      if (delivs[0]) {
        const d = delivs[0];
        const remainingKm = haversineDistance(lat, lng, d.dropoff_lat, d.dropoff_lng);
        const remainingMin = estimateDurationMinutes(remainingKm, 'scooter');
        await query(
          'UPDATE deliveries SET courier_lat = ?, courier_lng = ?, distance_km = ?, duration_min = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [lat, lng, remainingKm, remainingMin, deliveryId],
        );
      }
    }
  });

  return {
    courierId,
    latitude: lat,
    longitude: lng,
    recordedAt: new Date().toISOString(),
  };
}

/**
 * Données de suivi en direct pour l'écran de tracking Flutter.
 */
async function getDeliveryTracking(deliveryId) {
  const delivery = await getDeliveryById(deliveryId);
  const orderEvents = await query(
    'SELECT * FROM order_events WHERE order_id = ? ORDER BY id ASC',
    [delivery.orderId],
  );

  const orderCreated = orderEvents.find((e) => e.status === 'pending');
  const orderReady = orderEvents.find((e) => e.status === 'ready');
  const orderPickedUp = orderEvents.find((e) => e.status === 'delivering');
  const orderDelivered = orderEvents.find((e) => e.status === 'delivered');

  const steps = [
    {
      title: 'Commande validée',
      subtitle: 'Le restaurant a reçu la commande',
      isCompleted: true,
      time: orderCreated ? toIso(orderCreated.created_at) : delivery.createdAt,
    },
    {
      title: 'En cuisine',
      subtitle: 'Les plats sont en préparation',
      isCompleted: ['preparing', 'ready', 'delivering', 'delivered'].includes(delivery.status) || orderEvents.some((e) => e.status === 'preparing'),
      time: orderReady ? toIso(orderReady.created_at) : null,
    },
    {
      title: 'Livreur en route',
      subtitle: delivery.courierName ? `${delivery.courierName} a pris en charge la course` : 'Recherche de livreur...',
      isCompleted: ['assigned', 'picked_up', 'in_transit', 'on_the_way', 'delivered'].includes(delivery.status),
      time: delivery.startedAt,
    },
    {
      title: 'Commande récupérée',
      subtitle: 'Le livreur se dirige vers vous',
      isCompleted: ['picked_up', 'in_transit', 'on_the_way', 'delivered'].includes(delivery.status),
      time: orderPickedUp ? toIso(orderPickedUp.created_at) : null,
    },
    {
      title: 'Livrée',
      subtitle: 'Bon appétit !',
      isCompleted: delivery.status === 'delivered',
      time: delivery.completedAt,
    },
  ];

  return {
    delivery,
    steps,
    telemetry: {
      courierPosition: {
        latitude: delivery.courierLat,
        longitude: delivery.courierLng,
      },
      pickupPosition: {
        latitude: delivery.pickupLat,
        longitude: delivery.pickupLng,
      },
      dropoffPosition: {
        latitude: delivery.dropoffLat,
        longitude: delivery.dropoffLng,
      },
      remainingDistanceKm: delivery.distanceKm,
      remainingMinutes: delivery.durationMin,
    },
  };
}

/**
 * Statistiques du livreur (courses, gains, historique).
 */
async function getCourierStats(courierId) {
  const couriers = await query('SELECT * FROM couriers WHERE id = ? LIMIT 1', [courierId]);
  if (!couriers[0]) throw new HttpError(404, `Livreur introuvable (${courierId}).`);
  const c = couriers[0];

  const activeDeliveries = await query(
    "SELECT id, order_id, status, distance_km, duration_min FROM deliveries WHERE courier_id = ? AND status IN ('assigned', 'picked_up', 'on_the_way', 'in_transit')",
    [courierId],
  );

  return {
    courierId: c.id,
    name: `${c.first_name} ${c.last_name}`,
    vehicle: c.vehicle,
    status: c.status,
    rating: Number(c.rating),
    completedDeliveries: Number(c.completed_deliveries) || 0,
    totalEarnings: Number(c.total_earnings) || 0,
    activeDeliveriesCount: activeDeliveries.length,
    activeDelivery: activeDeliveries[0] || null,
  };
}

module.exports = {
  getDeliveryById,
  listDeliveries,
  findNearbyAvailableCouriers,
  autoDispatchDelivery,
  assignCourier,
  updateDeliveryStatus,
  updateCourierLocation,
  getDeliveryTracking,
  getCourierStats,
};
