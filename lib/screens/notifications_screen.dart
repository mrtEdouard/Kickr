import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

const _kLime   = Color(0xFFAAFF00);
const _kBg     = Color(0xFF0D0D16);
const _kCard   = Color(0xFF141420);
const _kGray   = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifs   = provider.notifications;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.markAllRead,
              child: const Text('Tout lire', style: TextStyle(color: _kLime, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              color: _kLime,
              backgroundColor: _kCard,
              onRefresh: provider.refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NotifCard(
                  notif: notifs[i],
                  onTap: () => provider.markRead(notifs[i].id),
                ),
              ),
            ),
    );
  }
}

// ─── Carte notification ───────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final NotificationItem notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  static const _icons = <String, IconData>{
    'join_request':        Icons.how_to_reg_rounded,
    'new_participant':     Icons.person_add_rounded,
    'request_accepted':    Icons.check_circle_rounded,
    'request_refused':     Icons.cancel_rounded,
    'kicked':              Icons.person_remove_rounded,
    'composition_updated': Icons.groups_rounded,
  };

  static const _colors = <String, Color>{
    'join_request':        Colors.orange,
    'new_participant':     Color(0xFF3B82F6),
    'request_accepted':    Color(0xFFAAFF00),
    'request_refused':     Colors.redAccent,
    'kicked':              Colors.redAccent,
    'composition_updated': Color(0xFF3B82F6),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1)     return 'Hier';
    if (diff.inDays < 7)      return 'il y a ${diff.inDays} j';
    final months = ['jan','fév','mar','avr','mai','jun','jul','aoû','sep','oct','nov','déc'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[notif.type] ?? _kGray;
    final icon  = _icons[notif.type] ?? Icons.notifications_rounded;
    final unread = !notif.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? _kCard : _kBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread ? color.withValues(alpha: 0.3) : _kBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône colorée
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notif.createdAt),
                        style: const TextStyle(color: _kGray, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      color: unread ? const Color(0xFFCCCCCC) : _kGray,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Point de non-lecture
            if (unread)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _kCard,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: _kGray, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Aucune notification',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tu seras notifié des activités sur tes matchs.',
              style: TextStyle(color: _kGray, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
