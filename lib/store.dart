import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'game/content.dart';
import 'game/model.dart';
import 'game/rules.dart';

/// Something new to celebrate (an achievement or a gear item).
typedef Unlock = ({String title, String name, String sub});

/// Everything the app remembers, on the phone only (shared_preferences).
/// The keys and formats are in lib/game/model.dart (docs/data-schema.md).
class LogStore extends ChangeNotifier {
  LogStore(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        chaos = ValueNotifier(_prefs.getBool('chaos') ?? false),
        cel = ValueNotifier(_prefs.getBool('cel') ?? false) {
    _load();
  }

  static const _profileKey = 'profile_v1';
  static const _bodyKey = 'body_history_v1';
  static const _sessionsKey = 'sessions_v3';
  static const _xpKey = 'xp_events_v1';
  static const _achievementsKey = 'achievements_v1';
  static const _gearKey = 'gear_v1';

  /// Keys of the old app (deleted by the one-time migration).
  static const oldKeys = ['sessions_v2', 'logs_v2', 'swaps_v2', 'session_started_ms'];
  static const oldKeyPrefix = 'snooze2_';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  Profile? _profile;
  final List<BodyChange> _body = [];
  final Map<String, Session> _sessions = {};
  final List<XpEvent> _events = [];
  final Map<String, String> _achievements = {};
  Gear _gear = const Gear();
  final List<Unlock> _unlocks = [];

  dynamic _json(String key, Object fallback) {
    final raw = _prefs.getString(key);
    return raw == null ? fallback : jsonDecode(raw);
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
    _achievements
      ..clear()
      ..addAll(Map<String, String>.from(_json(_achievementsKey, const {}) as Map));
    _gear = Gear.fromJson(Map<String, dynamic>.from(_json(_gearKey, const {}) as Map));
  }

  String get _now => isoNow(_clock());
  String get _today => dateKey(_clock());

  void _saveSessions() => _prefs.setString(
      _sessionsKey, jsonEncode({for (final s in _sessions.values) s.date: s.toJson()}));
  void _saveEvents() => _prefs.setString(_xpKey, jsonEncode([for (final e in _events) e.toJson()]));

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

  // ------------------------------------------------------------- old data

  /// True while the old app's data is still on the phone (before the
  /// one-time migration, docs/data-schema.md §5).
  bool get hasOldData =>
      oldKeys.any(_prefs.containsKey) || _prefs.getKeys().any((k) => k.startsWith(oldKeyPrefix));

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
            if (oldKeys.contains(k) || k.startsWith(oldKeyPrefix)) k: _prefs.get(k),
        },
      });

  /// Dates of old workout days (rest days dropped, one per date).
  static Set<String> _oldWorkoutDates(List raw) => {
        for (final s in raw)
          if (s is Map && s['rested'] != true && s['date'] is String) s['date'] as String,
      };

  /// Old sessions -> legacy sessions + one legacy XP event each.
  static (List<Session>, List<XpEvent>) _convertOld(List raw) {
    final byDate = <String, Session>{};
    for (final s in raw) {
      if (s is! Map || s['rested'] == true || s['date'] is! String) continue;
      final date = s['date'] as String;
      String? iso(Object? ms) =>
          ms is num ? isoNow(DateTime.fromMillisecondsSinceEpoch(ms.toInt())) : null;
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
      if (oldKeys.contains(k) || k.startsWith(oldKeyPrefix)) await _prefs.remove(k);
    }
    _checkUnlocks();
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
    return [
      for (var i = 0; i < n; i++)
        SessionExercise(
          position: i,
          exerciseId: pool[(start + i) % pool.length].id,
          originalExerciseId: pool[(start + i) % pool.length].id,
          targetSets: r.targetSets,
        ),
    ];
  }

  /// Today's workout (all entries, removed ones too: use the index of this
  /// list for the edit calls). A new plan until something is done today.
  List<SessionExercise> get todayExercises =>
      todaySession?.exercises ?? planFor(gameClass, difficulty, _today);

  /// Indexes of [todayExercises] shown as cards (not removed).
  List<int> get todayCards => [
        for (final (i, e) in todayExercises.indexed)
          if (!e.removed) i,
      ];

  GameClass get _todayClass => classById(todaySession?.classId ?? gameClass.id);

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
    _checkUnlocks();
    notifyListeners();
  }

  /// Tap on card [i]: one more working set.
  void addSet(int i) => _edit((l) => l..[i] = l[i].copyWith(sets: l[i].sets + 1));

  /// Long-press on card [i]: one working set less (for a wrong tap).
  void removeSet(int i) {
    if (todayExercises[i].sets == 0) return;
    _edit((l) => l..[i] = l[i].copyWith(sets: l[i].sets - 1));
  }

  /// Class pool exercises not on a card.
  List<Exercise> get unusedExercises {
    final used = {for (final e in todayExercises) if (!e.removed) e.exerciseId};
    return [for (final e in _todayClass.exercises) if (!used.contains(e.id)) e];
  }

  /// Swipe on card [i]: the next (or, [dir] < 0, previous) pool exercise
  /// that is not on another card. Only on a card with no sets.
  bool swap(int i, int dir) {
    final list = todayExercises;
    if (list[i].sets > 0) return false;
    final pool = _todayClass.exercises;
    final used = {for (final (k, e) in list.indexed) if (k != i && !e.removed) e.exerciseId};
    var at = pool.indexWhere((e) => e.id == list[i].exerciseId);
    for (var step = 0; step < pool.length; step++) {
      at = (at + (dir < 0 ? -1 : 1)) % pool.length;
      if (at < 0) at += pool.length;
      final id = pool[at].id;
      if (id == list[i].exerciseId) return false;
      if (!used.contains(id)) {
        _edit((l) => l..[i] = l[i].copyWith(exerciseId: id));
        return true;
      }
    }
    return false;
  }

  /// Card [i] goes back to the exercise the workout first gave.
  bool resetSlot(int i) {
    final list = todayExercises;
    if (!list[i].switched || list[i].sets > 0) return false;
    final first = list[i].originalExerciseId;
    final other = list.indexWhere((e) => !e.removed && e.exerciseId == first);
    _edit((l) {
      // If that exercise sits on another empty card, the two cards trade.
      if (other >= 0 && l[other].sets == 0) l[other] = l[other].copyWith(exerciseId: l[i].exerciseId);
      return l..[i] = l[i].copyWith(exerciseId: first);
    });
    return true;
  }

  /// Adds a card for pool exercise [exerciseId] (or shows a removed one again).
  void addExercise(String exerciseId) => _edit((l) {
        final back = l.indexWhere((e) => e.removed && e.exerciseId == exerciseId);
        if (back >= 0) return l..[back] = l[back].copyWith(removed: false);
        return l
          ..add(SessionExercise(
            position: l.length,
            exerciseId: exerciseId,
            originalExerciseId: exerciseId,
            targetSets: rulesFor(difficultyIndex(todaySession?.difficultyId ?? difficulties[difficulty].id)).targetSets,
            added: true,
          ));
      });

  /// Removes card [i] (kept as `removed`). Only a card with no sets.
  bool removeSlot(int i) {
    if (todayExercises[i].sets > 0) return false;
    _edit((l) => l..[i] = l[i].copyWith(removed: true));
    return true;
  }

  // --------------------------------------------------------------- streak

  /// Monday of [date]'s week.
  static String weekOf(String date) {
    final d = parseDateKey(date);
    return dateKey(addDays(d, 1 - d.weekday));
  }

  /// Week (Monday) -> (training days, N of the last session that week).
  /// Legacy days do not count: their XP is the legacy event.
  Map<String, ({int days, int n})> get _weeks {
    final out = <String, ({int days, int n})>{};
    final played = _sessions.values.where((s) => !s.legacy && s.totalSets > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final s in played) {
      final w = weekOf(s.date);
      out[w] = (days: (out[w]?.days ?? 0) + 1, n: rulesFor(difficultyIndex(s.difficultyId)).streakN);
    }
    return out;
  }

  /// This week: training days so far, and the target N.
  ({int days, int n}) get thisWeek {
    final w = _weeks[weekOf(_today)];
    return (days: w?.days ?? 0, n: w?.n ?? rulesFor(difficulty).streakN);
  }

  /// Streak weeks in a row up to now. This week counts once it is met;
  /// until then the streak from last week still stands.
  int get streakWeeks {
    final weeks = _weeks;
    bool met(String w) => (weeks[w]?.days ?? 0) >= (weeks[w]?.n ?? 999);
    var w = weekOf(_today);
    if (!met(w)) w = dateKey(addDays(parseDateKey(w), -7));
    var n = 0;
    while (met(w)) {
      n++;
      w = dateKey(addDays(parseDateKey(w), -7));
    }
    return n;
  }

  int get _bestStreakWeeks {
    final met = _weeks.entries.where((e) => e.value.days >= e.value.n).map((e) => e.key).toList()..sort();
    var best = 0, run = 0;
    String? prev;
    for (final w in met) {
      run = prev != null && dateKey(addDays(parseDateKey(prev), 7)) == w ? run + 1 : 1;
      best = run > best ? run : best;
      prev = w;
    }
    return best;
  }

  // ------------------------------------------------------------------- XP

  /// XP for the working sets of one session (with the over-target bonus).
  static int setsXp(Session s) => s.exercises.fold(
      0, (a, e) => a + xpForExercise(e.sets, e.targetSets, difficultyIndex(s.difficultyId)));

  /// All XP events: the saved ones (legacy, achievement) and the computed
  /// ones (sets, day, streak). See lib/game/model.dart.
  List<XpEvent> get xpEvents {
    final out = [..._events];
    for (final s in _sessions.values) {
      if (s.legacy || s.totalSets == 0) continue;
      final at = s.lastMarkAt ?? '${s.date}T00:00:00';
      out.add(XpEvent(at: at, source: 'sets', amount: setsXp(s), ref: s.date));
      out.add(XpEvent(at: at, source: 'day', amount: xpPerTrainingDay, ref: s.date));
    }
    for (final e in _weeks.entries) {
      if (e.value.days >= e.value.n) {
        out.add(XpEvent(at: '${e.key}T00:00:00', source: 'streak', amount: xpPerStreakWeek, ref: e.key));
      }
    }
    return out;
  }

  int get totalXp => xpEvents.fold(0, (a, e) => a + e.amount);

  /// XP a session brought (sets + day bonus; legacy: its event).
  int xpOfSession(Session s) => s.legacy
      ? _events.where((e) => e.source == 'legacy' && e.ref == s.date).fold(0, (a, e) => a + e.amount)
      : s.totalSets == 0
          ? 0
          : setsXp(s) + xpPerTrainingDay;

  // ------------------------------------------------- achievements and gear

  Map<String, String> get achievementsUnlocked => Map.unmodifiable(_achievements);
  Gear get gear => _gear;

  /// New unlocks since the last call (the UI shows a burst for each).
  List<Unlock> takeUnlocks() {
    final out = [..._unlocks];
    _unlocks.clear();
    return out;
  }

  void _checkUnlocks() {
    var changed = true;
    while (changed) {
      changed = false;
      final played = _sessions.values.where((s) => !s.legacy);
      final stats = (
        totalSets: played.fold(0, (a, s) => a + s.totalSets),
        trainingDays: played.where((s) => s.totalSets > 0).length,
        bestStreakWeeks: _bestStreakWeeks,
        level: levelFor(totalXp).level,
      );
      for (final a in achievements) {
        if (_achievements.containsKey(a.id) || !a.met(stats)) continue;
        _achievements[a.id] = _now;
        if (a.xp > 0) _events.add(XpEvent(at: _now, source: 'achievement', amount: a.xp, ref: a.id));
        _unlocks.add((title: 'ACHIEVE-\nMENT!!!', name: a.name, sub: '${a.line.toUpperCase()}\n+${a.xp} XP'));
        changed = true;
      }
      final level = levelFor(totalXp).level;
      for (final it in items) {
        if (it.unlockLevel > level || _gear.owned.contains(it.id)) continue;
        final slot = it.slot.name;
        _gear = Gear(
          owned: [..._gear.owned, it.id],
          equipped: {..._gear.equipped, if (!_gear.equipped.containsKey(slot)) slot: it.id},
        );
        _unlocks.add((title: 'NEW\nGEAR!!!', name: it.name, sub: 'UNLOCKED AT LVL ${it.unlockLevel}. EQUIP IT IN GEAR.'));
        changed = true;
      }
    }
    _prefs.setString(_achievementsKey, jsonEncode(_achievements));
    _prefs.setString(_gearKey, jsonEncode(_gear.toJson()));
    _saveEvents();
  }

  /// Puts owned item [itemId] in its slot (null clears [slot]).
  void equip(GearSlot slot, String? itemId) {
    if (itemId != null && !_gear.owned.contains(itemId)) return;
    final eq = {..._gear.equipped}..remove(slot.name);
    if (itemId != null) eq[slot.name] = itemId;
    _gear = Gear(owned: _gear.owned, equipped: eq);
    _prefs.setString(_gearKey, jsonEncode(_gear.toJson()));
    notifyListeners();
  }

  // ----------------------------------------------------------------- backup

  static const backupVersion = 3;

  /// Backup file contents: every key of docs/data-schema.md §4.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': backupVersion,
        if (_profile != null) _profileKey: _profile!.toJson(),
        _bodyKey: [for (final b in _body) b.toJson()],
        _sessionsKey: {for (final s in _sessions.values) s.date: s.toJson()},
        _xpKey: [for (final e in _events) e.toJson()],
        _achievementsKey: _achievements,
        _gearKey: _gear.toJson(),
      });

  /// Replaces everything with a backup file. Version 3 is [backupJson].
  /// Version 2 (the old app) goes through the same migration: its workout
  /// days become legacy sessions with legacy XP; there is no profile, so
  /// the setup runs again.
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || (data['version'] != 2 && data['version'] != 3)) {
      throw const FormatException('Not a PUMPLEX backup');
    }
    // Parse everything before touching current data.
    final Map<String, String> out;
    if (data['version'] == 2) {
      final (sessions, events) = _convertOld(data['sessions'] as List? ?? const []);
      out = {
        _sessionsKey: jsonEncode({for (final s in sessions) s.date: s.toJson()}),
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
      Map<String, String>.from(data[_achievementsKey] as Map? ?? const {});
      Gear.fromJson(Map<String, dynamic>.from(data[_gearKey] as Map? ?? const {}));
      out = {
        if (p is Map) _profileKey: jsonEncode(p),
        _bodyKey: jsonEncode(data[_bodyKey] ?? const []),
        _sessionsKey: jsonEncode(data[_sessionsKey] ?? const {}),
        _xpKey: jsonEncode(data[_xpKey] ?? const []),
        _achievementsKey: jsonEncode(data[_achievementsKey] ?? const {}),
        _gearKey: jsonEncode(data[_gearKey] ?? const {}),
      };
    }
    for (final k in [_profileKey, _bodyKey, _sessionsKey, _xpKey, _achievementsKey, _gearKey]) {
      out.containsKey(k) ? await _prefs.setString(k, out[k]!) : await _prefs.remove(k);
    }
    // Old-app keys on this phone are left alone: only the migration deletes
    // them, after its own backup file.
    _load();
    _unlocks.clear();
    notifyListeners();
  }
}
