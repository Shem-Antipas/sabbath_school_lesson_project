import 'package:flutter/material.dart';
import 'home_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  // ✅ Pre-load images to prevent "Skipped Frames" lag
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
    precacheImage(const AssetImage('assets/branding.png'), context);
  }

  _navigateToHome() async {
    // Keep 3 seconds so users have time to see the branding
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06275C), // Dark Blue Background
      body: Stack(
        fit: StackFit.expand, // ✅ Ensures the Stack fills the whole screen
        children: [
          // ---------------------------------------------
          // 1. CENTER CONTENT (App Logo + Loader)
          // ---------------------------------------------
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png', 
                  width: 150,
                  height: 150,
                  errorBuilder: (c, e, s) => const Icon(Icons.apps, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(
                  color: Colors.white, 
                  strokeWidth: 3,
                ),
              ],
            ),
          ),

          // ---------------------------------------------
          // 2. BOTTOM BRANDING (Clean Production Layout)
          // ---------------------------------------------
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0), 
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    const Text(
                      "Powered by",
                      style: TextStyle(
                        color: Colors.white70, 
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // --- FINAL LOGO IMPLEMENTATION ---
                    Image.asset(
                      'assets/branding.png', 
                      width: 160,       // ✅ Set width to 160 for readability
                      fit: BoxFit.contain, // ✅ Ensures it scales without cutting off
                      
                      // Fallback just in case
                      errorBuilder: (c, e, s) => const Text(
                        "INKWELL CREATIONS", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                    // ---------------------------------
                    
                    const SizedBox(height: 8),
                    const Text(
                      "v1.0.0", 
                      style: TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}