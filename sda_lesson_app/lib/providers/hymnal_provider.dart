import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

// --- 0. CONFIGURATION MODELS ---

// ✅ LANGUAGE DEFINITION
// Ensure these paths match your actual asset folder structure exactly
enum HymnLanguage {
  english('English', 'assets/data/hymns_en.json'),
  swahili('Kiswahili', 'assets/data/hymns_sw.json'),
  kisii('Ekegusii', 'assets/data/hymns_ek.json'),
  luo('Dholuo', 'assets/data/hymns_lu.json'),
  gikuyu('Gikuyu', 'assets/data/hymns_gk.json');

  final String label;
  final String assetPath;
  const HymnLanguage(this.label, this.assetPath);
}

class Hymn {
  final int id;
  final String title;
  final String lyrics;      // Plain text for Search & List Preview
  final String htmlContent; // Raw HTML for the Detail Screen
  final String topic;

  Hymn({
    required this.id,
    required this.title,
    required this.lyrics,
    required this.htmlContent,
    required this.topic,
  });

  // ✅ ROBUST FACTORY: Handles both English (Simple) and Local (HTML) formats
  factory Hymn.fromJson(Map<String, dynamic> json) {
    // 1. HANDLE ID: Support both 'id' (English) and 'number' (Swahili)
    int safeId = 0;
    if (json.containsKey('number')) {
      // Handle case where number might be a String "1" or Int 1
      safeId = json['number'] is int 
          ? json['number'] 
          : int.tryParse(json['number'].toString()) ?? 0;
    } else if (json.containsKey('id')) {
      safeId = json['id'] is int 
          ? json['id'] 
          : int.tryParse(json['id'].toString()) ?? 0;
    }

    // 2. HANDLE LYRICS: Support 'lyrics' (Old) and 'content' (New)
    String rawContent = json['content'] ?? json['lyrics'] ?? "";

    // 3. GENERATE PLAIN TEXT: Remove HTML tags for the list view preview & search
    String plainText = _stripHtml(rawContent);

    // 4. HANDLE TITLE: Remove "1 - " prefix if it exists (Optional cleanup)
    String cleanTitle = json['title'] ?? "Untitled";

    return Hymn(
      id: safeId,
      title: cleanTitle,
      lyrics: plainText,        // Used for search and list subtitle
      htmlContent: rawContent,  // Used for the detail screen
      topic: json['topic'] ?? "General",
    );
  }

  // Helper to remove HTML tags (<br>, <b>, <font>) to get plain text
  static String _stripHtml(String htmlString) {
    // Replace <br> and <p> with spaces to prevent words mashing together
    String spaced = htmlString.replaceAll(RegExp(r'<(br|p|div)[^>]*>', caseSensitive: false), ' ');
    // Remove all other tags
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    String stripped = spaced.replaceAll(exp, '');
    // Remove extra whitespace created by stripping
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// --- AUDIO STATE MODEL ---
class AudioState {
  final Hymn? currentHymn;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  AudioState({
    this.currentHymn,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });
}

// --- 1. STATE PROVIDERS ---

// ✅ TRACK SELECTED LANGUAGE (Default: English)
final hymnLanguageProvider = StateProvider<HymnLanguage>((ref) => HymnLanguage.english);

final hymnSearchProvider = StateProvider<String>((ref) => "");
final hymnSortModeProvider = StateProvider<String>((ref) => 'Numerical');
final hymnFontSizeProvider = StateProvider<double>((ref) => 18.0);


// --- 2. BASE DATA PROVIDER ---
final allHymnsProvider = FutureProvider<List<Hymn>>((ref) async {
  // Watch the language provider. If language changes, this re-runs!
  final selectedLanguage = ref.watch(hymnLanguageProvider);
  
  try {
    // Load the specific JSON file for the selected language
    final String response = await rootBundle.loadString(selectedLanguage.assetPath);
    final List<dynamic> data = json.decode(response);
    return data.map((json) => Hymn.fromJson(json)).toList();
  } catch (e) {
    // Return empty list instead of crashing, but log the error
    print("Error loading ${selectedLanguage.label}: $e");
    return [];
  }
});


// --- 3. LOGIC PROVIDER ---
final filteredHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final allHymnsAsync = ref.watch(allHymnsProvider);
  final search = ref.watch(hymnSearchProvider).toLowerCase();
  final sortMode = ref.watch(hymnSortModeProvider);

  return allHymnsAsync.whenData((hymns) {
    // FILTER
    List<Hymn> filtered = hymns.where((h) {
      return h.id.toString().contains(search) ||
          h.title.toLowerCase().contains(search) ||
          h.lyrics.toLowerCase().contains(search); // Also search lyrics
    }).toList();

    // SORT
    if (sortMode == 'Alphabet') {
      filtered.sort((a, b) => a.title.compareTo(b.title));
    } else if (sortMode == 'Numerical') {
      filtered.sort((a, b) => a.id.compareTo(b.id));
    } else if (sortMode == 'Topics') {
      filtered.sort((a, b) {
        int topicComp = a.topic.compareTo(b.topic);
        if (topicComp != 0) return topicComp;
        return a.id.compareTo(b.id);
      });
    }

    return filtered;
  });
});

// --- 4. HARDWARE PROVIDER ---
final keepScreenOnProvider = StateProvider<bool>((ref) {
  ref.listenSelf((previous, next) {
    if (next) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  });
  return false;
});

// --- 5. AUDIO PLAYER PROVIDER ---
final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>((ref) {
  return AudioNotifier();
});

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioPlayer _player = AudioPlayer();

  AudioNotifier() : super(AudioState()) {
    _player.onPositionChanged.listen((p) {
      state = _updateState(position: p);
    });
    _player.onDurationChanged.listen((d) {
      state = _updateState(duration: d);
    });
    _player.onPlayerStateChanged.listen((s) {
      state = _updateState(isPlaying: s == PlayerState.playing);
    });

    _player.onPlayerComplete.listen((_) {
      state = _updateState(isPlaying: false, position: Duration.zero);
    });
  }

  AudioState _updateState({
    Hymn? currentHymn,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return AudioState(
      currentHymn: currentHymn ?? state.currentHymn,
      isPlaying: isPlaying ?? state.isPlaying,
      position: position ?? state.position,
      duration: duration ?? state.duration,
    );
  }

  Future<void> playHymn(Hymn hymn) async {
    try {
      if (state.currentHymn?.id == hymn.id) {
        state.isPlaying ? await _player.pause() : await _player.resume();
      } else {
        await _player.stop();
        state = AudioState(currentHymn: hymn);
        
        // Note: Assumes audio files are named 'hymn_1.mp3', 'hymn_2.mp3', etc.
        // If local languages have different audio, you might need logic here.
        await _player.play(AssetSource('audio/hymn_${hymn.id}.mp3'));
      }
    } catch (e) {
      state = AudioState();
      print("Audio file missing for hymn ${hymn.id}");
    }
  }

  Future<void> togglePlay() async {
    if (state.currentHymn == null) return;
    state.isPlaying ? await _player.pause() : await _player.resume();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}