'use strict';

/**
 * Crée une notification en base pour un utilisateur donné.
 * Non-bloquant : les erreurs sont loguées mais pas propagées.
 * @param {object} db     - Instance better-sqlite3
 * @param {number} userId - Destinataire
 * @param {string} type   - Type de notification (join_request, request_accepted, …)
 * @param {string} title  - Titre court affiché en gras
 * @param {string} body   - Texte explicatif
 * @param {object} data   - Données optionnelles (event_id, etc.)
 */
function createNotification(db, userId, type, title, body, data = {}) {
  try {
    db.prepare(`
      INSERT INTO notifications (user_id, type, title, body, data)
      VALUES (?, ?, ?, ?, ?)
    `).run(userId, type, title, body, JSON.stringify(data));
  } catch (err) {
    console.error('createNotification error:', err.message);
  }
}

module.exports = { createNotification };
