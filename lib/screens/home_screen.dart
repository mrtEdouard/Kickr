import 'package:flutter/material.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kPill = Color(0xFF1A1A2A);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Salutation
            const Text(
              'Salut Edouard 👋',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Prêt pour un match aujourd'hui ?",
              style: TextStyle(color: _kGray, fontSize: 15),
            ),

            const SizedBox(height: 20),

            // Barre localisation + filtres
            Row(
              children: [
                Expanded(child: _LocationPill()),
                const SizedBox(width: 10),
                _FilterPill(),
              ],
            ),

            const SizedBox(height: 28),

            // En-tête de section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Matchs autour de toi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      color: _kLime,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Liste des matchs (données fictives pour la maquette)
            _MatchCard(
              type: '5v5',
              date: "Aujourd'hui • 20:00",
              distance: '1.2 km',
              title: 'Five du soir',
              location: 'Parc Montcalm',
              players: 7,
              maxPlayers: 10,
              level: 'Niveau intermédiaire',
              extraPlayers: 3,
            ),
            const SizedBox(height: 14),
            _MatchCard(
              type: '7v7',
              date: 'Demain • 18:30',
              distance: '2.4 km',
              title: 'Match détente',
              location: 'Stade Grammont',
              players: 9,
              maxPlayers: 14,
              level: 'Niveau ouvert',
              extraPlayers: 6,
            ),
            const SizedBox(height: 14),
            _MatchCard(
              type: '5v5',
              date: 'Vendredi • 21:00',
              distance: '1.8 km',
              title: 'Foot entre potes',
              location: 'City Sport',
              players: 6,
              maxPlayers: 10,
              level: 'Niveau intermédiaire',
              extraPlayers: 2,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Pill de localisation avec dropdown
class _LocationPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kPill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on_rounded, color: _kLime, size: 16),
          SizedBox(width: 6),
          Text(
            'Autour de moi • Montpellier',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded, color: _kLime, size: 20),
        ],
      ),
    );
  }
}

// Pill filtres
class _FilterPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kPill,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.tune_rounded, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text('Filtres', style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

// Carte d'un match
class _MatchCard extends StatelessWidget {
  final String type;
  final String date;
  final String distance;
  final String title;
  final String location;
  final int players;
  final int maxPlayers;
  final String level;
  final int extraPlayers;

  const _MatchCard({
    required this.type,
    required this.date,
    required this.distance,
    required this.title,
    required this.location,
    required this.players,
    required this.maxPlayers,
    required this.level,
    required this.extraPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Image de stade en fond, alignée à droite pour laisser la place au texte
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=600&q=75',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              // Fallback sombre si l'image ne charge pas
              errorBuilder: (ctx, obj, err) => Container(color: const Color(0xFF091A07)),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(color: const Color(0xFF0D0D16));
              },
            ),
          ),

          // Fondu de gauche à droite pour garantir la lisibilité du texte
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kCard, _kCard, Colors.transparent],
                  stops: [0.0, 0.4, 0.78],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),

          // Contenu de la carte
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : badge type, date, distance
                Row(
                  children: [
                    _TypeBadge(type),
                    const SizedBox(width: 8),
                    Text(date, style: const TextStyle(color: _kGray, fontSize: 13)),
                    const Spacer(),
                    _DistancePill(distance),
                  ],
                ),

                const SizedBox(height: 10),

                // Titre du match
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                // Lieu
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: _kGray),
                    const SizedBox(width: 3),
                    Text(location, style: const TextStyle(color: _kGray, fontSize: 13)),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  '$players / $maxPlayers joueurs',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(level, style: const TextStyle(color: _kGray, fontSize: 13)),

                const SizedBox(height: 14),

                // Avatars joueurs + bouton rejoindre
                Row(
                  children: [
                    _AvatarStack(count: 5, extra: extraPlayers),
                    const Spacer(),
                    _JoinButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Badge du type de match (5v5, 7v7, 11v11)
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kLime,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Color(0xFF0D0D16),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Pill de distance en haut à droite de la carte
class _DistancePill extends StatelessWidget {
  final String distance;
  const _DistancePill(this.distance);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        distance,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Pile d'avatars des joueurs avec un "+N" à la fin
class _AvatarStack extends StatelessWidget {
  final int count;
  final int extra;

  const _AvatarStack({required this.count, required this.extra});

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const step = 20.0; // chevauchement entre chaque avatar

    return SizedBox(
      height: size,
      width: count * step + size,
      child: Stack(
        children: [
          // Les avatars des joueurs
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * step,
              child: _Avatar(),
            ),
          // Le "+N" pour les joueurs non affichés
          Positioned(
            left: count * step,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kCard, width: 2),
                color: const Color(0xFF2A2A40),
              ),
              child: Center(
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kCard, width: 2),
        color: const Color(0xFF2A2A40),
      ),
      child: const Icon(Icons.person, size: 15, color: Colors.white54),
    );
  }
}

// Bouton "Rejoindre"
class _JoinButton extends StatelessWidget {
  const _JoinButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _kLime,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Rejoindre',
        style: TextStyle(
          color: Color(0xFF0D0D16),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
