import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/event.dart';
import '../models/participant.dart';
import '../services/event_service.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);
const _kTeam1 = Color(0xFF3B82F6);
const _kTeam2 = Color(0xFFF97316);
const _base = 'http://localhost:3000';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _service = EventService();
  List<Participant> _participants = [];
  Map<int, int> _composition = {};
  Map<int, int> _draft = {};
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getParticipants(widget.event.id),
        _service.getComposition(widget.event.id),
      ]);
      setState(() {
        _participants = results[0] as List<Participant>;
        _composition = results[1] as Map<int, int>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int get _teamSize {
    final m = RegExp(r'^(\d+)v\d+$').firstMatch(widget.event.matchType);
    return m != null ? int.parse(m.group(1)!) : 5;
  }

  Future<void> _randomize() async {
    setState(() => _saving = true);
    try {
      final comp = await _service.randomizeComposition(widget.event.id);
      setState(() {
        _composition = comp;
        _draft = Map.from(comp);
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveComposition(widget.event.id, _draft);
      setState(() {
        _composition = Map.from(_draft);
        _editMode = false;
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _enterEdit() => setState(() {
        _draft = Map.from(_composition);
        _editMode = true;
      });

  void _cancelEdit() => setState(() {
        _editMode = false;
        _draft = {};
      });

  void _showAssignSheet(Participant p) {
    final currentTeam = (_editMode ? _draft : _composition)[p.id];
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignSheet(
        participant: p,
        currentTeam: currentTeam,
        onAssign: (team) {
          setState(() {
            if (team == null) {
              _draft.remove(p.id);
            } else {
              _draft[p.id] = team;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final isOrganizer = currentUserId == widget.event.creatorId;
    final active = _editMode ? _draft : _composition;

    final team1 = _participants.where((p) => active[p.id] == 1).toList();
    final team2 = _participants.where((p) => active[p.id] == 2).toList();
    final unassigned = _participants.where((p) => !active.containsKey(p.id)).toList();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(widget.event.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(6)),
            child: Text(widget.event.matchType,
                style: const TextStyle(color: Color(0xFF0D0D16), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kLime))
          : RefreshIndicator(
              color: _kLime,
              backgroundColor: _kCard,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EventHeader(event: widget.event),
                    const SizedBox(height: 16),
                    _Countdown(dateRaw: widget.event.date),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Text('Composition',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (isOrganizer) ...[
                          const Spacer(),
                          _OrganizerControls(
                            editMode: _editMode,
                            saving: _saving,
                            onRandomize: _randomize,
                            onEdit: _enterEdit,
                            onSave: _save,
                            onCancel: _cancelEdit,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _TeamColumn(
                            teamNum: 1,
                            players: team1,
                            teamSize: _teamSize,
                            editMode: _editMode,
                            onTap: _editMode ? _showAssignSheet : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TeamColumn(
                            teamNum: 2,
                            players: team2,
                            teamSize: _teamSize,
                            editMode: _editMode,
                            onTap: _editMode ? _showAssignSheet : null,
                          ),
                        ),
                      ],
                    ),

                    if (unassigned.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _editMode ? 'Non assignés — appuie pour placer' : 'Non assignés',
                        style: const TextStyle(color: _kGray, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: unassigned
                            .map((p) => _PlayerChip(
                                  participant: p,
                                  editMode: _editMode,
                                  onTap: _editMode ? () => _showAssignSheet(p) : null,
                                ))
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 24),
                    _ChatPlaceholder(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Countdown ───────────────────────────────────────────────────────────────

class _Countdown extends StatefulWidget {
  final String dateRaw;
  const _Countdown({required this.dateRaw});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _isPast = false;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _update() {
    final target = DateTime.tryParse(widget.dateRaw.replaceFirst(' ', 'T'));
    if (target == null) return;
    final diff = target.difference(DateTime.now());
    setState(() {
      _isPast = diff.isNegative;
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPast) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: const Center(
          child: Text('Match en cours ou terminé',
              style: TextStyle(color: _kGray, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );
    }

    final months = _remaining.inDays ~/ 30;
    final days = _remaining.inDays % 30;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CountUnit(value: months, label: 'MOIS'),
          _Divider(),
          _CountUnit(value: days, label: 'JOURS'),
          _Divider(),
          _CountUnit(value: hours, label: 'HEURES'),
          _Divider(),
          _CountUnit(value: minutes, label: 'MIN'),
          _Divider(),
          _CountUnit(value: seconds, label: 'SEC'),
        ],
      ),
    );
  }
}

class _CountUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: _kLime,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: _kGray, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(':', style: TextStyle(color: _kGray, fontSize: 20, fontWeight: FontWeight.w300));
  }
}

// ─── Event header ───────────────────────────────────────────────────────────

class _EventHeader extends StatelessWidget {
  final Event event;
  const _EventHeader({required this.event});

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
    return Container(
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
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(_formatDate(event.date), style: const TextStyle(color: _kGray, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: _kGray),
              const SizedBox(width: 4),
              Expanded(
                child: Text(event.location, style: const TextStyle(color: _kGray, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.group_rounded, size: 14, color: _kGray),
              const SizedBox(width: 4),
              Text('${event.participantsCount} / ${event.maxPlayers} joueurs',
                  style: const TextStyle(color: _kGray, fontSize: 13)),
            ],
          ),
          if (event.creatorPseudo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('⚽ ', style: TextStyle(fontSize: 12)),
                Text('Organisé par ${event.creatorPseudo}',
                    style: const TextStyle(color: _kGray, fontSize: 13)),
              ],
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: _kBorder, height: 1),
            const SizedBox(height: 10),
            Text(event.description!, style: const TextStyle(color: _kGray, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ─── Organizer controls ──────────────────────────────────────────────────────

class _OrganizerControls extends StatelessWidget {
  final bool editMode;
  final bool saving;
  final VoidCallback onRandomize;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _OrganizerControls({
    required this.editMode,
    required this.saving,
    required this.onRandomize,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (editMode) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: saving ? null : onCancel,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('Annuler', style: TextStyle(color: _kGray, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: saving ? null : onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(20)),
              child: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D0D16)))
                  : const Text('Enregistrer',
                      style: TextStyle(
                          color: Color(0xFF0D0D16), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: saving ? null : onRandomize,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kLime))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎲', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text('Tirer au sort', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('Modifier', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Team column ─────────────────────────────────────────────────────────────

class _TeamColumn extends StatelessWidget {
  final int teamNum;
  final List<Participant> players;
  final int teamSize;
  final bool editMode;
  final void Function(Participant)? onTap;

  const _TeamColumn({
    required this.teamNum,
    required this.players,
    required this.teamSize,
    required this.editMode,
    this.onTap,
  });

  Color get _color => teamNum == 1 ? _kTeam1 : _kTeam2;
  String get _label => teamNum == 1 ? 'Équipe 1' : 'Équipe 2';

  @override
  Widget build(BuildContext context) {
    final emptySlots = (teamSize - players.length).clamp(0, teamSize);
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Center(
              child: Text(
                '$_label  ${players.length}/$teamSize',
                style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ...players.map((p) => _PlayerTile(
                participant: p,
                editMode: editMode,
                onTap: onTap != null ? () => onTap!(p) : null,
              )),
          ...List.generate(emptySlots, (_) => _EmptySlot(color: _color)),
        ],
      ),
    );
  }
}

// ─── Player tile ─────────────────────────────────────────────────────────────

class _PlayerTile extends StatelessWidget {
  final Participant participant;
  final bool editMode;
  final VoidCallback? onTap;

  const _PlayerTile({required this.participant, required this.editMode, this.onTap});

  String _posLabel(String p) {
    switch (p) {
      case 'goalkeeper': return 'Gardien';
      case 'defender': return 'Défenseur';
      case 'midfielder': return 'Milieu';
      case 'forward': return 'Attaquant';
      default: return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            _MiniAvatar(participant: participant),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.pseudo,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (participant.position != null)
                    Text(_posLabel(participant.position!),
                        style: const TextStyle(color: _kGray, fontSize: 10)),
                ],
              ),
            ),
            if (editMode) const Icon(Icons.swap_horiz_rounded, size: 14, color: _kGray),
          ],
        ),
      ),
    );
  }
}

// ─── Empty slot ───────────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  final Color color;
  const _EmptySlot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
              color: color.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 7),
          Text('Libre', style: TextStyle(color: color.withValues(alpha: 0.35), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Mini avatar ─────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final Participant participant;
  const _MiniAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final url = participant.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          '$_base$url',
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A40)),
        child: Center(
          child: Text(
            participant.pseudo.isNotEmpty ? participant.pseudo[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

// ─── Player chip (unassigned) ─────────────────────────────────────────────────

class _PlayerChip extends StatelessWidget {
  final Participant participant;
  final bool editMode;
  final VoidCallback? onTap;

  const _PlayerChip({required this.participant, required this.editMode, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: editMode ? _kLime.withValues(alpha: 0.4) : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniAvatar(participant: participant),
            const SizedBox(width: 6),
            Text(participant.pseudo,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            if (editMode) ...[
              const SizedBox(width: 4),
              const Icon(Icons.add_circle_outline_rounded, size: 14, color: _kLime),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Assign bottom sheet ──────────────────────────────────────────────────────

class _AssignSheet extends StatelessWidget {
  final Participant participant;
  final int? currentTeam;
  final void Function(int? team) onAssign;

  const _AssignSheet({
    required this.participant,
    this.currentTeam,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(participant.pseudo,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SheetOption(
            label: 'Équipe 1',
            color: _kTeam1,
            selected: currentTeam == 1,
            onTap: () => onAssign(1),
          ),
          const SizedBox(height: 8),
          _SheetOption(
            label: 'Équipe 2',
            color: _kTeam2,
            selected: currentTeam == 2,
            onTap: () => onAssign(2),
          ),
          if (currentTeam != null) ...[
            const SizedBox(height: 8),
            _SheetOption(
              label: 'Retirer',
              color: _kGray,
              selected: false,
              onTap: () => onAssign(null),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : _kBorder),
        ),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.white, fontWeight: FontWeight.w600)),
            if (selected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Chat placeholder ─────────────────────────────────────────────────────────

class _ChatPlaceholder extends StatelessWidget {
  const _ChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: _kLime, size: 18),
              SizedBox(width: 8),
              Text('Chat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Column(
              children: [
                Icon(Icons.lock_outline_rounded, color: _kGray, size: 32),
                SizedBox(height: 8),
                Text('À venir',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Le chat sera disponible prochainement.',
                    style: TextStyle(color: _kGray, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
