'use strict';
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { getDb } = require('../db/database');
const { requireAuth } = require('../middleware/authMiddleware');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'kickr_secret_change_in_production';
const SALT_ROUNDS = 12;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PSEUDO_RE = /^[a-zA-Z0-9_-]+$/;

// POST /auth/register
router.post('/register', async (req, res) => {
  const { pseudo, email, password, confirmPassword } = req.body ?? {};

  if (!pseudo || !email || !password || !confirmPassword) {
    return res.status(400).json({ error: 'Tous les champs sont requis.' });
  }
  if (typeof pseudo !== 'string' || pseudo.length < 3 || pseudo.length > 30) {
    return res.status(400).json({ error: 'Le pseudo doit contenir entre 3 et 30 caractères.' });
  }
  if (!PSEUDO_RE.test(pseudo)) {
    return res.status(400).json({ error: 'Le pseudo ne peut contenir que des lettres, chiffres, _ et -.' });
  }
  if (!EMAIL_RE.test(email)) {
    return res.status(400).json({ error: 'Adresse email invalide.' });
  }
  if (typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ error: 'Le mot de passe doit contenir au moins 8 caractères.' });
  }
  if (password !== confirmPassword) {
    return res.status(400).json({ error: 'Les mots de passe ne correspondent pas.' });
  }

  try {
    const db = getDb();
    const existing = db.prepare('SELECT id FROM users WHERE email = ? OR pseudo = ?')
      .get(email.toLowerCase(), pseudo);
    if (existing) {
      return res.status(409).json({ error: 'Cet email ou ce pseudo est déjà utilisé.' });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const { lastInsertRowid } = db.prepare(
      'INSERT INTO users (pseudo, email, password_hash) VALUES (?, ?, ?)'
    ).run(pseudo, email.toLowerCase(), passwordHash);

    const token = jwt.sign({ userId: lastInsertRowid }, JWT_SECRET, { expiresIn: '7d' });
    return res.status(201).json({
      token,
      user: { id: Number(lastInsertRowid), pseudo, email: email.toLowerCase() },
    });
  } catch (err) {
    console.error('register error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue. Réessayez.' });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body ?? {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email et mot de passe requis.' });
  }

  try {
    const db = getDb();
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email.toLowerCase());
    if (!user) {
      return res.status(401).json({ error: 'Identifiants incorrects.' });
    }
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({ error: 'Identifiants incorrects.' });
    }
    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });
    return res.json({
      token,
      user: { id: user.id, pseudo: user.pseudo, email: user.email },
    });
  } catch (err) {
    console.error('login error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue. Réessayez.' });
  }
});

// GET /auth/me
router.get('/me', requireAuth, (req, res) => {
  try {
    const db = getDb();
    const user = db.prepare('SELECT id, pseudo, email, created_at FROM users WHERE id = ?')
      .get(req.userId);
    if (!user) return res.status(404).json({ error: 'Utilisateur introuvable.' });
    return res.json({ user });
  } catch (err) {
    console.error('me error:', err);
    return res.status(500).json({ error: 'Une erreur est survenue.' });
  }
});

// POST /auth/logout 
router.post('/logout', requireAuth, (req, res) => {
  return res.json({ message: 'Déconnexion réussie.' });
});

module.exports = router;
