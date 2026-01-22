import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class HymnMidiPlayer extends StatefulWidget {
  final String midiUrl; // Path to asset (e.g., 'assets/audio/hymns/100.mid')
  final String hymnTitle;
  final String hymnNumber;

  const HymnMidiPlayer({
    super.key,
    required this.midiUrl,
    required this.hymnTitle,
    required this.hymnNumber,
  });

  @override
  State<HymnMidiPlayer> createState() => _HymnMidiPlayerState();
}

class _HymnMidiPlayerState extends State<HymnMidiPlayer> {
  late AudioPlayer _player;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // ✅ Set the Audio Source with Metadata (This shows in Notification Bar)
      await _player.setAudioSource(
        AudioSource.asset(
          widget.midiUrl,
          tag: MediaItem(
            id: widget.hymnNumber,
            album: "Advent Hymnal",
            title: widget.hymnTitle,
            artUri: Uri.parse("https://example.com/icon.png"), // Optional: Add app icon URL here
          ),
        ),
      );
      if (mounted) setState(() => _isPlayerReady = true);
    } catch (e) {
      print("Error loading MIDI: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose(); // Stop playing when user leaves the screen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If MIDI isn't ready or doesn't exist, hide the player
    if (!_isPlayerReady) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Progress Bar
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;
              
              return Column(
                children: [
                  Slider(
                    value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
                    max: duration.inSeconds.toDouble(),
                    onChanged: (value) {
                      _player.seek(Duration(seconds: value.toInt()));
                    },
                    activeColor: Colors.teal,
                    inactiveColor: Colors.teal.withOpacity(0.2),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(fontSize: 12)),
                        Text(_formatDuration(duration), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Controls (Play / Pause / Replay)
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final processingState = state?.processingState;
              final playing = state?.playing ?? false;

              // ✅ LOGIC: If song finished, show Replay Button
              if (processingState == ProcessingState.completed) {
                return IconButton(
                  icon: const Icon(Icons.replay, size: 48, color: Colors.teal),
                  onPressed: () {
                    _player.seek(Duration.zero);
                    _player.play();
                  },
                );
              }

              // Loading State
              if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                return const CircularProgressIndicator();
              }

              // Play/Pause State
              return IconButton(
                icon: Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 54,
                  color: Colors.teal,
                ),
                onPressed: () {
                  if (playing) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
              );
            },
          ),
          const SizedBox(height: 10),
          const Text("Backing Track", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}