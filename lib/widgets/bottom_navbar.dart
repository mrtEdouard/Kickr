import 'package:flutter/material.dart';

// Les couleurs de la navbar centralisées ici pour éviter de les répéter partout.
// Le vert lime c'est la couleur signature de Kickr, on s'en sert pour tout ce qui est "actif".
const _kLime = Color(0xFFAAFF00);
const _kInactive = Color(0xFF5A5A6E); // gris doux pour les onglets non sélectionnés
const _kBg = Color(0xFF0D0D16);       // même fond que le reste de l'app

// La navbar principale — reçoit l'index actif et un callback quand l'utilisateur tape un onglet.
// On garde ça stateless, la gestion de l'état appartient au parent (MainScaffold).
class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        // Une fine ligne en haut pour séparer visuellement la navbar du contenu,
        // sans être agressive — juste un indice subtil de séparation.
        border: Border(
          top: BorderSide(color: Color(0xFF1E1E2E), width: 1),
        ),
      ),
      child: SafeArea(
        // SafeArea gère le padding en bas sur iPhone (home indicator, etc.)
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: 'Explorer',
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              // Le bouton "Créer" est volontairement différent des autres onglets :
              // c'est l'action principale de l'app, elle mérite d'être mise en avant.
              _CreateButton(onTap: () => onTap(2)),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Mes matchs',
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                index: 4,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Un onglet classique de la navbar : icône + label.
// Il sait s'il est actif ou pas grâce à la comparaison index / currentIndex.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      // HitTestBehavior.opaque pour que toute la zone soit tappable,
      // même les pixels transparents entre l'icône et le label.
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isActive ? _kLime : _kInactive,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                // Légèrement plus gras quand actif, c'est un petit détail
                // mais ça renforce bien la sensation de sélection.
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? _kLime : _kInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Le bouton central "+" pour créer un match.
// Pas de label, pas d'index actif — c'est un bouton d'action, pas un onglet.
class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _kLime,
          // L'ombre colorée en lime donne un effet de "lueur" qui attire l'œil
          // vers ce bouton — exactement ce qu'on veut pour l'action principale.
          boxShadow: [
            BoxShadow(
              color: Color(0x55AAFF00),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        // L'icône est sombre sur fond lime pour un contraste maximal.
        child: const Icon(
          Icons.add_rounded,
          color: Color(0xFF0D0D16),
          size: 30,
        ),
      ),
    );
  }
}
