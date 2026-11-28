import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'game/content.dart';
import 'game/chalk.dart';
import 'game/exercises.dart';
import 'game/forge.dart';
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

  /// "My gear" (D89): the lifter's adds to and removes from the class gear
  /// ([MyGear]). In the backup; an old save has none.
  static const myGearKey = 'my_gear_v1';

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
  MyGear _gear = MyGear.none;

  dynamic _json(String key, Object fallback) {
    final raw = _prefs.getString(key);
    return raw == null ? fallback : jsonDecode(raw);
  }

  /// A list of UI data: a broken value is an empty list.
  List<Object?> _uiList(String key) {
    try {
      final v = _json(key, const []);
      return v is List ? v : const [];
    } on FormatException {
      return const [];
    }
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
          e.key as String: Session.fromJson(e.key as String, Map<String, dynamic>.from(e.value as Map))
              .withExerciseIds(exerciseCatalog.resolveId), // old ids of merged exercises (D90)
      });
    _events
      ..clear()
      ..addAll([
        for (final e in _json(_xpKey, const []) as List) XpEvent.fromJson(Map<String, dynamic>.from(e as Map)),
      ]);
    _favorites
      ..clear()
      ..addAll([for (final id in _json(_favoritesKey, const []) as List) if (id is String) exerciseCatalog.resolveId(id)]);
    try {
      _gear = MyGear.fromJson(_json(myGearKey, const {}));
    } on FormatException {
      _gear = MyGear.none; // a broken value: the class gear only
    }
    _picked.clear();
    final forgedJson = _uiList(forgedKey);
    _forged
      ..clear()
      ..addAll([
        for (final j in forgedJson)
          if (j is Map && j['id'] is String) ForgedMove.fromJson(Map<String, dynamic>.from(j)),
      ]);
    // An older entry kept an English name: keep only the words (the name
    // is composed in the current language), once.
    if (forgedJson.any((j) => j is Map && j.containsKey('name'))) {
      _prefs.setString(forgedKey, jsonEncode([for (final f in _forged) f.toJson()]));
    }
    exerciseCatalog = catalogWithForged(exerciseCatalog, _forged);
    try {
      final raw = _json(pickedVariantsKey, const {});
      if (raw is Map) {
        for (final e in raw.entries) {
          if (e.key is String && e.value is List) {
            _picked[e.key as String] = [
              for (final id in {for (final id in e.value as List) if (id is String) exerciseCatalog.resolveId(id)}) id,
            ];
          }
        }
      }
    } on FormatException {
      // A broken value is only UI state: start without picks.
    }
    _loadToday(); // after the picks: the old Today needs them (D82)
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
    notifyListeners();
  }

  // --------------------------------------------------- favorites and picks

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
    _remember(id);
    notifyListeners();
  }

  /// Exercise [id] is the one picked last on its move ([variantFor]).
  void _remember(String id) {
    final key = exerciseCatalog.groupKeyOf(id);
    _picked[key] = [id, ...?_picked[key]?.where((p) => p != id)].take(_pickedPerCard).toList();
    _prefs.setString(pickedVariantsKey, jsonEncode(_picked));
  }

  // ------------------------------------------------------- my gear (D89)

  /// The lifter's own changes to the class gear.
  MyGear get myGear => _gear;

  /// The lit tools (D89): the class gear, Bodyweight, the lifter's adds,
  /// minus their removes. The class's tools first. A hint, never a filter.
  List<String> get litTools => _gear.lit(gameClass.id);

  /// A long-press on [tool] in the gear rack: a lit tool goes out, a dim one is lit.
  void toggleGear(String tool) {
    _gear = _gear.toggle(gameClass.id, tool);
    _prefs.setString(myGearKey, jsonEncode(_gear.toJson()));
    notifyListeners();
  }

  /// Variation [e] fits my gear: the class mark (D89). No XP effect.
  bool fitsMyGear(CatalogExercise e) => fitsGear(e, litTools);

  /// The CHALK cards for [line] (D89): every card (no lift is hidden),
  /// the cards of my gear first (by gear), my-gear variations first in a card.
  List<ExerciseGroup> chalkCards(Iterable<String> line) => ChalkIndex.of(exerciseCatalog).search(line, lit: litTools);

  /// The first 5 move words of OR SAY THE MOVE (D89): the class's.
  List<String> get topMoves => classMoves[gameClass.id] ?? const [];

  /// The workout card picked last (its exercise id: one card per Today
  /// exercise, D82; an old group key just shows the first card), kept on the phone so it is
  /// still there after leaving the workout or the app (D75). UI state only:
  /// not in the backup.
  static const pickedCardKey = 'workout_card_v1';
  String? get pickedCard {
    final id = _prefs.getString(pickedCardKey);
    return id == null ? null : exerciseCatalog.resolveId(id); // an old id of a merged exercise (D90)
  }
  void setPickedCard(String key) {
    if (key != _preview) _preview = null; // leaving the preview drops it (D82)
    if (_prefs.getString(pickedCardKey) != key) _prefs.setString(pickedCardKey, key);
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

  /// The forged moves (D72, lib/game/forge.dart), kept on the phone. UI
  /// data: not in the backup file yet (still open, HANDOFF.md).
  static const forgedKey = 'custom_exercises_v1';
  final List<ForgedMove> _forged = [];
  List<ForgedMove> get forged => List.unmodifiable(_forged);

  /// Forge a move from the chalk [words]: it joins the exercise list, and
  /// the workout shows it (the chalk line becomes its words).
  /// A [typed] move word (D83) takes the place of the MOVE word.
  ForgedMove forge(Set<String> words, String muscle, String? nickname, {String? typed}) {
    var n = _forged.length + 1;
    while (exerciseCatalog.byId.containsKey('custom_$n')) {
      n++;
    }
    final own = cleanTyped(typed);
    final move = ForgedMove(
      id: 'custom_$n',
      words: own == null ? words : {for (final w in words) if (!w.startsWith('move.')) w},
      muscle: muscle,
      nickname: nickname,
      typed: own,
    );
    _forged.add(move);
    _saveForged();
    _chalk
      ..clear()
      ..addAll(ChalkIndex.of(exerciseCatalog).words[move.id] ?? const {});
    setPickedCard(move.id);
    _addToToday([move.id]); // FORGE IT adds the move to Today (D79)
    notifyListeners();
    return move;
  }

  /// Saves the forged moves and puts them in the exercise list again.
  void _saveForged() {
    _prefs.setString(forgedKey, jsonEncode([for (final f in _forged) f.toJson()]));
    exerciseCatalog = catalogWithForged(exerciseCatalog, _forged);
  }

  /// The forged move [id], or null.
  ForgedMove? forgedById(String id) => _forged.where((f) => f.id == id).firstOrNull;

  /// SAVE on the FORGE card in edit mode (D78): forged move [id] gets new
  /// words, muscle, nickname and typed word. Its id stays, so its sets,
  /// XP and Today place stay.
  void editForged(String id, Set<String> words, String muscle, String? nickname, {String? typed}) {
    final i = _forged.indexWhere((f) => f.id == id);
    if (i < 0) return;
    final own = cleanTyped(typed);
    _forged[i] = ForgedMove(
      id: id,
      words: own == null ? words : {for (final w in words) if (!w.startsWith('move.')) w},
      muscle: muscle,
      nickname: nickname,
      typed: own,
    );
    _saveForged();
    notifyListeners();
  }

  /// All the working sets of exercise [id], on every day.
  int allSets(String id) => _sessions.values
      .expand((s) => s.exercises)
      .where((e) => e.exerciseId == id)
      .fold(0, (a, e) => a + e.sets);

  /// MELT on the FORGE card in edit mode (D78): forged move [id] is
  /// deleted. It leaves Today, the favorites and the list, and its sets on
  /// every day go too (so does their XP: XP is worked out from the sets).
  void meltForged(String id) {
    if (forgedById(id) == null) return;
    removeFromToday(id);
    if (_favorites.remove(id)) _prefs.setString(_favoritesKey, jsonEncode(_favorites.toList()));
    if (allSets(id) > 0) {
      for (final e in _sessions.entries.toList()) {
        if (e.value.exercises.any((x) => x.exerciseId == id)) {
          _sessions[e.key] = e.value.copyWith(exercises: [
            for (final x in e.value.exercises)
              if (x.exerciseId != id) x,
          ]);
        }
      }
      _saveSessions();
    }
    _forged.removeWhere((f) => f.id == id);
    _saveForged();
    if (pickedCard == id) _prefs.remove(pickedCardKey);
    notifyListeners();
  }

  /// The HARD badge (D89) for exercise [e]: above your mode. For every
  /// lift, of any gear; nothing is hidden or locked.
  bool isHard(CatalogExercise e) => isHardFor(e, difficulty);

  // ---------------------------------------------------------------- today

  /// TODAY (D79, D82): the exercises (variations) the lifter put in today's
  /// list, in order. Two variations of one move can both be there (a cable
  /// fly and a dumbbell fly); each one is its own carousel card. Kept on the
  /// phone with the day it belongs to: `{"date": "yyyy-MM-dd", "exercises":
  /// [ids]}`. A new day starts empty. UI data, not in the backup: the
  /// exercises with sets are in the day's session.
  static const todayKey = 'today_v2';

  /// The old Today (card keys), read once and changed to [todayKey].
  static const oldTodayKey = 'today_v1';
  String? _todayDate;
  final List<String> _todaySaved = [];

  void _loadToday() {
    _todayDate = null;
    _todaySaved.clear();
    try {
      final j = _json(todayKey, const {});
      if (j is Map && j['date'] is String && j['exercises'] is List) {
        _todayDate = j['date'] as String;
        // An old id of a merged exercise goes to the one that replaces it (D90).
        _todaySaved.addAll({for (final k in j['exercises'] as List) if (k is String) exerciseCatalog.resolveId(k)});
      }
    } on FormatException {
      // A broken value is only UI data: start with an empty Today.
    }
    if (_prefs.containsKey(oldTodayKey)) _migrateToday();
  }

  /// Once: the old Today held card keys. Each card becomes its variations
  /// with sets on that day, else the one picked on it, else its first one.
  /// The picked card becomes its first variation.
  void _migrateToday() {
    try {
      final j = _json(oldTodayKey, const {});
      if (_todayDate == null && j is Map && j['date'] is String && j['cards'] is List) {
        final date = j['date'] as String, s = _sessions[date];
        final ids = <String>[];
        String? pickedTo;
        final picked = pickedCard;
        for (final k in j['cards'] as List) {
          final g = k is String ? exerciseCatalog.byKey[k] : null;
          if (g == null) continue;
          final of = {for (final v in g.variants) v.id};
          final done = [
            for (final e in s == null || s.legacy ? const <SessionExercise>[] : s.exercises)
              if (e.sets > 0 && of.contains(e.exerciseId)) e.exerciseId,
          ];
          final add = done.isNotEmpty ? done : [_picked[g.key]?.where(of.contains).firstOrNull ?? g.variants.first.id];
          if (k == picked) pickedTo = add.first;
          ids.addAll([for (final id in add) if (!ids.contains(id)) id]);
        }
        _todayDate = date;
        _todaySaved
          ..clear()
          ..addAll(ids);
        _prefs.setString(todayKey, jsonEncode({'date': date, 'exercises': ids}));
        if (pickedTo != null) _prefs.setString(pickedCardKey, pickedTo);
      }
    } on FormatException {
      // A broken old value: nothing to keep.
    }
    _prefs.remove(oldTodayKey);
  }

  /// Today's exercises, in order: the ones put in today (a set, a CHALK
  /// "+", FORGE IT, COPY), then any exercise with sets today not in the
  /// list. The day rule is the sessions' one (D6): the list of another day
  /// is gone, so an exercise with 0 sets does not stay past its day. Only
  /// exercises the list has.
  List<String> get todayIds {
    final out = <String>[if (_todayDate == _today) ..._todaySaved];
    for (final e in todaySession?.exercises ?? const <SessionExercise>[]) {
      if (e.sets > 0 && !out.contains(e.exerciseId)) out.add(e.exerciseId);
    }
    return [for (final id in out) if (exerciseCatalog.byId.containsKey(id)) id];
  }

  /// Whether exercise (variation) [id] is in Today.
  bool inToday(String id) => todayIds.contains(id);

  /// Puts exercises [ids] at the end of Today (each one once) and saves the
  /// list. No notify: the callers do it.
  void _addToToday(Iterable<String> ids) {
    final list = todayIds;
    final add = [for (final id in ids) if (exerciseCatalog.byId.containsKey(id) && !list.contains(id)) id];
    if (add.isEmpty && _todayDate == _today) return;
    _saveToday({...list, ...add}.toList());
    if (ids.contains(_preview)) _preview = null;
  }

  void _saveToday(List<String> ids) {
    _todayDate = _today;
    _todaySaved
      ..clear()
      ..addAll(ids);
    _prefs.setString(todayKey, jsonEncode({'date': _today, 'exercises': ids}));
  }

  /// The delete button on a Today card (D82): exercise [id] leaves Today,
  /// and today's sets of it go too (so does their XP: XP is worked out from
  /// the sets). Other variations of the same move keep theirs. The carousel
  /// goes to the card in its place, else the one before.
  void removeFromToday(String id) {
    final list = todayIds;
    final i = list.indexOf(id);
    if (i < 0) return;
    final rest = [...list]..removeAt(i);
    _saveToday(rest);
    if (_preview == id) _preview = null;
    if (pickedCard == id) {
      if (rest.isEmpty) {
        _prefs.remove(pickedCardKey);
      } else {
        setPickedCard(rest[min(i, rest.length - 1)]);
      }
    }
    if (setsToday(id) > 0) {
      _edit((l) => l..removeWhere((e) => e.exerciseId == id)); // notifies
    } else {
      notifyListeners();
    }
  }

  /// The CHALK "+" (D81): exercise [id] joins Today and is shown (D79).
  void addToToday(String id) {
    _addToToday([id]);
    setPickedCard(id);
    notifyListeners();
  }

  /// A modifier chip on the card of exercise [from] picked exercise [to]
  /// (D55). On a Today card the chip changes that card's variation: [to]
  /// takes the place of [from] in Today. When [to] is in Today already, the
  /// carousel goes there (no duplicates). When [from] has sets today, it
  /// stays (its sets are done) and [to] comes right after it. On the CHALK
  /// preview, the preview becomes [to].
  void changeVariant(String from, String to) {
    _remember(to);
    if (from != to) {
      final list = todayIds;
      final i = list.indexOf(from);
      if (i >= 0 && !list.contains(to)) {
        if (setsToday(from) > 0) {
          list.insert(i + 1, to);
        } else {
          list[i] = to;
        }
        _saveToday(list);
      } else if (i >= 0 && setsToday(from) == 0) {
        _saveToday(list..removeAt(i));
      }
      final preview = _preview == from;
      setPickedCard(to);
      if (preview && !list.contains(to)) _preview = to;
    }
    notifyListeners();
  }

  /// A tap on a CHALK result row (D81): the carousel goes to exercise
  /// [id]. It does not join Today; the first set does that (D79). An
  /// exercise not in Today shows as a preview at the end of the carousel
  /// until the lifter swipes away from it (D82). This is per variation:
  /// another variation of a Today move is a preview too.
  void selectExercise(String id) {
    _remember(id);
    setPickedCard(id);
    _preview = inToday(id) || !exerciseCatalog.byId.containsKey(id) ? null : id;
    notifyListeners();
  }

  /// The exercise a CHALK row selected that is not in Today (D82), in
  /// memory only: it shows after the Today cards until the carousel leaves it.
  String? _preview;
  String? get previewId =>
      _preview != null && !inToday(_preview!) && exerciseCatalog.byId.containsKey(_preview) ? _preview : null;

  /// BACK TO TODAY on the CHALK sheet (D81): the words are wiped and the
  /// carousel goes to the first Today card, or to the start of the list
  /// when Today is empty (no card picked).
  void backToToday() {
    _chalk.clear();
    _preview = null;
    final first = todayIds.firstOrNull;
    if (first != null) {
      setPickedCard(first);
    } else {
      _prefs.remove(pickedCardKey);
    }
    notifyListeners();
  }

  /// The exercises (variations) a past day trained, each one once, in the
  /// order of the day, worked out from the saved session. Exercises the
  /// list no longer has are left out.
  List<CatalogExercise> dayMoves(String date) {
    final s = _sessions[date];
    if (s == null || s.legacy) return const [];
    final seen = <String>{};
    return [
      for (final e in s.exercises)
        if (e.sets > 0 && exerciseCatalog.byId[e.exerciseId] != null && seen.add(e.exerciseId))
          exerciseCatalog.byId[e.exerciseId]!,
    ];
  }

  /// The days before today with exercises to copy, newest first (COPY A
  /// PAST DAY, D79).
  List<String> get pastDays => [
        for (final s in _sessions.values)
          if (s.date.compareTo(_today) < 0 && dayMoves(s.date).isNotEmpty) s.date,
      ]..sort((a, b) => b.compareTo(a));

  /// COPY: the variations done on day [date] join Today; the sets do not (D79).
  void copyDay(String date) {
    final ids = [for (final e in dayMoves(date)) e.id];
    if (ids.isEmpty) return;
    _addToToday(ids);
    setPickedCard(ids.first);
    notifyListeners();
  }

  /// The workout carousel (D82): one card per Today exercise, then the
  /// CHALK preview when there is one. No catalog after them: CHALK is the
  /// way to the other cards. A card keeps all the exercises of its move: no
  /// chip is greyed by class (D89).
  List<TodayEntry> get carousel {
    _favoritesToVariants();
    final preview = previewId;
    final out = <TodayEntry>[];
    for (final id in [...todayIds, ?preview]) {
      final e = exerciseCatalog.byId[id];
      if (e == null) continue;
      final key = exerciseCatalog.groupKeyOf(id);
      final full = exerciseCatalog.byKey[key];
      final g = full != null && full.variants.any((v) => v.id == id) ? full : ExerciseGroup(key, e.name, [e]);
      out.add(TodayEntry(e, g));
    }
    return out;
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

  /// Tap on the world: one more working set of exercise [id]. The first
  /// set on an exercise puts that variation in Today (D79, D82).
  void addSet(String id) {
    _addToToday([id]);
    _addSet(id);
  }

  void _addSet(String id) {
    // A weighted move logs the set's weight and reps (D84), carried from
    // the set before (today, else the last day with this exercise).
    // The first set takes what the strip set before it (D85).
    final first = setsToday(id) == 0 ? _next.remove(id) : null;
    final log = isWeighted(id) ? [..._logPadded(id, setsToday(id)), first ?? lastSetLog(id)?.carried ?? const SetLog()] : null;
    _edit((l) {
      final i = l.indexWhere((e) => e.exerciseId == id);
      return i < 0
          // The score now sets the XP tier of the day's sets (D91).
          ? (l..add(SessionExercise(exerciseId: id, sets: 1, log: log ?? const [], score: exerciseCatalog.byId[id]?.score)))
          : (l..[i] = l[i].copyWith(sets: l[i].sets + 1, log: log));
    });
  }

  /// Hold on the world: one working set less (for a wrong tap), with its
  /// weight and reps (D84). An exercise with no sets left leaves the session.
  void removeSet(String id) {
    if (setsToday(id) == 0) return;
    _edit((l) {
      final i = l.indexWhere((e) => e.exerciseId == id);
      final e = l[i];
      return e.sets == 1
          ? (l..removeAt(i))
          : (l..[i] = e.copyWith(sets: e.sets - 1, log: e.log.take(e.sets - 1).toList()));
    });
  }

  // -------------------------------------------------- weight and reps (D84)

  /// The tools that log weight and reps (D84): barbell, dumbbell,
  /// kettlebell, cable, machine (and Smith machine), EZ bar. Not bodyweight,
  /// bands, balls or cardio.
  static const weightedEquipment = {'barbell', 'dumbbell', 'kettlebells', 'cable', 'machine', 'e-z curl bar'};

  /// Whether exercise [id] logs weight and reps.
  bool isWeighted(String id) {
    final e = exerciseCatalog.byId[id];
    return e != null && e.category != 'cardio' && weightedEquipment.contains(e.equipment);
  }

  /// Today's set logs of exercise [id], one per set (empty for sets with none).
  List<SetLog> setLogs(String id) => _logPadded(id, setsToday(id));

  List<SetLog> _logPadded(String id, int n) {
    final log = todaySession?.exercises.where((e) => e.exerciseId == id).firstOrNull?.log ?? const <SetLog>[];
    return [for (var k = 0; k < n; k++) k < log.length ? log[k] : const SetLog()];
  }

  /// The last set log of exercise [id] with values: today's, else the last
  /// day's with that exercise. Null with no history.
  SetLog? lastSetLog(String id) {
    final today = setLogs(id).lastWhere((l) => !l.isEmpty, orElse: () => const SetLog());
    if (!today.isEmpty) return today;
    final days = _sessions.keys.where((d) => d.compareTo(_today) < 0).toList()..sort();
    for (final d in days.reversed) {
      final log = _sessions[d]!.exercises.where((e) => e.exerciseId == id).firstOrNull?.log ?? const <SetLog>[];
      final last = log.lastWhere((l) => !l.isEmpty, orElse: () => const SetLog());
      if (!last.isEmpty) return last;
    }
    return null;
  }

  /// The coming first set of exercise [id] (D85): what the strip shows
  /// before any set today. In memory only.
  final Map<String, SetLog> _next = {};

  /// The values the first set of [id] today will get: the strip's, else
  /// the last day's last set (carried), else empty.
  SetLog nextSetLog(String id) => _next[id] ?? lastSetLog(id)?.carried ?? const SetLog();

  /// The lifter sets the coming first set of [id]: a value given is typed.
  void setNextSetLog(String id, {double? kg, int? reps}) {
    final old = nextSetLog(id);
    _next[id] = SetLog(
      kg: kg ?? old.kg,
      reps: reps ?? old.reps,
      kgTyped: old.kgTyped || kg != null,
      repsTyped: old.repsTyped || reps != null,
    );
    notifyListeners();
  }

  /// The lifter sets set [index] (0 = the first) of exercise [id] today: a
  /// value given is saved as typed. Log only: XP does not change.
  void setSetLog(String id, int index, {double? kg, int? reps}) {
    final n = setsToday(id);
    if (index < 0 || index >= n) return;
    final log = _logPadded(id, n);
    final old = log[index];
    log[index] = SetLog(
      kg: kg ?? old.kg,
      reps: reps ?? old.reps,
      kgTyped: old.kgTyped || kg != null,
      repsTyped: old.repsTyped || reps != null,
    );
    _edit((l) {
      final i = l.indexWhere((e) => e.exerciseId == id);
      return l..[i] = l[i].copyWith(log: log);
    });
  }

  // ------------------------------------------------------------------- XP

  /// Set XP of a session (docs/rules.md §1, set by set; the tier of each
  /// entry's saved score, D91), only for card
  /// [key] or only for exercise [id] when given. Sets count per card: all
  /// the exercises of one move share the 10-set cap and the set numbers
  /// (D55), also when they are separate Today cards (D82).
  static int _setsXp(Session s, [String? key, String? id]) {
    final d = difficultyIndex(s.difficultyId);
    final n = <String, int>{};
    var xp = 0;
    for (final e in s.exercises) {
      final g = exerciseCatalog.groupKeyOf(e.exerciseId);
      for (var i = 0; i < e.sets; i++) {
        final k = n[g] = (n[g] ?? 0) + 1;
        if ((key == null || key == g) && (id == null || id == e.exerciseId)) xp += xpForSet(setNumber: k, difficulty: d, score: e.score, critical: isCritical(s.date, g, k));
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

  /// XP of the sets of exercise [id] today so far (with criticals; the set
  /// numbers and the cap are its move's, D55).
  int xpToday(String id) {
    final s = todaySession;
    return s == null ? 0 : _setsXp(s, exerciseCatalog.groupKeyOf(id), id);
  }

  /// Whether the last set of exercise [id] today was a critical set. Its
  /// number on the move is the one [_setsXp] gives it.
  bool lastSetCritical(String id) {
    final g = exerciseCatalog.groupKeyOf(id);
    var n = 0;
    for (final e in todaySession?.exercises ?? const <SessionExercise>[]) {
      if (exerciseCatalog.groupKeyOf(e.exerciseId) == g) n += e.sets;
      if (e.exerciseId == id) break;
    }
    return setsToday(id) > 0 && n <= xpSetsPerExercise && isCritical(_today, g, n);
  }

  // ----------------------------------------------------------------- backup

  /// 4: no achievements, and the old streak XP is in the XP events (D34).
  /// 5: no gear (D38).
  /// 6: favorites; exercise ids from the exercise list (D50, D53).
  /// 7: my gear (D89).
  static const backupVersion = 7;

  /// Backup file contents: every key of docs/data-schema.md §4.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': backupVersion,
        if (_profile != null) _profileKey: _profile!.toJson(),
        _bodyKey: [for (final b in _body) b.toJson()],
        _sessionsKey: _sessionsJson(_sessions.values),
        _xpKey: [for (final e in _events) e.toJson()],
        _favoritesKey: _favorites.toList(),
        myGearKey: _gear.toJson(),
      });

  /// Replaces everything with a backup file. Version 7 is [backupJson];
  /// version 6 is the same with no my gear (the class gear only).
  /// Versions 3 to 5 have no favorites, and their old exercise lists are
  /// frozen on import (D54). Versions 3 and 4 may hold achievements or gear (ignored); version 3
  /// has no saved streak XP (worked out again on import). Version 2 (the old app) goes through the same migration: its workout
  /// days become legacy sessions with legacy XP; there is no profile, so
  /// the setup runs again.
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || ![2, 3, 4, 5, 6, 7].contains(data['version'])) {
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
        if (data[myGearKey] is Map) myGearKey: jsonEncode(MyGear.fromJson(data[myGearKey]).toJson()),
      };
    }
    for (final k in [_profileKey, _bodyKey, _sessionsKey, _xpKey, _favoritesKey, myGearKey]) {
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

/// One card of the workout carousel (D82): a Today exercise (or the CHALK
/// preview) and the card whose chips pick its variation.
class TodayEntry {
  const TodayEntry(this.exercise, this.card);

  final CatalogExercise exercise;
  final ExerciseGroup card;

  String get id => exercise.id;
}
