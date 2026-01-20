import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart'; // Required for debugPrint

// --- 0. CONFIGURATION MODELS ---

// ✅ LANGUAGE DEFINITION
enum HymnLanguage {
  english('English', 'assets/data/hymns_en.json'),
  swahili('Kiswahili', 'assets/data/hymns_sw.json'),
  kisii('Ekegusii', 'assets/data/hymns_ek.json'),
  luo('Dholuo', 'assets/data/hymns_lu.json'),
  gikuyu('Gikuyu', 'assets/data/hymns_gk.json'),
  oldHymn('Old Hymn', 'assets/data/hymns_old_en.json');

  final String label;
  final String assetPath;
  const HymnLanguage(this.label, this.assetPath);
}

class Hymn {
  final int id;
  final String title;
  final String lyrics;      
  final String htmlContent; 
  final String topic;

  Hymn({
    required this.id,
    required this.title,
    required this.lyrics,
    required this.htmlContent,
    required this.topic,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) {
    int safeId = 0;
    if (json.containsKey('number')) {
      safeId = json['number'] is int 
          ? json['number'] 
          : int.tryParse(json['number'].toString()) ?? 0;
    } else if (json.containsKey('id')) {
      safeId = json['id'] is int 
          ? json['id'] 
          : int.tryParse(json['id'].toString()) ?? 0;
    }

    String rawContent = json['content'] ?? json['lyrics'] ?? "";
    String plainText = _stripHtml(rawContent);
    String cleanTitle = json['title'] ?? "Untitled";

    return Hymn(
      id: safeId,
      title: cleanTitle,
      lyrics: plainText,
      htmlContent: rawContent,
      topic: json['topic'] ?? "General",
    );
  }

  static String _stripHtml(String htmlString) {
    String spaced = htmlString.replaceAll(RegExp(r'<(br|p|div)[^>]*>', caseSensitive: false), ' ');
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    String stripped = spaced.replaceAll(exp, '');
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

  AudioState copyWith({
    Hymn? currentHymn,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return AudioState(
      currentHymn: currentHymn ?? this.currentHymn,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

// --- 1. STATE PROVIDERS ---
final hymnLanguageProvider = StateProvider<HymnLanguage>((ref) => HymnLanguage.english);
final hymnSearchProvider = StateProvider<String>((ref) => "");
final hymnSortModeProvider = StateProvider<String>((ref) => 'Numerical');
final hymnFontSizeProvider = StateProvider<double>((ref) => 18.0);

// --- 2. BASE DATA PROVIDER ---
final allHymnsProvider = FutureProvider<List<Hymn>>((ref) async {
  final selectedLanguage = ref.watch(hymnLanguageProvider);
  
  try {
    final String response = await rootBundle.loadString(selectedLanguage.assetPath);
    final List<dynamic> data = json.decode(response);
    return data.map((json) => Hymn.fromJson(json)).toList();
  } catch (e) {
    debugPrint("Error loading ${selectedLanguage.label}: $e");
    return [];
  }
});

// --- 3. LOGIC PROVIDER ---
final filteredHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final allHymnsAsync = ref.watch(allHymnsProvider);
  final search = ref.watch(hymnSearchProvider).toLowerCase();
  final sortMode = ref.watch(hymnSortModeProvider);

  return allHymnsAsync.whenData((hymns) {
    List<Hymn> filtered = hymns.where((h) {
      return h.id.toString().contains(search) ||
          h.title.toLowerCase().contains(search) ||
          h.lyrics.toLowerCase().contains(search);
    }).toList();

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
  // We pass 'ref' to the notifier so it can check the current language
  return AudioNotifier(ref);
});

class AudioNotifier extends StateNotifier<AudioState> {
  final Ref ref; // ✅ Access to read other providers
  final AudioPlayer _player = AudioPlayer();
  
  // MIDI MAPPING LOGIC
  Map<int, String> _midiFiles = {};
  bool _isMapLoaded = false;

  AudioNotifier(this.ref) : super(AudioState()) {
    _initListeners();
    // Don't load immediately; load when first needed to save resources
  }

  void _initListeners() {
    _player.onPositionChanged.listen((p) {
      if (mounted) state = state.copyWith(position: p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) state = state.copyWith(duration: d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) state = state.copyWith(isPlaying: s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) state = state.copyWith(isPlaying: false, position: Duration.zero);
    });
  }

  // ✅ NEW: Uses AssetManifest class (Fixes the "Unable to load asset" error)
  Future<void> _loadMidiFiles() async {
    try {
      // Modern way to load assets in newer Flutter versions
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      // Filter for files inside assets/midi/
      final midiPaths = assets.where((path) => path.contains('assets/midi/')).toList();

      for (var path in midiPaths) {
        final filename = path.split('/').last; // e.g., "SAH001_Title.MID"
        
        // Regex: Find "SAH" followed by digits (e.g. SAH001)
        final match = RegExp(r'SAH(\d+)').firstMatch(filename);
        
        if (match != null) {
          final id = int.parse(match.group(1)!);
          _midiFiles[id] = path;
        }
      }
      _isMapLoaded = true;
      debugPrint("Midi Map Loaded: Found ${_midiFiles.length} files.");
    } catch (e) {
      debugPrint("Error loading midi manifest: $e");
    }
  }

  Future<bool> playHymn(Hymn hymn) async {
    try {
      // 1. ✅ CHECK LANGUAGE: If not English, stop immediately
      final currentLang = ref.read(hymnLanguageProvider);
      if (currentLang != HymnLanguage.english) {
        debugPrint("Skipping audio: MIDI only available for English.");
        return false;
      }

      // 2. Toggle if same hymn
      if (state.currentHymn?.id == hymn.id) {
        await togglePlay();
        return true; 
      }

      // 3. Ensure Map is Loaded
      if (!_isMapLoaded) await _loadMidiFiles();

      // 4. Find File
      String? fullPath = _midiFiles[hymn.id];

      if (fullPath == null) {
        debugPrint("EXCEPTION: Audio missing for Hymn #${hymn.id}");
        return false; 
      }

      // 5. Clean Path for AudioPlayer (Remove 'assets/' prefix if present)
      if (fullPath.startsWith('assets/')) {
        fullPath = fullPath.substring(7);
      }

      // 6. Play
      await _player.stop();
      await _player.play(AssetSource(fullPath));
      
      state = state.copyWith(currentHymn: hymn, isPlaying: true);
      return true; // Success!

    } catch (e) {
      debugPrint("Error playing audio: $e");
      return false; 
    }
  }

  Future<void> togglePlay() async {
    if (state.currentHymn == null) return;
    state.isPlaying ? await _player.pause() : await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
    // Setting currentHymn to null hides the MiniPlayer
    state = AudioState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}