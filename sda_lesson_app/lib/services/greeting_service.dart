import 'package:shared_preferences/shared_preferences.dart';

class GreetingService {
  static const String _keyLastSeenNewYear = 'last_seen_new_year_2026';

  /// Checks if we should show the New Year 2026 Card
  static Future<bool> shouldShowNewYearCard() async {
    final now = DateTime.now();

    // 1. Check Date Range (Jan 1, 2026 to Jan 20, 2026)
    final startDate = DateTime(2026, 1, 1);
    final endDate = DateTime(2026, 1, 20, 23, 59, 59);

    if (now.isBefore(startDate) || now.isAfter(endDate)) {
      return false;
    }

    // 2. Check 3-Hour Cooldown
    final prefs = await SharedPreferences.getInstance();
    final lastSeenMillis = prefs.getInt(_keyLastSeenNewYear);

    if (lastSeenMillis != null) {
      final lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeenMillis);
      final difference = now.difference(lastSeenTime);

      // If seen less than 3 hours ago, DO NOT show
      if (difference.inHours < 3) {
        return false;
      }
    }

    // If we pass checks, we allow showing it.
    // NOTE: We update the timestamp only when the widget is actually built/shown.
    return true;
  }

  /// Call this when the New Year card is actually rendered to reset the 3-hour timer
  static Future<void> markNewYearCardAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keyLastSeenNewYear,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Checks if it is Friday evening (Sabbath Start)
  static bool isSabbathTime() {
    final now = DateTime.now();

    // Check if it is Friday
    if (now.weekday == DateTime.friday) {
      // Check if time is 18:30 (6:30 PM) or later
      if (now.hour > 18 || (now.hour == 18 && now.minute >= 30)) {
        return true;
      }
    }

    // Optional: You can extend this to include Saturday if you wish
    // if (now.weekday == DateTime.saturday) return true;

    return false;
  }
}
