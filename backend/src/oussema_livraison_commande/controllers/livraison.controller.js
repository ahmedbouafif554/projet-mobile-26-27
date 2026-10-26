'use strict';

const livraisonService = require('../services/livraison.service');

async function list(req, res) {
  const deliveries = await livraisonService.listDeliveries(req.query);
  res.json(deliveries);
}

async function getById(req, res) {
  const delivery = await livraisonService.getDeliveryById(req.params.id);
  res.json(delivery);
}

async function getTracking(req, res) {
  const tracking = await livraisonService.getDeliveryTracking(req.params.id);
  res.json(tracking);
}

async function findNearbyCouriers(req, res) {
  const couriers = await livraisonService.findNearbyAvailableCouriers({
    latitude: Number(req.query.latitude) || 48.8699,
    longitude: Number(req.query.longitude) || 2.3305,
    maxDistanceKm: Number(req.query.maxDistanceKm) || 15,
    limit: Number(req.query.limit) || 5,
  });
  res.json(couriers);
}

async function autoDispatch(req, res) {
  const result = await livraisonService.autoDispatchDelivery(req.params.id);
  res.json(result);
}

async function assign(req, res) {
  const delivery = await livraisonService.assignCourier(req.params.id, req.body.courierId);
  res.json(delivery);
}

async function updateStatus(req, res) {
  const updated = await livraisonService.updateDeliveryStatus(req.params.id, req.body.status, {
    courierId: req.body.courierId || req.auth?.id,
    otpCode: req.body.otpCode,
    note: req.body.note,
  });
  res.json(updated);
}

async function updateLocation(req, res) {
  const result = await livraisonService.updateCourierLocation(req.params.courierId, req.body);
  res.json(result);
}

async function getCourierStats(req, res) {
  const stats = await livraisonService.getCourierStats(req.params.courierId);
  res.json(stats);
}

module.exports = {
  list,
  getById,
  getTracking,
  findNearbyCouriers,
  autoDispatch,
  assign,
  updateStatus,
  updateLocation,
  getCourierStats,
};
