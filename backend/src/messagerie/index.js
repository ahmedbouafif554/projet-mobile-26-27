'use strict';

const express = require('express');
const asyncHandler = require('../middleware/async');
const { authenticate } = require('../middleware/auth.middleware');
const { ensureSchema, schemaReady, clear } = require('./schema');
const chats = require('./chat.service');

// ── /api/chats ──────────────────────────────────────────────────────────────
const chatRoutes = express.Router();
chatRoutes.use(schemaReady, authenticate);

chatRoutes.get('/', asyncHandler(async (req, res) => {
  res.json(await chats.list(req.auth, req.query));
}));
chatRoutes.post('/', asyncHandler(async (req, res) => {
  res.status(201).json(await chats.create(req.auth, req.body));
}));
chatRoutes.get('/:id', asyncHandler(async (req, res) => {
  res.json(await chats.get(req.auth, req.params.id));
}));
chatRoutes.put('/:id', asyncHandler(async (req, res) => {
  res.json(await chats.update(req.auth, req.params.id, req.body));
}));
chatRoutes.delete('/:id', asyncHandler(async (req, res) => {
  await chats.remove(req.auth, req.params.id);
  res.status(204).send();
}));
chatRoutes.patch('/:id/read', asyncHandler(async (req, res) => {
  res.json(await chats.markRead(req.auth, req.params.id));
}));
chatRoutes.patch('/:id/flag', asyncHandler(async (req, res) => {
  res.json(await chats.setFlagged(req.auth, req.params.id, Boolean(req.body?.isFlagged)));
}));
chatRoutes.get('/:id/messages', asyncHandler(async (req, res) => {
  res.json(await chats.messagesOf(req.auth, req.params.id));
}));

// ── /api/messages ───────────────────────────────────────────────────────────
const messageRoutes = express.Router();
messageRoutes.use(schemaReady, authenticate);

messageRoutes.get('/', asyncHandler(async (req, res) => {
  if (!req.query.chatId) {
    res.json([]);
    return;
  }
  res.json(await chats.messagesOf(req.auth, String(req.query.chatId)));
}));
messageRoutes.post('/', asyncHandler(async (req, res) => {
  res.status(201).json(await chats.send(req.auth, req.body));
}));
messageRoutes.get('/:id', asyncHandler(async (req, res) => {
  res.json(await chats.getMessage(req.auth, req.params.id));
}));
messageRoutes.put('/:id', asyncHandler(async (req, res) => {
  res.json(await chats.edit(req.auth, req.params.id, req.body));
}));
messageRoutes.delete('/:id', asyncHandler(async (req, res) => {
  await chats.removeMessage(req.auth, req.params.id);
  res.status(204).send();
}));

module.exports = { chatRoutes, messageRoutes, chatService: chats, init: ensureSchema, clear };
