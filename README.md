# Kickr ⚽

Application mobile-first pour organiser et rejoindre des matchs de football entre particuliers. Trouver un match, s'inscrire, composer les équipes et communiquer — tout en un seul endroit.

---

## Stack technique

| Couche | Technologie |
|---|---|
| Frontend | Flutter (Dart) — iOS, Android, Web |
| Backend | Node.js + Express |
| Base de données | SQLite (fichier `backend/kickr.db`) |
| Authentification | JWT (JSON Web Token) |
| Images | Multer — stockage local dans `backend/uploads/` |

---

## Structure du projet

```
Kickr/
├── backend/                        Serveur Node.js / Express
│   ├── server.js                   Point d'entrée — monte les routes
│   ├── kickr.db                    Base de données SQLite (créée au 1er lancement)
│   ├── db/
│   │   └── database.js             Initialisation des tables, migrations
│   ├── routes/
│   │   ├── auth.js                 Inscription, connexion, profil
│   │   ├── events.js               Événements, participants, composition, chat
│   │   └── notifications.js        Lecture et marquage des notifications
│   ├── middleware/
│   │   └── authMiddleware.js       Vérification JWT
│   ├── utils/
│   │   └── notifications.js        Helper createNotification()
│   └── uploads/
│       ├── avatars/                Photos de profil
│       └── events/                 Photos de couverture des événements
│
└── lib/                            Application Flutter
    ├── main.dart                   Point d'entrée, ThemeData, GoRouter
    ├── models/                     Objets métier
    │   ├── event.dart
    │   ├── participant.dart
    │   ├── pending_request.dart
    │   ├── message.dart
    │   └── notification_item.dart
    ├── services/                   Appels HTTP vers l'API
    │   ├── auth_service.dart
    │   ├── event_service.dart
    │   ├── chat_service.dart
    │   └── notification_service.dart
    ├── providers/                  État global (ChangeNotifier)
    │   ├── auth_provider.dart
    │   ├── event_provider.dart
    │   └── notification_provider.dart
    └── screens/                    Écrans de l'application
        ├── splash_screen.dart
        ├── onboarding_screen.dart
        ├── home_screen.dart
        ├── explore_screen.dart
        ├── create_match_screen.dart
        ├── my_matches_screen.dart
        ├── profile_screen.dart
        ├── event_preview_screen.dart
        ├── event_detail_screen.dart
        ├── login_screen.dart
        ├── register_screen.dart
        └── notifications_screen.dart
```

---

## Base de données

Toutes les tables sont créées automatiquement au démarrage via `initDb()`. Aucune migration manuelle requise.

| Table | Description |
|---|---|
| `users` | Comptes utilisateurs, profil (pseudo, ville, poste, pied…), stats |
| `events` | Matchs créés (titre, date, lieu, type, mode d'accès, statut) |
| `event_participants` | Inscriptions : `confirmed`, `pending`, `refused` |
| `event_compositions` | Assignation des joueurs en équipe 1 ou 2 |
| `messages` | Messages du chat, isolés par événement |
| `notifications` | Notifications en base, avec flag `is_read` |

---

## Installation et lancement

### Prérequis

- Node.js ≥ 18
- Flutter ≥ 3.0
- Dart ≥ 3.0

### Backend

```bash
cd backend
npm install
npm run dev          # nodemon — rechargement automatique
# ou
node server.js       # lancement simple
```

Le serveur démarre sur **`http://localhost:3000`**.  
La base de données `kickr.db` est créée automatiquement à la racine du dossier `backend/`.

### Frontend Flutter

```bash
flutter pub get
flutter run          # émulateur / navigateur
```

> L'application pointe par défaut sur `http://localhost:3000`.  
> Pour un déploiement, remplacer `_base = 'http://localhost:3000'` dans chaque service.

---

## API REST

### Authentification — `/auth`

| Méthode | Route | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | Non | Créer un compte |
| POST | `/auth/login` | Non | Connexion, retourne un token JWT |
| GET | `/auth/me` | Oui | Profil de l'utilisateur connecté |

### Événements — `/events`

| Méthode | Route | Auth | Description |
|---|---|---|---|
| GET | `/events` | Non | Liste des matchs publics à venir |
| POST | `/events` | Oui | Créer un événement |
| GET | `/events/mine` | Oui | Mes matchs (créés + rejoints) |
| GET | `/events/:id` | Non | Détail d'un événement |
| POST | `/events/:id/join` | Oui | Rejoindre un événement |
| GET | `/events/:id/participants` | Oui | Participants confirmés |
| DELETE | `/events/:id/participants/:userId` | Oui (orga) | Retirer un participant |
| GET | `/events/:id/requests` | Oui (orga) | Demandes en attente |
| PATCH | `/events/:id/requests/:userId` | Oui (orga) | Accepter ou refuser une demande |
| GET | `/events/:id/composition` | Oui | Composition des équipes |
| PUT | `/events/:id/composition` | Oui (orga) | Sauvegarder la composition manuelle |
| POST | `/events/:id/composition/random` | Oui (orga) | Tirage au sort |
| POST | `/events/:id/image` | Oui (orga) | Uploader une photo de couverture |
| GET | `/events/:id/messages` | Oui (participant) | Messages du chat |
| POST | `/events/:id/messages` | Oui (participant) | Envoyer un message |

### Notifications — `/notifications`

| Méthode | Route | Auth | Description |
|---|---|---|---|
| GET | `/notifications` | Oui | 60 dernières notifications |
| GET | `/notifications/unread-count` | Oui | Nombre de non lues (badge) |
| PATCH | `/notifications/:id/read` | Oui | Marquer une notif comme lue |
| PATCH | `/notifications/read-all` | Oui | Tout marquer comme lu |

---

## Fonctionnalités

### Parcours public (non connecté)
- Consulter les matchs disponibles (accueil + explorateur)
- Rechercher un match par titre, lieu ou type
- Voir la preview d'un événement (infos, places restantes, mode d'accès)

### Parcours connecté
- Créer un événement avec photo de couverture
- Rejoindre un match en accès libre ou envoyer une demande (mode validation)
- Accéder à l'espace équipe une fois participant

### Espace équipe (participants)
- Compte à rebours jusqu'au match
- Composition des équipes (tirage au sort ou assignation manuelle)
- Chat interne isolé par événement

### Outils organisateur
- Voir et traiter les demandes en attente avec profil complet du demandeur
- Retirer un participant (libère une place)
- Modifier la composition des équipes

### Notifications automatiques
| Déclencheur | Destinataire |
|---|---|
| Quelqu'un rejoint (accès libre) | Organisateur |
| Quelqu'un envoie une demande | Organisateur |
| Demande acceptée | Demandeur |
| Demande refusée | Demandeur |
| Joueur retiré | Joueur retiré |
| Composition mise à jour | Tous les participants |

---

## Sécurité

- Les routes protégées vérifient le token JWT via `authMiddleware.js`
- Certaines routes vérifient en plus que l'utilisateur est **organisateur** de l'événement
- Le chat vérifie que l'utilisateur est **participant confirmé** — impossible de lire/écrire dans le chat d'un autre événement
- En production : remplacer `kickr_secret_change_in_production` par un secret fort dans la variable d'environnement `JWT_SECRET`

---

## Variables d'environnement

| Variable | Défaut | Description |
|---|---|---|
| `PORT` | `3000` | Port du serveur Express |
| `JWT_SECRET` | `kickr_secret_change_in_production` | Clé de signature JWT — **à changer en prod** |

---

## Branches git

| Branche | Contenu |
|---|---|
| `main` | Base stable de l'application |
| `feat/explorer` | Écran Explorer avec recherche en temps réel |
| `feat/event-preview` | Page de preview publique entre la liste et l'espace équipe |
| `notification` | Système de notifications complet |

---

## Auteur

Edouard Mouret — Projet CDA (Concepteur Développeur d'Applications)
