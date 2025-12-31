import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'egw_library_screen.dart';
import 'hymnal_screen.dart';
import 'bible_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    // 1. THEME DETECTION
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. DYNAMIC COLORS
    // Dark Mode: Dark Grey Background, White Active Icon
    // Light Mode: White Background, Deep Blue Active Icon
    final navBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final selectedItemColor = isDark
        ? Colors.white
        : const Color.fromARGB(255, 1, 5, 66);
    final unselectedItemColor = isDark ? Colors.grey[600] : Colors.grey;

    return WillPopScope(
      onWillPop: () async {
        final isFirstRouteInCurrentTab = !await _navigatorKeys[_currentIndex]
            .currentState!
            .maybePop();
        return isFirstRouteInCurrentTab;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTab(0, const DashboardScreen()),
            _buildTab(1, const EGWLibraryScreen()),
            _buildTab(2, const HymnalScreen()),
            _buildTab(3, const HomeScreen()),
            _buildTab(4, const BibleScreen()),
          ],
        ),
        // 3. Wrap in Theme to ensure background color applies correctly
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            canvasColor:
                navBarColor, // Fixes background glitches on some devices
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (_currentIndex == index) {
                _navigatorKeys[index].currentState!.popUntil(
                  (route) => route.isFirst,
                );
              } else {
                setState(() => _currentIndex = index);
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: navBarColor, // Dynamic Background
            selectedItemColor: selectedItemColor, // Dynamic Active Color
            unselectedItemColor: unselectedItemColor, // Dynamic Inactive Color
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_stories_outlined),
                activeIcon: Icon(Icons.auto_stories),
                label: 'EGW',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.music_note_outlined),
                activeIcon: Icon(Icons.music_note),
                label: 'Hymns',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book),
                label: 'Lessons',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined),
                activeIcon: Icon(Icons.book),
                label: 'Bible',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, Widget rootPage) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootPage);
      },
    );
  }
}
