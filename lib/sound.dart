// The design team's sound pack (docs/moodboard/sounds, copied to
// assets/sounds). Played with the audioplayers package (owner OK,
// 22 Nov 2026, exception to D26). The SOUND toggle in the menu turns it off.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound ids = file names in assets/sounds without `.wav`.
abstract final class Sfx {
  /// Set by main() from the SOUND toggle. Stays false in tests (no audio
  /// plugin there).
  static bool enabled = false;

  static final _pool = <AudioPlayer>[];
  static var _next = 0;

  /// Up to 4 sounds at once (a set, a stamp and a level-up can overlap).
  static AudioPlayer _player() {
    if (_pool.length < 4) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
      return p;
    }
    return _pool[_next++ % _pool.length];
  }

  static void play(String id) {
    if (!enabled) return;
    try {
      final p = _player();
      p.stop().then((_) => p.play(AssetSource('sounds/$id.wav'))).catchError((Object e) {
        debugPrint('sound $id: $e');
      });
    } catch (e) {
      debugPrint('sound $id: $e');
    }
  }
}
