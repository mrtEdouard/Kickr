import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLime = Color(0xFFAAFF00);
const _kBg   = Color(0xFF0D0D16);
const _kGray = Color(0xFF8A8A9A);

/// Écran d'onboarding affiché uniquement au premier lancement de l'application.
/// Une fois terminé (bouton "C'est parti !" ou "Passer"), le flag 'kickr_onboarded'
/// est enregistré dans SharedPreferences et l'utilisateur est redirigé vers l'accueil.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  /// Marque l'onboarding comme terminé et navigue vers l'accueil.
  Future<void> _complete(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kickr_onboarded', true);
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2);
    const bodyStyle  = TextStyle(color: _kGray, fontSize: 15, height: 1.5);
    const deco = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      pageColor: _kBg,
      imagePadding: EdgeInsets.only(top: 60),
      titlePadding: EdgeInsets.only(top: 28, bottom: 12),
      bodyPadding: EdgeInsets.symmetric(horizontal: 24),
    );

    final pages = [
      PageViewModel(
        title: 'Trouve un match\nprès de toi',
        body: 'Des matchs de foot organisés autour de toi, disponibles en temps réel.',
        image: _OnboardingIcon(Icons.sports_soccer_rounded),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Rejoins ou crée\nton match',
        body: 'Inscris-toi en un tap ou organise ton propre match avec tes règles.',
        image: _OnboardingIcon(Icons.group_add_rounded),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Compose tes\néquipes',
        body: "L'organisateur tire les équipes au sort ou les compose lui-même, joueur par joueur.",
        image: _OnboardingIcon(Icons.shuffle_rounded),
        decoration: deco,
      ),
    ];

    return IntroductionScreen(
      pages: pages,
      onDone: () => _complete(context),
      onSkip: () => _complete(context),
      showSkipButton: true,
      // Bouton "Passer" discret
      skip: const Text('Passer', style: TextStyle(color: _kGray, fontWeight: FontWeight.w600, fontSize: 14)),
      // Flèche "Suivant" dans un cercle lime
      next: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: _kLime, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0D0D16), size: 20),
      ),
      // Bouton final "C'est parti !"
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(color: _kLime, borderRadius: BorderRadius.circular(24)),
        child: const Text(
          "C'est parti !",
          style: TextStyle(color: Color(0xFF0D0D16), fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      // Points de progression stylisés
      dotsDecorator: const DotsDecorator(
        color: Color(0xFF2A2A3A),
        activeColor: _kLime,
        size: Size(8, 8),
        activeSize: Size(22, 8),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      ),
      globalBackgroundColor: _kBg,
      isProgressTap: true,
      animationDuration: 400,
    );
  }
}

/// Icône grande taille affichée au centre de chaque slide d'onboarding.
class _OnboardingIcon extends StatelessWidget {
  final IconData icon;
  const _OnboardingIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: _kLime.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: _kLime.withValues(alpha: 0.2), width: 2),
        ),
        child: Icon(icon, size: 80, color: _kLime),
      ),
    );
  }
}
