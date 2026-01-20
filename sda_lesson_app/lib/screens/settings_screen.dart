import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ✅ 1. IMPORT THE PACKAGE
import '../providers/favorites_provider.dart';
import '../providers/hymnal_provider.dart'; 
import '../providers/theme_provider.dart'; 

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keepScreenOn = ref.watch(keepScreenOnProvider);
    final currentTheme = ref.watch(themeProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: ListView(
        children: [
          // --- APPEARANCE SECTION ---
          const ListTile(
            title: Text("Appearance", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("System Default"),
            value: ThemeMode.system,
            groupValue: currentTheme,
            onChanged: (value) => ref.read(themeProvider.notifier).setTheme(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Light Mode"),
            value: ThemeMode.light,
            groupValue: currentTheme,
            onChanged: (value) => ref.read(themeProvider.notifier).setTheme(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text("Dark Mode"),
            value: ThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (value) => ref.read(themeProvider.notifier).setTheme(value!),
          ),
          const Divider(),

          // --- DISPLAY SETTINGS ---
          const ListTile(
            title: Text("Display Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline, color: Colors.orange),
            title: const Text("Keep Screen Awake"),
            value: keepScreenOn,
            onChanged: (val) => ref.read(keepScreenOnProvider.notifier).state = val,
          ),
          const Divider(),

          // --- DATA MANAGEMENT ---
          const ListTile(
            title: Text("Data Management", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text("Clear All Favorites"),
            onTap: () => _showClearFavoritesDialog(context, ref),
          ),
          const Divider(),

          // --- ABOUT SECTION ---
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Advent Study Hub",
                applicationVersion: "1.0.0",
                applicationIcon: const Icon(Icons.book, size: 50, color: Colors.blue),
                children: [ const Text("A comprehensive study tool for the SDA Faithfuls.") ],
              );
            },
          ),
          
          // --- BRANDING ---
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Powered by", style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/branding.png',
                    width: 130,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 40), 
              ],
            ),
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
        content: const Text("This will remove all books from your favorites list."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              ref.read(favoritesProvider.notifier).clearAll();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All favorites cleared")));
            },
            child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}