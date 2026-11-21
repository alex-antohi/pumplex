import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';

/// 100 → "100", 102.5 → "102.5"
String fmtKg(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// "100×5", "100 kg", "12 reps"
String fmtSet(SetEntry s) {
  if (s.kg != null && s.reps != null) return '${fmtKg(s.kg!)}×${s.reps}';
  if (s.kg != null) return '${fmtKg(s.kg!)} kg';
  if (s.reps != null) return '${s.reps} reps';
  return '–';
}

class SetEntry {
  SetEntry({this.kg, this.reps, this.done = false});

  double? kg;
  int? reps;

  /// Ticked with ✔ (typing numbers alone doesn't count).
  bool done;

  bool get isEmpty => kg == null && reps == null;

  Map<String, dynamic> toJson() => {
        if (kg != null) 'kg': kg,
        if (reps != null) 'reps': reps,
        'done': done,
      };

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        kg: (j['kg'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
        // Logged before ticking existed: count it as done.
        done: j['done'] as bool? ?? true,
      );
}

class ExerciseLog {
  ExerciseLog(this.name, [List<SetEntry>? sets]) : sets = sets ?? [];

  /// Movement name when this was logged (it can change over time).
  String name;
  final List<SetEntry> sets;

  bool get hasData => sets.any((s) => !s.isEmpty);

  /// Sets up to the last non-empty one.
  List<SetEntry> get filledSets {
    var end = sets.length;
    while (end > 0 && sets[end - 1].isEmpty) {
      end--;
    }
    return sets.sublist(0, end);
  }

  double? get topKg {
    double? top;
    for (final s in sets) {
      if (s.kg != null && (top == null || s.kg! > top)) top = s.kg;
    }
    return top;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': [for (final s in filledSets) s.toJson()],
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        j['name'] as String? ?? '',
        [
          for (final s in (j['sets'] as List? ?? const []))
            SetEntry.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );
}

/// Storage key for session [n] (1-based). Zero-padded so keys sort in order.
String sessionKey(int n) => 'S${n.toString().padLeft(5, '0')}';
int sessionNumber(String key) => int.parse(key.substring(1));

/// A program day that was marked done with "I WORKED" / "I RESTED".
class Session {
  const Session({
    required this.day,
    required this.date,
    required this.rested,
    this.startMs,
    this.endMs,
  });

  /// Program day 1..7.
  final int day;

  /// yyyy-MM-dd it was marked done.
  final String date;
  final bool rested;

  /// START TRAINING and I WORKED times (epoch ms), if the clock was used.
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

typedef KeyedLog = ({String key, ExerciseLog log});

/// Everything the app remembers, saved on the phone with shared_preferences:
/// sessions done, sets logged per session, movement swaps.
class LogStore extends ChangeNotifier {
  LogStore(this._prefs)
      : chaos = ValueNotifier(_prefs.getBool('chaos') ?? false),
        cel = ValueNotifier(_prefs.getBool('cel') ?? false) {
    final raw = _prefs.getString(_logsKey);
    if (raw != null) {
      try {
        _logs.addAll(_parseLogs(raw));
      } catch (_) {
        // Never overwrite data we could not read: keep a copy aside.
        _prefs.setString('${_logsKey}_unreadable_${DateTime.now().millisecondsSinceEpoch}', raw);
      }
    }
    _sessions.addAll(_parseSessions(_prefs.getString(_sessionsKey)));
    _swaps.addAll(_parseSwaps(_prefs.getString(_swapsKey)));
  }

  static const _logsKey = 'logs_v2';
  static const _sessionsKey = 'sessions_v2';
  static const _swapsKey = 'swaps_v2';

  final SharedPreferences _prefs;

  /// sessionKey -> exerciseId -> log
  final Map<String, Map<String, ExerciseLog>> _logs = {};
  final List<Session> _sessions = [];

  /// exerciseId -> fromSessionKey -> movement name
  final Map<String, Map<String, String>> _swaps = {};
  Timer? _saveTimer;

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

  // ---------------------------------------------------------------- parsing

  static Map<String, Map<String, ExerciseLog>> _parseLogs(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map) throw const FormatException('Not a logs document');
    return {
      for (final s in data.entries)
        s.key as String: {
          for (final ex in (s.value as Map).entries)
            ex.key as String:
                ExerciseLog.fromJson(Map<String, dynamic>.from(ex.value as Map)),
        },
    };
  }

  static List<Session> _parseSessions(String? raw) {
    if (raw == null) return [];
    return [
      for (final s in jsonDecode(raw) as List)
        Session.fromJson(Map<String, dynamic>.from(s as Map)),
    ];
  }

  static Map<String, Map<String, String>> _parseSwaps(String? raw) {
    if (raw == null) return {};
    return {
      for (final e in (jsonDecode(raw) as Map).entries)
        e.key as String: Map<String, String>.from(e.value as Map),
    };
  }

  // --------------------------------------------------------------- sessions

  List<Session> get sessions => List.unmodifiable(_sessions);

  /// The session being trained now (not marked done yet).
  int get currentN => _sessions.length + 1;

  bool isDone(int n) => n >= 1 && n <= _sessions.length;

  /// Program day (1..7) of session [n]. Day 1 comes first; later sessions
  /// are projected from the last one done.
  int dayOf(int n) {
    if (isDone(n)) return _sessions[n - 1].day;
    final lastDay = _sessions.isEmpty ? 0 : _sessions.last.day;
    return (lastDay + (n - _sessions.length) - 1) % 7 + 1;
  }

  /// When session [n] was done (today for one that isn't done yet).
  DateTime dateOf(int n) =>
      isDone(n) ? parseDateKey(_sessions[n - 1].date) : dateOnly(DateTime.now());

  static const _startedKey = 'session_started_ms';

  /// When START TRAINING was pressed for the current session.
  DateTime? get startedAt {
    final ms = _prefs.getInt(_startedKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// START TRAINING: the current session's clock starts now.
  void startTraining() {
    _prefs.setInt(_startedKey, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  /// "I WORKED" / "I RESTED": the current session is done, next one is up.
  void complete({required bool rested}) {
    final now = DateTime.now();
    final started = _prefs.getInt(_startedKey);
    _sessions.add(Session(
      day: dayOf(currentN),
      date: dateKey(now),
      rested: rested,
      startMs: started,
      endMs: started == null ? null : now.millisecondsSinceEpoch,
    ));
    _prefs.remove(_startedKey);
    _saveSessions();
    notifyListeners();
  }

  /// Takes back the last "I WORKED / I RESTED", as long as nothing has been
  /// logged in the session after it yet. Its clock keeps running.
  bool undoComplete() {
    if (_sessions.isEmpty) return false;
    final next = _logs[sessionKey(currentN)];
    if (next != null && next.values.any((l) => l.hasData)) return false;
    final undone = _sessions.removeLast();
    if (undone.startMs != null) {
      _prefs.setInt(_startedKey, undone.startMs!);
    } else {
      _prefs.remove(_startedKey);
    }
    _saveSessions();
    notifyListeners();
    return true;
  }

  void _saveSessions() =>
      _prefs.setString(_sessionsKey, jsonEncode([for (final s in _sessions) s.toJson()]));

  // ------------------------------------------------------------------- logs

  ExerciseLog? get(String key, String exerciseId) => _logs[key]?[exerciseId];

  /// Log for editing, created if needed.
  ExerciseLog edit(String key, String exerciseId, String name) {
    final log = _logs
        .putIfAbsent(key, () => {})
        .putIfAbsent(exerciseId, () => ExerciseLog(name));
    log.name = name;
    return log;
  }

  /// Call after mutating a log from [edit].
  void changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _prefs.setString(_logsKey, jsonEncode(_logsJson()));
  }

  Map<String, dynamic> _logsJson() {
    final out = <String, dynamic>{};
    for (final key in _logs.keys.toList()..sort()) {
      final exercises = {
        for (final e in _logs[key]!.entries)
          if (e.value.hasData) e.key: e.value.toJson(),
      };
      if (exercises.isNotEmpty) out[key] = exercises;
    }
    return out;
  }

  /// Sessions of [exerciseId] before session [key], oldest first
  /// (optionally only under movement [name]).
  List<KeyedLog> history(String exerciseId, String key, {String? name}) {
    final out = <KeyedLog>[];
    for (final e in _logs.entries) {
      final log = e.value[exerciseId];
      if (e.key.compareTo(key) < 0 &&
          log != null &&
          log.hasData &&
          (name == null || log.name == name)) {
        out.add((key: e.key, log: log));
      }
    }
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  /// Most recent earlier session of [exerciseId] (optionally under [name]).
  KeyedLog? lastBefore(String key, String exerciseId, {String? name}) {
    final h = history(exerciseId, key, name: name);
    return h.isEmpty ? null : h.last;
  }

  /// Heaviest weight logged for [exerciseId] before session [key].
  double? bestBefore(String key, String exerciseId, {String? name}) {
    double? best;
    for (final e in history(exerciseId, key, name: name)) {
      final top = e.log.topKg;
      if (top != null && (best == null || top > best)) best = top;
    }
    return best;
  }

  /// Every logged exercise with data, in session order.
  List<({int n, String id, ExerciseLog log})> allLogs() {
    final keys = _logs.keys.toList()..sort();
    return [
      for (final k in keys)
        for (final e in _logs[k]!.entries)
          if (e.value.hasData) (n: sessionNumber(k), id: e.key, log: e.value),
    ];
  }

  /// Logged exercises from sessions dated [from]..[to] (yyyy-MM-dd, inclusive).
  List<({int n, String date, String id, ExerciseLog log})> betweenDates(String from, String to) {
    final out = <({int n, String date, String id, ExerciseLog log})>[];
    for (final e in allLogs()) {
      final d = dateKey(dateOf(e.n));
      if (d.compareTo(from) >= 0 && d.compareTo(to) <= 0) {
        out.add((n: e.n, date: d, id: e.id, log: e.log));
      }
    }
    return out;
  }

  /// Date of the first session with anything logged.
  String? get firstDate {
    final all = allLogs();
    return all.isEmpty ? null : dateKey(dateOf(all.first.n));
  }

  int get loggedSessions =>
      _logs.values.where((d) => d.values.any((l) => l.hasData)).length;

  // ------------------------------------------------------------------ swaps

  /// Movement chosen for [exerciseId] at or before session [key], if any.
  String? swapOn(String exerciseId, String key) {
    final m = _swaps[exerciseId];
    if (m == null) return null;
    String? from;
    for (final k in m.keys) {
      if (k.compareTo(key) <= 0 && (from == null || k.compareTo(from) > 0)) from = k;
    }
    return from == null ? null : m[from];
  }

  void setSwap(String exerciseId, String fromKey, String name) {
    _swaps.putIfAbsent(exerciseId, () => {})[fromKey] = name;
    _prefs.setString(_swapsKey, jsonEncode(_swaps));
    notifyListeners();
  }

  /// Every movement name used in this slot, most recent first.
  List<String> namesUsed(String exerciseId) {
    final seen = <String, String>{}; // name -> latest session key
    void see(String name, String key) {
      if (name.isEmpty) return;
      final prev = seen[name];
      if (prev == null || key.compareTo(prev) > 0) seen[name] = key;
    }

    for (final e in _logs.entries) {
      final log = e.value[exerciseId];
      if (log != null && log.hasData) see(log.name, e.key);
    }
    _swaps[exerciseId]?.forEach((key, name) => see(name, key));
    return seen.keys.toList()..sort((a, b) => seen[b]!.compareTo(seen[a]!));
  }

  // "Not yet" on a swap reminder: hidden up to and including session key.

  bool snoozed(String exerciseId, String key) {
    final until = _prefs.getString('snooze2_$exerciseId');
    return until != null && key.compareTo(until) <= 0;
  }

  void snooze(String exerciseId, String untilKey) {
    _prefs.setString('snooze2_$exerciseId', untilKey);
    notifyListeners();
  }

  // ----------------------------------------------------------------- backup

  /// Backup file contents: sessions, logs and movement swaps.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': 2,
        'sessions': [for (final s in _sessions) s.toJson()],
        'logs': _logsJson(),
        'swaps': _swaps,
      });

  /// Replaces everything with a backup made by [backupJson].
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || data['version'] != 2) {
      throw const FormatException('Not a PUMPLEX backup');
    }
    // Parse everything before touching current data.
    final logs = _parseLogs(jsonEncode(data['logs'] ?? {}));
    final sessions = _parseSessions(jsonEncode(data['sessions'] ?? []));
    final swaps = _parseSwaps(jsonEncode(data['swaps'] ?? {}));
    _logs
      ..clear()
      ..addAll(logs);
    _sessions
      ..clear()
      ..addAll(sessions);
    _swaps
      ..clear()
      ..addAll(swaps);
    _saveSessions();
    await _prefs.setString(_swapsKey, jsonEncode(_swaps));
    notifyListeners();
    await flush();
  }
}
