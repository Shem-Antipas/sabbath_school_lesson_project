import 'package:flutter/material.dart';
import '../services/mpesa_service.dart'; // ✅ Imported M-Pesa Service

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ✅ Brand Colors
    const Color navyBlue = Color(0xFF06275C);
    const Color brandCyan = Color(0xFF00A8E8);
    
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : navyBlue;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Support the Ministry", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          children: [
            // --- HERO SECTION ---
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navyBlue, Color(0xFF0A3A80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: navyBlue.withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 50, color: brandCyan),
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
              brandColor: brandCyan,
              cardColor: cardColor,
              textColor: textColor,
            ),

            const SizedBox(height: 20),

            _buildOptionCard(
              context,
              title: "One-Time Gift",
              subtitle: "Make a single contribution today.",
              buttonText: "DONATE ONCE",
              isPrimary: false,
              brandColor: brandCyan,
              cardColor: cardColor,
              textColor: textColor,
            ),

            const SizedBox(height: 40),

            // --- FOOTER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: subTextColor),
                const SizedBox(width: 8),
                Text(
                  "Secure Payment Processing",
                  style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500),
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
            : Border.all(color: Colors.grey.withOpacity(0.1)),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
              // ✅ UPDATED: Calls the payment dialog
              onPressed: () => _showPaymentDialog(context, title),
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

  // ✅ UPDATED: Payment Dialog with M-Pesa Logic
  void _showPaymentDialog(BuildContext context, String donationType) {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme Colors for Dialog
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF06275C);
    const brandCyan = Color(0xFF00A8E8);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Make a Donation", 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your details to proceed with M-Pesa secure payment.",
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            
            // Amount Field
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Amount (KES)",
                labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.blueGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: brandCyan, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money, color: brandCyan),
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone Field
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "M-Pesa Phone (e.g. 0712...)",
                labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.blueGrey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: brandCyan, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone_android, color: brandCyan),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700])),
          ),
          
          // ✅ INTEGRATED "PAY NOW" BUTTON
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandCyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              // 1. Validation
              if (phoneController.text.isEmpty || amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter both amount and phone number.")),
                );
                return;
              }

              Navigator.pop(context); // Close dialog

              // 2. Show Processing Message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Processing M-Pesa Request... Check your phone."), 
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.blue,
                ),
              );

              // 3. Call M-Pesa Service
              try {
                await MpesaService.startSTKPush(
                  context: context,
                  phoneNumber: phoneController.text,
                  amount: double.parse(amountController.text),
                );
                
                // Note: The actual success confirmation comes via Callback (Webhook),
                // not immediately here. This just means the popup was sent.
                
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Pay Now", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}