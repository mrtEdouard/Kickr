import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../data/countries.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg = Color(0xFF0D0D16);
const _kCard = Color(0xFF141420);
const _kGray = Color(0xFF8A8A9A);
const _kBorder = Color(0xFF2A2A3A);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _pseudoCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  String? _nationality;
  String? _position;
  String? _foot;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _initialized = false;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthChanged);
    // Cas où l'user est déjà disponible au montage
    if (_authProvider.user != null) _initFromUser(_authProvider.user!);
  }

  // Appelé à chaque notifyListeners() de AuthProvider
  void _onAuthChanged() {
    if (!_initialized && _authProvider.user != null) {
      setState(() => _initFromUser(_authProvider.user!));
    }
  }

  void _initFromUser(User user) {
    _pseudoCtrl.text = user.pseudo;
    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _cityCtrl.text = user.city ?? '';
    _bioCtrl.text = user.bio ?? '';
    _nationality = user.nationality;
    _position = user.position;
    _foot = user.preferredFoot;
    _initialized = true;
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _pseudoCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    setState(() => _uploadingAvatar = true);
    final Uint8List bytes = await image.readAsBytes();
    if (!mounted) return;
    final ok = await authProvider.updateAvatar(bytes, image.name);
    if (mounted) {
      setState(() => _uploadingAvatar = false);
      if (!ok) {
        final err = context.read<AuthProvider>().error ?? "Erreur lors de l'upload.";
        context.read<AuthProvider>().clearError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_pseudoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le pseudo est obligatoire.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await context.read<AuthProvider>().updateProfile(
      pseudo: _pseudoCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      nationality: _nationality,
      position: _position,
      preferredFoot: _foot,
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profil mis à jour !' : (context.read<AuthProvider>().error ?? 'Erreur')),
        backgroundColor: ok ? _kLime.withValues(alpha: 0.9) : Colors.redAccent,
      ),
    );
    if (ok) context.read<AuthProvider>().clearError();
  }

  void _openCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountryPickerSheet(
        selected: _nationality,
        onSelect: (code) {
          setState(() => _nationality = code);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Avatar + identité
            Center(
              child: Column(
                children: [
                  _AvatarWidget(
                    avatarUrl: user.avatarUrl,
                    pseudo: user.pseudo,
                    uploading: _uploadingAvatar,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.pseudo,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(user.email, style: const TextStyle(color: _kGray, fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                _StatChip(label: 'Matchs', value: user.matchesPlayed.toString(), icon: Icons.sports_soccer_rounded),
                const SizedBox(width: 10),
                _StatChip(label: 'Note moy.', value: user.averageRating.toStringAsFixed(1), icon: Icons.star_rounded),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Présence',
                  value: '${user.presenceRate.toStringAsFixed(0)}%',
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Informations personnelles ──────────────────────────────
            const _SectionTitle('Informations personnelles'),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ProfileField(label: 'Prénom', controller: _firstNameCtrl, hint: 'Jean')),
                const SizedBox(width: 12),
                Expanded(child: _ProfileField(label: 'Nom', controller: _lastNameCtrl, hint: 'Dupont')),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileField(label: 'Pseudo', controller: _pseudoCtrl, hint: 'monpseudo'),
            const SizedBox(height: 14),
            _ProfileField(label: 'Ville', controller: _cityCtrl, hint: 'Paris, Montpellier...'),
            const SizedBox(height: 14),

            // Nationalité
            const Text(
              'Nationalité',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    if (_nationality != null) ...[
                      Text(flagEmoji(_nationality!), style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        countryName(_nationality!),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ] else
                      const Text('Sélectionner un pays', style: TextStyle(color: _kGray, fontSize: 15)),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: _kGray),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Football ───────────────────────────────────────────────
            const _SectionTitle('Football'),
            const SizedBox(height: 14),

            const Text(
              'Poste',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _PickerRow(
              options: const [
                ('goalkeeper', 'Gardien'),
                ('defender', 'Défenseur'),
                ('midfielder', 'Milieu'),
                ('forward', 'Attaquant'),
              ],
              selected: _position,
              onSelect: (v) => setState(() => _position = v),
            ),
            const SizedBox(height: 16),

            const Text(
              'Pied fort',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _PickerRow(
              options: const [
                ('right', 'Droit'),
                ('left', 'Gauche'),
                ('both', 'Les deux'),
              ],
              selected: _foot,
              onSelect: (v) => setState(() => _foot = v),
            ),

            const SizedBox(height: 32),

            // ── Bio ────────────────────────────────────────────────────
            const _SectionTitle('Bio'),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Dis quelque chose sur toi...',
                hintStyle: const TextStyle(color: _kGray, fontSize: 15),
                filled: true,
                fillColor: _kCard,
                counterStyle: const TextStyle(color: _kGray, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kLime, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Bouton Enregistrer
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kLime,
                  foregroundColor: _kBg,
                  disabledBackgroundColor: _kLime.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Color(0xFF0D0D16), strokeWidth: 2.5),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String pseudo;
  final bool uploading;
  final VoidCallback onTap;

  const _AvatarWidget({
    required this.pseudo,
    this.avatarUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kLime, width: 2.5),
              color: const Color(0xFF1E1E2E),
            ),
            child: uploading
                ? const Center(child: CircularProgressIndicator(color: _kLime, strokeWidth: 2))
                : avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          'http://localhost:3000$avatarUrl',
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                          errorBuilder: (_, __, ___) => _initials(),
                        ),
                      )
                    : _initials(),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _kLime,
                shape: BoxShape.circle,
                border: Border.all(color: _kBg, width: 2),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 15, color: Color(0xFF0D0D16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() => Center(
        child: Text(
          pseudo.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: _kLime, fontSize: 34, fontWeight: FontWeight.w800),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: _kLime, size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _kGray, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(2)),
        ),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _ProfileField({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kGray, fontSize: 15),
            filled: true,
            fillColor: _kCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kLime, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  final List<(String, String)> options;
  final String? selected;
  final void Function(String) onSelect;

  const _PickerRow({required this.options, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(options[i].$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected == options[i].$1 ? _kLime : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected == options[i].$1 ? _kLime : _kBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    options[i].$2,
                    style: TextStyle(
                      color: selected == options[i].$1 ? _kBg : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Sélecteur de pays (bottom sheet avec recherche) ────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final String? selected;
  final void Function(String) onSelect;

  const _CountryPickerSheet({required this.selected, required this.onSelect});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<(String, String)> _filtered = kCountries;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? kCountries
          : kCountries.where((c) => c.$1.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Poignée
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A4A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Titre
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Nationalité',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),

            // Recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays...',
                  hintStyle: const TextStyle(color: _kGray, fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kGray, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kLime, width: 1.5),
                  ),
                ),
              ),
            ),

            // Liste
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final country = _filtered[i];
                  final isSelected = widget.selected == country.$2;
                  return ListTile(
                    leading: Text(flagEmoji(country.$2), style: const TextStyle(fontSize: 24)),
                    title: Text(
                      country.$1,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: _kLime, size: 20)
                        : null,
                    tileColor: isSelected ? _kLime.withValues(alpha: 0.07) : null,
                    onTap: () => widget.onSelect(country.$2),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
