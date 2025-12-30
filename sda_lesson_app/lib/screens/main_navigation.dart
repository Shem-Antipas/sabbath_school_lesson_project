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

  // 1. Create unique GlobalKeys for each tab to track their individual navigation stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    // 2. Wrap the app in WillPopScope to handle the "Back" button correctly
    // This ensures if you press back, it navigates back inside the tab instead of closing the app
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_currentIndex == index) {
              // If user taps the current tab again, pop to the root of that tab
              _navigatorKeys[index].currentState!.popUntil(
                (route) => route.isFirst,
              );
            } else {
              setState(() => _currentIndex = index);
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color.fromARGB(255, 1, 5, 66),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories),
              label: 'EGW',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note),
              label: 'Hymns',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Lessons',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Bible'),
          ],
        ),
      ),
    );
  }

  // 3. Helper method to build a Navigator for each tab
  Widget _buildTab(int index, Widget rootPage) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => rootPage);
      },
    );
  }
}
