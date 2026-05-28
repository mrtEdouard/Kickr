import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

const _kLime   = Color(0xFFAAFF00);
const _kBg     = Color(0xFF0D0D16);
const _kCard   = Color(0xFF141420);
const _kGray   = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Event> _filter(List<Event> events) {
    if (_query.isEmpty) return events;
    final q = _query.toLowerCase();
    return events.where((e) =>
      e.title.toLowerCase().contains(q) ||
      e.location.toLowerCase().contains(q) ||
      e.matchType.toLowerCase().contains(q) ||
      (e.creatorPseudo?.toLowerCase().contains(q) ?? false),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events  = context.watch<EventProvider>().events;
    final results = _filter(events);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: const Text(
                'Explorer',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),

            // Champ de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Titre, lieu, type de match...',
                  prefixIcon: const Icon(Icons.search_rounded, color: _kGray, size: 22),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: _kGray, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Compteur de résultats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _query.isEmpty
                    ? '${events.length} match${events.length > 1 ? 's' : ''} disponibles'
                    : '${results.length} résultat${results.length != 1 ? 's' : ''} pour "$_query"',
                style: const TextStyle(color: _kGray, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Liste
            Expanded(
              child: results.isEmpty && _query.isNotEmpty
                  ? _NoResults(query: _query)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: _query.isEmpty ? events.length : results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final event = _query.isEmpty ? events[i] : results[i];
                        return _EventTile(event: event, query: _query);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Event event;
  final String query;
  const _EventTile({required this.event, required this.query});

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      final now = DateTime.now();
      final diff = DateTime(dt.year, dt.month, dt.day).difference(DateTime(now.year, now.month, now.day)).inDays;
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
    return GestureDetector(
      onTap: () {
        if (!context.read<AuthProvider>().isLoggedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connecte-toi pour voir les détails du match.')),
          );
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // Badge type
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kLime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  event.matchType,
                  style: const TextStyle(
                    color: _kLime,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: _kGray),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(color: _kGray, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: _kGray),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(event.date),
                        style: const TextStyle(color: _kGray, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Joueurs
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${event.participantsCount}/${event.maxPlayers}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text('joueurs', style: TextStyle(color: _kGray, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, color: _kGray, size: 48),
          const SizedBox(height: 16),
          const Text('Aucun résultat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Aucun match ne correspond à "$query"',
            style: const TextStyle(color: _kGray, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
