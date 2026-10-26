const express = require('express');
const asyncHandler = require('../middleware/async');
const { query, newId, toIso } = require('../data/db');

const router = express.Router();

function mapDelivery(row) {
  if (!row) return null;
  return {
    id: row.id,
    orderId: row.order_id,
    orderReference: `CMD-${row.order_id.slice(-6).toUpperCase()}`,
    courierId: row.courier_id || null,
    status: row.status || 'assigned',
    pickupName: row.pickup_name || 'Restaurant',
    pickupAddress: row.pickup_address || '10 rue de la Paix, Paris',
    customerName: row.customer_name || 'Client',
    dropoffAddress: row.dropoff_address || row.delivery_address || '12 rue de la Paix, Paris',
    distanceKm: Number(row.distance_km) || 2.5,
    fee: 4.5,
    tip: 0,
    estimatedMinutes: Number(row.duration_min) || 25,
    createdAt: toIso(row.created_at),
    assignedAt: toIso(row.started_at),
    deliveredAt: toIso(row.completed_at),
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    let sql = `
      SELECT d.*, 
             o.delivery_address,
             r.name AS pickup_name,
             r.address AS pickup_address,
             u.first_name || ' ' || u.last_name AS customer_name
      FROM deliveries d
      LEFT JOIN orders o ON o.id = d.order_id
      LEFT JOIN restaurants r ON r.id = o.restaurant_id
      LEFT JOIN users u ON u.id = o.user_id
    `;
    const params = [];
    if (req.query.courierId) {
      sql += ' WHERE d.courier_id = ?';
      params.push(req.query.courierId);
    }
    sql += ' ORDER BY d.created_at DESC';

    const rows = await query(sql, params);
    res.json(rows.map(mapDelivery));
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const rows = await query(
      `SELECT d.*, 
              o.delivery_address,
              r.name AS pickup_name,
              r.address AS pickup_address,
              u.first_name || ' ' || u.last_name AS customer_name
       FROM deliveries d
       LEFT JOIN orders o ON o.id = d.order_id
       LEFT JOIN restaurants r ON r.id = o.restaurant_id
       LEFT JOIN users u ON u.id = o.user_id
       WHERE d.id = ? LIMIT 1`,
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ error: 'Livraison non trouvée' });
    res.json(mapDelivery(rows[0]));
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    const id = b.id || newId('deliv');
    await query(
      `INSERT INTO deliveries (id, order_id, courier_id, status, distance_km, duration_min)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        id,
        b.orderId || newId('ord'),
        b.courierId || null,
        b.status || 'assigned',
        Number(b.distanceKm) || 2.5,
        Number(b.estimatedMinutes) || 25,
      ],
    );
    const rows = await query('SELECT * FROM deliveries WHERE id = ? LIMIT 1', [id]);
    res.status(201).json(mapDelivery(rows[0]));
  }),
);

router.patch(
  '/:id/status',
  asyncHandler(async (req, res) => {
    const status = req.body?.status;
    await query('UPDATE deliveries SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
      status,
      req.params.id,
    ]);
    const rows = await query('SELECT * FROM deliveries WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Livraison non trouvée' });
    res.json(mapDelivery(rows[0]));
  }),
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    await query(
      `UPDATE deliveries SET
         status = COALESCE(?, status),
         courier_id = COALESCE(?, courier_id),
         distance_km = COALESCE(?, distance_km),
         duration_min = COALESCE(?, duration_min),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [
        b.status,
        b.courierId,
        b.distanceKm != null ? Number(b.distanceKm) : null,
        b.estimatedMinutes != null ? Number(b.estimatedMinutes) : null,
        req.params.id,
      ],
    );
    const rows = await query('SELECT * FROM deliveries WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Livraison non trouvée' });
    res.json(mapDelivery(rows[0]));
  }),
);

module.exports = router;
