import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'screens/main_navigation.dart';
import 'providers/theme_provider.dart';
// ✅ NEW: Import for the "What's New" logic
import 'utils/update_checker.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // We wrap the app in ProviderScope as you already have
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // ✅ NEW: Trigger the "What's New" Dialog after the first frame
    // This will check if the user has seen the v2.0.0 features yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkAndShowUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the smart theme provider
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Advent Study Hub',

      // Firebase Analytics tracking
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],

      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // DARK THEME
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      themeMode: themeMode,
      home: const MainNavigation(),
    );
  }
}