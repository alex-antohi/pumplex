import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'game/content.dart';
import 'game/model.dart';
import 'game/rules.dart';

/// A day from the OLD app (7-day pattern, "I WORKED" / "I RESTED"), read
/// from `sessions_v2`. Read-only now: it shows in history and gives beta XP.
class Session {
  const Session({
    required this.day,
    required this.date,
    required this.rested,
    this.startMs,
    this.endMs,
  });

  /// Old program day 1..7.
  final int day;

  /// yyyy-MM-dd it was marked done.
  final String date;
  final bool rested;

  /// Old START TRAINING and I WORKED times (epoch ms), if the clock was used.
  final int? startMs;
  final int? endMs;

  Duration? get duration =>
      startMs == null || endMs == null ? null : Duration(milliseconds: endMs! - startMs!);

  Map<String, dynamic> toJson() => {
        'day': day,
        'date': date,
        'rested': rested,
        if (startMs != null) 'startMs': startMs,
        if (endMs != null) 'endMs': endMs,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        day: (j['day'] as num).toInt(),
        date: j['date'] as String,
        rested: j['rested'] as bool? ?? false,
        startMs: (j['startMs'] as num?)?.toInt(),
        endMs: (j['endMs'] as num?)?.toInt(),
      );
}

/// Everything the app remembers, on the phone only (shared_preferences).
///
/// - The game: profile, closed sessions and the open session
///   (see lib/game/model.dart for the keys and the format).
/// - The old app's data (`sessions_v2`, `logs_v2`, `swaps_v2`): never
///   changed here, kept in backups as it is.
class LogStore extends ChangeNotifier {
  LogStore(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        chaos = ValueNotifier(_prefs.getBool('chaos') ?? false),
        cel = ValueNotifier(_prefs.getBool('cel') ?? false) {
    _load();
  }

  static const _oldSessionsKey = 'sessions_v2';
  static const _profileKey = 'game_profile_v1';
  static const _gameSessionsKey = 'game_sessions_v1';
  static const _openKey = 'game_open_v1';

  /// Backup field -> storage key, kept from the old tracking system.
  static const _legacy = {'logs': 'logs_v2', 'swaps': 'swaps_v2'};

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final List<Session> _oldSessions = [];
  final List<GameSession> _sessions = [];
  Profile? _profile;
  GameSession? _open;

  void _load() {
    _oldSessions
      ..clear()
      ..addAll(_parseOld(_prefs.getString(_oldSessionsKey)));
    _sessions
      ..clear()
      ..addAll(_parseGame(_prefs.getString(_gameSessionsKey)));
    final p = _prefs.getString(_profileKey);
    _profile = p == null ? null : Profile.fromJson(Map<String, dynamic>.from(jsonDecode(p) as Map));
    final o = _prefs.getString(_openKey);
    _open = o == null ? null : GameSession.fromJson(Map<String, dynamic>.from(jsonDecode(o) as Map));
  }

  // ------------------------------------------------------------- settings

  /// Chaos mode (hue-cycling), remembered between launches.
  final ValueNotifier<bool> chaos;

  void setChaos(bool on) {
    chaos.value = on;
    _prefs.setBool('chaos', on);
  }

  /// Cel shader mode (toon bands + ink outlines), remembered between launches.
  final ValueNotifier<bool> cel;

  void setCel(bool on) {
    cel.value = on;
    _prefs.setBool('cel', on);
  }

  // -------------------------------------------------------------- profile

  /// Null until the initial setup is done.
  Profile? get profile => _profile;

  void setProfile(Profile p) {
    _profile = p;
    _prefs.setString(_profileKey, jsonEncode(p.toJson()));
    notifyListeners();
  }

  GameClass get gameClass => classById(_profile?.classId);
  int get difficulty => difficultyIndex(_profile?.difficultyId);

  // ------------------------------------------------------------- sessions

  /// Days from the old app (read-only).
  List<Session> get oldSessions => List.unmodifiable(_oldSessions);

  /// Closed game sessions, oldest first.
  List<GameSession> get sessions => List.unmodifiable(_sessions);

  /// The session being trained now, if any.
  GameSession? get open => _open;

  /// Working sets for [exerciseId] in the open session.
  int setsOf(String exerciseId) => _open?.sets[exerciseId] ?? 0;

  /// Applies the session rule (lib/game/rules.dart) when the app is opened
  /// or comes back from the background. Returns the session it closed.
  GameSession? onAppOpened() => _closeIfOver(checkDay: true);

  GameSession? _closeIfOver({required bool checkDay}) {
    final o = _open;
    if (o == null) return null;
    final now = _clock();
    final idle = now.difference(o.end) >= sessionTimeout;
    final newDay = checkDay && daysBetween(o.end, now) > 0;
    if (!idle && !newDay) return null;
    _sessions.add(o);
    _open = null;
    _saveGame();
    notifyListeners();
    return o;
  }

  /// Tap on an exercise card: one more working set. Starts a session if
  /// none is open (or the open one timed out).
  void addSet(String exerciseId) {
    _closeIfOver(checkDay: false);
    final now = _clock().millisecondsSinceEpoch;
    final o = _open ??
        GameSession(
          startMs: now,
          endMs: now,
          classId: gameClass.id,
          difficultyId: difficulties[difficulty].id,
          sets: const {},
        );
    _open = o.copyWith(endMs: now, sets: {...o.sets, exerciseId: (o.sets[exerciseId] ?? 0) + 1});
    _saveGame();
    notifyListeners();
  }

  /// Long-press: one working set less (for a wrong tap). If no sets are
  /// left, the session did not happen. Does not count as a new mark.
  void removeSet(String exerciseId) {
    final o = _open;
    final n = o?.sets[exerciseId] ?? 0;
    if (o == null || n == 0) return;
    final sets = {...o.sets}..[exerciseId] = n - 1;
    sets.removeWhere((_, v) => v <= 0);
    _open = sets.isEmpty ? null : o.copyWith(sets: sets);
    _saveGame();
    notifyListeners();
  }

  // ------------------------------------------------------------------- XP

  static int xpOf(GameSession s) => xpForSets(s.totalSets, difficultyIndex(s.difficultyId));

  /// Beta: XP from the old app's sessions.
  int get oldXp => _oldSessions.fold<int>(
      0, (a, s) => a + (s.rested ? xpPerOldRestDay : xpPerOldWorkout));

  int get totalXp =>
      oldXp + _sessions.fold<int>(0, (a, s) => a + xpOf(s)) + (_open == null ? 0 : xpOf(_open!));

  // --------------------------------------------------------------- saving

  static List<Session> _parseOld(String? raw) => raw == null
      ? []
      : [
          for (final s in jsonDecode(raw) as List)
            Session.fromJson(Map<String, dynamic>.from(s as Map)),
        ];

  static List<GameSession> _parseGame(String? raw) => raw == null
      ? []
      : [
          for (final s in jsonDecode(raw) as List)
            GameSession.fromJson(Map<String, dynamic>.from(s as Map)),
        ];

  void _saveGame() {
    _prefs.setString(_gameSessionsKey, jsonEncode([for (final s in _sessions) s.toJson()]));
    final o = _open;
    o == null ? _prefs.remove(_openKey) : _prefs.setString(_openKey, jsonEncode(o.toJson()));
  }

  // ----------------------------------------------------------------- backup

  static const backupVersion = 3;

  /// Backup file contents: everything, the old data as it is.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': backupVersion,
        'sessions': [for (final s in _oldSessions) s.toJson()],
        for (final e in _legacy.entries)
          e.key: jsonDecode(_prefs.getString(e.value) ?? '{}'),
        'game': {
          if (_profile != null) 'profile': _profile!.toJson(),
          'sessions': [for (final s in _sessions) s.toJson()],
          if (_open != null) 'open': _open!.toJson(),
        },
      });

  /// Replaces everything with a backup made by [backupJson]. Also reads
  /// version 2 backups (the old app, before the game): those have no game
  /// data, so the initial setup runs again after the restore.
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || (data['version'] != 2 && data['version'] != 3)) {
      throw const FormatException('Not a PUMPLEX backup');
    }
    // Parse everything before touching current data.
    final old = _parseOld(jsonEncode(data['sessions'] ?? []));
    final legacy = {
      for (final e in _legacy.entries)
        e.value: data[e.key] is Map ? jsonEncode(data[e.key]) : null,
    };
    final game = data['game'] is Map ? Map<String, dynamic>.from(data['game'] as Map) : const {};
    final profile = game['profile'] is Map
        ? Profile.fromJson(Map<String, dynamic>.from(game['profile'] as Map))
        : null;
    final sessions = _parseGame(jsonEncode(game['sessions'] ?? []));
    final open = game['open'] is Map
        ? GameSession.fromJson(Map<String, dynamic>.from(game['open'] as Map))
        : null;

    await _prefs.setString(_oldSessionsKey, jsonEncode([for (final s in old) s.toJson()]));
    for (final e in legacy.entries) {
      e.value == null ? await _prefs.remove(e.key) : await _prefs.setString(e.key, e.value!);
    }
    profile == null
        ? await _prefs.remove(_profileKey)
        : await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString(_gameSessionsKey, jsonEncode([for (final s in sessions) s.toJson()]));
    open == null
        ? await _prefs.remove(_openKey)
        : await _prefs.setString(_openKey, jsonEncode(open.toJson()));
    _load();
    notifyListeners();
  }
}
