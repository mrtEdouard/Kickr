import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kPill = Color(0xFF1A1A2A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Charge les events dès que l'écran s'affiche
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final eventProvider = context.watch<EventProvider>();
    final pseudo = auth.user?.pseudo ?? 'toi';

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kLime,
        backgroundColor: _kCard,
        onRefresh: () => context.read<EventProvider>().loadEvents(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                'Salut $pseudo 👋',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text("Prêt pour un match aujourd'hui ?", style: TextStyle(color: _kGray, fontSize: 15)),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _LocationPill()),
                  const SizedBox(width: 10),
                  _FilterPill(),
                ],
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Matchs autour de toi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${eventProvider.events.length} match${eventProvider.events.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: _kGray, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),

              // États de chargement / erreur / liste
              if (eventProvider.loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _kLime),
                ))
              else if (eventProvider.error != null)
                _ErrorState(message: eventProvider.error!, onRetry: () => context.read<EventProvider>().loadEvents())
              else if (eventProvider.events.isEmpty)
                const _EmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventProvider.events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _MatchCard(event: eventProvider.events[i]),
                ),

              const SizedBox(height: 24),
            ],
          ),
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

class _MatchCard extends StatelessWidget {
  final Event event;
  const _MatchCard({required this.event});

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(dt.year, dt.month, dt.day);
      final diff = eventDay.difference(today).inDays;
      final time = '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return "Aujourd'hui • $time";
      if (diff == 1) return 'Demain • $time';
      return '${dt.day} ${months[dt.month - 1]} • $time';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelLabel = event.requiredLevel != null ? 'Niveau ${event.requiredLevel}' : 'Niveau ouvert';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=600&q=75',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF091A07)),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Container(color: _kBg),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(event.matchType),
                    const SizedBox(width: 8),
                    Text(_formatDate(event.date), style: const TextStyle(color: _kGray, fontSize: 13)),
                    const Spacer(),
                    if (event.joinMode == 'validation')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: const Text('Sur validation', style: TextStyle(color: Colors.orange, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: _kGray),
                    const SizedBox(width: 3),
                    Text(event.location, style: const TextStyle(color: _kGray, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${event.participantsCount} / ${event.maxPlayers} joueurs',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(levelLabel, style: const TextStyle(color: _kGray, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _AvatarStack(count: event.participantsCount.clamp(0, 5), extra: 0),
                    const Spacer(),
                    _JoinButton(event: event),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.sports_soccer_rounded, color: _kGray, size: 48),
            SizedBox(height: 16),
            Text('Aucun match disponible', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Sois le premier à en créer un !', style: TextStyle(color: _kGray, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _kGray, size: 40),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: _kGray, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: const Text('Réessayer', style: TextStyle(color: _kLime, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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

class _JoinButton extends StatefulWidget {
  final Event event;
  const _JoinButton({required this.event});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour rejoindre un match.')),
      );
      return;
    }

    setState(() => _loading = true);
    final message = await context.read<EventProvider>().joinEvent(widget.event.id);
    if (!mounted) return;
    setState(() => _loading = false);

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: _kLime.withValues(alpha: 0.9)),
      );
    } else {
      final error = context.read<EventProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Erreur'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = context.watch<EventProvider>().joinedIds.contains(widget.event.id);
    final isFull = widget.event.status == 'full';
    final isValidation = widget.event.joinMode == 'validation';

    final label = joined
        ? 'Inscrit ✓'
        : isFull
            ? 'Complet'
            : isValidation
                ? 'Demander'
                : 'Rejoindre';

    final color = joined ? _kGray : isFull ? const Color(0xFF2A2A3A) : _kLime;
    final textColor = joined || isFull ? Colors.white54 : const Color(0xFF0D0D16);

    return GestureDetector(
      onTap: (joined || isFull || _loading) ? null : _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
        child: _loading
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: Color(0xFF0D0D16), strokeWidth: 2),
              )
            : Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
