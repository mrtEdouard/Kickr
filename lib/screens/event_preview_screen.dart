import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../models/participant.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../services/event_service.dart';
import 'event_detail_screen.dart';

const _kLime   = Color(0xFFAAFF00);
const _kBg     = Color(0xFF0D0D16);
const _kCard   = Color(0xFF141420);
const _kGray   = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class EventPreviewScreen extends StatefulWidget {
  final Event event;
  const EventPreviewScreen({super.key, required this.event});

  @override
  State<EventPreviewScreen> createState() => _EventPreviewScreenState();
}

class _EventPreviewScreenState extends State<EventPreviewScreen> {
  List<Participant>? _participants;
  bool _loadingParticipants = false;
  bool _joiningLoading = false;
  bool _uploadingPhoto = false;
  // URL locale mise à jour après un upload sans recharger tout l'event
  String? _localImageUrl;

  @override
  void initState() {
    super.initState();
    _localImageUrl = widget.event.imageUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadParticipants());
  }

  Future<void> _loadParticipants() async {
    if (!context.read<AuthProvider>().isLoggedIn) return;
    setState(() => _loadingParticipants = true);
    try {
      final p = await EventService().getParticipants(widget.event.id);
      if (mounted) setState(() => _participants = p);
    } catch (_) {
      if (mounted) setState(() => _participants = []);
    } finally {
      if (mounted) setState(() => _loadingParticipants = false);
    }
  }

  Future<void> _join() async {
    setState(() => _joiningLoading = true);
    final message = await context.read<EventProvider>().joinEvent(widget.event.id);
    if (!mounted) return;
    setState(() => _joiningLoading = false);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: _kLime.withValues(alpha: 0.9)),
      );
      _loadParticipants();
    } else {
      final err = context.read<EventProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Erreur'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await EventService().uploadEventImage(widget.event.id, File(picked.path));
      if (mounted) setState(() => _localImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _enterWorkspace() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: widget.event)),
      );

  bool get _isOrganizer {
    final id = context.read<AuthProvider>().user?.id;
    return id != null && widget.event.creatorId == id;
  }

  bool get _isParticipant {
    final id = context.read<AuthProvider>().user?.id;
    if (id == null) return false;
    if (context.read<EventProvider>().joinedIds.contains(widget.event.id)) return true;
    return _participants?.any((p) => p.id == id) ?? false;
  }

  bool get _isFull =>
      widget.event.status == 'full' ||
      widget.event.participantsCount >= widget.event.maxPlayers;

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
      const days   = ['lundi','mardi','mercredi','jeudi','vendredi','samedi','dimanche'];
      final time = '${dt.hour.toString().padLeft(2,'0')}h${dt.minute.toString().padLeft(2,'0')}';
      return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} à $time';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Bannière hero ──────────────────────────────────────
          _HeroBanner(
            imageUrl: _localImageUrl,
            matchType: widget.event.matchType,
            isOrganizer: _isOrganizer,
            uploading: _uploadingPhoto,
            onBack: () => Navigator.pop(context),
            onPickPhoto: _pickPhoto,
          ),

          // ── Contenu scrollable ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte titre chevauchant la bannière
                  _TitleCard(event: widget.event),
                  const SizedBox(height: 14),

                  // Infos générales
                  _InfoCard(
                    dateLabel: _formatDate(widget.event.date),
                    event: widget.event,
                  ),
                  const SizedBox(height: 14),

                  // Barre de joueurs
                  _PlayersCard(event: widget.event),

                  // Description
                  if ((widget.event.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _DescriptionCard(description: widget.event.description!),
                  ],
                  const SizedBox(height: 14),

                  // Participants
                  _ParticipantsCard(
                    isLoggedIn: isLoggedIn,
                    participants: _participants,
                    loading: _loadingParticipants,
                    totalSlots: widget.event.maxPlayers,
                  ),
                ],
              ),
            ),
          ),

          // ── CTA bas de page ────────────────────────────────────
          _BottomCta(
            isLoggedIn: isLoggedIn,
            isOrganizer: _isOrganizer,
            isParticipant: _isParticipant,
            isFull: _isFull,
            isValidation: widget.event.joinMode == 'validation',
            joiningLoading: _joiningLoading,
            onJoin: _join,
            onEnter: _enterWorkspace,
            onLogin: () => context.go('/login'),
          ),
        ],
      ),
    );
  }
}

// ─── Bannière hero ────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String? imageUrl;
  final String matchType;
  final bool isOrganizer;
  final bool uploading;
  final VoidCallback onBack;
  final VoidCallback onPickPhoto;

  const _HeroBanner({
    required this.imageUrl,
    required this.matchType,
    required this.isOrganizer,
    required this.uploading,
    required this.onBack,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fond : photo ou dégradé
          if (imageUrl != null)
            Image.network(
              'http://localhost:3000$imageUrl',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _BannerPlaceholder(),
            )
          else
            const _BannerPlaceholder(),

          // Dégradé bas pour lisibilité
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000), Color(0xFF0D0D16)],
                stops: [0.35, 0.72, 1.0],
              ),
            ),
          ),

          // Controls flottants
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bouton retour
                  _BannerBtn(
                    onTap: onBack,
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
                  ),
                  Row(
                    children: [
                      // Bouton photo organisateur
                      if (isOrganizer)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _BannerBtn(
                            onTap: onPickPhoto,
                            child: uploading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      // Badge type de match
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kLime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          matchType,
                          style: const TextStyle(color: _kBg, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C2010), Color(0xFF071008), Color(0xFF0D0D16)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_rounded,
          color: _kLime.withValues(alpha: 0.12),
          size: 110,
        ),
      ),
    );
  }
}

class _BannerBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _BannerBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: child),
    ),
  );
}

// ─── Titre (chevauchant la bannière via margin négative) ──────────────────────

class _TitleCard extends StatelessWidget {
  final Event event;
  const _TitleCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _kGray),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: const TextStyle(color: _kGray, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Infos générales ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String dateLabel;
  final Event event;
  const _InfoCard({required this.dateLabel, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _Row(Icons.calendar_today_rounded, dateLabel),
          const _Divider(),
          _Row(Icons.sports_soccer_rounded, 'Organisé par ${event.creatorPseudo ?? '?'}'),
          if (event.requiredLevel != null) ...[
            const _Divider(),
            _Row(Icons.bar_chart_rounded, 'Niveau ${event.requiredLevel}'),
          ],
          if (!event.isPublic) ...[
            const _Divider(),
            _Row(Icons.lock_rounded, 'Événement privé', color: Colors.orange),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Row(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: color ?? _kLime),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(color: color ?? Colors.white, fontSize: 14))),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, color: _kBorder),
  );
}

// ─── Barre joueurs ────────────────────────────────────────────────────────────

class _PlayersCard extends StatelessWidget {
  final Event event;
  const _PlayersCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final ratio = event.maxPlayers > 0
        ? (event.participantsCount / event.maxPlayers).clamp(0.0, 1.0)
        : 0.0;
    final remaining = event.maxPlayers - event.participantsCount;
    final barColor  = ratio >= 1.0 ? Colors.redAccent : _kLime;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Joueurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${event.participantsCount}',
                      style: TextStyle(color: barColor, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    TextSpan(
                      text: ' / ${event.maxPlayers}',
                      style: const TextStyle(color: _kGray, fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFF2A2A3A),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                ratio >= 1.0 ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                size: 14,
                color: ratio >= 1.0 ? Colors.redAccent : _kGray,
              ),
              const SizedBox(width: 6),
              Text(
                ratio >= 1.0
                    ? 'Match complet — plus de places disponibles'
                    : '$remaining place${remaining > 1 ? 's' : ''} restante${remaining > 1 ? 's' : ''}',
                style: TextStyle(
                  color: ratio >= 1.0 ? Colors.redAccent : _kGray,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Description ──────────────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        Text(description, style: const TextStyle(color: _kGray, fontSize: 14, height: 1.6)),
      ],
    ),
  );
}

// ─── Participants ─────────────────────────────────────────────────────────────

class _ParticipantsCard extends StatelessWidget {
  final bool isLoggedIn;
  final List<Participant>? participants;
  final bool loading;
  final int totalSlots;
  const _ParticipantsCard({
    required this.isLoggedIn,
    required this.participants,
    required this.loading,
    required this.totalSlots,
  });

  String _posLabel(String? p) => switch (p) {
    'goalkeeper' => 'Gardien',
    'defender'   => 'Défenseur',
    'midfielder' => 'Milieu',
    'forward'    => 'Attaquant',
    _            => 'Tous postes',
  };

  String _footLabel(String? f) => switch (f) {
    'left'  => '🦶 Gauche',
    'right' => '🦶 Droite',
    'both'  => '🦶 Les deux',
    _       => '',
  };

  @override
  Widget build(BuildContext context) {
    final count = participants?.length;
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Text('Participants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count / $totalSlots', style: const TextStyle(color: _kLime, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          if (!isLoggedIn)
            Row(children: [
              const Icon(Icons.lock_outline_rounded, color: _kGray, size: 18),
              const SizedBox(width: 10),
              const Text('Connecte-toi pour voir les participants', style: TextStyle(color: _kGray, fontSize: 14)),
            ])
          else if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(color: _kLime, strokeWidth: 2),
            ))
          else ...[
            if (participants == null || participants!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun participant pour l\'instant.', style: TextStyle(color: _kGray, fontSize: 14)),
              )
            else
              for (final p in participants!)
                _ParticipantRow(
                  participant: p,
                  posLabel: _posLabel(p.position),
                  footLabel: _footLabel(p.preferredFoot),
                ),
            for (int i = (participants?.length ?? 0); i < totalSlots; i++)
              _EmptySlot(i + 1),
          ],
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final Participant participant;
  final String posLabel;
  final String footLabel;
  const _ParticipantRow({required this.participant, required this.posLabel, required this.footLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A3A),
              border: Border.all(color: _kBorder),
            ),
            child: participant.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      'http://localhost:3000${participant.avatarUrl}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Initial(participant.pseudo),
                    ),
                  )
                : _Initial(participant.pseudo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.pseudo,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  [posLabel, if (footLabel.isNotEmpty) footLabel].join('  ·  '),
                  style: const TextStyle(color: _kGray, fontSize: 12),
                ),
              ],
            ),
          ),
          if (participant.status == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text('En attente', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String pseudo;
  const _Initial(this.pseudo);
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      pseudo.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: _kLime, fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptySlot extends StatelessWidget {
  final int index;
  const _EmptySlot(this.index);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF141420),
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.person_add_alt_rounded, color: _kBorder, size: 20),
        ),
        const SizedBox(width: 12),
        const Text('Place libre', style: TextStyle(color: _kBorder, fontSize: 14, fontStyle: FontStyle.italic)),
      ],
    ),
  );
}

// ─── CTA sticky ───────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final bool isLoggedIn;
  final bool isOrganizer;
  final bool isParticipant;
  final bool isFull;
  final bool isValidation;
  final bool joiningLoading;
  final VoidCallback onJoin;
  final VoidCallback onEnter;
  final VoidCallback onLogin;

  const _BottomCta({
    required this.isLoggedIn,
    required this.isOrganizer,
    required this.isParticipant,
    required this.isFull,
    required this.isValidation,
    required this.joiningLoading,
    required this.onJoin,
    required this.onEnter,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      decoration: const BoxDecoration(
        color: _kBg,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: _buildBtn(),
    );
  }

  Widget _buildBtn() {
    if (!isLoggedIn) {
      return _Btn(
        label: 'Connexion pour rejoindre',
        bg: _kCard, fg: Colors.white, border: _kBorder,
        icon: Icons.login_rounded, onTap: onLogin,
      );
    }
    if (isOrganizer || isParticipant) {
      return _Btn(
        label: "Accéder à l'espace équipe",
        bg: _kLime, fg: _kBg,
        icon: Icons.arrow_forward_rounded, onTap: onEnter,
      );
    }
    if (isFull) {
      return const _Btn(label: 'Match complet', bg: Color(0xFF1A1A2A), fg: _kGray, disabled: true);
    }
    if (isValidation) {
      return _Btn(
        label: 'Demander à rejoindre',
        bg: _kCard, fg: Colors.orange, border: Colors.orange,
        icon: Icons.how_to_reg_rounded,
        loading: joiningLoading, onTap: onJoin,
      );
    }
    return _Btn(
      label: 'Rejoindre le match',
      bg: _kLime, fg: _kBg,
      icon: Icons.sports_soccer_rounded,
      loading: joiningLoading, onTap: onJoin,
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;
  final bool loading;
  final bool disabled;
  final VoidCallback? onTap;

  const _Btn({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    this.icon,
    this.loading = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (disabled || loading) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: disabled ? bg.withValues(alpha: 0.6) : bg,
          borderRadius: BorderRadius.circular(28),
          border: border != null ? Border.all(color: border!, width: 1.5) : null,
        ),
        child: loading
            ? Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: fg, strokeWidth: 2.5)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: disabled ? fg.withValues(alpha: 0.5) : fg, size: 19),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: disabled ? fg.withValues(alpha: 0.5) : fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
