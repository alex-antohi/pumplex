import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'game/content.dart';
import 'game/chalk.dart';
import 'game/exercises.dart';
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
    _freezeOldWorkouts();
    removedKeys.forEach(_prefs.remove);
  }

  static const _profileKey = 'profile_v1';
  static const _bodyKey = 'body_history_v1';
  static const _sessionsKey = 'sessions_v3';
  static const _xpKey = 'xp_events_v1';
  static const _favoritesKey = 'favorites_v1';

  /// Copy of the sessions as they were before the old exercise lists were
  /// dropped (D54), kept on the phone.
  static const oldExercisesBackupKey = 'old_exercises_v0_backup';

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
  final Set<String> _favorites = {};

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
    _events.addAll(_oldStreakEvents(_rawSessions()).where((e) => !known.contains(e.ref)));
    _saveEvents();
    _prefs.setBool(streakFrozenKey, true);
  }

  /// The saved sessions with the old fields the parsed model no longer has
  /// (each exercise's target), for the one-time XP freezes.
  List<_RawSession> _rawSessions() => [
        for (final e in (_json(_sessionsKey, const {}) as Map).entries)
          if (e.value is Map)
            (
              date: e.key as String,
              difficultyId: (e.value as Map)['difficultyId'] as String? ?? '',
              legacy: (e.value as Map)['legacy'] as bool? ?? false,
              lastMarkAt: (e.value as Map)['lastMarkAt'] as String?,
              exercises: [
                for (final x in (e.value as Map)['exercises'] as List? ?? const [])
                  if (x is Map && x['exerciseId'] is String)
                    (
                      id: newExerciseId(x['exerciseId'] as String),
                      target: (x['targetSets'] as num?)?.toInt() ?? 0,
                      sets: (x['sets'] as num?)?.toInt() ?? 0,
                    ),
              ],
            ),
      ];

  /// One-time (D54): sessions from before the exercise list use the old
  /// class-pool ids (`paladin.squat`). Their exercise lists are dropped;
  /// each training day stays in history as a legacy day, and its XP (sets
  /// by the old target rules, and the first-set bonus) is saved as a
  /// `workout` XP event, so no one loses XP.
  void _freezeOldWorkouts() {
    final old = _rawSessions().where((s) => !s.legacy && s.exercises.any((e) => e.id.contains('.'))).toList();
    if (old.isEmpty) return;
    if (!_prefs.containsKey(oldExercisesBackupKey)) {
      _prefs.setString(oldExercisesBackupKey, _prefs.getString(_sessionsKey) ?? '');
    }
    final known = {for (final e in _events) if (e.source == 'workout') e.ref};
    for (final s in old) {
      final had = _sessions[s.date]!;
      final sets = s.exercises.fold(0, (a, e) => a + e.sets);
      if (sets == 0) {
        _sessions.remove(s.date);
        continue;
      }
      final d = difficultyIndex(s.difficultyId);
      var xp = 0;
      for (final e in s.exercises) {
        for (var n = 1; n <= e.sets; n++) {
          xp += oldSetXp(setNumber: n, target: e.target, difficulty: d, critical: isCritical(s.date, e.id, n)).round();
        }
      }
      if (!known.contains(s.date)) {
        _events.add(XpEvent(
          at: s.lastMarkAt ?? '${s.date}T00:00:00',
          source: 'workout',
          amount: xp + xpFirstSetOfDay,
          ref: s.date,
        ));
      }
      _sessions[s.date] = Session(
        date: s.date,
        classId: had.classId,
        difficultyId: had.difficultyId,
        areaId: had.areaId,
        firstMarkAt: had.firstMarkAt,
        lastMarkAt: had.lastMarkAt,
        legacy: true,
      );
    }
    _saveEvents();
    _saveSessions();
  }

  /// The streak bonus of each session, by the rules before D34: a week with
  /// N training days (N by difficulty: 2, 2, 2, 3, 3, 4) is a streak week; a
  /// session gets +5% set XP per streak week in a row before its week, at
  /// most +25%, rounded set by set.
  static List<XpEvent> _oldStreakEvents(List<_RawSession> all) {
    const streakN = [2, 2, 2, 3, 3, 4];
    String weekOf(String date) {
      final d = parseDateKey(date);
      return dateKey(addDays(d, 1 - d.weekday));
    }

    String before(String w) => dateKey(addDays(parseDateKey(w), -7));
    final played = all.where((s) => !s.legacy && s.exercises.any((e) => e.sets > 0)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
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
          final xp = oldSetXp(setNumber: n, target: e.target, difficulty: d, critical: isCritical(s.date, e.id, n));
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
    _favorites
      ..clear()
      ..addAll([for (final id in _json(_favoritesKey, const []) as List) if (id is String) id]);
    _picked.clear();
    _filter = null;
    _filterLoaded = false;
    try {
      final raw = _json(pickedVariantsKey, const {});
      if (raw is Map) {
        for (final e in raw.entries) {
          if (e.key is String && e.value is List) _picked[e.key as String] = [for (final id in e.value as List) if (id is String) id];
        }
      }
    } on FormatException {
      // A broken value is only UI state: start without picks.
    }
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
      // today's workout at once, also after sets (D64).
      _sessions[_today] = t.copyWith(areaId: p.areaId);
      _saveSessions();
    }
    _clearFilter(); // the filters go back to the new class and mode
    notifyListeners();
  }

  // ------------------------------------------------- favorites and filters

  /// Favorite exercises (D53, D72): the star saves the exact exercise (the
  /// variant), not the card.
  Set<String> get favorites => Set.unmodifiable(_favorites);

  bool isFavorite(String exerciseId) => _favorites.contains(exerciseId);

  void toggleFavorite(String exerciseId) {
    if (!_favorites.remove(exerciseId)) _favorites.add(exerciseId);
    _prefs.setString(_favoritesKey, jsonEncode(_favorites.toList()));
    notifyListeners();
  }

  /// A favorite saved as a card (`move:<name>`, D55, before D72) becomes the
  /// exercise picked on that card last, else its simplest exercise.
  void _favoritesToVariants() {
    final moved = {
      for (final f in _favorites)
        if (exerciseCatalog.byId.containsKey(f) || exerciseCatalog.byKey[f] == null)
          f
        else
          (_picked[f]?.firstOrNull ?? exerciseCatalog.byKey[f]!.variants.first.id),
    };
    if (moved.length == _favorites.length && moved.containsAll(_favorites)) return;
    _favorites
      ..clear()
      ..addAll(moved);
    _prefs.setString(_favoritesKey, jsonEncode(_favorites.toList()));
  }

  /// The exercises picked on each card, the last one first: group key ->
  /// ids. Kept on the phone, so the exercise picked is still there after
  /// leaving the workout or the app. UI state only: not in the backup.
  static const pickedVariantsKey = 'workout_variants_v1';
  final Map<String, List<String>> _picked = {};

  /// How many picks a card remembers.
  static const _pickedPerCard = 8;

  /// The exercise to show for card [g] (one of its exercises that pass the
  /// filters): the one picked last that passes, else the one used last
  /// today, else the simplest.
  CatalogExercise variantFor(ExerciseGroup g) {
    final ids = {for (final v in g.variants) v.id};
    final picked = _picked[g.key]?.where(ids.contains).firstOrNull;
    if (picked != null) return exerciseCatalog.byId[picked]!;
    // A favorite exercise of the card (D72), when nothing was picked.
    final fav = g.variants.where((v) => _favorites.contains(v.id)).firstOrNull;
    if (fav != null) return fav;
    final used = todaySession?.exercises.lastWhere((e) => ids.contains(e.exerciseId) && e.sets > 0,
        orElse: () => const SessionExercise(exerciseId: ''));
    if (used != null && used.exerciseId.isNotEmpty) return exerciseCatalog.byId[used.exerciseId]!;
    return g.variants.first;
  }

  /// A modifier chip picked exercise [id] on its card.
  void pickVariant(String id) {
    final key = exerciseCatalog.groupKeyOf(id);
    _picked[key] = [id, ...?_picked[key]?.where((p) => p != id)].take(_pickedPerCard).toList();
    _prefs.setString(pickedVariantsKey, jsonEncode(_picked));
    notifyListeners();
  }

  /// The last filter choice, kept on the phone (also the next day and after
  /// closing the app) until RESET TO MINE or a new class or mode. UI state
  /// only: not in the backup.
  static const filterKey = 'workout_filter_v1';
  ExerciseFilter? _filter;
  bool _filterLoaded = false;

  /// Your class, your mode, all body parts, not only favorites.
  ExerciseFilter get defaultFilter => ExerciseFilter(classId: gameClass.id, difficulty: difficulty);

  /// The workout filters: the last choice, else [defaultFilter].
  ExerciseFilter get filter {
    if (!_filterLoaded) {
      _filterLoaded = true;
      _filter = _savedFilter();
    }
    return _filter ?? defaultFilter;
  }

  /// The saved choice, checked against the list as it is now: an unknown
  /// class or difficulty means the defaults; an unknown body part or
  /// muscle, or one with nothing left, goes back to all.
  ExerciseFilter? _savedFilter() {
    final Object? j;
    try {
      j = _json(filterKey, const {});
    } on FormatException {
      return null;
    }
    if (j is! Map) return null;
    final cls = j['class'], d = j['difficulty'];
    if (cls is! String || !classEquipment.containsKey(cls) || d is! int || d < 0 || d >= difficulties.length) return null;
    final body = bodyPartById(j['body'] is String ? j['body'] as String : null);
    final m = j['muscle'];
    final muscle = body != null && m is String && body.muscles.contains(m) ? m : null;
    return ExerciseFilter(classId: cls, difficulty: d, body: body?.id, muscle: muscle, favorites: j['favorites'] == true)
        .settle(exerciseCatalog, _favorites);
  }

  /// A new choice; a body part or muscle with nothing left goes back to all.
  void setFilter(ExerciseFilter f) {
    final s = _filter = f.settle(exerciseCatalog, _favorites);
    _filterLoaded = true;
    _prefs.setString(filterKey, jsonEncode({
      'class': s.classId,
      'difficulty': s.difficulty,
      'body': s.body,
      'muscle': s.muscle,
      'favorites': s.favorites,
    }));
    notifyListeners();
  }

  /// Back to [defaultFilter], and the saved choice is gone.
  void _clearFilter() {
    _filter = null;
    _filterLoaded = true;
    _prefs.remove(filterKey);
  }

  /// The workout card picked last (a group key), kept on the phone so it is
  /// still there after leaving the workout or the app (D75). UI state only:
  /// not in the backup.
  static const pickedCardKey = 'workout_card_v1';
  String? get pickedCard => _prefs.getString(pickedCardKey);
  void setPickedCard(String key) {
    if (_prefs.getString(pickedCardKey) != key) _prefs.setString(pickedCardKey, key);
  }

  void resetFilter() {
    _clearFilter();
    _chalk.clear();
    notifyListeners();
  }

  /// The CHALK line (D72): the words picked in the search, one per row
  /// (`<row>.<id>`, lib/game/chalk.dart). While it has words, the cards are
  /// the search results over ALL exercises (no class, no filters). In
  /// memory only.
  final Set<String> _chalk = {};
  Set<String> get chalk => Set.unmodifiable(_chalk);

  void setChalk(Set<String> line) {
    _chalk
      ..clear()
      ..addAll(line);
    notifyListeners();
  }

  /// The HARD badge (D70) for exercise [e] of card [g]: only for a card of
  /// your class (a CHALK result for other gear opens with no badge, D72).
  bool isHard(ExerciseGroup g, CatalogExercise e) => g.variants.first.unlock.containsKey(gameClass.id) && filter.isHard(g, e);

  /// The cards the filters show, in carousel order (one per move, D55).
  List<ExerciseGroup> get cards {
    _favoritesToVariants();
    if (_chalk.isNotEmpty) return ChalkIndex.of(exerciseCatalog).search(_chalk);
    return filter.apply(exerciseCatalog, _favorites);
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

  /// Today's working sets of exercise [id].
  int setsToday(String id) =>
      todaySession?.exercises.where((e) => e.exerciseId == id).firstOrNull?.sets ?? 0;

  /// Today's working sets of all the exercises of card [key] (D55).
  int groupSetsToday(String key) => (todaySession?.exercises ?? const <SessionExercise>[])
      .where((e) => exerciseCatalog.groupKeyOf(e.exerciseId) == key)
      .fold(0, (a, e) => a + e.sets);

  void _edit(List<SessionExercise> Function(List<SessionExercise> list) edit) {
    final s = todaySession ??
        Session(
          date: _today,
          classId: gameClass.id,
          difficultyId: difficulties[difficulty].id,
          areaId: areaById(_profile?.areaId).id,
        );
    _sessions[_today] = s.copyWith(lastMarkAt: _now, exercises: edit([...s.exercises]));
    _saveSessions();
    notifyListeners();
  }

  /// Tap on the world: one more working set of exercise [id].
  void addSet(String id) => _edit((l) {
        final i = l.indexWhere((e) => e.exerciseId == id);
        return i < 0 ? (l..add(SessionExercise(exerciseId: id, sets: 1))) : (l..[i] = l[i].copyWith(sets: l[i].sets + 1));
      });

  /// Hold on the world: one working set less (for a wrong tap). An
  /// exercise with no sets left leaves the session.
  void removeSet(String id) {
    if (setsToday(id) == 0) return;
    _edit((l) {
      final i = l.indexWhere((e) => e.exerciseId == id);
      return l[i].sets == 1 ? (l..removeAt(i)) : (l..[i] = l[i].copyWith(sets: l[i].sets - 1));
    });
  }

  // ------------------------------------------------------------------- XP

  /// Set XP of a session (docs/rules.md §1, set by set), only for card
  /// [key] when given. Sets count per card: all the exercises of one move
  /// share the 10-set cap and the set numbers (D55).
  static int _setsXp(Session s, [String? key]) {
    final d = difficultyIndex(s.difficultyId);
    final n = <String, int>{};
    var xp = 0;
    for (final e in s.exercises) {
      final g = exerciseCatalog.groupKeyOf(e.exerciseId);
      for (var i = 0; i < e.sets; i++) {
        final k = n[g] = (n[g] ?? 0) + 1;
        if (key == null || key == g) xp += xpForSet(setNumber: k, difficulty: d, critical: isCritical(s.date, g, k));
      }
    }
    return xp;
  }

  /// All XP events: the saved ones (legacy, and the old streak and
  /// achievement XP) and the computed ones (sets, day = first set of the
  /// day). See lib/game/model.dart.
  List<XpEvent> get xpEvents {
    final out = [..._events];
    // A day frozen by D54 already holds its first-set bonus.
    final frozen = {for (final e in _events) if (e.source == 'workout') e.ref};
    for (final s in _sessions.values) {
      if (s.legacy || s.totalSets == 0) continue;
      final at = s.lastMarkAt ?? '${s.date}T00:00:00';
      out.add(XpEvent(at: at, source: 'sets', amount: _setsXp(s), ref: s.date));
      if (!frozen.contains(s.date)) {
        out.add(XpEvent(at: s.firstMarkAt ?? at, source: 'day', amount: xpFirstSetOfDay, ref: s.date));
      }
    }
    return out;
  }

  int get totalXp => xpEvents.fold(0, (a, e) => a + e.amount);

  /// Saved XP events that belong to one day's session.
  static const _sessionSources = {'legacy', 'streak', 'workout'};

  /// XP a session brought: sets and the first-set bonus, plus its saved
  /// events (legacy: the old-app day; old streak bonus; old workout, D54).
  int xpOfSession(Session s) {
    final saved = _events
        .where((e) => e.ref == s.date && _sessionSources.contains(e.source))
        .fold(0, (a, e) => a + e.amount);
    if (s.legacy || s.totalSets == 0) return saved;
    final day = _events.any((e) => e.ref == s.date && e.source == 'workout') ? 0 : xpFirstSetOfDay;
    return _setsXp(s) + day + saved;
  }

  /// XP of card [key] today so far (with criticals).
  int groupXpToday(String key) {
    final s = todaySession;
    return s == null ? 0 : _setsXp(s, key);
  }

  /// Whether the last set of exercise [id] today (on its card) was a critical set.
  bool lastSetCritical(String id) {
    final g = exerciseCatalog.groupKeyOf(id);
    final n = groupSetsToday(g);
    return n > 0 && n <= xpSetsPerExercise && isCritical(_today, g, n);
  }

  // ----------------------------------------------------------------- backup

  /// 4: no achievements, and the old streak XP is in the XP events (D34).
  /// 5: no gear (D38).
  /// 6: favorites; exercise ids from the exercise list (D50, D53).
  static const backupVersion = 6;

  /// Backup file contents: every key of docs/data-schema.md §4.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': backupVersion,
        if (_profile != null) _profileKey: _profile!.toJson(),
        _bodyKey: [for (final b in _body) b.toJson()],
        _sessionsKey: _sessionsJson(_sessions.values),
        _xpKey: [for (final e in _events) e.toJson()],
        _favoritesKey: _favorites.toList(),
      });

  /// Replaces everything with a backup file. Version 6 is [backupJson].
  /// Versions 3 to 5 have no favorites, and their old exercise lists are
  /// frozen on import (D54). Versions 3 and 4 may hold achievements or gear (ignored); version 3
  /// has no saved streak XP (worked out again on import). Version 2 (the old app) goes through the same migration: its workout
  /// days become legacy sessions with legacy XP; there is no profile, so
  /// the setup runs again.
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || ![2, 3, 4, 5, 6].contains(data['version'])) {
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
        if (data[_favoritesKey] is List) _favoritesKey: jsonEncode(data[_favoritesKey]),
      };
    }
    for (final k in [_profileKey, _bodyKey, _sessionsKey, _xpKey, _favoritesKey]) {
      out.containsKey(k) ? await _prefs.setString(k, out[k]!) : await _prefs.remove(k);
    }
    await _prefs.setBool(streakFrozenKey, (data['version'] as int) >= 4);
    // Old-app keys on this phone are left alone: only the migration deletes
    // them, after its own backup file.
    _load();
    _migrateIds();
    _freezeStreakXp();
    _freezeOldWorkouts();
    notifyListeners();
  }
}

/// A saved session read straight from the JSON, with the old target field.
typedef _RawSession = ({
  String date,
  String difficultyId,
  bool legacy,
  String? lastMarkAt,
  List<({String id, int target, int sets})> exercises,
});
