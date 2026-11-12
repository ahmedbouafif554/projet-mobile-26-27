'use strict';

const { query } = require('../../data/db');
const commandeService = require('../services/commande.service');
const stripeService = require('../services/stripe.service');
const HttpError = require('../../errors/http-error');

/**
 * POST /api/orders/:id/payment-intent
 * Crée un Stripe PaymentIntent pour payer une commande.
 */
async function createPaymentIntent(req, res) {
  const order = await commandeService.getOrderFor(req.auth, req.params.id);
  if (order.paymentStatus === 'paid') {
    throw new HttpError(409, 'Cette commande est déjà payée.');
  }
  if (order.paymentMethod === 'cash') {
    throw new HttpError(422, 'Cette commande est en paiement cash à la livraison.');
  }
  const user = await query('SELECT email FROM users WHERE id = ? LIMIT 1', [req.auth.id]);
  const intent = await stripeService.createPaymentIntent(order.id, order.totalAmount, {
    customerEmail: user[0]?.email,
    description: `SuperFaster commande ${order.reference}`,
  });
  res.json({
    orderId: order.id,
    reference: order.reference,
    amount: intent.amount,
    currency: intent.currency,
    clientSecret: intent.clientSecret,
    paymentIntentId: intent.paymentIntentId,
  });
}

/**
 * POST /api/webhooks/stripe
 * Reçoit les événements Stripe (payment_intent.succeeded, etc.)
 * Cette route doit recevoir le body RAW (pas parsé JSON).
 */
async function stripeWebhook(req, res) {
  const signature = req.headers['stripe-signature'];
  if (!signature) {
    res.status(400).json({ error: 'Signature Stripe manquante.' });
    return;
  }
  try {
    const event = await stripeService.handleWebhookEvent(req.body, signature);
    if (event.type === 'payment_succeeded' && event.orderId) {
      await query(
        "UPDATE orders SET payment_status = 'paid', updated_at = ? WHERE id = ?",
        [new Date().toISOString(), event.orderId],
      );
    }
    if (event.type === 'payment_failed' && event.orderId) {
      await query(
        "UPDATE orders SET payment_status = 'failed', updated_at = ? WHERE id = ?",
        [new Date().toISOString(), event.orderId],
      );
    }
    res.json({ received: true, type: event.type });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
}

/**
 * POST /api/orders/:id/confirm-payment
 * Confirme le paiement Stripe d'une commande côté client (après validation de la carte).
 */
async function confirmPayment(req, res) {
  const { paymentIntentId } = req.body || {};
  const order = await commandeService.getOrderFor(req.auth, req.params.id);
  const result = await stripeService.confirmPayment(order.id, paymentIntentId);
  if (result.success) {
    await query(
      "UPDATE orders SET payment_status = 'paid', updated_at = ? WHERE id = ?",
      [new Date().toISOString(), order.id],
    );
  }
  res.json({
    orderId: order.id,
    paymentStatus: result.success ? 'paid' : order.paymentStatus,
    status: result.status,
  });
}

module.exports = { createPaymentIntent, stripeWebhook, confirmPayment };
