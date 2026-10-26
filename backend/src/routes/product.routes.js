const express = require('express');
const asyncHandler = require('../middleware/async');
const { query, newId } = require('../data/db');

const router = express.Router();

function mapProduct(row) {
  if (!row) return null;
  return {
    id: row.id,
    restaurantId: row.restaurant_id,
    categoryId: row.category || '',
    name: row.name,
    description: row.description || '',
    price: Number(row.price) || 0,
    imageUrl: row.image_url || '',
    section: row.category || '',
    optionGroups: [],
    isAvailable: Boolean(row.is_available),
    isPopular: false,
    calories: null,
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    let sql = 'SELECT * FROM products';
    const params = [];
    const conditions = [];

    if (req.query.restaurantId) {
      conditions.push('restaurant_id = ?');
      params.push(req.query.restaurantId);
    }
    if (req.query.category) {
      conditions.push('category = ?');
      params.push(req.query.category);
    }
    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY id';

    const rows = await query(sql, params);
    res.json(rows.map(mapProduct));
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const rows = await query('SELECT * FROM products WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Produit non trouvé' });
    res.json(mapProduct(rows[0]));
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    const id = b.id || newId('prod');
    await query(
      `INSERT INTO products (id, restaurant_id, name, description, price, category, image_url, is_available)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        b.restaurantId || 'rest_demo',
        b.name || 'Nouveau produit',
        b.description || '',
        Number(b.price) || 0,
        b.categoryId || b.section || b.category || '',
        b.imageUrl || '',
        b.isAvailable !== false ? 1 : 0,
      ],
    );
    const rows = await query('SELECT * FROM products WHERE id = ? LIMIT 1', [id]);
    res.status(201).json(mapProduct(rows[0]));
  }),
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    await query(
      `UPDATE products SET
         name = COALESCE(?, name),
         description = COALESCE(?, description),
         price = COALESCE(?, price),
         category = COALESCE(?, category),
         image_url = COALESCE(?, image_url),
         is_available = COALESCE(?, is_available)
       WHERE id = ?`,
      [
        b.name,
        b.description,
        b.price != null ? Number(b.price) : null,
        b.categoryId || b.section || b.category,
        b.imageUrl,
        b.isAvailable != null ? (b.isAvailable ? 1 : 0) : null,
        req.params.id,
      ],
    );
    const rows = await query('SELECT * FROM products WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Produit non trouvé' });
    res.json(mapProduct(rows[0]));
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    await query('DELETE FROM products WHERE id = ?', [req.params.id]);
    res.status(204).send();
  }),
);

module.exports = router;
