import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'game/content.dart';
import 'game/model.dart';
import 'game/rules.dart';

/// Everything the app remembers, on the phone only (shared_preferences).
/// The keys and formats are in lib/game/model.dart (docs/data-schema.md).
class LogStore extends ChangeNotifier {
  LogStore(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _load();
    _migrateIds();
    _freezeStreakXp();
    removedKeys.forEach(_prefs.remove);
  }

  static const _profileKey = 'profile_v1';
  static const _bodyKey = 'body_history_v1';
  static const _sessionsKey = 'sessions_v3';
  static const _xpKey = 'xp_events_v1';

  /// Keys of removed features, deleted on start: achievements (D35; the XP
  /// they gave stays as saved `achievement` XP events), gear (D38), chaos
  /// mode (D39), cel shader (D40) and sound (D41).
  static const removedKeys = ['achievements_v1', 'gear_v1', 'chaos', 'cel', 'sound'];

  /// Set once the streak bonus of every session is saved as XP events (D34).
  static const streakFrozenKey = 'streak_xp_frozen_v1';

  /// Copy of the profile and sessions as they were before the class id
  /// migration (D31) and the area id migration (D36), kept on the phone.
  static const classIdBackupKey = 'class_ids_v0_backup';
  static const areaIdBackupKey = 'area_ids_v0_backup';

  /// Keys of the old app (deleted by the one-time migration).
  static const oldKeys = ['sessions_v2', 'logs_v2', 'swaps_v2', 'session_started_ms'];
  static const oldKeyPrefix = 'snooze2_';

  static bool _isOldKey(String k) => oldKeys.contains(k) || k.startsWith(oldKeyPrefix);

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  Profile? _profile;
  final List<BodyChange> _body = [];
  final Map<String, Session> _sessions = {};
  final List<XpEvent> _events = [];

  dynamic _json(String key, Object fallback) {
    final raw = _prefs.getString(key);
    return raw == null ? fallback : jsonDecode(raw);
  }

  /// One-time: saved data with old class ids (speedy, rogue, warrior, mage;
  /// D31) or old area ids (beach, castle, summit; D36) is written back with
  /// the design ids. _load already maps the ids; this keeps a copy of the
  /// old text first, then saves the new text.
  void _migrateIds() {
    final rawProfile = _prefs.getString(_profileKey) ?? '';
    final rawSessions = _prefs.getString(_sessionsKey) ?? '';
    bool has(RegExp old) => old.hasMatch(rawProfile) || old.hasMatch(rawSessions);
    final oldClass = has(RegExp('"(${oldClassIds.keys.join('|')})[".]'));
    final oldArea = has(RegExp('"areaId": ?"(${oldAreaIds.keys.join('|')})"'));
    if (!oldClass && !oldArea) return;
    final copy = jsonEncode({'profile': rawProfile, 'sessions': rawSessions});
    for (final (old, key) in [(oldClass, classIdBackupKey), (oldArea, areaIdBackupKey)]) {
      if (old && !_prefs.containsKey(key)) _prefs.setString(key, copy);
    }
    if (_profile != null) _prefs.setString(_profileKey, jsonEncode(_profile!.toJson()));
    _saveSessions();
  }

  /// One-time (D34): the streak is gone. The streak bonus each session had
  /// is saved as a `streak` XP event, so no one loses XP.
  void _freezeStreakXp() {
    if (_prefs.getBool(streakFrozenKey) ?? false) return;
    final known = {for (final e in _events) if (e.source == 'streak') e.ref};
    _events.addAll(_oldStreakEvents(_sessions.values).where((e) => !known.contains(e.ref)));
    _saveEvents();
    _prefs.setBool(streakFrozenKey, true);
  }

  /// The streak bonus of each session, by the rules before D34: a week with
  /// N training days (N by difficulty: 2, 2, 2, 3, 3, 4) is a streak week; a
  /// session gets +5% set XP per streak week in a row before its week, at
  /// most +25%, rounded set by set.
  static List<XpEvent> _oldStreakEvents(Iterable<Session> all) {
    const streakN = [2, 2, 2, 3, 3, 4];
    String weekOf(String date) {
      final d = parseDateKey(date);
      return dateKey(addDays(d, 1 - d.weekday));
    }

    String before(String w) => dateKey(addDays(parseDateKey(w), -7));
    final played = all.where((s) => !s.legacy && s.totalSets > 0).toList()..sort((a, b) => a.date.compareTo(b.date));
    final weeks = <String, ({int days, int n})>{};
    for (final s in played) {
      final w = weekOf(s.date);
      weeks[w] = (days: (weeks[w]?.days ?? 0) + 1, n: streakN[difficultyIndex(s.difficultyId).clamp(0, 5)]);
    }
    bool met(String w) => (weeks[w]?.days ?? 0) >= (weeks[w]?.n ?? 999);
    final out = <XpEvent>[];
    for (final s in played) {
      var run = 0;
      for (var w = before(weekOf(s.date)); met(w); w = before(w)) {
        run++;
      }
      if (run == 0) continue;
      final mult = 1 + min(0.25, 0.05 * run);
      final d = difficultyIndex(s.difficultyId);
      var bonus = 0;
      for (final e in s.exercises) {
        for (var n = 1; n <= e.sets; n++) {
          final xp = setXp(setNumber: n, target: e.targetSets, difficulty: d, critical: isCritical(s.date, e.exerciseId, n));
          bonus += (xp * mult).round() - xp.round();
        }
      }
      if (bonus > 0) out.add(XpEvent(at: s.lastMarkAt ?? '${s.date}T00:00:00', source: 'streak', amount: bonus, ref: s.date));
    }
    return out;
  }

  void _load() {
    final p = _json(_profileKey, const {}) as Map;
    _profile = p.isEmpty ? null : Profile.fromJson(Map<String, dynamic>.from(p));
    _body
      ..clear()
      ..addAll([
        for (final b in _json(_bodyKey, const []) as List) BodyChange.fromJson(Map<String, dynamic>.from(b as Map)),
      ]);
    _sessions
      ..clear()
      ..addAll({
        for (final e in (_json(_sessionsKey, const {}) as Map).entries)
          e.key as String: Session.fromJson(e.key as String, Map<String, dynamic>.from(e.value as Map)),
      });
    _events
      ..clear()
      ..addAll([
        for (final e in _json(_xpKey, const []) as List) XpEvent.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);
  }

  String get _now => isoNow(_clock());
  String get _today => dateKey(_clock());

  /// Sessions as saved: date -> session.
  static Map<String, Object?> _sessionsJson(Iterable<Session> sessions) =>
      {for (final s in sessions) s.date: s.toJson()};

  void _saveSessions() => _prefs.setString(_sessionsKey, jsonEncode(_sessionsJson(_sessions.values)));
  void _saveEvents() => _prefs.setString(_xpKey, jsonEncode([for (final e in _events) e.toJson()]));

  // ------------------------------------------------------------- old data

  /// True while the old app's data is still on the phone (before the
  /// one-time migration, docs/data-schema.md §5).
  bool get hasOldData => _prefs.getKeys().any(_isOldKey);

  /// Old workout days still waiting for the migration (for the screen text).
  int get oldWorkoutCount => _oldWorkoutDates(_json('sessions_v2', const []) as List).length;

  /// Step 1 of the migration: the old data as a version-2 backup file,
  /// with every old key (extra keys under `raw`).
  String oldBackupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': 2,
        'sessions': _json('sessions_v2', const []),
        'logs': _json('logs_v2', const {}),
        'swaps': _json('swaps_v2', const {}),
        'raw': {
          for (final k in _prefs.getKeys())
            if (_isOldKey(k)) k: _prefs.get(k),
        },
      });

  /// Dates of old workout days (rest days dropped, one per date).
  static Set<String> _oldWorkoutDates(List raw) => {
        for (final s in raw)
          if (s is Map && s['rested'] != true && s['date'] is String) s['date'] as String,
      };

  /// Old sessions -> legacy sessions + one legacy XP event each.
  static (List<Session>, List<XpEvent>) _convertOld(List raw) {
    String? iso(Object? ms) => ms is num ? isoNow(DateTime.fromMillisecondsSinceEpoch(ms.toInt())) : null;
    final byDate = <String, Session>{};
    for (final s in raw) {
      if (s is! Map || s['rested'] == true || s['date'] is! String) continue;
      final date = s['date'] as String;
      final had = byDate[date];
      byDate[date] = Session(
        date: date,
        classId: '',
        difficultyId: '',
        areaId: '',
        legacy: true,
        firstMarkAt: had?.firstMarkAt ?? iso(s['startMs']),
        lastMarkAt: iso(s['endMs']) ?? had?.lastMarkAt,
      );
    }
    final sessions = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return (
      sessions,
      [
        for (final s in sessions)
          XpEvent(at: '${s.date}T00:00:00', source: 'legacy', amount: xpPerLegacySession, ref: s.date),
      ],
    );
  }

  /// Steps 2-5 of the migration. Call it only after the backup file from
  /// [oldBackupJson] was saved.
  Future<void> migrateOld() async {
    final (legacy, events) = _convertOld(_json('sessions_v2', const []) as List);
    for (final s in legacy) {
      _sessions.putIfAbsent(s.date, () => s);
    }
    final known = {for (final e in _events) if (e.source == 'legacy') e.ref};
    _events.addAll(events.where((e) => !known.contains(e.ref)));
    _saveSessions();
    _saveEvents();
    for (final k in _prefs.getKeys().toList()) {
      if (_isOldKey(k)) await _prefs.remove(k);
    }
    notifyListeners();
  }

  // -------------------------------------------------------------- profile

  /// Null until the initial setup is done.
  Profile? get profile => _profile;

  GameClass get gameClass => classById(_profile?.classId);
  int get difficulty => difficultyIndex(_profile?.difficultyId);

  /// Every saved body change, oldest first (for charts later).
  List<BodyChange> get bodyHistory => List.unmodifiable(_body);

  /// Saves the setup. A changed body goes into [bodyHistory].
  ///
  /// Class, difficulty and area can change any time. Each session keeps
  /// the ones it was made with, so its XP never changes. Today's workout is
  /// made again with the new choices only while it has no sets.
  void setProfile(Profile p) {
    final first = _profile;
    final saved = p.copyWith(createdAt: first?.createdAt.isNotEmpty == true ? first!.createdAt : _now);
    _profile = saved;
    _prefs.setString(_profileKey, jsonEncode(saved.toJson()));
    if (_body.isEmpty || !_body.last.character.sameBody(p.character)) {
      _body.add(BodyChange(at: _now, character: p.character));
      _prefs.setString(_bodyKey, jsonEncode([for (final b in _body) b.toJson()]));
    }
    final t = _sessions[_today];
    if (t != null &&
        !t.legacy &&
        t.totalSets == 0 &&
        (t.classId != p.classId || t.difficultyId != p.difficultyId || t.areaId != p.areaId)) {
      _sessions.remove(_today);
      _saveSessions();
    } else if (t != null && !t.legacy && t.areaId != p.areaId) {
      // The area is only the look and the marks (no XP): a change shows on
      // today's workout at once, also after sets (D55).
      _sessions[_today] = t.copyWith(areaId: p.areaId);
      _saveSessions();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- sessions

  /// Every session (legacy too), by date.
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);

  /// Training days, newest first (skipped days are not shown).
  List<Session> get history =>
      _sessions.values.where((s) => s.trained).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// Today's session, once something was marked or changed today.
  Session? get todaySession {
    final s = _sessions[_today];
    return s == null || s.legacy ? null : s;
  }

  /// The first workout of a day: `exercisesPerWorkout` exercises from the
  /// class pool, starting at a place that moves on each day.
  static List<SessionExercise> planFor(GameClass c, int difficulty, String day) {
    final pool = c.exercises;
    final r = rulesFor(difficulty);
    final n = r.exercisesPerWorkout.clamp(1, pool.length);
    final start = daysBetween(DateTime(2026), parseDateKey(day)).abs() % pool.length;
    final ids = [for (var i = 0; i < n; i++) pool[(start + i) % pool.length].id];
    return [
      for (final (i, id) in ids.indexed)
        SessionExercise(position: i, exerciseId: id, originalExerciseId: id, targetSets: r.targetSets),
    ];
  }

  /// Today's workout (all entries; sessions from before D32 may have
  /// removed ones: use the index of this list for the set calls). A new
  /// plan until something is done today.
  List<SessionExercise> get todayExercises =>
      todaySession?.exercises ?? planFor(gameClass, difficulty, _today);

  /// Indexes of [todayExercises] shown as cards (not removed).
  List<int> get todayCards => [
        for (final (i, e) in todayExercises.indexed)
          if (!e.removed) i,
      ];

  void _edit(List<SessionExercise> Function(List<SessionExercise> list) edit) {
    final s = todaySession ??
        Session(
          date: _today,
          classId: gameClass.id,
          difficultyId: difficulties[difficulty].id,
          areaId: areaById(_profile?.areaId).id,
          exercises: planFor(gameClass, difficulty, _today),
        );
    _sessions[_today] = s.copyWith(lastMarkAt: _now, exercises: edit([...s.exercises]));
    _saveSessions();
    notifyListeners();
  }

  /// Tap on card [i]: one more working set.
  void addSet(int i) => _edit((l) => l..[i] = l[i].copyWith(sets: l[i].sets + 1));

  /// Long-press on card [i]: one working set less (for a wrong tap).
  void removeSet(int i) {
    if (todayExercises[i].sets == 0) return;
    _edit((l) => l..[i] = l[i].copyWith(sets: l[i].sets - 1));
  }

  // ------------------------------------------------------------------- XP

  /// XP of one exercise in a session (docs/rules.md §1, set by set).
  static int _exerciseXp(Session s, SessionExercise e) {
    final d = difficultyIndex(s.difficultyId);
    var xp = 0;
    for (var n = 1; n <= e.sets; n++) {
      xp += xpForSet(
        setNumber: n,
        target: e.targetSets,
        difficulty: d,
        critical: isCritical(s.date, e.exerciseId, n),
      );
    }
    return xp;
  }

  /// A session's set XP.
  static int _setsXp(Session s) => s.exercises.fold(0, (a, e) => a + _exerciseXp(s, e));

  /// All XP events: the saved ones (legacy, and the old streak and
  /// achievement XP) and the computed ones (sets, day = first set of the
  /// day). See lib/game/model.dart.
  List<XpEvent> get xpEvents {
    final out = [..._events];
    for (final s in _sessions.values) {
      if (s.legacy || s.totalSets == 0) continue;
      final at = s.lastMarkAt ?? '${s.date}T00:00:00';
      out.add(XpEvent(at: at, source: 'sets', amount: _setsXp(s), ref: s.date));
      out.add(XpEvent(at: s.firstMarkAt ?? at, source: 'day', amount: xpFirstSetOfDay, ref: s.date));
    }
    return out;
  }

  int get totalXp => xpEvents.fold(0, (a, e) => a + e.amount);

  /// XP a session brought: sets and the first-set bonus, plus its saved
  /// events (legacy: the old-app day; old streak bonus).
  int xpOfSession(Session s) {
    final saved = _events
        .where((e) => e.ref == s.date && (e.source == 'legacy' || e.source == 'streak'))
        .fold(0, (a, e) => a + e.amount);
    if (s.legacy || s.totalSets == 0) return saved;
    return _setsXp(s) + xpFirstSetOfDay + saved;
  }

  /// XP of today's card [i] so far (with criticals).
  int cardXp(int i) {
    final s = todaySession;
    if (s == null) return 0;
    return _exerciseXp(s, s.exercises[i]);
  }

  /// Whether the last set on today's card [i] was a critical set.
  bool lastSetCritical(int i) {
    final s = todaySession;
    if (s == null) return false;
    final e = s.exercises[i];
    return e.sets > 0 && e.sets <= e.targetSets * overTargetCap && isCritical(s.date, e.exerciseId, e.sets);
  }

  // ----------------------------------------------------------------- backup

  /// 4: no achievements, and the old streak XP is in the XP events (D34).
  /// 5: no gear (D38).
  static const backupVersion = 5;

  /// Backup file contents: every key of docs/data-schema.md §4.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': backupVersion,
        if (_profile != null) _profileKey: _profile!.toJson(),
        _bodyKey: [for (final b in _body) b.toJson()],
        _sessionsKey: _sessionsJson(_sessions.values),
        _xpKey: [for (final e in _events) e.toJson()],
      });

  /// Replaces everything with a backup file. Version 5 is [backupJson].
  /// Versions 3 and 4 may hold achievements or gear (ignored); version 3
  /// has no saved streak XP (worked out again on import). Version 2 (the old app) goes through the same migration: its workout
  /// days become legacy sessions with legacy XP; there is no profile, so
  /// the setup runs again.
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || ![2, 3, 4, 5].contains(data['version'])) {
      throw const FormatException('Not a PUMPLEX backup');
    }
    // Parse everything before touching current data.
    final Map<String, String> out;
    if (data['version'] == 2) {
      final (sessions, events) = _convertOld(data['sessions'] as List? ?? const []);
      out = {
        _sessionsKey: jsonEncode(_sessionsJson(sessions)),
        _xpKey: jsonEncode([for (final e in events) e.toJson()]),
      };
    } else {
      final p = data[_profileKey];
      if (p is Map) Profile.fromJson(Map<String, dynamic>.from(p));
      for (final e in (data[_sessionsKey] as Map? ?? const {}).entries) {
        Session.fromJson(e.key as String, Map<String, dynamic>.from(e.value as Map));
      }
      for (final e in data[_xpKey] as List? ?? const []) {
        XpEvent.fromJson(Map<String, dynamic>.from(e as Map));
      }
      for (final b in data[_bodyKey] as List? ?? const []) {
        BodyChange.fromJson(Map<String, dynamic>.from(b as Map));
      }
      out = {
        if (p is Map) _profileKey: jsonEncode(p),
        _bodyKey: jsonEncode(data[_bodyKey] ?? const []),
        _sessionsKey: jsonEncode(data[_sessionsKey] ?? const {}),
        _xpKey: jsonEncode(data[_xpKey] ?? const []),
      };
    }
    for (final k in [_profileKey, _bodyKey, _sessionsKey, _xpKey]) {
      out.containsKey(k) ? await _prefs.setString(k, out[k]!) : await _prefs.remove(k);
    }
    await _prefs.setBool(streakFrozenKey, (data['version'] as int) >= 4);
    // Old-app keys on this phone are left alone: only the migration deletes
    // them, after its own backup file.
    _load();
    _migrateIds();
    _freezeStreakXp();
    notifyListeners();
  }
}
