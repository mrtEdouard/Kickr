import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/event.dart';
import '../models/message.dart';
import '../models/participant.dart';
import '../models/pending_request.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';

// ─── Palette de couleurs partagée dans cet écran ─────────────────────────────
const _kLime   = Color(0xFFAAFF00); // couleur d'accent principale
const _kBg     = Color(0xFF0D0D16); // fond général
const _kCard   = Color(0xFF141420); // fond des cartes
const _kGray   = Color(0xFF8A8A9A); // textes secondaires
const _kBorder = Color(0xFF2A2A3A); // bordures
const _kTeam1  = Color(0xFF3B82F6); // couleur Équipe 1 (bleu)
const _kTeam2  = Color(0xFFF97316); // couleur Équipe 2 (orange)
const _base    = 'http://localhost:3000'; // URL de base de l'API

/// Écran de détail d'un événement.
/// Affiche : informations du match, countdown, composition des équipes et placeholder chat.
/// L'organisateur dispose de contrôles supplémentaires (tirage au sort, édition manuelle).
class EventDetailScreen extends StatefulWidget {
  /// L'événement à afficher, passé depuis la carte cliquée (HomeScreen ou MyMatchesScreen).
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _service = EventService();

  // ─── État de l'écran ───────────────────────────────────────────────────────
  List<Participant> _participants = []; // liste des joueurs confirmés
  Map<int, int> _composition = {};     // composition sauvegardée : userId → équipe (1 ou 2)
  Map<int, int> _draft = {};           // brouillon en cours d'édition (non encore sauvegardé)
  bool _loading = true;
  bool _saving  = false;
  bool _editMode = false;
  List<PendingRequest> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _load(); // chargement des participants et de la composition au démarrage
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final isOrg = context.read<AuthProvider>().user?.id == widget.event.creatorId;
      final futures = <Future>[
        _service.getParticipants(widget.event.id),
        _service.getComposition(widget.event.id),
        if (isOrg && widget.event.joinMode == 'validation')
          _service.getPendingRequests(widget.event.id),
      ];
      final results = await Future.wait(futures);
      setState(() {
        _participants     = results[0] as List<Participant>;
        _composition      = results[1] as Map<int, int>;
        _pendingRequests  = results.length > 2 ? results[2] as List<PendingRequest> : [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _respondToRequest(int userId, String action) async {
    try {
      await _service.respondToRequest(widget.event.id, userId, action);
      setState(() => _pendingRequests.removeWhere((r) => r.userId == userId));
      if (action == 'accept') {
        final updated = await _service.getParticipants(widget.event.id);
        if (mounted) setState(() => _participants = updated);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'accept' ? 'Demande acceptée ✓' : 'Demande refusée.'),
          backgroundColor: action == 'accept' ? _kLime.withValues(alpha: 0.9) : Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _confirmRemove(Participant p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Retirer le joueur', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          'Retirer ${p.pseudo} de l\'événement ? Sa place sera libérée.',
          style: const TextStyle(color: _kGray, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: _kGray)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _removeParticipant(p); },
            child: const Text('Retirer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeParticipant(Participant p) async {
    try {
      await _service.removeParticipant(widget.event.id, p.id);
      setState(() {
        _participants.removeWhere((x) => x.id == p.id);
        _composition.remove(p.id);
        _draft.remove(p.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${p.pseudo} a été retiré du match.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showRequestProfile(PendingRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RequestProfileSheet(
        request: req,
        onAccept: () { Navigator.pop(context); _respondToRequest(req.userId, 'accept'); },
        onReject: () { Navigator.pop(context); _respondToRequest(req.userId, 'reject'); },
      ),
    );
  }

  /// Déduit la taille d'une équipe depuis le match_type (ex: '7v7' → 7).
  /// Valeur de repli : 5 si le format ne correspond pas à l'expression régulière.
  int get _teamSize {
    final m = RegExp(r'^(\d+)v\d+$').firstMatch(widget.event.matchType);
    return m != null ? int.parse(m.group(1)!) : 5;
  }

  /// Déclenche le tirage au sort côté serveur.
  /// Met à jour [_composition] avec le résultat et synchronise [_draft].
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

  /// Sauvegarde le brouillon [_draft] en base via l'API,
  /// puis le promouvoit en composition officielle et quitte le mode édition.
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveComposition(widget.event.id, _draft);
      setState(() {
        _composition = Map.from(_draft);
        _editMode = false;
        _saving  = false;
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

  /// Entre en mode édition : copie la composition actuelle dans [_draft]
  /// pour que les modifications n'affectent pas la vue sauvegardée avant validation.
  void _enterEdit() => setState(() {
        _draft    = Map.from(_composition);
        _editMode = true;
      });

  /// Annule le mode édition sans sauvegarder ; vide [_draft].
  void _cancelEdit() => setState(() {
        _editMode = false;
        _draft    = {};
      });

  /// Affiche le bottom sheet d'assignation d'équipe pour le joueur [p].
  /// En mode édition, lit depuis [_draft] ; sinon depuis [_composition].
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
              _draft.remove(p.id); // retirer le joueur de toute équipe
            } else {
              _draft[p.id] = team; // assigner à l'équipe 1 ou 2
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
    // L'utilisateur est organisateur si son id correspond au créateur de l'événement
    final isOrganizer = currentUserId == widget.event.creatorId;
    // En mode édition on affiche le brouillon, sinon la composition sauvegardée
    final active = _editMode ? _draft : _composition;

    // Répartition des joueurs selon leur assignation dans la composition active
    final team1      = _participants.where((p) =>  active[p.id] == 1).toList();
    final team2      = _participants.where((p) =>  active[p.id] == 2).toList();
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
          // Badge du type de match (5v5, 7v7, 11v11) en haut à droite
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
              onRefresh: _load, // pull-to-refresh recharge participants + composition
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte récapitulative des infos du match
                    _EventHeader(event: widget.event, participantsCount: _participants.length),
                    const SizedBox(height: 16),

                    // Compte à rebours jusqu'à la date du match
                    _Countdown(dateRaw: widget.event.date),
                    const SizedBox(height: 24),

                    // Demandes en attente — visible uniquement par l'organisateur
                    if (isOrganizer && widget.event.joinMode == 'validation') ...[
                      _PendingSection(
                        requests: _pendingRequests,
                        onTap: _showRequestProfile,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // En-tête de section "Composition" + boutons organisateur
                    Row(
                      children: [
                        const Text('Composition',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (isOrganizer) ...[
                          const Spacer(),
                          // Boutons visibles uniquement pour l'organisateur
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

                    // Deux colonnes côte à côte : Équipe 1 et Équipe 2
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
                            onRemove: isOrganizer && !_editMode ? _confirmRemove : null,
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
                            onRemove: isOrganizer && !_editMode ? _confirmRemove : null,
                          ),
                        ),
                      ],
                    ),

                    // Section des joueurs non encore assignés à une équipe
                    if (unassigned.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _editMode ? 'Non assignés — appuie pour placer' : 'Non assignés',
                        style: const TextStyle(color: _kGray, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // Affichage en chips cliquables en mode édition
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
                    _ChatSection(
                      eventId: widget.event.id,
                      currentUserId: currentUserId ?? 0,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Countdown ───────────────────────────────────────────────────────────────

/// Widget affichant un compte à rebours en temps réel jusqu'à la date du match.
/// Se met à jour toutes les secondes via [Timer.periodic].
/// Affiche "Match en cours ou terminé" si la date est dépassée.
class _Countdown extends StatefulWidget {
  /// Date brute de l'événement au format 'YYYY-MM-DD HH:MM:SS' (format SQLite).
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
    _update(); // calcul immédiat pour éviter un affichage vide au premier rendu
    // Mise à jour toutes les secondes
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer.cancel(); // annulation obligatoire pour éviter les fuites mémoire
    super.dispose();
  }

  /// Recalcule la durée restante entre maintenant et la date cible.
  /// Le format SQLite ('YYYY-MM-DD HH:MM:SS') est converti en ISO 8601
  /// en remplaçant l'espace par 'T' pour que [DateTime.tryParse] le reconnaisse.
  void _update() {
    final target = DateTime.tryParse(widget.dateRaw.replaceFirst(' ', 'T'));
    if (target == null) return;
    final diff = target.difference(DateTime.now());
    setState(() {
      _isPast    = diff.isNegative;
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

    // Décomposition de la durée totale en unités d'affichage
    final months  = _remaining.inDays ~/ 30;
    final days    = _remaining.inDays % 30;
    final hours   = _remaining.inHours % 24;
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
          _CountUnit(value: months,  label: 'MOIS'),
          _Divider(),
          _CountUnit(value: days,    label: 'JOURS'),
          _Divider(),
          _CountUnit(value: hours,   label: 'HEURES'),
          _Divider(),
          _CountUnit(value: minutes, label: 'MIN'),
          _Divider(),
          _CountUnit(value: seconds, label: 'SEC'),
        ],
      ),
    );
  }
}

/// Une unité du countdown : valeur numérique + label (ex: "07 / JOURS").
/// [tabularFigures] maintient une largeur fixe pour chaque chiffre,
/// évitant que les éléments bougent latéralement à chaque mise à jour.
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
            style: const TextStyle(
                color: _kGray, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ],
    );
  }
}

/// Séparateur visuel ':' entre les unités du countdown.
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(':', style: TextStyle(color: _kGray, fontSize: 20, fontWeight: FontWeight.w300));
  }
}

// ─── Event header ───────────────────────────────────────────────────────────

/// Carte récapitulative des informations principales de l'événement :
/// statut, date formatée, lieu, nombre de joueurs, organisateur et description.
class _EventHeader extends StatelessWidget {
  final Event event;
  final int participantsCount;
  const _EventHeader({required this.event, required this.participantsCount});

  /// Formate la date brute SQLite en texte lisible.
  /// Cas spéciaux : "Aujourd'hui" et "Demain" pour les deux prochains jours.
  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      final now      = DateTime.now();
      final today    = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(dt.year, dt.month, dt.day);
      final diff     = eventDay.difference(today).inDays;
      final time     = '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return "Aujourd'hui • $time";
      if (diff == 1) return 'Demain • $time';
      return '${dt.day} ${months[dt.month - 1]} • $time';
    } catch (_) {
      return raw; // retourne la valeur brute en cas d'échec de parsing
    }
  }

  /// Couleur du badge de statut selon l'état de l'événement.
  Color get _statusColor {
    switch (event.status) {
      case 'full':      return Colors.orange;
      case 'done':      return _kGray;
      case 'cancelled': return Colors.redAccent;
      default:          return _kLime; // 'open'
    }
  }

  /// Libellé français du statut de l'événement.
  String get _statusLabel {
    switch (event.status) {
      case 'open':      return 'Ouvert';
      case 'full':      return 'Complet';
      case 'done':      return 'Terminé';
      case 'cancelled': return 'Annulé';
      default:          return event.status;
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
              // Badge coloré indiquant le statut du match
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
              Text('$participantsCount / ${event.maxPlayers} joueurs',
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
          // Description optionnelle séparée par un divider
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

/// Barre de contrôles visible uniquement par l'organisateur du match.
/// Deux états :
/// - Mode normal  → boutons "Tirer au sort" et "Modifier".
/// - Mode édition → boutons "Annuler" et "Enregistrer".
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
    // Mode édition actif : afficher Annuler + Enregistrer
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
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D0D16)))
                  : const Text('Enregistrer',
                      style: TextStyle(
                          color: Color(0xFF0D0D16), fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      );
    }

    // Mode normal : afficher Tirer au sort + Modifier
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
                    width: 14, height: 14,
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

/// Colonne représentant une équipe dans la composition.
/// Affiche les joueurs assignés puis des slots vides jusqu'à [teamSize].
/// En mode édition, chaque joueur est cliquable pour être réassigné.
class _TeamColumn extends StatelessWidget {
  final int teamNum;             // 1 ou 2
  final List<Participant> players; // joueurs déjà assignés à cette équipe
  final int teamSize;            // nombre de joueurs attendus par équipe
  final bool editMode;
  final void Function(Participant)? onTap;
  final void Function(Participant)? onRemove;

  const _TeamColumn({
    required this.teamNum,
    required this.players,
    required this.teamSize,
    required this.editMode,
    this.onTap,
    this.onRemove,
  });

  Color get _color => teamNum == 1 ? _kTeam1 : _kTeam2;
  String get _label => teamNum == 1 ? 'Équipe 1' : 'Équipe 2';

  @override
  Widget build(BuildContext context) {
    // Nombre de slots vides restants (clampé à 0 pour éviter les valeurs négatives)
    final emptySlots = (teamSize - players.length).clamp(0, teamSize);
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // En-tête coloré avec nom de l'équipe et compteur (ex: Équipe 1  3/5)
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
          // Joueurs assignés
          ...players.map((p) => _PlayerTile(
                participant: p,
                editMode: editMode,
                onTap: onTap != null ? () => onTap!(p) : null,
                onRemove: onRemove != null ? () => onRemove!(p) : null,
              )),
          // Slots libres jusqu'à la capacité maximale de l'équipe
          ...List.generate(emptySlots, (_) => _EmptySlot(color: _color)),
        ],
      ),
    );
  }
}

// ─── Player tile ─────────────────────────────────────────────────────────────

/// Tuile représentant un joueur dans une colonne d'équipe.
/// Affiche avatar miniature, pseudo et poste.
/// En mode édition, une icône d'échange est visible et la tuile est cliquable.
class _PlayerTile extends StatelessWidget {
  final Participant participant;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _PlayerTile({required this.participant, required this.editMode, this.onTap, this.onRemove});

  /// Convertit la valeur technique du poste en libellé français.
  String _posLabel(String p) {
    switch (p) {
      case 'goalkeeper': return 'Gardien';
      case 'defender':   return 'Défenseur';
      case 'midfielder': return 'Milieu';
      case 'forward':    return 'Attaquant';
      default:           return p;
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
            if (editMode)
              const Icon(Icons.swap_horiz_rounded, size: 14, color: _kGray)
            else if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.person_remove_rounded, size: 15, color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty slot ───────────────────────────────────────────────────────────────

/// Slot vide dans une colonne d'équipe, indiquant une place disponible.
/// La couleur est celle de l'équipe concernée (bleu ou orange).
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
            width: 28, height: 28,
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

/// Avatar circulaire 28×28 px d'un participant.
/// Affiche l'image réseau si disponible, sinon la première lettre du pseudo.
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
          width: 28, height: 28, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(), // fallback en cas d'erreur réseau
        ),
      );
    }
    return _initials();
  }

  /// Cercle avec l'initiale du pseudo en majuscule.
  Widget _initials() => Container(
        width: 28, height: 28,
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

/// Chip compact pour afficher un joueur non encore assigné à une équipe.
/// En mode édition, la bordure devient verte et une icône "+" est visible
/// pour indiquer que le joueur est cliquable et assignable.
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
          // Bordure verte en mode édition pour signaler l'interactivité
          border: Border.all(color: editMode ? _kLime.withValues(alpha: 0.4) : _kBorder),
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

/// Bottom sheet permettant à l'organisateur d'assigner un joueur à une équipe.
/// Propose : Équipe 1, Équipe 2, et "Retirer" si le joueur est déjà assigné.
class _AssignSheet extends StatelessWidget {
  final Participant participant;
  final int? currentTeam; // équipe actuelle du joueur (null si non assigné)
  final void Function(int? team) onAssign; // null = retirer de toute équipe

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
          // Nom du joueur en titre du sheet
          Text(participant.pseudo,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _SheetOption(label: 'Équipe 1', color: _kTeam1, selected: currentTeam == 1, onTap: () => onAssign(1)),
          const SizedBox(height: 8),
          _SheetOption(label: 'Équipe 2', color: _kTeam2, selected: currentTeam == 2, onTap: () => onAssign(2)),
          // Option "Retirer" uniquement si le joueur est déjà dans une équipe
          if (currentTeam != null) ...[
            const SizedBox(height: 8),
            _SheetOption(label: 'Retirer', color: _kGray, selected: false, onTap: () => onAssign(null)),
          ],
        ],
      ),
    );
  }
}

/// Option sélectionnable dans le bottom sheet d'assignation.
/// Affiche un point coloré, le libellé, et une coche si l'option est sélectionnée.
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
          // Fond légèrement coloré si l'option est sélectionnée
          color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF1A1A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : _kBorder),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: selected ? color : Colors.white, fontWeight: FontWeight.w600)),
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

// ─── Chat ─────────────────────────────────────────────────────────────────────

class _ChatSection extends StatefulWidget {
  final int eventId;
  final int currentUserId;
  const _ChatSection({required this.eventId, required this.currentUserId});

  @override
  State<_ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<_ChatSection> {
  final _service    = ChatService();
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Polling toutes les 5 secondes pour les nouveaux messages
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await _service.getMessages(widget.eventId);
      if (!mounted) return;
      setState(() { _messages = msgs; _loading = false; });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _poll() async {
    try {
      final msgs = await _service.getMessages(widget.eventId);
      if (!mounted) return;
      if (msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      final msg = await _service.sendMessage(widget.eventId, text);
      if (!mounted) return;
      setState(() { _messages.add(msg); _sending = false; });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() { _sending = false; _ctrl.text = text; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeLabel(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    final time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    if (diff.inDays == 0) return time;
    if (diff.inDays == 1) return 'Hier $time';
    return '${dt.day}/${dt.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: _kLime, size: 17),
                const SizedBox(width: 8),
                const Text('Chat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_messages.length} message${_messages.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: _kGray, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // ── Liste des messages ────────────────────────────────
          SizedBox(
            height: 320,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kLime, strokeWidth: 2))
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: _kBorder, size: 36),
                            SizedBox(height: 10),
                            Text('Aucun message pour l\'instant.',
                                style: TextStyle(color: _kGray, fontSize: 13)),
                            Text('Sois le premier à écrire !',
                                style: TextStyle(color: _kBorder, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg   = _messages[i];
                          final isMe  = msg.userId == widget.currentUserId;
                          final showHeader = i == 0 || _messages[i - 1].userId != msg.userId;
                          return _Bubble(
                            msg: msg,
                            isMe: isMe,
                            showHeader: showHeader,
                            timeLabel: _timeLabel(msg.createdAt),
                          );
                        },
                      ),
          ),

          // ── Saisie ────────────────────────────────────────────
          const Divider(height: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Envoie un message…',
                      hintStyle: const TextStyle(color: _kGray, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF0D0D16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _kLime, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _kLime,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(color: _kBg, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: _kBg, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final Message msg;
  final bool isMe;
  final bool showHeader;
  final String timeLabel;
  const _Bubble({required this.msg, required this.isMe, required this.showHeader, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        top: showHeader && !isMe ? 8 : 2,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Pseudo + avatar pour les autres (affiché une fois par groupe)
          if (!isMe && showHeader)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MsgAvatar(pseudo: msg.pseudo, avatarUrl: msg.avatarUrl, size: 20),
                  const SizedBox(width: 6),
                  Text(msg.pseudo,
                      style: const TextStyle(color: _kGray, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar gauche pour les autres (espace quand même si pas showHeader)
              if (!isMe) SizedBox(width: 26, child: showHeader ? null : null),

              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? _kLime : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe ? null : Border.all(color: _kBorder),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      color: isMe ? _kBg : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Horodatage
          Padding(
            padding: EdgeInsets.only(
              top: 3,
              left: isMe ? 0 : 30,
              right: 4,
            ),
            child: Text(timeLabel,
                style: const TextStyle(color: _kGray, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _MsgAvatar extends StatelessWidget {
  final String pseudo;
  final String? avatarUrl;
  final double size;
  const _MsgAvatar({required this.pseudo, this.avatarUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A2A3A),
        border: Border.all(color: _kBorder),
      ),
      child: avatarUrl != null
          ? ClipOval(child: Image.network('$_base$avatarUrl', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Initial(pseudo, size)))
          : _Initial(pseudo, size),
    );
  }
}

class _Initial extends StatelessWidget {
  final String pseudo;
  final double size;
  const _Initial(this.pseudo, this.size);
  @override
  Widget build(BuildContext context) => Center(
    child: Text(pseudo.substring(0, 1).toUpperCase(),
        style: TextStyle(color: _kLime, fontSize: size * 0.5, fontWeight: FontWeight.w800)),
  );
}

// ─── Demandes en attente ──────────────────────────────────────────────────────

class _PendingSection extends StatelessWidget {
  final List<PendingRequest> requests;
  final void Function(PendingRequest) onTap;
  const _PendingSection({required this.requests, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Demandes en attente',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            if (requests.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Text('${requests.length}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: const Text('Aucune demande en attente.',
                style: TextStyle(color: _kGray, fontSize: 14)),
          )
        else
          for (final req in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onTap(req),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A3A),
                          border: Border.all(color: _kBorder),
                        ),
                        child: req.avatarUrl != null
                            ? ClipOval(child: Image.network(
                                '$_base${req.avatarUrl}', fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _ReqInitial(req.pseudo)))
                            : _ReqInitial(req.pseudo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.pseudo,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (req.position != null) _posLabel(req.position),
                                if (req.city != null) req.city!,
                              ].join(' · '),
                              style: const TextStyle(color: _kGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Voir le profil',
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  static String _posLabel(String? p) => switch (p) {
    'goalkeeper' => 'Gardien',
    'defender'   => 'Défenseur',
    'midfielder' => 'Milieu',
    'forward'    => 'Attaquant',
    _            => 'Joueur',
  };
}

// ─── Bottom sheet profil du demandeur ────────────────────────────────────────

class _RequestProfileSheet extends StatelessWidget {
  final PendingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _RequestProfileSheet({required this.request, required this.onAccept, required this.onReject});

  String _posLabel(String? p) => switch (p) {
    'goalkeeper' => 'Gardien',  'defender' => 'Défenseur',
    'midfielder' => 'Milieu',   'forward'  => 'Attaquant',
    _ => 'Tous postes',
  };
  String _footLabel(String? f) => switch (f) {
    'left' => 'Gauche', 'right' => 'Droite', 'both' => 'Les deux', _ => '—',
  };
  String _levelLabel(String? l) => switch (l) {
    'beginner' => 'Débutant', 'intermediate' => 'Intermédiaire', 'confirmed' => 'Confirmé', _ => '—',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24,
          24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),

          // Avatar + nom + ville
          Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: const Color(0xFF2A2A3A),
                border: Border.all(color: _kLime, width: 2),
              ),
              child: request.avatarUrl != null
                  ? ClipOval(child: Image.network('$_base${request.avatarUrl}', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ReqInitial(request.pseudo, size: 24)))
                  : _ReqInitial(request.pseudo, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.pseudo,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                if (request.city != null)
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: _kGray),
                    const SizedBox(width: 3),
                    Text(request.city!, style: const TextStyle(color: _kGray, fontSize: 13)),
                  ]),
              ],
            )),
          ]),
          const SizedBox(height: 20),

          // Stats : matchs / note / présence
          Row(children: [
            _Stat('${request.matchesPlayed}', 'matchs'),
            const SizedBox(width: 10),
            _Stat(request.averageRating > 0 ? request.averageRating.toStringAsFixed(1) : '—', 'note moy.'),
            const SizedBox(width: 10),
            _Stat('${request.presenceRate.toInt()}%', 'présence'),
          ]),
          const SizedBox(height: 16),

          // Détails profil
          _Detail(Icons.sports_soccer_rounded, 'Poste',  _posLabel(request.position)),
          const SizedBox(height: 8),
          _Detail(Icons.swap_horiz_rounded,    'Pied',   _footLabel(request.preferredFoot)),
          const SizedBox(height: 8),
          _Detail(Icons.bar_chart_rounded,     'Niveau', _levelLabel(request.level)),

          if ((request.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: _kBorder),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(request.bio!,
                  style: const TextStyle(color: _kGray, fontSize: 13, height: 1.5)),
            ),
          ],

          const SizedBox(height: 24),

          // Boutons Refuser / Accepter
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: onReject,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 6),
                  Text('Refuser', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: onAccept,
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(14)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_rounded, color: _kBg, size: 18),
                  SizedBox(width: 6),
                  Text('Accepter', style: TextStyle(color: _kBg, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

class _ReqInitial extends StatelessWidget {
  final String pseudo;
  final double size;
  const _ReqInitial(this.pseudo, {this.size = 18});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(pseudo.substring(0, 1).toUpperCase(),
        style: TextStyle(color: _kLime, fontSize: size, fontWeight: FontWeight.w800)),
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2A), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _kGray, fontSize: 11)),
      ]),
    ),
  );
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Detail(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: _kGray),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: _kGray, fontSize: 13)),
    const Spacer(),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}
