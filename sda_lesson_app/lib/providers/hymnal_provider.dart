import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

class Hymn {
  final int id;
  final String title;
  final String lyrics;
  final String topic;

  Hymn({
    required this.id,
    required this.title,
    required this.lyrics,
    required this.topic,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) => Hymn(
    id: json['id'],
    title: json['title'],
    lyrics: json['lyrics'],
    topic: json['topic'] ?? "General",
  );
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

// --- 1. BASE DATA PROVIDER ---
final allHymnsProvider = FutureProvider<List<Hymn>>((ref) async {
  final String response = await rootBundle.loadString('assets/hymns.json');
  final List<dynamic> data = json.decode(response);
  return data.map((json) => Hymn.fromJson(json)).toList();
});

// --- 2. UI STATE PROVIDERS ---
final hymnSearchProvider = StateProvider<String>((ref) => "");
final hymnSortModeProvider = StateProvider<String>((ref) => 'Numerical');
final hymnFontSizeProvider = StateProvider<double>((ref) => 18.0);

// --- 3. LOGIC PROVIDER ---
final filteredHymnsProvider = Provider<AsyncValue<List<Hymn>>>((ref) {
  final allHymnsAsync = ref.watch(allHymnsProvider);
  final search = ref.watch(hymnSearchProvider).toLowerCase();
  final sortMode = ref.watch(hymnSortModeProvider);

  return allHymnsAsync.whenData((hymns) {
    List<Hymn> filtered = hymns.where((h) {
      return h.id.toString().contains(search) ||
          h.title.toLowerCase().contains(search);
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

    // Safety: Reset state when audio finishes
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
        // Using setSourceAsset to better handle potential missing files
        await _player.play(AssetSource('audio/hymn_${hymn.id}.mp3'));
      }
    } catch (e) {
      // If file doesn't exist, reset the player state so UI doesn't hang
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
