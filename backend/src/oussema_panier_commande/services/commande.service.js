'use strict';

const HttpError = require('../../errors/http-error');
const { query, withTransaction, newId, toIso } = require('../../data/db');
const {
  ORDER_STATUSES,
  ORDER_STATUS_LABELS,
  ALLOWED_ORDER_TRANSITIONS,
  STATUS_ROLE_PERMISSIONS,
} = require('../domain/commande.constants');
const {
  BASE_DELIVERY_FEE,
  PER_KM_FEE,
  FREE_DELIVERY_THRESHOLD,
} = require('../domain/livraison.constants');
const { haversineDistance, estimateDurationMinutes } = require('./geo.utils');

function mapOrder(row, items = [], events = []) {
  if (!row) return null;
  const status = row.status || 'pending';
  const orderRef = row.reference || `CMD-${row.id.slice(-6).toUpperCase()}`;

  let addrObj = null;
  if (row.delivery_address && typeof row.delivery_address === 'string') {
    try {
      if (row.delivery_address.startsWith('{')) {
        addrObj = JSON.parse(row.delivery_address);
      }
    } catch (_) {}
  }

  const deliveryAddress = addrObj || {
    id: `addr_${row.id}`,
    userId: row.user_id,
    label: 'Adresse de livraison',
    street: row.delivery_address || 'Adresse de livraison',
    postalCode: '75001',
    city: 'Paris',
    type: 'home',
    instructions: row.notes || null,
    isDefault: true,
    latitude: row.delivery_lat ? Number(row.delivery_lat) : 48.8686,
    longitude: row.delivery_lng ? Number(row.delivery_lng) : 2.3312,
  };

  return {
    id: row.id,
    reference: orderRef,
    userId: row.user_id,
    customerName: row.customer_name || 'Client',
    customerPhone: row.customer_phone || '',
    restaurantId: row.restaurant_id,
    restaurantName: row.restaurant_name || 'Restaurant',
    restaurantAddress: row.restaurant_address || '',
    courierId: row.courier_id || null,
    courierName: row.courier_name || null,
    status,
    statusLabel: ORDER_STATUS_LABELS[row.status] || ORDER_STATUS_LABELS[status] || status,
    totalAmount: Number(row.total_amount) || 0,
    deliveryFee: Number(row.delivery_fee) || 0,
    serviceFee: Number(row.service_fee) || 0.0,
    discount: Number(row.discount) || 0.0,
    paymentMethod: row.payment_method || 'card',
    paymentStatus: row.payment_status || 'paid',
    deliveryAddress,
    deliveryAddressText: addrObj && addrObj.street ? `${addrObj.street}, ${addrObj.postalCode || ''} ${addrObj.city || ''}`.trim() : (row.delivery_address || ''),
    deliveryLat: row.delivery_lat ? Number(row.delivery_lat) : null,
    deliveryLng: row.delivery_lng ? Number(row.delivery_lng) : null,
    notes: row.notes || null,
    note: row.notes || null,
    promoCode: row.promo_code || null,
    cancelReason: row.cancel_reason || null,
    estimatedMinutes: Number(row.estimated_time) || 30,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    items: items.map((i) => {
      let savedProd = null;
      if (i.product_data) {
        try {
          savedProd = typeof i.product_data === 'string' ? JSON.parse(i.product_data) : i.product_data;
        } catch (_) {}
      }
      let options = [];
      if (i.options) {
        try {
          options = typeof i.options === 'string' ? JSON.parse(i.options) : i.options;
        } catch (_) {}
      }
      return {
        id: String(i.id),
        product: savedProd || {
          id: i.product_id,
          restaurantId: row.restaurant_id,
          categoryId: 'c1',
          name: i.name,
          description: '',
          price: Number(i.price),
          imageUrl: '',
          section: 'Menu',
          optionGroups: [],
          isAvailable: true,
          isPopular: false,
          calories: null,
        },
        productId: i.product_id,
        name: i.name,
        price: Number(i.price),
        quantity: Number(i.quantity) || 1,
        options: Array.isArray(options) ? options : [],
        note: i.note || null,
        total: Math.round(Number(i.price) * (Number(i.quantity) || 1) * 100) / 100,
      };
    }),
    history: events.map((e) => ({
      status: e.status,
      at: toIso(e.created_at),
      note: e.note || null,
    })),
    timeline: events.map((e) => ({
      id: e.id,
      status: e.status,
      statusLabel: ORDER_STATUS_LABELS[e.status] || e.status,
      note: e.note || null,
      actorId: e.actor_id || null,
      at: toIso(e.created_at),
    })),
  };
}

/**
 * Crée une nouvelle commande avec validation métier, calcul dynamique des prix et création automatique de la livraison liée.
 */
async function createOrder(data) {
  const {
    userId = 'u-client-1',
    restaurantId,
    items = [],
    deliveryAddress,
    notes = null,
    note = null,
    promoCode = null,
  } = data;

  if (!restaurantId) throw new HttpError(422, 'Le restaurant est obligatoire.');
  if (!items || items.length === 0) throw new HttpError(422, 'Le panier ne peut pas être vide.');
  if (!deliveryAddress) throw new HttpError(422, "L'adresse de livraison est obligatoire.");

  let addrText = '';
  let deliveryLat = Number(data.deliveryLat) || 48.8686;
  let deliveryLng = Number(data.deliveryLng) || 2.3312;

  if (typeof deliveryAddress === 'object' && deliveryAddress !== null) {
    addrText = JSON.stringify(deliveryAddress);
    if (deliveryAddress.latitude) deliveryLat = Number(deliveryAddress.latitude);
    if (deliveryAddress.longitude) deliveryLng = Number(deliveryAddress.longitude);
  } else if (typeof deliveryAddress === 'string') {
    addrText = deliveryAddress;
  }

  const orderNotes = notes || note || null;

  // Vérifier le restaurant
  const rests = await query('SELECT * FROM restaurants WHERE id = ? LIMIT 1', [restaurantId]);
  const restaurant = rests[0] || {
    id: restaurantId,
    name: data.restaurantName || 'Restaurant',
    latitude: 48.8699,
    longitude: 2.3305,
    is_open: 1,
  };

  // Récupérer et vérifier les produits en base pour certifier les prix
  const productIds = items.map((it) => it.productId || it.id || (it.product && it.product.id)).filter(Boolean);
  let productMap = new Map();
  if (productIds.length > 0) {
    const placeholders = productIds.map(() => '?').join(',');
    const dbProducts = await query(
      `SELECT * FROM products WHERE id IN (${placeholders})`,
      productIds,
    );
    productMap = new Map(dbProducts.map((p) => [p.id, p]));
  }

  let subtotal = 0;
  const verifiedItems = [];

  for (const item of items) {
    const pid = item.productId || item.id || (item.product && item.product.id) || newId('prod');
    const dbProd = productMap.get(pid);
    const price = dbProd ? Number(dbProd.price) : Number(item.price ?? (item.product && item.product.price) ?? 0);
    const name = dbProd ? dbProd.name : (item.name || (item.product && item.product.name) || 'Article');
    const quantity = Math.max(1, parseInt(item.quantity, 10) || 1);

    subtotal += price * quantity;
    verifiedItems.push({
      productId: pid,
      name,
      price,
      quantity,
      options: item.options || [],
      note: item.note || null,
      product: item.product || null,
    });
  }

  // Calcul de la distance restaurant -> client
  const distanceKm = haversineDistance(
    restaurant.latitude || 48.8699,
    restaurant.longitude || 2.3305,
    deliveryLat,
    deliveryLng,
  );

  // Calcul des frais de livraison
  let deliveryFee = subtotal >= FREE_DELIVERY_THRESHOLD ? 0 : Math.round((BASE_DELIVERY_FEE + (distanceKm > 2 ? (distanceKm - 2) * PER_KM_FEE : 0)) * 10) / 10;
  if (data.deliveryFee !== undefined) {
    deliveryFee = Number(data.deliveryFee) || 0;
  }

  // Calcul éventuel de réduction (code promo)
  let discount = Number(data.discount) || 0;
  if (promoCode) {
    const code = String(promoCode).toUpperCase().trim();
    if (code === 'BIENVENUE' || code === 'SUPER5') discount = 5.0;
    else if (code === 'PROMO10') discount = 10.0;
    else if (code === 'LIVRAISON') deliveryFee = 0.0;
  }

  const serviceFee = Number(data.serviceFee) || 0;
  const totalAmount = Math.max(0, Math.round((subtotal + deliveryFee + serviceFee - discount) * 100) / 100);
  const estimatedMinutes = estimateDurationMinutes(distanceKm, 'scooter');
  const orderId = newId('ord');
  const orderReference = data.reference || `CMD-${orderId.slice(-6).toUpperCase()}`;
  const deliveryId = newId('deliv');
  const otpCode = String(Math.floor(1000 + Math.random() * 9000)); // Code OTP 4 chiffres pour validation livraison
  const paymentMethod = data.paymentMethod || 'card';
  const paymentStatus = data.paymentStatus || 'paid';

  await withTransaction(async () => {
    // 1. Insérer la commande
    await query(
      `INSERT INTO orders (id, reference, user_id, restaurant_id, courier_id, status, total_amount, delivery_fee, service_fee, discount, payment_method, payment_status, promo_code, delivery_address, delivery_lat, delivery_lng, notes, estimated_time)
       VALUES (?, ?, ?, ?, NULL, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderId,
        orderReference,
        userId,
        restaurantId,
        totalAmount,
        deliveryFee,
        serviceFee,
        discount,
        paymentMethod,
        paymentStatus,
        promoCode || null,
        addrText,
        deliveryLat,
        deliveryLng,
        orderNotes,
        estimatedMinutes,
      ],
    );

    // 2. Insérer les articles avec options, note et données produit
    for (const it of verifiedItems) {
      await query(
        `INSERT INTO order_items (order_id, product_id, name, price, quantity, options, note, product_data)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          orderId,
          it.productId,
          it.name,
          it.price,
          it.quantity,
          JSON.stringify(it.options || []),
          it.note || null,
          it.product ? JSON.stringify(it.product) : null,
        ],
      );
    }

    // 3. Insérer l'événement initial dans l'historique
    await query(
      `INSERT INTO order_events (order_id, status, note, actor_id)
       VALUES (?, 'pending', 'Commande créée par le client.', ?)`,
      [orderId, userId],
    );

    // 4. Créer la course de livraison liée (en attente d'assignation)
    await query(
      `INSERT INTO deliveries (id, order_id, courier_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, distance_km, duration_min, fee, tip, otp_code)
       VALUES (?, ?, NULL, 'waiting', ?, ?, ?, ?, ?, ?, ?, 0.0, ?)`,
      [
        deliveryId,
        orderId,
        restaurant.latitude || 48.8699,
        restaurant.longitude || 2.3305,
        deliveryLat,
        deliveryLng,
        distanceKm,
        estimatedMinutes,
        deliveryFee > 0 ? deliveryFee : BASE_DELIVERY_FEE,
        otpCode,
      ],
    );
  });

  return getOrderById(orderId);
}

/**
 * Récupère une commande par son identifiant avec articles et timeline.
 */
async function getOrderById(orderId) {
  const sql = `
    SELECT o.*,
           u.first_name || ' ' || u.last_name AS customer_name,
           u.phone AS customer_phone,
           r.name AS restaurant_name,
           r.address AS restaurant_address,
           c.first_name || ' ' || c.last_name AS courier_name
    FROM orders o
    LEFT JOIN users u ON u.id = o.user_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN couriers c ON c.id = o.courier_id
    WHERE o.id = ? LIMIT 1
  `;
  const orderRows = await query(sql, [orderId]);
  if (!orderRows[0]) throw new HttpError(404, `Commande introuvable (${orderId}).`);

  const itemRows = await query('SELECT * FROM order_items WHERE order_id = ? ORDER BY id', [orderId]);
  const eventRows = await query('SELECT * FROM order_events WHERE order_id = ? ORDER BY id ASC', [orderId]);

  return mapOrder(orderRows[0], itemRows, eventRows);
}

/**
 * Liste les commandes avec filtres avancés (userId, restaurantId, courierId, status, date).
 */
async function listOrders(filters = {}) {
  let sql = `
    SELECT o.*,
           u.first_name || ' ' || u.last_name AS customer_name,
           u.phone AS customer_phone,
           r.name AS restaurant_name,
           r.address AS restaurant_address,
           c.first_name || ' ' || c.last_name AS courier_name
    FROM orders o
    LEFT JOIN users u ON u.id = o.user_id
    LEFT JOIN restaurants r ON r.id = o.restaurant_id
    LEFT JOIN couriers c ON c.id = o.courier_id
  `;
  const params = [];
  const conditions = [];

  if (filters.userId) {
    conditions.push('o.user_id = ?');
    params.push(filters.userId);
  }
  if (filters.restaurantId) {
    conditions.push('o.restaurant_id = ?');
    params.push(filters.restaurantId);
  }
  if (filters.courierId) {
    conditions.push('o.courier_id = ?');
    params.push(filters.courierId);
  }
  if (filters.status) {
    conditions.push('o.status = ?');
    params.push(filters.status);
  }
  if (conditions.length > 0) {
    sql += ' WHERE ' + conditions.join(' AND ');
  }
  sql += ' ORDER BY o.created_at DESC';

  const orderRows = await query(sql, params);
  if (orderRows.length === 0) return [];

  const orderIds = orderRows.map((o) => o.id);
  const placeholders = orderIds.map(() => '?').join(',');

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

  return orderRows.map((o) => mapOrder(o, itemsByOrder.get(o.id) || []));
}

/**
 * Met à jour le statut d'une commande selon la machine d'états et vérifie les permissions.
 */
async function updateOrderStatus(orderId, nextStatus, { actorId, role, note } = {}) {
  if (!ORDER_STATUSES.includes(nextStatus)) {
    throw new HttpError(422, `Statut de commande invalide: ${nextStatus}`);
  }

  const order = await getOrderById(orderId);
  const currentStatus = order.status;

  if (currentStatus === nextStatus) return order;

  // Validation de la transition
  const allowed = ALLOWED_ORDER_TRANSITIONS[currentStatus] || [];
  if (!allowed.includes(nextStatus)) {
    throw new HttpError(
      400,
      `Transition impossible de « ${ORDER_STATUS_LABELS[currentStatus] || currentStatus} » vers « ${ORDER_STATUS_LABELS[nextStatus] || nextStatus} ».`,
    );
  }

  // Validation des permissions par rôle
  if (role && STATUS_ROLE_PERMISSIONS[nextStatus]) {
    const permittedRoles = STATUS_ROLE_PERMISSIONS[nextStatus];
    if (!permittedRoles.includes(role)) {
      throw new HttpError(403, `Le rôle « ${role} » n'est pas autorisé à passer la commande en statut « ${nextStatus} ».`);
    }
  }

  const defaultNote = `Passage au statut ${ORDER_STATUS_LABELS[nextStatus] || nextStatus}.`;

  await withTransaction(async () => {
    await query(
      'UPDATE orders SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [nextStatus, orderId],
    );

    await query(
      'INSERT INTO order_events (order_id, status, note, actor_id) VALUES (?, ?, ?, ?)',
      [orderId, nextStatus, note || defaultNote, actorId || null],
    );

    // Synchronisation du paiement et de la livraison
    if (nextStatus === 'refunded') {
      await query(
        'UPDATE orders SET payment_status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        ['refunded', orderId],
      );
    }

    if (nextStatus === 'cancelled') {
      await query('UPDATE deliveries SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE order_id = ?', [
        'cancelled',
        orderId,
      ]);
    } else if (nextStatus === 'delivered') {
      await query(
        'UPDATE deliveries SET status = ?, completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE order_id = ?',
        ['delivered', orderId],
      );
    }
  });

  return getOrderById(orderId);
}

/**
 * Annule une commande selon les règles métier.
 */
async function cancelOrder(orderId, { actorId, role, reason = 'Annulation demandée' } = {}) {
  const order = await getOrderById(orderId);
  if (role === 'client' && order.status !== 'pending') {
    throw new HttpError(400, 'Une commande déjà confirmée ou en cours de préparation ne peut plus être annulée par le client.');
  }
  await query('UPDATE orders SET cancel_reason = ? WHERE id = ?', [reason, orderId]);
  return updateOrderStatus(orderId, 'cancelled', {
    actorId,
    role,
    note: `Commande annulée: ${reason}`,
  });
}

/**
 * Récupère l'historique complet des statuts (timeline).
 */
async function getOrderTimeline(orderId) {
  await getOrderById(orderId); // Assure l'existence
  const events = await query(
    'SELECT * FROM order_events WHERE order_id = ? ORDER BY id ASC',
    [orderId],
  );
  return events.map((e) => ({
    id: e.id,
    status: e.status,
    statusLabel: ORDER_STATUS_LABELS[e.status] || e.status,
    note: e.note,
    actorId: e.actor_id,
    at: toIso(e.created_at),
  }));
}

/**
 * Métriques et statistiques avancées sur les commandes.
 */
async function getOrderStats({ restaurantId = null } = {}) {
  let sql = 'SELECT status, COUNT(*) as count, SUM(total_amount) as revenue FROM orders';
  const params = [];
  if (restaurantId) {
    sql += ' WHERE restaurant_id = ?';
    params.push(restaurantId);
  }
  sql += ' GROUP BY status';

  const rows = await query(sql, params);

  let totalOrders = 0;
  let totalRevenue = 0;
  const byStatus = {};

  for (const s of ORDER_STATUSES) {
    byStatus[s] = 0;
  }

  for (const r of rows) {
    const cnt = Number(r.count) || 0;
    const rev = Number(r.revenue) || 0;
    totalOrders += cnt;
    totalRevenue += rev;
    byStatus[r.status] = cnt;
  }

  return {
    totalOrders,
    totalRevenue: Math.round(totalRevenue * 100) / 100,
    averageBasket: totalOrders > 0 ? Math.round((totalRevenue / totalOrders) * 100) / 100 : 0,
    byStatus,
  };
}

/**
 * Met à jour une commande (PUT /orders/:id) avec support des modifications générales ou de statut.
 */
async function updateOrder(orderId, data, context = {}) {
  const existing = await getOrderById(orderId);

  // Si un changement de statut est demandé
  if (data.status && data.status !== existing.status) {
    await updateOrderStatus(orderId, data.status, {
      actorId: context.actorId || data.actorId,
      role: context.role || data.role,
      note: data.note || `Mise à jour statut: ${data.status}`,
    });
  }

  const updates = [];
  const params = [];

  if (data.notes !== undefined || data.note !== undefined) {
    updates.push('notes = ?');
    params.push(data.notes ?? data.note);
  }
  if (data.courierId !== undefined) {
    updates.push('courier_id = ?');
    params.push(data.courierId);
  }
  if (data.paymentStatus !== undefined) {
    updates.push('payment_status = ?');
    params.push(data.paymentStatus);
  }
  if (data.cancelReason !== undefined) {
    updates.push('cancel_reason = ?');
    params.push(data.cancelReason);
  }

  if (updates.length > 0) {
    updates.push('updated_at = CURRENT_TIMESTAMP');
    params.push(orderId);
    await query(`UPDATE orders SET ${updates.join(', ')} WHERE id = ?`, params);
  }

  return getOrderById(orderId);
}

/**
 * Supprime une commande et ses données associées (DELETE /orders/:id).
 */
async function deleteOrder(orderId) {
  await getOrderById(orderId); // vérifie existence
  await withTransaction(async () => {
    await query('DELETE FROM order_events WHERE order_id = ?', [orderId]);
    await query('DELETE FROM order_items WHERE order_id = ?', [orderId]);
    await query('DELETE FROM deliveries WHERE order_id = ?', [orderId]);
    await query('DELETE FROM orders WHERE id = ?', [orderId]);
  });
  return { success: true, id: orderId };
}

module.exports = {
  createOrder,
  getOrderById,
  listOrders,
  updateOrder,
  updateOrderStatus,
  cancelOrder,
  deleteOrder,
  getOrderTimeline,
  getOrderStats,
};
