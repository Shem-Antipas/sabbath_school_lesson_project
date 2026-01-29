import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';

// --- IMPORTS ---
import 'screens/main_navigation.dart';
import 'providers/theme_provider.dart';
import 'utils/update_checker.dart';
import 'services/mpesa_service.dart'; // ✅ 1. ADD THIS IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Starting App Initialization...");

  // --- START NUCLEAR FIX FOR RANGE ERROR ---
  try {
    print("🧹 Clearing saved settings to fix RangeError...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    print("✅ Settings cleared. App is fresh.");
  } catch (e) {
    print("⚠️ Error clearing settings: $e");
  }
  // --- END NUCLEAR FIX ---

  try {
    // 1. Initialize Firebase
    print("🔥 Initializing Firebase...");
    await Firebase.initializeApp();
    print("✅ Firebase Initialized");
  } catch (e) {
    print("❌ Firebase Error: $e");
  }

  try {
    // 2. Initialize Audio Background
    print("🎵 Initializing Audio Background...");
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    );
    print("✅ Audio Background Initialized");
  } catch (e) {
    print("❌ Audio Background Error: $e");
  }

  try {
    // 3. ✅ INITIALIZE M-PESA SERVICE
    print("💳 Initializing M-Pesa Service...");
    
    // REMOVED 'await' because initialize() is synchronous
    MpesaService.initialize(); 
    
    print("✅ M-Pesa Initialized");
  } catch (e) {
    print("❌ M-Pesa Init Error: $e");
  }

  print("🏁 Running App...");
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

    // Trigger the "What's New" Dialog after the first frame
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