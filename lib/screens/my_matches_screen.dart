import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import 'event_detail_screen.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<EventProvider>().loadMyEvents();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mes matchs', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Matchs créés et rejoints.', style: TextStyle(color: _kGray, fontSize: 15)),
                  const SizedBox(height: 20),
                  TabBar(
                    controller: _tabs,
                    indicatorColor: _kLime,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: _kLime,
                    unselectedLabelColor: _kGray,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: [
                      Tab(text: 'Créés (${provider.myCreated.length})'),
                      Tab(text: 'Rejoints (${provider.myJoined.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator(color: _kLime))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _EventList(events: provider.myCreated, emptyMessage: 'Tu n\'as pas encore créé de match.'),
                        _EventList(events: provider.myJoined, emptyMessage: 'Tu n\'as rejoint aucun match pour l\'instant.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<Event> events;
  final String emptyMessage;
  const _EventList({required this.events, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer_rounded, color: _kGray, size: 44),
            const SizedBox(height: 14),
            Text(emptyMessage, style: const TextStyle(color: _kGray, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _kLime,
      backgroundColor: _kCard,
      onRefresh: () => context.read<EventProvider>().loadMyEvents(),
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _MyEventCard(event: events[i]),
      ),
    );
  }
}

class _MyEventCard extends StatelessWidget {
  final Event event;
  const _MyEventCard({required this.event});

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      return '${dt.day} ${months[dt.month - 1]} • ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Color get _statusColor {
    switch (event.status) {
      case 'full': return Colors.orange;
      case 'done': return _kGray;
      case 'cancelled': return Colors.redAccent;
      default: return _kLime;
    }
  }

  String get _statusLabel {
    switch (event.status) {
      case 'open': return 'Ouvert';
      case 'full': return 'Complet';
      case 'done': return 'Terminé';
      case 'cancelled': return 'Annulé';
      default: return event.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(6)),
                child: Text(event.matchType,
                    style: const TextStyle(color: Color(0xFF0D0D16), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(_formatDate(event.date), style: const TextStyle(color: _kGray, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _kGray),
              const SizedBox(width: 4),
              Text(event.location, style: const TextStyle(color: _kGray, fontSize: 13)),
              const Spacer(),
              const Icon(Icons.group_rounded, size: 13, color: _kGray),
              const SizedBox(width: 4),
              Text('${event.participantsCount}/${event.maxPlayers}',
                  style: const TextStyle(color: _kGray, fontSize: 13)),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
