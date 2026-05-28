import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
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
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/bottom_navbar.dart';

// Instance globale partagée entre le Provider et le GoRouter (refreshListenable)
final _authProvider = AuthProvider();

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Maintient le splash natif pendant l'initialisation async
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
  FlutterNativeSplash.remove();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: const KickrApp(),
    ),
  );
}

class KickrApp extends StatefulWidget {
  const KickrApp({super.key});

  @override
  State<KickrApp> createState() => _KickrAppState();
}

class _KickrAppState extends State<KickrApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _authProvider,
      redirect: (context, state) {
        final loggedIn = _authProvider.isLoggedIn;
        final loc = state.matchedLocation;
        if (loggedIn && (loc == '/login' || loc == '/register')) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/splash',    builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/login',     builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register',  builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/',          builder: (_, __) => const MainScaffold()),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kickr',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFAAFF00),
          onPrimary: Color(0xFF0D0D16),
          secondary: Color(0xFFAAFF00),
          onSecondary: Color(0xFF0D0D16),
          surface: Color(0xFF141420),
          onSurface: Colors.white,
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 15),
          bodyMedium: TextStyle(color: Color(0xFF8A8A9A), fontSize: 14),
          labelLarge: TextStyle(
            color: Color(0xFF0D0D16),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D16),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141420),
          hintStyle: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 15),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A2A3A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A2A3A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFAAFF00), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFAAFF00),
            foregroundColor: const Color(0xFF0D0D16),
            disabledBackgroundColor: const Color(0xFFAAFF00).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 0,
            minimumSize: const Size(double.infinity, 54),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF141420),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D0D16),
          selectedItemColor: Color(0xFFAAFF00),
          unselectedItemColor: Color(0xFF8A8A9A),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A3A),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1A2A),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1A1A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2A2A3A)),
          ),
          elevation: 8,
        ),
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final events = context.read<EventProvider>();
      // SplashScreen a déjà tout initialisé — on ne refait rien si c'est le cas
      if (auth.status == AuthStatus.unknown) {
        await auth.initialize();
        if (auth.isLoggedIn) await events.loadMyEvents();
      }
    });
  }

  void _onTabTap(int index) {
    final auth = context.read<AuthProvider>();
    if (_protectedTabs.contains(index) && !auth.isLoggedIn) {
      context.go('/login');
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
          IconButton(
            onPressed: () => context.go('/onboarding'),
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF8A8A9A), size: 20),
            tooltip: "Revoir l'introduction",
          ),
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
              onLogin: () => context.go('/login'),
              onRegister: () => context.go('/register'),
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
