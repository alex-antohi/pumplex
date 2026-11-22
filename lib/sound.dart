// The design team's sound pack (docs/moodboard/sounds, copied to
// assets/sounds). Played with the audioplayers package (owner OK,
// 22 Nov 2026, exception to D26). The SOUND toggle in the menu turns it off.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound ids = file names in assets/sounds without `.wav`.
abstract final class Sfx {
  /// True once main() runs (the real app, not a test).
  static bool ready = false;

  /// False in tests and while the user has sound off.
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

  /// The set sound of an area (riptide, gainsgard, rustbelt, arcade, frostbite).
  static void set(String areaId) => play('set_$areaId');
}
