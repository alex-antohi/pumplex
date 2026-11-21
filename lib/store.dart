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
  static const _bodyKey = 'game_body_v1';

  /// Backup field -> storage key, kept from the old tracking system.
  static const _legacy = {'logs': 'logs_v2', 'swaps': 'swaps_v2'};

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final List<Session> _oldSessions = [];
  final List<GameSession> _sessions = [];
  final List<BodyEntry> _body = [];
  Profile? _profile;
  GameSession? _open;

  void _load() {
    _body
      ..clear()
      ..addAll([
        for (final b in jsonDecode(_prefs.getString(_bodyKey) ?? '[]') as List)
          BodyEntry.fromJson(Map<String, dynamic>.from(b as Map)),
      ]);
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

  /// Every saved change of the body sliders, oldest first (for charts later).
  List<BodyEntry> get bodyHistory => List.unmodifiable(_body);

  /// Saves the setup. A changed body is added to [bodyHistory].
  ///
  /// A new class or difficulty applies to today's workout only while it has
  /// no sets yet (the plan is made again). Once sets are marked, today's
  /// session keeps the class and difficulty it started with, so its XP
  /// stays the same; the change shows from the next day.
  void setProfile(Profile p) {
    _profile = p;
    _prefs.setString(_profileKey, jsonEncode(p.toJson()));
    if (_body.isEmpty || _body.last.character != p.character) {
      _body.add(BodyEntry(atMs: _clock().millisecondsSinceEpoch, character: p.character));
      _prefs.setString(_bodyKey, jsonEncode([for (final b in _body) b.toJson()]));
    }
    final o = _open;
    if (o != null &&
        o.totalSets == 0 &&
        (o.classId != p.classId || o.difficultyId != p.difficultyId)) {
      _open = null;
      _saveGame();
    }
    notifyListeners();
  }

  GameClass get gameClass => classById(_profile?.classId);
  int get difficulty => difficultyIndex(_profile?.difficultyId);

  // ------------------------------------------------------------- sessions

  /// Days from the old app (read-only).
  List<Session> get oldSessions => List.unmodifiable(_oldSessions);

  /// Closed game sessions, oldest first.
  List<GameSession> get sessions => List.unmodifiable(_sessions);

  /// Today's session, once something was marked or changed today.
  GameSession? get open => _open;

  String get _today => dateKey(_clock());

  /// Today's session (null before the first mark or change of the day).
  GameSession? get todaySession => _open?.day == _today ? _open : null;

  /// Applies the session rule (lib/game/rules.dart) when the app is opened
  /// or comes back from the background. Returns the session it banked
  /// (null if none, or if it had no sets).
  GameSession? onAppOpened() => _closeIfOver();

  /// ONE SESSION PER CALENDAR DAY: the session of an earlier day closes.
  /// A session with no sets is a skipped day and is not kept.
  GameSession? _closeIfOver() {
    final o = _open;
    if (o == null || o.day == _today) return null;
    _open = null;
    if (o.totalSets > 0) _sessions.add(o);
    _saveGame();
    notifyListeners();
    return o.totalSets > 0 ? o : null;
  }

  /// The first workout of a day: [workoutSize] exercises from the class
  /// pool, starting at a place that moves on each day.
  static List<Slot> planFor(GameClass c, int difficulty, String day) {
    final pool = c.exercises;
    final n = workoutSize(difficulty).clamp(1, pool.length);
    final start = daysBetween(DateTime(2026), parseDateKey(day)).abs() % pool.length;
    return [
      for (var i = 0; i < n; i++)
        Slot(exerciseId: pool[(start + i) % pool.length].id, initialId: pool[(start + i) % pool.length].id),
    ];
  }

  /// Today's workout: the open session's exercises, or a new plan.
  List<Slot> get todaySlots {
    final o = _open;
    if (o != null && o.day == _today) return o.slots;
    return planFor(gameClass, difficulty, _today);
  }

  /// Working sets on card [i] of today's workout.
  int setsAt(int i) => i < todaySlots.length ? todaySlots[i].sets : 0;

  /// Applies [edit] to today's slots, opening today's session if needed.
  void _edit(List<Slot> Function(List<Slot> slots) edit) {
    _closeIfOver();
    final now = _clock().millisecondsSinceEpoch;
    final o = _open ??
        GameSession(
          day: _today,
          startMs: now,
          endMs: now,
          classId: gameClass.id,
          difficultyId: difficulties[difficulty].id,
          slots: planFor(gameClass, difficulty, _today),
        );
    _open = o.copyWith(endMs: now, slots: edit([...o.slots]));
    _saveGame();
    notifyListeners();
  }

  GameClass get _todayClass => classById(_open?.day == _today ? _open!.classId : gameClass.id);

  /// Tap on card [i]: one more working set.
  void addSet(int i) => _edit((s) => s..[i] = s[i].copyWith(sets: s[i].sets + 1));

  /// Long-press on card [i]: one working set less (for a wrong tap).
  void removeSet(int i) {
    if (setsAt(i) == 0) return;
    _edit((s) => s..[i] = s[i].copyWith(sets: s[i].sets - 1));
  }

  /// Class pool exercises not on any card yet.
  List<Exercise> get unusedExercises {
    final used = todaySlots.map((s) => s.exerciseId).toSet();
    return [for (final e in _todayClass.exercises) if (!used.contains(e.id)) e];
  }

  /// Swipe on card [i]: the next (or, [dir] < 0, previous) pool exercise
  /// that is not on another card. Only on a card with no sets. False if
  /// nothing changed.
  bool swap(int i, int dir) {
    final slots = todaySlots;
    if (i >= slots.length || slots[i].sets > 0) return false;
    final pool = _todayClass.exercises;
    final used = {for (final (k, s) in slots.indexed) if (k != i) s.exerciseId};
    var at = pool.indexWhere((e) => e.id == slots[i].exerciseId);
    for (var step = 0; step < pool.length; step++) {
      at = (at + (dir < 0 ? -1 : 1)) % pool.length;
      if (at < 0) at += pool.length;
      final id = pool[at].id;
      if (id == slots[i].exerciseId) return false;
      if (!used.contains(id)) {
        _edit((s) => s..[i] = s[i].copyWith(exerciseId: id));
        return true;
      }
    }
    return false;
  }

  /// Card [i] goes back to the exercise the workout first gave.
  bool resetSlot(int i) {
    final slots = todaySlots;
    if (i >= slots.length || !slots[i].switched || slots[i].sets > 0) return false;
    final initial = slots[i].initialId!;
    final other = slots.indexWhere((s) => s.exerciseId == initial);
    _edit((s) {
      // If that exercise sits on another empty card, the two cards trade.
      if (other >= 0 && s[other].sets == 0) s[other] = s[other].copyWith(exerciseId: s[i].exerciseId);
      return s..[i] = s[i].copyWith(exerciseId: initial);
    });
    return true;
  }

  /// Adds a card for pool exercise [exerciseId].
  void addExercise(String exerciseId) =>
      _edit((s) => s..add(Slot(exerciseId: exerciseId)));

  /// Removes card [i]. Only a card with no sets (take the sets away first).
  bool removeSlot(int i) {
    if (i >= todaySlots.length || setsAt(i) > 0) return false;
    _edit((s) => s..removeAt(i));
    return true;
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
          'body': [for (final b in _body) b.toJson()],
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
    final body = [
      for (final b in game['body'] as List? ?? const [])
        BodyEntry.fromJson(Map<String, dynamic>.from(b as Map)),
    ];
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
    await _prefs.setString(_bodyKey, jsonEncode([for (final b in body) b.toJson()]));
    open == null
        ? await _prefs.remove(_openKey)
        : await _prefs.setString(_openKey, jsonEncode(open.toJson()));
    _load();
    notifyListeners();
  }
}
