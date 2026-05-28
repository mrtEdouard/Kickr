'use strict';
const express = require('express');
const multer  = require('multer');
const path    = require('path');
const fs      = require('fs');
const { getDb } = require('../db/database');
const { requireAuth } = require('../middleware/authMiddleware');
const { createNotification } = require('../utils/notifications');

const uploadsDir = path.join(__dirname, '..', 'uploads', 'events');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadsDir),
    filename: (req, _file, cb) => cb(null, `event-${req.params.id}-${Date.now()}.jpg`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => cb(null, file.mimetype.startsWith('image/')),
});

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
      WHERE e.is_public = 1 AND e.date >= datetime('now')
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

    const joiner = db.prepare('SELECT pseudo FROM users WHERE id = ?').get(req.userId);
    if (status === 'pending') {
      createNotification(db, event.creator_id, 'join_request',
        'Demande de participation',
        `${joiner.pseudo} souhaite rejoindre "${event.title}"`,
        { event_id: eventId, event_title: event.title, requester_id: req.userId });
    } else {
      createNotification(db, event.creator_id, 'new_participant',
        'Nouveau participant',
        `${joiner.pseudo} a rejoint "${event.title}"`,
        { event_id: eventId, event_title: event.title });
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

/**
 * GET /events/:id/participants
 * Retourne la liste des participants confirmés d'un événement,
 * avec leurs informations de profil (pseudo, avatar, poste, pied préféré).
 * Les participants sont triés par date d'inscription croissante.
 * Authentification requise (token JWT).
 */
router.get('/:id/participants', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const participants = db.prepare(`
      SELECT u.id, u.pseudo, u.avatar_url, u.position, u.preferred_foot, ep.status
      FROM event_participants ep
      JOIN users u ON ep.user_id = u.id
      WHERE ep.event_id = ? AND ep.status = 'confirmed'
      ORDER BY ep.joined_at ASC
    `).all(Number(req.params.id));
    return res.json({ participants });
  } catch (err) {
    console.error('get participants error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * GET /events/:id/composition
 * Retourne la composition actuelle de l'événement sous la forme :
 * { composition: { "userId": equipe, ... } }
 * où equipe vaut 1 (Équipe 1) ou 2 (Équipe 2).
 * Les clés sont des strings car JSON ne supporte pas les clés entières.
 * Authentification requise (token JWT).
 */
router.get('/:id/composition', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const rows = db.prepare('SELECT user_id, team FROM event_compositions WHERE event_id = ?')
      .all(Number(req.params.id));
    // Conversion tableau → objet { userId: equipe }
    const composition = {};
    for (const row of rows) composition[row.user_id] = row.team;
    return res.json({ composition });
  } catch (err) {
    console.error('get composition error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * PUT /events/:id/composition
 * Sauvegarde la composition manuelle définie par l'organisateur.
 * Corps attendu : { assignments: { "userId": equipe, ... } }
 * Stratégie : suppression complète puis réinsertion (plus simple qu'un UPSERT
 * quand tous les assignments sont envoyés d'un coup).
 * Réservé à l'organisateur — retourne 403 sinon.
 */
router.put('/:id/composition', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId = Number(req.params.id);
    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    // Seul l'organisateur peut modifier la composition
    if (event.creator_id !== req.userId) {
      return res.status(403).json({ error: 'Seul l\'organisateur peut modifier la composition.' });
    }
    const { assignments } = req.body ?? {};
    if (!assignments || typeof assignments !== 'object') {
      return res.status(400).json({ error: 'assignments requis.' });
    }
    // Suppression de l'ancienne composition avant réinsertion
    db.prepare('DELETE FROM event_compositions WHERE event_id = ?').run(eventId);
    const insert = db.prepare('INSERT INTO event_compositions (event_id, user_id, team) VALUES (?, ?, ?)');
    for (const [userId, team] of Object.entries(assignments)) {
      if (team === 1 || team === 2) insert.run(eventId, Number(userId), team);
    }
    // Notifie les participants (hors organisateur) que la compo a changé
    const participants = db.prepare(
      "SELECT user_id FROM event_participants WHERE event_id = ? AND status = 'confirmed' AND user_id != ?"
    ).all(eventId, req.userId);
    for (const p of participants) {
      createNotification(db, p.user_id, 'composition_updated',
        'Composition mise à jour',
        `L'organisateur a défini les équipes pour "${event.title}"`,
        { event_id: eventId, event_title: event.title });
    }
    return res.json({ ok: true });
  } catch (err) {
    console.error('save composition error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * POST /events/:id/composition/random
 * Génère une composition aléatoire en répartissant les participants confirmés
 * en deux équipes équilibrées selon la taille déduite du match_type.
 * Exemple : '7v7' → teamSize = 7 → joueurs 0..6 → Équipe 1, joueurs 7..13 → Équipe 2.
 * Algorithme : Fisher-Yates shuffle sur le tableau des user_id.
 * Retourne la nouvelle composition : { composition: { "userId": equipe, ... } }
 * Réservé à l'organisateur — retourne 403 sinon.
 */
router.post('/:id/composition/random', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId = Number(req.params.id);
    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.creator_id !== req.userId) {
      return res.status(403).json({ error: 'Seul l\'organisateur peut modifier la composition.' });
    }

    // Récupération des participants confirmés
    const participants = db.prepare(
      "SELECT user_id FROM event_participants WHERE event_id = ? AND status = 'confirmed'"
    ).all(eventId);

    // Fisher-Yates shuffle : mélange aléatoire impartial du tableau
    const ids = participants.map(p => p.user_id);
    for (let i = ids.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [ids[i], ids[j]] = [ids[j], ids[i]];
    }

    // Extraction de la taille d'équipe depuis le match_type (ex: '5v5' → 5)
    const m = event.match_type.match(/^(\d+)v\d+$/);
    const teamSize = m ? parseInt(m[1]) : 5;

    // Réinsertion avec assignation : les teamSize premiers → équipe 1, le reste → équipe 2
    db.prepare('DELETE FROM event_compositions WHERE event_id = ?').run(eventId);
    const insert = db.prepare('INSERT INTO event_compositions (event_id, user_id, team) VALUES (?, ?, ?)');
    const composition = {};
    for (let i = 0; i < ids.length; i++) {
      const team = i < teamSize ? 1 : 2;
      insert.run(eventId, ids[i], team);
      composition[ids[i]] = team;
    }
    // Notifie les participants (hors organisateur) du tirage au sort
    for (const id of ids) {
      if (id !== req.userId) {
        createNotification(db, id, 'composition_updated',
          'Équipes tirées au sort 🎲',
          `Les équipes ont été mélangées pour "${event.title}"`,
          { event_id: eventId, event_title: event.title });
      }
    }
    return res.json({ composition });
  } catch (err) {
    console.error('random composition error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * POST /events/:id/image
 * Upload ou remplacement de la photo de couverture de l'événement.
 * Réservé à l'organisateur. Champ multipart : "image".
 */
router.post('/:id/image', requireAuth, upload.single('image'), (req, res) => {
  try {
    const db = getDb();
    const eventId = Number(req.params.id);
    const event = db.prepare('SELECT creator_id, image_url FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.creator_id !== req.userId) return res.status(403).json({ error: 'Non autorisé.' });
    if (!req.file) return res.status(400).json({ error: 'Aucune image fournie.' });

    // Supprime l'ancienne image si elle existe
    if (event.image_url) {
      const old = path.join(__dirname, '..', event.image_url.replace(/^\//, ''));
      if (fs.existsSync(old)) fs.unlinkSync(old);
    }

    const imageUrl = `/uploads/events/${req.file.filename}`;
    db.prepare('UPDATE events SET image_url = ? WHERE id = ?').run(imageUrl, eventId);
    return res.json({ image_url: imageUrl });
  } catch (err) {
    console.error('upload event image error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * DELETE /events/:id/participants/:userId
 * Retire un participant confirmé de l'événement (organisateur uniquement).
 * Remet le statut de l'événement à 'open' s'il était 'full'.
 */
router.delete('/:id/participants/:userId', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId      = Number(req.params.id);
    const targetUserId = Number(req.params.userId);

    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.creator_id !== req.userId) return res.status(403).json({ error: 'Non autorisé.' });
    if (event.creator_id === targetUserId) return res.status(400).json({ error: 'Impossible de retirer l\'organisateur.' });

    const participant = db.prepare(
      "SELECT id FROM event_participants WHERE event_id = ? AND user_id = ? AND status = 'confirmed'"
    ).get(eventId, targetUserId);
    if (!participant) return res.status(404).json({ error: 'Participant introuvable.' });

    db.prepare('DELETE FROM event_participants WHERE event_id = ? AND user_id = ?').run(eventId, targetUserId);
    db.prepare('DELETE FROM event_compositions WHERE event_id = ? AND user_id = ?').run(eventId, targetUserId);

    // Remet l'événement à 'open' si il était complet
    if (event.status === 'full') {
      db.prepare("UPDATE events SET status = 'open' WHERE id = ?").run(eventId);
    }

    createNotification(db, targetUserId, 'kicked',
      'Retiré de l\'événement',
      `Tu as été retiré de "${event.title}" par l'organisateur.`,
      { event_id: eventId, event_title: event.title });

    return res.json({ message: 'Participant retiré.' });
  } catch (err) {
    console.error('remove participant error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * GET /events/:id/requests
 * Retourne les demandes de participation en attente avec le profil complet du demandeur.
 * Réservé à l'organisateur.
 */
router.get('/:id/requests', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId = Number(req.params.id);
    const event = db.prepare('SELECT creator_id FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.creator_id !== req.userId) return res.status(403).json({ error: 'Non autorisé.' });

    const requests = db.prepare(`
      SELECT u.id as user_id, u.pseudo, u.avatar_url, u.position, u.preferred_foot,
             u.level, u.city, u.bio, u.matches_played, u.average_rating, u.presence_rate,
             ep.joined_at
      FROM event_participants ep
      JOIN users u ON ep.user_id = u.id
      WHERE ep.event_id = ? AND ep.status = 'pending'
      ORDER BY ep.joined_at ASC
    `).all(eventId);
    return res.json({ requests });
  } catch (err) {
    console.error('get requests error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

/**
 * PATCH /events/:id/requests/:userId
 * Accepte ou refuse une demande de participation.
 * Corps attendu : { action: 'accept' | 'reject' }
 * Réservé à l'organisateur.
 */
router.patch('/:id/requests/:userId', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const eventId      = Number(req.params.id);
    const targetUserId = Number(req.params.userId);
    const { action }   = req.body ?? {};

    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Action invalide.' });
    }
    const event = db.prepare('SELECT * FROM events WHERE id = ?').get(eventId);
    if (!event) return res.status(404).json({ error: 'Événement introuvable.' });
    if (event.creator_id !== req.userId) return res.status(403).json({ error: 'Non autorisé.' });

    const pending = db.prepare(
      "SELECT id FROM event_participants WHERE event_id = ? AND user_id = ? AND status = 'pending'"
    ).get(eventId, targetUserId);
    if (!pending) return res.status(404).json({ error: 'Demande introuvable.' });

    if (action === 'accept') {
      const { count } = db.prepare(
        "SELECT COUNT(*) as count FROM event_participants WHERE event_id = ? AND status = 'confirmed'"
      ).get(eventId);
      if (count >= event.max_players) return res.status(400).json({ error: 'Le match est complet.' });

      db.prepare("UPDATE event_participants SET status = 'confirmed' WHERE event_id = ? AND user_id = ?")
        .run(eventId, targetUserId);
      if (count + 1 >= event.max_players) {
        db.prepare("UPDATE events SET status = 'full' WHERE id = ?").run(eventId);
      }
      createNotification(db, targetUserId, 'request_accepted',
        'Demande acceptée ✓',
        `Tu as été accepté dans "${event.title}" !`,
        { event_id: eventId, event_title: event.title });
      return res.json({ message: 'Demande acceptée.' });
    } else {
      db.prepare("UPDATE event_participants SET status = 'refused' WHERE event_id = ? AND user_id = ?")
        .run(eventId, targetUserId);
      createNotification(db, targetUserId, 'request_refused',
        'Demande refusée',
        `Ta demande pour "${event.title}" n'a pas été acceptée.`,
        { event_id: eventId, event_title: event.title });
      return res.json({ message: 'Demande refusée.' });
    }
  } catch (err) {
    console.error('respond request error:', err);
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
