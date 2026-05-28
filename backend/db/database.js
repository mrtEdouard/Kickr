'use strict';
const { DatabaseSync } = require('node:sqlite');
const path = require('path');

const DB_PATH = path.join(__dirname, '..', 'kickr.db');
let db;

function initDb() {
  db = new DatabaseSync(DB_PATH);
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      pseudo         TEXT    NOT NULL UNIQUE,
      email          TEXT    NOT NULL UNIQUE,
      password_hash  TEXT    NOT NULL,
      -- Profil (rempli après inscription)
      first_name     TEXT,
      last_name      TEXT,
      avatar_url     TEXT,
      city           TEXT,
      position       TEXT,    -- 'goalkeeper' | 'defender' | 'midfielder' | 'forward'
      level          TEXT,    -- 'beginner' | 'intermediate' | 'confirmed'
      preferred_foot TEXT,    -- 'left' | 'right' | 'both'
      bio            TEXT,
      nationality    TEXT,
      -- Stats (mises à jour après chaque match)
      matches_played INTEGER NOT NULL DEFAULT 0,
      average_rating REAL    NOT NULL DEFAULT 0,
      presence_rate  REAL    NOT NULL DEFAULT 100,
      created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS events (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      title          TEXT    NOT NULL,
      type           TEXT    NOT NULL DEFAULT 'match',      -- 'match' | 'tournament'
      creator_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      date           TEXT    NOT NULL,
      location       TEXT    NOT NULL,
      latitude       REAL,
      longitude      REAL,
      match_type     TEXT    NOT NULL DEFAULT '5v5',        -- '5v5' | '7v7' | '11v11'
      max_players    INTEGER NOT NULL DEFAULT 10,
      required_level TEXT,                                  -- null = tous niveaux acceptés
      description    TEXT,
      join_mode      TEXT    NOT NULL DEFAULT 'open',       -- 'open' | 'validation'
      is_public      INTEGER NOT NULL DEFAULT 1,            -- 1 = public, 0 = privé
      invite_code    TEXT    UNIQUE,                        -- null si public
      status         TEXT    NOT NULL DEFAULT 'open',       -- 'open' | 'full' | 'done' | 'cancelled'
      created_at     TEXT    NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS event_participants (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id   INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status     TEXT    NOT NULL DEFAULT 'confirmed',      -- 'confirmed' | 'pending' | 'refused'
      joined_at  TEXT    NOT NULL DEFAULT (datetime('now')),
      UNIQUE(event_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS ratings (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id       INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      rater_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      rated_user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      game_level     INTEGER,   -- note 1-5
      fair_play      INTEGER,   -- note 1-5
      was_present    INTEGER    NOT NULL DEFAULT 1,         -- 1 = présent, 0 = absent
      created_at     TEXT       NOT NULL DEFAULT (datetime('now')),
      UNIQUE(event_id, rater_id, rated_user_id)
    );

    CREATE TABLE IF NOT EXISTS event_compositions (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      team     INTEGER NOT NULL CHECK(team IN (1, 2)),
      UNIQUE(event_id, user_id)
    );
  `);
  db.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type       TEXT    NOT NULL,
      title      TEXT    NOT NULL,
      body       TEXT    NOT NULL,
      data       TEXT    NOT NULL DEFAULT '{}',
      is_read    INTEGER NOT NULL DEFAULT 0,
      created_at TEXT    NOT NULL DEFAULT (datetime('now'))
    );
    CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, is_read);
  `);

  try { db.exec('ALTER TABLE users ADD COLUMN nationality TEXT'); } catch (_) {}
  try { db.exec('ALTER TABLE events ADD COLUMN image_url TEXT'); } catch (_) {}

  console.log('Database initialized at', DB_PATH);
}

function getDb() {
  return db;
}

module.exports = { initDb, getDb };
