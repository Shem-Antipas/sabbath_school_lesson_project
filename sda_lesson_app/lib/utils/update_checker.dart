import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateChecker {
  static const String _versionKey = 'last_viewed_version';
  
  // ✅ IMPORTANT: Change this string whenever you release a big update
  static const String _currentVersion = '2.0.0'; 

  static Future<void> checkAndShowUpdate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastVersion = prefs.getString(_versionKey);

    // If the version saved on the phone is different from our current version, show the popup
    if (lastVersion != _currentVersion) {
      if (context.mounted) {
        _showUpdateDialog(context);
        // Save the new version so the user doesn't see the popup again
        await prefs.setString(_versionKey, _currentVersion);
      }
    }
  }

  static void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "What's New in Version 2.0",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFeatureItem(
                  Icons.music_note, 
                  "Hymns & MIDI Audio", 
                  "New Hymnals in Luo, Swahili, and English with MIDI for all English tracks."
                ),
                _buildFeatureItem(
                  Icons.translate, 
                  "New Bible Versions", 
                  "Now including Dholuo (Biblica) and Swahili translations."
                ),
                _buildFeatureItem(
                  Icons.search, 
                  "Smarter Search", 
                  "Keyword highlighting and better accuracy for Luo apostrophes."
                ),
                _buildFeatureItem(
                  Icons.playlist_add_check, 
                  "Multi-Verse Select", 
                  "Easily select and copy multiple verses or stanzas at once."
                ),
              ],
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("AWESOME!", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.teal, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  description, 
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}