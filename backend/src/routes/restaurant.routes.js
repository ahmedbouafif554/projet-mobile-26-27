const express = require('express');
const asyncHandler = require('../middleware/async');
const { query, newId, toIso } = require('../data/db');

const router = express.Router();

function mapRestaurant(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    description: row.description || '',
    address: row.address || '',
    phone: row.phone || '',
    email: row.email || '',
    cuisine: row.category || '',
    categoryIds: row.category ? [row.category] : [],
    imageUrl: row.image_url || '',
    latitude: Number(row.latitude) || 48.8566,
    longitude: Number(row.longitude) || 2.3522,
    rating: Number(row.rating) || 0,
    isOpen: Boolean(row.is_open),
    ownerId: row.owner_id || null,
    status: 'approved',
    createdAt: toIso(row.created_at),
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    let sql = 'SELECT * FROM restaurants';
    const params = [];
    if (req.query.category) {
      sql += ' WHERE category = ?';
      params.push(req.query.category);
    }
    sql += ' ORDER BY id';
    const rows = await query(sql, params);
    res.json(rows.map(mapRestaurant));
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const rows = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Restaurant non trouvé' });
    res.json(mapRestaurant(rows[0]));
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    const id = b.id || newId('rest');
    await query(
      `INSERT INTO restaurants (id, name, description, address, phone, email, category, image_url, latitude, longitude, rating, is_open, owner_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        b.name || 'Nouveau restaurant',
        b.description || '',
        b.address || '',
        b.phone || '',
        b.email || '',
        b.cuisine || (Array.isArray(b.categoryIds) ? b.categoryIds[0] : '') || '',
        b.imageUrl || '',
        Number(b.latitude) || 48.8566,
        Number(b.longitude) || 2.3522,
        Number(b.rating) || 0,
        b.isOpen !== false ? 1 : 0,
        b.ownerId || null,
      ],
    );
    const rows = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [id]);
    res.status(201).json(mapRestaurant(rows[0]));
  }),
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    await query(
      `UPDATE restaurants SET
         name = COALESCE(?, name),
         description = COALESCE(?, description),
         address = COALESCE(?, address),
         phone = COALESCE(?, phone),
         email = COALESCE(?, email),
         category = COALESCE(?, category),
         image_url = COALESCE(?, image_url),
         latitude = COALESCE(?, latitude),
         longitude = COALESCE(?, longitude),
         rating = COALESCE(?, rating),
         is_open = COALESCE(?, is_open),
         owner_id = COALESCE(?, owner_id)
       WHERE id = ?`,
      [
        b.name,
        b.description,
        b.address,
        b.phone,
        b.email,
        b.cuisine || (Array.isArray(b.categoryIds) ? b.categoryIds[0] : null),
        b.imageUrl,
        b.latitude != null ? Number(b.latitude) : null,
        b.longitude != null ? Number(b.longitude) : null,
        b.rating != null ? Number(b.rating) : null,
        b.isOpen != null ? (b.isOpen ? 1 : 0) : null,
        b.ownerId,
        req.params.id,
      ],
    );
    const rows = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Restaurant non trouvé' });
    res.json(mapRestaurant(rows[0]));
  }),
);

router.patch(
  '/:id/status',
  asyncHandler(async (req, res) => {
    const status = req.body?.status;
    const isOpen = status === 'approved' || status === 'open' ? 1 : 0;
    await query('UPDATE restaurants SET is_open = ? WHERE id = ?', [isOpen, req.params.id]);
    const rows = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Restaurant non trouvé' });
    res.json(mapRestaurant(rows[0]));
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    await query('DELETE FROM restaurants WHERE id = ?', [req.params.id]);
    res.status(204).send();
  }),
);

module.exports = router;
