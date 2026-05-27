import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _matchType = '5v5';
  String _joinMode = 'open';
  String? _requiredLevel;
  bool _isPublic = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _kLime, surface: Color(0xFF1A1A2A)),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _kLime, surface: Color(0xFF1A1A2A)),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  String? get _formattedDate {
    if (_selectedDate == null || _selectedTime == null) return null;
    final d = _selectedDate!;
    final t = _selectedTime!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_formattedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une date et une heure.')),
      );
      return;
    }

    final ok = await context.read<EventProvider>().createEvent(
          title: _titleCtrl.text.trim(),
          date: _formattedDate!,
          location: _locationCtrl.text.trim(),
          matchType: _matchType,
          maxPlayers: int.parse(_matchType.split('v').first) * 2,
          requiredLevel: _requiredLevel,
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          joinMode: _joinMode,
          isPublic: _isPublic,
        );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match créé !'),
          backgroundColor: _kLime,
        ),
      );
      _titleCtrl.clear();
      _locationCtrl.clear();
      _descriptionCtrl.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _matchType = '5v5';
        _joinMode = 'open';
        _requiredLevel = null;
        _isPublic = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créer un match',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text('Organise ta prochaine session.', style: TextStyle(color: _kGray, fontSize: 15)),
                const SizedBox(height: 32),

                if (provider.error != null) ...[
                  _ErrorBanner(message: provider.error!),
                  const SizedBox(height: 20),
                ],

                // Titre
                _Label('Titre du match'),
                const SizedBox(height: 8),
                _KickrField(
                  controller: _titleCtrl,
                  hint: 'Ex: Five du soir, Match détente…',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
                ),
                const SizedBox(height: 20),

                // Lieu
                _Label('Lieu'),
                const SizedBox(height: 8),
                _KickrField(
                  controller: _locationCtrl,
                  hint: 'Parc Montcalm, City Sport…',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
                ),
                const SizedBox(height: 20),

                // Date + Heure
                _Label('Date et heure'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today_rounded,
                        label: _selectedDate == null
                            ? 'Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.access_time_rounded,
                        label: _selectedTime == null
                            ? 'Heure'
                            : '${_selectedTime!.hour.toString().padLeft(2, '0')}h${_selectedTime!.minute.toString().padLeft(2, '0')}',
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Type de match
                _Label('Type de match'),
                const SizedBox(height: 8),
                _SegmentedPicker(
                  options: const ['5v5', '7v7', '11v11'],
                  selected: _matchType,
                  onChanged: (v) => setState(() => _matchType = v),
                ),
                const SizedBox(height: 20),

                // Niveau requis
                _Label('Niveau requis'),
                const SizedBox(height: 8),
                _SegmentedPicker(
                  options: const ['Tous', 'Débutant', 'Intermédiaire', 'Confirmé'],
                  selected: _requiredLevel ?? 'Tous',
                  onChanged: (v) => setState(() => _requiredLevel = v == 'Tous' ? null : v),
                ),
                const SizedBox(height: 20),

                // Mode de rejoindre
                _Label('Mode d\'accès'),
                const SizedBox(height: 8),
                _SegmentedPicker(
                  options: const ['open', 'validation'],
                  labels: const ['Ouvert', 'Validation'],
                  selected: _joinMode,
                  onChanged: (v) => setState(() => _joinMode = v),
                ),
                const SizedBox(height: 20),

                // Public / Privé
                _Label('Visibilité'),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: _isPublic ? 'Match public' : 'Match privé',
                  subtitle: _isPublic ? 'Visible par tous' : 'Sur invitation uniquement',
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                const SizedBox(height: 20),

                // Description (optionnelle)
                _Label('Description (optionnelle)'),
                const SizedBox(height: 8),
                _KickrField(
                  controller: _descriptionCtrl,
                  hint: 'Infos supplémentaires, règles…',
                  maxLines: 3,
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: provider.loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kLime,
                      foregroundColor: _kBg,
                      disabledBackgroundColor: _kLime.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: provider.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Color(0xFF0D0D16), strokeWidth: 2.5),
                          )
                        : const Text('Créer le match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      );
}

class _KickrField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _KickrField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kGray, fontSize: 15),
        filled: true,
        fillColor: _kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kLime, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kLime, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(options[i]),
            child: Container(
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _kLime : _kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? _kLime : _kBorder),
              ),
              child: Center(
                child: Text(
                  labels != null ? labels![i] : options[i],
                  style: TextStyle(
                    color: isSelected ? _kBg : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: _kGray, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _kLime,
            activeTrackColor: _kLime.withValues(alpha: 0.3),
            inactiveThumbColor: _kGray,
            inactiveTrackColor: _kBorder,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}
