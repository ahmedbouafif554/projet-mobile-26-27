const express = require('express');
const asyncHandler = require('../middleware/async');
const { query, newId, toIso, withTransaction } = require('../data/db');

const router = express.Router();

function mapOrder(row, items = []) {
  if (!row) return null;
  return {
    id: row.id,
    reference: `CMD-${row.id.slice(-6).toUpperCase()}`,
    userId: row.user_id,
    customerName: row.customer_name || 'Client',
    restaurantId: row.restaurant_id,
    restaurantName: row.restaurant_name || 'Restaurant',
    courierId: row.courier_id || null,
    status: row.status || 'pending',
    totalAmount: Number(row.total_amount) || 0,
    deliveryFee: Number(row.delivery_fee) || 2.5,
    deliveryAddress: row.delivery_address || '',
    notes: row.notes || null,
    estimatedMinutes: Number(row.estimated_time) || 30,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    items: items.map((i) => ({
      id: String(i.id),
      productId: i.product_id,
      name: i.name,
      price: Number(i.price),
      quantity: Number(i.quantity) || 1,
    })),
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    let sql = `
      SELECT o.*, 
             u.first_name || ' ' || u.last_name AS customer_name,
             r.name AS restaurant_name
      FROM orders o
      LEFT JOIN users u ON u.id = o.user_id
      LEFT JOIN restaurants r ON r.id = o.restaurant_id
    `;
    const params = [];
    const conditions = [];

    if (req.query.userId) {
      conditions.push('o.user_id = ?');
      params.push(req.query.userId);
    }
    if (req.query.restaurantId) {
      conditions.push('o.restaurant_id = ?');
      params.push(req.query.restaurantId);
    }
    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY o.created_at DESC';

    const orderRows = await query(sql, params);
    if (orderRows.length === 0) return res.json([]);

    const placeholders = orderRows.map(() => '?').join(',');
    const orderIds = orderRows.map((o) => o.id);
    const itemRows = await query(
      `SELECT * FROM order_items WHERE order_id IN (${placeholders}) ORDER BY id`,
      orderIds,
    );

    const itemsByOrder = new Map();
    for (const item of itemRows) {
      const list = itemsByOrder.get(item.order_id) || [];
      list.push(item);
      itemsByOrder.set(item.order_id, list);
    }

    res.json(orderRows.map((o) => mapOrder(o, itemsByOrder.get(o.id) || [])));
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const orderRows = await query(
      `SELECT o.*, 
              u.first_name || ' ' || u.last_name AS customer_name,
              r.name AS restaurant_name
       FROM orders o
       LEFT JOIN users u ON u.id = o.user_id
       LEFT JOIN restaurants r ON r.id = o.restaurant_id
       WHERE o.id = ? LIMIT 1`,
      [req.params.id],
    );
    if (!orderRows[0]) return res.status(404).json({ error: 'Commande non trouvée' });

    const itemRows = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [
      req.params.id,
    ]);
    res.json(mapOrder(orderRows[0], itemRows));
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    const id = b.id || newId('ord');
    const items = Array.isArray(b.items) ? b.items : [];

    await withTransaction(async () => {
      await query(
        `INSERT INTO orders (id, user_id, restaurant_id, courier_id, status, total_amount, delivery_fee, delivery_address, notes, estimated_time)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          id,
          b.userId || 'u-client-1',
          b.restaurantId || 'rest_demo',
          b.courierId || null,
          b.status || 'pending',
          Number(b.totalAmount) || 0,
          Number(b.deliveryFee) || 2.5,
          b.deliveryAddress || 'Adresse non spécifiée',
          b.notes || null,
          Number(b.estimatedMinutes) || 30,
        ],
      );

      for (const item of items) {
        await query(
          `INSERT INTO order_items (order_id, product_id, name, price, quantity)
           VALUES (?, ?, ?, ?, ?)`,
          [
            id,
            item.productId || item.id || 'prod_1',
            item.name || 'Article',
            Number(item.price) || 0,
            Number(item.quantity) || 1,
          ],
        );
      }
    });

    const created = await query('SELECT * FROM orders WHERE id = ? LIMIT 1', [id]);
    const createdItems = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [id]);
    res.status(201).json(mapOrder(created[0], createdItems));
  }),
);

router.patch(
  '/:id/status',
  asyncHandler(async (req, res) => {
    const status = req.body?.status;
    await query('UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
      status,
      req.params.id,
    ]);
    const updated = await query('SELECT * FROM orders WHERE id = ? LIMIT 1', [req.params.id]);
    if (!updated[0]) return res.status(404).json({ error: 'Commande non trouvée' });
    const items = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [req.params.id]);
    res.json(mapOrder(updated[0], items));
  }),
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    await query(
      `UPDATE orders SET
         status = COALESCE(?, status),
         courier_id = COALESCE(?, courier_id),
         total_amount = COALESCE(?, total_amount),
         delivery_fee = COALESCE(?, delivery_fee),
         delivery_address = COALESCE(?, delivery_address),
         notes = COALESCE(?, notes),
         estimated_time = COALESCE(?, estimated_time),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [
        b.status,
        b.courierId,
        b.totalAmount != null ? Number(b.totalAmount) : null,
        b.deliveryFee != null ? Number(b.deliveryFee) : null,
        b.deliveryAddress,
        b.notes,
        b.estimatedMinutes != null ? Number(b.estimatedMinutes) : null,
        req.params.id,
      ],
    );
    const updated = await query('SELECT * FROM orders WHERE id = ? LIMIT 1', [req.params.id]);
    if (!updated[0]) return res.status(404).json({ error: 'Commande non trouvée' });
    const items = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [req.params.id]);
    res.json(mapOrder(updated[0], items));
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    await query('DELETE FROM orders WHERE id = ?', [req.params.id]);
    res.status(204).send();
  }),
);

module.exports = router;
