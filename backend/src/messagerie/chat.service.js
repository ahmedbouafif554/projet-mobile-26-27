'use strict';

/**
 * Messagerie (`ApiChatRepository`, `ApiMessageRepository`).
 *
 * Conversations :
 * - support : un compte et le support SuperFaster (les admins) ;
 * - restaurant : le client d'une commande et le restaurateur ;
 * - courier : le client d'une commande et son livreur.
 * Les participants viennent de la base (commande, restaurant, livreur) :
 * l'application ne peut pas s'inviter dans la conversation d'un autre.
 * L'admin voit toutes les conversations (supervision) et répond au nom du
 * support.
 */

const HttpError = require('../errors/http-error');
const { query, withTransaction, newId } = require('../data/db');
const { MESSAGES: ROLE_MESSAGES } = require('../domain/roles');

const TYPES = Object.freeze(['support', 'restaurant', 'courier']);
const SUPPORT_NAME = 'Support SuperFaster';
const WELCOME = 'Bonjour ! Comment pouvons-nous vous aider ?';
const ONLINE_WINDOW_MS = 2 * 60_000;
const MAX_TEXT = 2000;

const MESSAGES = Object.freeze({
  forbidden: ROLE_MESSAGES.forbidden,
  chatNotFound: (id) => `Conversation introuvable (${id}).`,
  messageNotFound: (id) => `Message introuvable (${id}).`,
  badType: 'Type de conversation invalide.',
  orderRequired: 'La commande est obligatoire pour cette conversation.',
  notYourOrder: "Cette commande n'est pas la vôtre.",
  noRestaurantOwner: 'Ce restaurant ne reçoit pas encore de messages.',
  noCourier: "Aucun livreur n'est encore assigné à cette commande.",
  emptyText: 'Le message est vide.',
  tooLong: `Le message est trop long (${MAX_TEXT} caractères maximum).`,
  notAuthor: 'Seul l’auteur peut modifier ce message.',
});

const now = () => new Date().toISOString();
const isAdmin = (actor) => actor?.role === 'admin';

// ── Lecture ─────────────────────────────────────────────────────────────────

async function userRow(id) {
  if (!id) return null;
  const rows = await query('SELECT id, first_name, last_name, role, avatar_url FROM users WHERE id = ? LIMIT 1', [id]);
  return rows[0] || null;
}

const fullName = (user) => (user ? `${user.first_name} ${user.last_name}`.trim() : '');

async function findChat(id) {
  const rows = await query('SELECT * FROM chats WHERE id = ? LIMIT 1', [id]);
  if (!rows[0]) throw new HttpError(404, MESSAGES.chatNotFound(id));
  return rows[0];
}

async function participantsOf(chatId) {
  return query('SELECT * FROM chat_participants WHERE chat_id = ? ORDER BY rowid', [chatId]);
}

/** Participant ou admin ; met à jour sa présence (« en ligne »). */
async function accessibleChat(actor, chatId) {
  const chat = await findChat(chatId);
  const participants = await participantsOf(chatId);
  const mine = participants.find((p) => p.user_id === actor.id);
  if (!mine && !isAdmin(actor)) throw new HttpError(403, MESSAGES.forbidden);
  if (mine) {
    await query('UPDATE chat_participants SET last_seen_at = ? WHERE chat_id = ? AND user_id = ?', [now(), chatId, actor.id]);
  }
  return { chat, participants, mine };
}

/**
 * Conversation au format `Chat.toJson()`, vue par [viewer] : le titre est
 * l'interlocuteur (le restaurant pour le client, le client pour le
 * restaurant…), le nombre de non lus est le sien.
 */
async function present(chat, viewer, participants = null) {
  const list = participants || (await participantsOf(chat.id));
  const mine = list.find((p) => p.user_id === viewer.id);
  let title = chat.title;
  let avatarUrl = chat.avatar_url || null;
  if (viewer.id !== chat.created_by && (mine || chat.type === 'support')) {
    // Pour l'autre côté (restaurant, livreur, support), l'interlocuteur est
    // la personne qui a ouvert la conversation.
    const creator = await userRow(chat.created_by);
    title = fullName(creator) || title;
    avatarUrl = creator?.avatar_url || null;
  }
  const cutoff = Date.now() - ONLINE_WINDOW_MS;
  const isOnline = list.some(
    (p) => p.user_id !== viewer.id && p.last_seen_at && new Date(p.last_seen_at).getTime() >= cutoff,
  );
  return {
    id: chat.id,
    type: chat.type,
    title,
    subtitle: chat.subtitle || null,
    avatarUrl,
    participantIds: list.map((p) => p.user_id),
    orderId: chat.order_id || null,
    lastMessage: chat.last_message || null,
    lastMessageAt: chat.last_message_at,
    unreadCount: mine ? Number(mine.unread_count) || 0 : 0,
    isOnline: chat.type === 'support' && viewer.id === chat.created_by ? true : isOnline,
    isFlagged: Boolean(chat.is_flagged),
  };
}

/**
 * `GET /chats` : l'admin voit tout (supervision) ; les autres, leurs
 * conversations. `?userId=` d'un autre compte ne renvoie rien.
 */
async function list(actor, { userId } = {}) {
  const wanted = typeof userId === 'string' && userId.trim() ? userId.trim() : null;
  let rows;
  if (isAdmin(actor) && (!wanted || wanted !== actor.id)) {
    rows = wanted
      ? await query(
        'SELECT c.* FROM chats c JOIN chat_participants p ON p.chat_id = c.id WHERE p.user_id = ? ORDER BY c.last_message_at DESC',
        [wanted],
      )
      : await query('SELECT * FROM chats ORDER BY last_message_at DESC');
  } else {
    if (wanted && wanted !== actor.id) return [];
    rows = await query(
      `SELECT c.* FROM chats c JOIN chat_participants p ON p.chat_id = c.id
        WHERE p.user_id = ? ORDER BY c.last_message_at DESC`,
      [actor.id],
    );
  }
  const result = [];
  for (const row of rows) result.push(await present(row, actor));
  return result;
}

async function get(actor, chatId) {
  const { chat, participants } = await accessibleChat(actor, chatId);
  return present(chat, actor, participants);
}

// ── Création ────────────────────────────────────────────────────────────────

async function supportAgentId() {
  const rows = await query("SELECT id FROM users WHERE role = 'admin' AND status = 'active' ORDER BY created_at ASC LIMIT 1");
  return rows[0]?.id || null;
}

async function orderContext(orderId) {
  const rows = await query(
    `SELECT o.id, o.reference, o.user_id, o.restaurant_id, o.courier_id,
            r.name AS r_name, r.image_url AS r_image, r.owner_id AS r_owner
       FROM orders o LEFT JOIN restaurants r ON r.id = o.restaurant_id
      WHERE o.id = ? LIMIT 1`,
    [orderId],
  );
  if (!rows[0]) throw new HttpError(404, `Commande introuvable (${orderId}).`);
  return rows[0];
}

async function restaurantOwnerOf(order) {
  if (order.r_owner) return order.r_owner;
  const rows = await query(
    "SELECT id FROM users WHERE role = 'restaurant' AND restaurant_id = ? AND status = 'active' LIMIT 1",
    [order.restaurant_id],
  );
  return rows[0]?.id || null;
}

async function courierUserOf(order) {
  if (!order.courier_id) return null;
  const rows = await query('SELECT user_id FROM couriers WHERE id = ? LIMIT 1', [order.courier_id]);
  return rows[0]?.user_id || null;
}

async function existingChat(where, params) {
  const rows = await query(`SELECT * FROM chats WHERE ${where} LIMIT 1`, params);
  return rows[0] || null;
}

async function insertChat({ type, title, subtitle, avatarUrl, orderId, createdBy, participants, welcome }) {
  const id = newId('chat');
  const at = now();
  await withTransaction(async () => {
    await query(
      `INSERT INTO chats (id, type, title, subtitle, avatar_url, order_id, created_by, last_message, last_message_at, is_flagged, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)`,
      [id, type, title, subtitle || null, avatarUrl || null, orderId || null, createdBy, welcome?.text || null, at, at],
    );
    for (const userId of [...new Set(participants.filter(Boolean))]) {
      await query(
        'INSERT INTO chat_participants (chat_id, user_id, unread_count, last_seen_at) VALUES (?, ?, ?, ?)',
        [id, userId, welcome && userId === createdBy ? 1 : 0, userId === createdBy ? at : null],
      );
    }
    if (welcome) {
      await query(
        `INSERT INTO chat_messages (id, chat_id, sender_id, sender_name, text, status, is_system, sent_at)
         VALUES (?, ?, ?, ?, ?, 'sent', 0, ?)`,
        [newId('m'), id, welcome.senderId, welcome.senderName, welcome.text, at],
      );
    }
  });
  return findChat(id);
}

/**
 * `POST /chats` (JSON de `Chat.toJson()`) : seuls `type` et `orderId` comptent.
 * Idempotent : la conversation existante est renvoyée.
 */
async function create(actor, body = {}) {
  const type = body.type;
  if (!TYPES.includes(type)) throw new HttpError(422, MESSAGES.badType);
  if (isAdmin(actor)) throw new HttpError(403, MESSAGES.forbidden);

  if (type === 'support') {
    const found = await existingChat("type = 'support' AND created_by = ?", [actor.id]);
    if (found) return present(found, actor);
    const agent = await supportAgentId();
    const chat = await insertChat({
      type,
      title: SUPPORT_NAME,
      subtitle: 'Disponible 7j/7',
      createdBy: actor.id,
      participants: [actor.id, agent],
      welcome: { senderId: agent || 'support', senderName: SUPPORT_NAME, text: WELCOME },
    });
    return present(chat, actor);
  }

  const orderId = typeof body.orderId === 'string' ? body.orderId.trim() : '';
  if (!orderId) throw new HttpError(422, MESSAGES.orderRequired);
  const order = await orderContext(orderId);
  const found = await existingChat('type = ? AND order_id = ?', [type, orderId]);

  if (type === 'restaurant') {
    if (order.user_id !== actor.id) throw new HttpError(403, MESSAGES.notYourOrder);
    if (found) return present(found, actor);
    const owner = await restaurantOwnerOf(order);
    if (!owner) throw new HttpError(409, MESSAGES.noRestaurantOwner);
    const chat = await insertChat({
      type,
      title: order.r_name || 'Restaurant',
      subtitle: `Commande #${order.reference}`,
      avatarUrl: order.r_image,
      orderId,
      createdBy: actor.id,
      participants: [actor.id, owner],
    });
    return present(chat, actor);
  }

  // Client ↔ livreur : ouverte par le client ou par le livreur de la commande.
  const courierUser = await courierUserOf(order);
  if (!courierUser) throw new HttpError(409, MESSAGES.noCourier);
  if (actor.id !== order.user_id && actor.id !== courierUser) throw new HttpError(403, MESSAGES.notYourOrder);
  if (found) {
    if (!(await participantsOf(found.id)).some((p) => p.user_id === actor.id)) {
      throw new HttpError(403, MESSAGES.forbidden);
    }
    return present(found, actor);
  }
  const other = actor.id === order.user_id ? courierUser : order.user_id;
  const otherUser = await userRow(other);
  const chat = await insertChat({
    type,
    title: fullName(otherUser) || 'Livreur',
    subtitle: `Commande #${order.reference}`,
    avatarUrl: otherUser?.avatar_url,
    orderId,
    createdBy: actor.id,
    participants: [actor.id, other],
  });
  return present(chat, actor);
}

/** `PUT /chats/:id` : l'aperçu est tenu par le serveur ; l'admin peut signaler. */
async function update(actor, chatId, body = {}) {
  const { chat, participants } = await accessibleChat(actor, chatId);
  if (isAdmin(actor) && typeof body.isFlagged === 'boolean') {
    await query('UPDATE chats SET is_flagged = ? WHERE id = ?', [body.isFlagged ? 1 : 0, chatId]);
    return present(await findChat(chatId), actor);
  }
  return present(chat, actor, participants);
}

async function markRead(actor, chatId) {
  const { mine } = await accessibleChat(actor, chatId);
  if (mine) {
    await withTransaction(async () => {
      await query('UPDATE chat_participants SET unread_count = 0 WHERE chat_id = ? AND user_id = ?', [chatId, actor.id]);
      await query("UPDATE chat_messages SET status = 'read' WHERE chat_id = ? AND sender_id <> ? AND status <> 'read'", [chatId, actor.id]);
    });
  }
  return present(await findChat(chatId), actor);
}

async function setFlagged(actor, chatId, flagged) {
  if (!isAdmin(actor)) throw new HttpError(403, MESSAGES.forbidden);
  await findChat(chatId);
  await query('UPDATE chats SET is_flagged = ? WHERE id = ?', [flagged ? 1 : 0, chatId]);
  return present(await findChat(chatId), actor);
}

async function remove(actor, chatId) {
  if (!isAdmin(actor)) throw new HttpError(403, MESSAGES.forbidden);
  await findChat(chatId);
  await withTransaction(async () => {
    await query('DELETE FROM chat_messages WHERE chat_id = ?', [chatId]);
    await query('DELETE FROM chat_participants WHERE chat_id = ?', [chatId]);
    await query('DELETE FROM chats WHERE id = ?', [chatId]);
  });
}

// ── Messages ────────────────────────────────────────────────────────────────

function presentMessage(row) {
  return {
    id: row.id,
    chatId: row.chat_id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    text: row.text,
    status: row.status,
    isSystem: Boolean(row.is_system),
    sentAt: row.sent_at,
    editedAt: row.edited_at || null,
  };
}

async function findMessage(id) {
  const rows = await query('SELECT * FROM chat_messages WHERE id = ? LIMIT 1', [id]);
  if (!rows[0]) throw new HttpError(404, MESSAGES.messageNotFound(id));
  return rows[0];
}

/** Messages du plus ancien au plus récent ; ceux reçus passent « distribué ». */
async function messagesOf(actor, chatId) {
  const { mine } = await accessibleChat(actor, chatId);
  if (mine) {
    await query(
      "UPDATE chat_messages SET status = 'delivered' WHERE chat_id = ? AND sender_id <> ? AND status = 'sent'",
      [chatId, actor.id],
    );
  }
  const rows = await query('SELECT * FROM chat_messages WHERE chat_id = ? ORDER BY sent_at ASC, rowid ASC', [chatId]);
  return rows.map(presentMessage);
}

function cleanText(value) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text) throw new HttpError(422, MESSAGES.emptyText);
  if (text.length > MAX_TEXT) throw new HttpError(422, MESSAGES.tooLong);
  return text;
}

/** Écran de l'app qui ouvre la conversation, selon le rôle du destinataire. */
function chatRouteFor(role, chatId) {
  if (role === 'client') return `/account/messages/${chatId}`;
  if (role === 'courier') return `/courier/messages/${chatId}`;
  return null;
}

async function notifyRecipients(chat, sender, senderName, text, recipients) {
  try {
    const avis = require('../avis_notification');
    await avis.init();
    for (const userId of recipients) {
      const user = await userRow(userId);
      if (!user) continue;
      await avis.notificationService.notify(userId, {
        title: `Nouveau message de ${senderName}`,
        body: text.length > 120 ? `${text.slice(0, 117)}…` : text,
        type: 'message',
        route: chatRouteFor(user.role, chat.id),
      });
    }
  } catch (error) {
    if (process.env.NODE_ENV !== 'test') console.error(`Notification de message impossible : ${error.message}`);
  }
}

/**
 * `POST /messages` : l'expéditeur est toujours le compte connecté (l'admin
 * écrit au nom du support). Les autres participants reçoivent un non lu et
 * une notification.
 */
async function send(actor, body = {}) {
  const chatId = typeof body.chatId === 'string' ? body.chatId : '';
  const { chat, participants, mine } = await accessibleChat(actor, chatId);
  const text = cleanText(body.text);
  const sender = await userRow(actor.id);
  const senderName = isAdmin(actor) ? SUPPORT_NAME : fullName(sender);
  const id = newId('m');
  const at = now();

  await withTransaction(async () => {
    if (!mine) {
      // L'admin qui répond rejoint la conversation.
      await query(
        'INSERT OR IGNORE INTO chat_participants (chat_id, user_id, unread_count, last_seen_at) VALUES (?, ?, 0, ?)',
        [chatId, actor.id, at],
      );
    }
    await query(
      `INSERT INTO chat_messages (id, chat_id, sender_id, sender_name, text, status, is_system, sent_at)
       VALUES (?, ?, ?, ?, ?, 'sent', 0, ?)`,
      [id, chatId, actor.id, senderName, text, at],
    );
    await query('UPDATE chats SET last_message = ?, last_message_at = ? WHERE id = ?', [text, at, chatId]);
    await query(
      'UPDATE chat_participants SET unread_count = unread_count + 1 WHERE chat_id = ? AND user_id <> ?',
      [chatId, actor.id],
    );
    await query(
      'UPDATE chat_participants SET unread_count = 0, last_seen_at = ? WHERE chat_id = ? AND user_id = ?',
      [at, chatId, actor.id],
    );
  });

  await notifyRecipients(
    chat,
    actor,
    senderName,
    text,
    participants.map((p) => p.user_id).filter((userId) => userId !== actor.id),
  );
  return presentMessage(await findMessage(id));
}

async function edit(actor, messageId, body = {}) {
  const message = await findMessage(messageId);
  await accessibleChat(actor, message.chat_id);
  if (message.sender_id !== actor.id) throw new HttpError(403, MESSAGES.notAuthor);
  const text = cleanText(body.text);
  if (text !== message.text) {
    await query('UPDATE chat_messages SET text = ?, edited_at = ? WHERE id = ?', [text, now(), messageId]);
    await refreshPreview(message.chat_id);
  }
  return presentMessage(await findMessage(messageId));
}

async function removeMessage(actor, messageId) {
  const message = await findMessage(messageId);
  await accessibleChat(actor, message.chat_id);
  if (message.sender_id !== actor.id && !isAdmin(actor)) throw new HttpError(403, MESSAGES.forbidden);
  await query('DELETE FROM chat_messages WHERE id = ?', [messageId]);
  await refreshPreview(message.chat_id);
}

/** L'aperçu de la liste reprend le dernier message restant. */
async function refreshPreview(chatId) {
  const rows = await query(
    'SELECT text, sent_at FROM chat_messages WHERE chat_id = ? ORDER BY sent_at DESC, rowid DESC LIMIT 1',
    [chatId],
  );
  if (rows[0]) {
    await query('UPDATE chats SET last_message = ?, last_message_at = ? WHERE id = ?', [rows[0].text, rows[0].sent_at, chatId]);
  } else {
    await query('UPDATE chats SET last_message = NULL WHERE id = ?', [chatId]);
  }
}

async function getMessage(actor, messageId) {
  const message = await findMessage(messageId);
  await accessibleChat(actor, message.chat_id);
  return presentMessage(message);
}

module.exports = {
  MESSAGES,
  SUPPORT_NAME,
  list,
  get,
  create,
  update,
  markRead,
  setFlagged,
  remove,
  messagesOf,
  send,
  edit,
  removeMessage,
  getMessage,
};
