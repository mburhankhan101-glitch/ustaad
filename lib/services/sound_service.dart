// lib/services/sound_service.dart
//
// The half of the feedback loop the app was missing.
//
// Until now _confirmAnswer fired HapticService.selection() whether the answer
// was right or wrong. The screen showed a tick or a cross, but nothing the
// student *felt* differed, so the moment that is supposed to carry the whole
// reward loop carried nothing. This pairs a sound and a distinct haptic with
// each outcome.
//
// ── Two deliberate choices ──────────────────────────────────────────────────
//
// The wrong-answer sound is soft, not harsh. Students preparing for an entry
// test are wrong a great deal of the time — that is the point of practice —
// and a punishing buzz every time teaches them to put the phone down. Duolingo
// gets this right: its error sound is gentle and short. Ours should be too.
//
// A missing sound file is not an error. The service degrades to haptics alone
// and logs once, so the app ships and behaves correctly before anyone has
// recorded or licensed the audio.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'haptic_service.dart';

enum AnswerFeedback { correct, wrong }

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  /// Mirrors HapticService so one settings toggle can govern both.
  static bool _enabled = true;
  static void setEnabled(bool value) => _enabled = value;
  static bool get enabled => _enabled;

  /// One player per sound, kept alive and pre-loaded. Creating a player per
  /// tap is what makes feedback arrive late enough to feel disconnected from
  /// the tap that caused it.
  final _players = <AnswerFeedback, AudioPlayer>{};
  final _missing = <AnswerFeedback>{};
  bool _warmed = false;

  static const _assets = {
    AnswerFeedback.correct: 'sounds/correct.mp3',
    AnswerFeedback.wrong: 'sounds/wrong.mp3',
  };

  /// Call once when a quiz opens. Loading the asset at the first correct
  /// answer costs a noticeable delay on exactly the tap that matters most.
  Future<void> warmUp() async {
    if (_warmed) return;
    _warmed = true;

    for (final entry in _assets.entries) {
      try {
        final player = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource(entry.value));
        _players[entry.key] = player;
      } catch (e) {
        // No file yet, or an unreadable one. Haptics still fire.
        _missing.add(entry.key);
        debugPrint(
          '[Sound] ${entry.value} unavailable, haptics only for '
          '${entry.key.name}: $e',
        );
      }
    }
  }

  /// The feedback for one answered question. Always fires a haptic, plays a
  /// sound when there is one, and never throws into the caller — a failed
  /// sound must not interrupt a quiz.
  Future<void> play(AnswerFeedback feedback) async {
    // Distinct by touch alone, which is what makes this work with the phone
    // on silent, in a classroom, or before any audio file exists.
    switch (feedback) {
      case AnswerFeedback.correct:
        HapticService.subtle();
      case AnswerFeedback.wrong:
        HapticService.prominent();
    }

    if (!_enabled) return;

    final player = _players[feedback];
    if (player == null) return;

    try {
      await player.stop();
      await player.resume();
    } catch (e) {
      debugPrint('[Sound] playback failed for ${feedback.name}: $e');
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
    _warmed = false;
  }
}
