import 'package:flutter/material.dart';
import 'home_screen.dart'; // Ensure this import points to your actual home screen file

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

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2)); // Show for 2 seconds
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
      // FIXED: Added 'FF' for full opacity. 0x06275C is transparent; 0xFF06275C is visible Blue.
      backgroundColor: const Color(0xFF06275C),
      body: Stack(
        children: [
          // 1. Center Content (Main App Logo + Loader)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 150),
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),

          // 2. Bottom Branding (Asset Image)
          Positioned(
            bottom: 40, // Padding from the bottom of the screen
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Optional: You can uncomment the text below if you want "Powered by" text above the logo
                // Text("Powered by", style: TextStyle(color: Colors.white70, fontSize: 10)),
                // SizedBox(height: 5),
                Image.asset(
                  'assets/branding.png', // <--- Make sure this matches your filename
                  width: 100, // Adjust width as needed
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        Text(
                          "IMAGE ERROR",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
