import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  final String paystackUrl = 'https://paystack.shop/pay/adventstudyhub';

  @override
  Widget build(BuildContext context) {
    // ✅ Use the current theme's color scheme
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ✅ Automatically adjusts to light/dark mode
    final Color primaryBrand = colorScheme.primary;
    final Color secondaryBrand = colorScheme.secondary;
    final Color surfaceColor = colorScheme.surface;
    final Color onSurfaceColor = colorScheme.onSurface;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(
          "Support the Ministry", 
          style: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurfaceColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          children: [
            // --- HERO SECTION ---
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                // ✅ Using a gradient derived from the theme's primary color
                gradient: LinearGradient(
                  colors: [
                    primaryBrand,
                    primaryBrand.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryBrand.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_rounded, size: 50, color: secondaryBrand),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Partner With Us",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Your generous donations help us maintain the app, develop new features, and spread the gospel to more people.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- DONATION OPTIONS ---
            _buildOptionCard(
              context,
              title: "Monthly Support",
              subtitle: "Sustain the ministry with a recurring gift.",
              buttonText: "DONATE MONTHLY",
              isPrimary: true,
              brandColor: primaryBrand,
              cardColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
              textColor: onSurfaceColor,
            ),

            const SizedBox(height: 20),

            _buildOptionCard(
              context,
              title: "One-Time Gift",
              subtitle: "Make a single contribution today.",
              buttonText: "DONATE ONCE",
              isPrimary: false,
              brandColor: primaryBrand,
              cardColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
              textColor: onSurfaceColor,
            ),

            const SizedBox(height: 40),

            // --- FOOTER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: onSurfaceColor.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  "Secure Payment Processing",
                  style: TextStyle(
                    color: onSurfaceColor.withOpacity(0.5), 
                    fontSize: 13, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String buttonText,
    required bool isPrimary,
    required Color brandColor,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isPrimary 
            ? Border.all(color: brandColor.withOpacity(0.5), width: 2)
            : Border.all(color: textColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.6)),
                  ),
                ],
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "POPULAR", 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brandColor),
                  ),
                )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _openPaystackDonation(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary ? brandColor : Colors.transparent,
                foregroundColor: isPrimary ? Colors.white : brandColor,
                elevation: isPrimary ? 2 : 0,
                side: isPrimary ? null : BorderSide(color: brandColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaystackDonation(BuildContext context) async {
    final Uri url = Uri.parse(paystackUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open donation page';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}