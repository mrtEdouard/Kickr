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
    const newId = Number(lastInsertRowid);
    // Le créateur est automatiquement inscrit comme participant confirmé
    db.prepare('INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)')
      .run(newId, req.userId, 'confirmed');
    const event = db.prepare(`
      SELECT e.*, COUNT(ep.id) as participants_count
      FROM events e
      LEFT JOIN event_participants ep ON e.id = ep.event_id AND ep.status = 'confirmed'
      WHERE e.id = ?
      GROUP BY e.id
    `).get(newId);
    return res.status(201).json({ event });
  } catch (err) {
    console.error('create event error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// Lister les événements publics avec le nombre de participants et le pseudo du créateur
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const events = db.prepare(`
      SELECT e.*, COUNT(ep.id) as participants_count, u.pseudo as creator_pseudo
      FROM events e
      LEFT JOIN event_participants ep ON e.id = ep.event_id AND ep.status = 'confirmed'
      LEFT JOIN users u ON e.creator_id = u.id
      WHERE e.is_public = 1
      GROUP BY e.id
      ORDER BY e.date ASC
    `).all();
    return res.json({ events });
  } catch (err) {
    console.error('get events error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// Mes matchs (créés + rejoints) — AVANT /:id pour éviter le conflit de route
router.get('/mine', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const created = db.prepare(`
      SELECT e.*, COUNT(ep.id) as participants_count
      FROM events e
      LEFT JOIN event_participants ep ON e.id = ep.event_id AND ep.status = 'confirmed'
      WHERE e.creator_id = ?
      GROUP BY e.id
      ORDER BY e.date ASC
    `).all(req.userId);

    const joined = db.prepare(`
      SELECT e.*, COUNT(ep2.id) as participants_count, ep.status as my_status
      FROM events e
      INNER JOIN event_participants ep ON e.id = ep.event_id AND ep.user_id = ?
      LEFT JOIN event_participants ep2 ON e.id = ep2.event_id AND ep2.status = 'confirmed'
      WHERE e.creator_id != ?
      GROUP BY e.id
      ORDER BY e.date ASC
    `).all(req.userId, req.userId);

    return res.json({ created, joined });
  } catch (err) {
    console.error('mine events error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// Rejoindre un événement
router.post('/:id/join', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId = Number(req.params.id);

    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.status !== 'open') return res.status(400).json({ error: 'Ce match n\'est plus disponible.' });
    if (event.creator_id === req.userId) return res.status(400).json({ error: 'Tu es l\'organisateur de ce match.' });

    const existing = db.prepare('SELECT * FROM event_participants WHERE event_id = ? AND user_id = ?')
      .get(eventId, req.userId);
    if (existing) return res.status(409).json({ error: 'Tu participes déjà à ce match.' });

    const { count } = db.prepare(
      "SELECT COUNT(*) as count FROM event_participants WHERE event_id = ? AND status = 'confirmed'"
    ).get(eventId);

    if (event.join_mode === 'open' && count >= event.max_players) {
      return res.status(400).json({ error: 'Ce match est complet.' });
    }

    const status = event.join_mode === 'validation' ? 'pending' : 'confirmed';
    db.prepare('INSERT INTO event_participants (event_id, user_id, status) VALUES (?, ?, ?)')
      .run(eventId, req.userId, status);

    // Passe l'event en "full" si le dernier spot vient d'être pris
    if (status === 'confirmed' && count + 1 >= event.max_players) {
      db.prepare("UPDATE events SET status = 'full' WHERE id = ?").run(eventId);
    }

    const message = status === 'pending'
      ? 'Demande envoyée, en attente de validation.'
      : 'Tu as rejoint le match !';
    return res.json({ message, status });
  } catch (err) {
    console.error('join event error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// Détail d'un événement
router.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const event = db.prepare(`
      SELECT e.*, COUNT(ep.id) as participants_count
      FROM events e
      LEFT JOIN event_participants ep ON e.id = ep.event_id AND ep.status = 'confirmed'
      WHERE e.id = ?
      GROUP BY e.id
    `).get(Number(req.params.id));
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    return res.json({ event });
  } catch (err) {
    console.error('get event error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

module.exports = router;
