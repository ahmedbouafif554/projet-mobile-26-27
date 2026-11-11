'use strict';

const config = require('../config');

let transport = null;
/** Derniers e-mails « envoyés » sans SMTP (lus par les tests). */
const outbox = [];

function transporter() {
  const smtp = config.smtp;
  if (!smtp.host) return null;
  if (!transport) {
    const nodemailer = require('nodemailer');
    transport = nodemailer.createTransport({
      host: smtp.host,
      port: smtp.port,
      secure: smtp.secure,
      auth: smtp.user ? { user: smtp.user, pass: smtp.pass } : undefined,
    });
  }
  return transport;
}

/**
 * Envoie un e-mail. Sans SMTP configuré, le message est écrit dans le journal
 * du serveur (développement) et gardé dans `outbox` (tests).
 */
async function send({ to, subject, text, html }) {
  const mail = { from: config.smtp.from, to, subject, text, html };
  const smtp = transporter();
  if (!smtp) {
    outbox.push(mail);
    if (outbox.length > 50) outbox.shift();
    if (!config.isTest) {
      console.log(`[mail] SMTP non configuré — e-mail pour ${to} : ${subject}\n${text}`);
    }
    return { delivered: false };
  }
  await smtp.sendMail(mail);
  return { delivered: true };
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function sendPasswordReset({ to, firstName, link, minutes }) {
  const name = firstName || '';
  return send({
    to,
    subject: 'SuperFaster — Réinitialisation de votre mot de passe',
    text:
      `Bonjour ${name},\n\n` +
      'Vous avez demandé à changer votre mot de passe SuperFaster.\n' +
      `Ouvrez ce lien pour en choisir un nouveau (valable ${minutes} minutes) :\n${link}\n\n` +
      "Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail : " +
      'votre mot de passe reste inchangé.',
    html:
      `<p>Bonjour ${escapeHtml(name)},</p>` +
      '<p>Vous avez demandé à changer votre mot de passe SuperFaster.</p>' +
      `<p><a href="${escapeHtml(link)}">Choisir un nouveau mot de passe</a> ` +
      `(lien valable ${minutes} minutes).</p>` +
      "<p>Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail : " +
      'votre mot de passe reste inchangé.</p>',
  });
}

module.exports = { send, sendPasswordReset, outbox, escapeHtml };
