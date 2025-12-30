import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../providers/hymnal_provider.dart'; // Ensure keepScreenOnProvider is here
import '../providers/theme_provider.dart'; // Import the new theme provider

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch existing providers
    final keepScreenOn = ref.watch(keepScreenOnProvider);

    // Watch new Theme provider
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: ListView(
        children: [
          // --- NEW: APPEARANCE SECTION ---
          const ListTile(
            title: Text(
              "Appearance",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("System Default"),
            subtitle: const Text("Follows your phone's settings"),
            secondary: const Icon(Icons.brightness_auto),
            value: ThemeMode.system,
            groupValue: currentTheme,
            onChanged: (value) {
              ref.read(themeProvider.notifier).setTheme(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Light Mode"),
            secondary: const Icon(Icons.wb_sunny),
            value: ThemeMode.light,
            groupValue: currentTheme,
            onChanged: (value) {
              ref.read(themeProvider.notifier).setTheme(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Dark Mode"),
            secondary: const Icon(Icons.nights_stay),
            value: ThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (value) {
              ref.read(themeProvider.notifier).setTheme(value!);
            },
          ),
          const Divider(),

          // --- EXISTING: DISPLAY SETTINGS SECTION ---
          const ListTile(
            title: Text(
              "Display Settings",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(
              Icons.lightbulb_outline,
              color: Colors.orange,
            ),
            title: const Text("Keep Screen Awake"),
            subtitle: const Text("Prevent screen from dimming during service"),
            value: keepScreenOn,
            onChanged: (val) {
              ref.read(keepScreenOnProvider.notifier).state = val;
            },
          ),
          const Divider(),

          // --- EXISTING: DATA MANAGEMENT SECTION ---
          const ListTile(
            title: Text(
              "Data Management",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text("Clear All Favorites"),
            subtitle: const Text("Remove all bookmarked EGW books"),
            onTap: () => _showClearFavoritesDialog(context, ref),
          ),
          const Divider(),

          // --- EXISTING: ABOUT SECTION ---
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "SDA Study Hub",
                applicationVersion: "1.0.0",
                applicationIcon: const Icon(
                  Icons.book,
                  size: 50,
                  color: Colors.blue,
                ),
                children: [
                  const Text(
                    "A comprehensive study tool for the SDA community.",
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showClearFavoritesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Favorites?"),
        content: const Text(
          "This will remove all books from your favorites list. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              ref.read(favoritesProvider.notifier).clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("All favorites cleared")),
              );
            },
            child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
