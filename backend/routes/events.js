'use strict';
const express = require('express');
const { getDb } = require('../db/database');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();

// Créer un événement (connecté obligatoire)
router.post('/', requireAuth, (req, res) => {
  const { title, date, location, match_type, max_players, required_level, description, join_mode, is_public } = req.body ?? {};

  if (!title || !date || !location || !match_type || !max_players) {
    return res.status(400).json({ error: 'Tous les champs obligatoires doivent être remplis.' });
  }

  try {
    const db = getDb();
    const { lastInsertRowid } = db.prepare(`
      INSERT INTO events (title, creator_id, date, location, match_type, max_players, required_level, description, join_mode, is_public)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      title, req.userId, date, location, match_type, max_players,
      required_level ?? null, description ?? null, join_mode ?? 'open', is_public ?? 1
    );
    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(Number(lastInsertRowid));
    return res.status(201).json({ event });
  } catch (err) {
    console.error('create event error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// Lister les événements publics, les plus proches en date en premier
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const events = db.prepare('SELECT * FROM events WHERE is_public = 1 ORDER BY date ASC').all();
    return res.json({ events });
  } catch (err) {
    console.error('get events error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

module.exports = router;
