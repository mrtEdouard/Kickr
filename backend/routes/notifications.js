'use strict';
const express    = require('express');
const { getDb }  = require('../db/database');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

/** GET /notifications — Liste les 60 dernières notifs de l'utilisateur connecté */
router.get('/', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const rows = db.prepare(`
      SELECT id, type, title, body, data, is_read, created_at
      FROM notifications
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 60
    `).all(req.userId);

    const notifications = rows.map(r => ({
      ...r,
      data:    JSON.parse(r.data || '{}'),
      is_read: r.is_read === 1,
    }));
    return res.json({ notifications });
  } catch (err) {
    console.error('get notifications error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/** GET /notifications/unread-count — Compteur badge */
router.get('/unread-count', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const { count } = db.prepare(
      "SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0"
    ).get(req.userId);
    return res.json({ count });
  } catch (err) {
    console.error('unread count error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/** PATCH /notifications/:id/read — Marque une notif comme lue */
router.patch('/:id/read', requireAuth, (req, res) => {
  try {
    const db = getDb();
    db.prepare(
      "UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?"
    ).run(Number(req.params.id), req.userId);
    return res.json({ ok: true });
  } catch (err) {
    console.error('mark read error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/** PATCH /notifications/read-all — Marque toutes les notifs comme lues */
router.patch('/read-all', requireAuth, (req, res) => {
  try {
    const db = getDb();
    db.prepare(
      "UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0"
    ).run(req.userId);
    return res.json({ ok: true });
  } catch (err) {
    console.error('mark all read error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

module.exports = router;
