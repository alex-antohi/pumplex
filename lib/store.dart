import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';

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

/// Everything the app remembers, on the phone only (shared_preferences).
///
/// Now: sessions done and the session clock. Sets and swaps logged by the old
/// tracking system stay in storage untouched ([_legacy]) and go into backup
/// files as they are, so no data is lost.
class LogStore extends ChangeNotifier {
  LogStore(this._prefs)
      : chaos = ValueNotifier(_prefs.getBool('chaos') ?? false),
        cel = ValueNotifier(_prefs.getBool('cel') ?? false) {
    _sessions.addAll(_parseSessions(_prefs.getString(_sessionsKey)));
  }

  static const _sessionsKey = 'sessions_v2';
  static const _startedKey = 'session_started_ms';

  /// Backup field -> storage key, kept from the old tracking system.
  static const _legacy = {'logs': 'logs_v2', 'swaps': 'swaps_v2'};

  final SharedPreferences _prefs;
  final List<Session> _sessions = [];

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

  static List<Session> _parseSessions(String? raw) {
    if (raw == null) return [];
    return [
      for (final s in jsonDecode(raw) as List)
        Session.fromJson(Map<String, dynamic>.from(s as Map)),
    ];
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

  /// Takes back the last "I WORKED / I RESTED". Its clock keeps running.
  bool undoComplete() {
    if (_sessions.isEmpty) return false;
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

  // ----------------------------------------------------------------- backup

  /// Backup file contents: sessions, plus the old tracking data as it is.
  String backupJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'pumplex',
        'version': 2,
        'sessions': [for (final s in _sessions) s.toJson()],
        for (final e in _legacy.entries)
          e.key: jsonDecode(_prefs.getString(e.value) ?? '{}'),
      });

  /// Replaces everything with a backup made by [backupJson] (also reads
  /// backups from the old tracking system).
  Future<void> importBackup(String raw) async {
    final data = jsonDecode(raw);
    if (data is! Map || data['app'] != 'pumplex' || data['version'] != 2) {
      throw const FormatException('Not a PUMPLEX backup');
    }
    // Parse everything before touching current data.
    final sessions = _parseSessions(jsonEncode(data['sessions'] ?? []));
    final legacy = {
      for (final e in _legacy.entries)
        e.value: data[e.key] is Map ? jsonEncode(data[e.key]) : null,
    };
    _sessions
      ..clear()
      ..addAll(sessions);
    _saveSessions();
    for (final e in legacy.entries) {
      e.value == null ? await _prefs.remove(e.key) : await _prefs.setString(e.key, e.value!);
    }
    await _prefs.remove(_startedKey);
    notifyListeners();
  }
}
