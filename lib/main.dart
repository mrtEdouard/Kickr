import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/create_match_screen.dart';
import 'screens/my_matches_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_navbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const KickrApp());
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

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    CreateMatchScreen(),
    MyMatchesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 26,
                ),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 4),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFAAFF00),
                    width: 2,
                  ),
                  color: const Color(0xFF1E1E2E),
                ),
                child: ClipOval(
                  child: Icon(
                    Icons.person,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                ),
              ),
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
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
