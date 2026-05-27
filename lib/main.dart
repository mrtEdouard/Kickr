import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';

import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/create_match_screen.dart';
import 'screens/my_matches_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'widgets/bottom_navbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: const KickrApp(),
    ),
  );
}

class KickrApp extends StatelessWidget {
  const KickrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kickr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFAAFF00),
          surface: Color(0xFF0D0D16),
        ),
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // Tabs 2, 3, 4 nécessitent d'être connecté
  static const _protectedTabs = {2, 3, 4};

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    CreateMatchScreen(),
    MyMatchesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Vérifie la session au démarrage, puis charge les events de l'utilisateur
    // si la session est encore valide. On capture les providers avant l'await
    // pour ne pas utiliser context dans un gap asynchrone.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final events = context.read<EventProvider>();
      await auth.initialize();
      if (auth.isLoggedIn) events.loadMyEvents();
    });
  }

  void _onTabTap(int index) {
    final auth = context.read<AuthProvider>();
    if (_protectedTabs.contains(index) && !auth.isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Splash pendant la vérification initiale du token
    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D16),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFAAFF00)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D16),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset('logo.png', height: 40, width: 40, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Text(
              'KICKR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          // Cloche de notifications
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFAAFF00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          // Auth actions : connecté → avatar+menu, non connecté → boutons
          if (auth.isLoggedIn)
            _ProfileMenu(
              pseudo: auth.user!.pseudo,
              avatarUrl: auth.user!.avatarUrl,
              onProfile: () => _onTabTap(4),
              onLogout: () async {
                final eventProvider = context.read<EventProvider>();
                await context.read<AuthProvider>().logout();
                eventProvider.reset();
                setState(() => _currentIndex = 0);
              },
            )
          else
            _AuthButtons(
              onLogin: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              onRegister: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

// Avatar + pseudo + menu déroulant (Profil / Déconnecter)
class _ProfileMenu extends StatelessWidget {
  final String pseudo;
  final String? avatarUrl;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _ProfileMenu({
    required this.pseudo,
    this.avatarUrl,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        color: const Color(0xFF1A1A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2A2A3A)),
        ),
        elevation: 8,
        onSelected: (value) {
          if (value == 'profile') onProfile();
          if (value == 'logout') onLogout();
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                const Text('Profil', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, color: Color(0xFFAAFF00), size: 18),
                const SizedBox(width: 10),
                const Text('Déconnecter', style: TextStyle(color: Color(0xFFAAFF00), fontSize: 14)),
              ],
            ),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFAAFF00), width: 2),
                color: const Color(0xFF1E1E2E),
              ),
              child: avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        'http://localhost:3000$avatarUrl',
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            pseudo.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFAAFF00),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        pseudo.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFAAFF00),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              pseudo,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

// Boutons Connexion / Inscription pour utilisateurs non connectés
class _AuthButtons extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _AuthButtons({required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('Connexion', style: TextStyle(fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: onRegister,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFAAFF00),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "S'inscrire",
                style: TextStyle(
                  color: Color(0xFF0D0D16),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
