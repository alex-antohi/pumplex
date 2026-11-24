// The app's texts in each language (D68): one flat JSON file per language
// in assets/i18n/ (`en.json`, `ro.json`), the same keys in every file.
// No packages: rootBundle loads the files, shared_preferences keeps the
// language the user picked.
//
// - t('key', {'name': value}) looks a key up and fills {name}.
// - tn('key', n) picks the plural form `key.one`, `key.few` or `key.other`
//   for n (Romanian: 1 / 0, 2-19 / 20+ "de") and fills {n}.
// - A key the language lacks falls back to English; a key English lacks
//   falls back to [fallback] (or to the key itself).
// - Exercise names: `move.<base, lower case>` and, per variation, a name
//   composed from the move and the `name.*` parts (D80, composeName), or a
//   special `exercise.<id>`; the English name of the list is the fallback
//   (exerciseLabel, groupLabel).

import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/exercises.dart';

class I18n {
  I18n._();

  static final instance = I18n._();

  /// The languages with a file in assets/i18n/, English first (the fallback).
  static const languages = ['en', 'ro'];

  /// The user's pick (no key: the phone's language).
  static const prefsKey = 'language_v1';

  static String asset(String lang) => 'assets/i18n/$lang.json';

  final Map<String, Map<String, String>> _files = {};
  String _lang = 'en';
  SharedPreferences? _prefs;

  String get language => _lang;

  /// The phone's language if the app has it, else English.
  static String phoneLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return languages.contains(code) ? code : 'en';
  }

  /// Loads every language file and picks the saved language, else the phone's.
  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    for (final l in languages) {
      _files[l] = parse(await rootBundle.loadString(asset(l)));
    }
    final saved = prefs.getString(prefsKey);
    _lang = languages.contains(saved) ? saved! : phoneLanguage();
  }

  /// For tests: set the files straight from their JSON text.
  void useJson(Map<String, String> jsonByLang, {String lang = 'en', SharedPreferences? prefs}) {
    _prefs = prefs;
    _files
      ..clear()
      ..addAll({for (final e in jsonByLang.entries) e.key: parse(e.value)});
    _lang = lang;
  }

  static Map<String, String> parse(String json) =>
      {for (final e in (jsonDecode(json) as Map).entries) e.key as String: e.value as String};

  /// Changes the language and saves the pick.
  void setLanguage(String lang) {
    if (!languages.contains(lang)) return;
    _lang = lang;
    _prefs?.setString(prefsKey, lang);
  }

  /// The text of [key] (null when no language has it).
  String? lookup(String key) => _files[_lang]?[key] ?? _files['en']?[key];

  String t(String key, [Map<String, Object?> params = const {}, String? fallback]) =>
      _fill(lookup(key) ?? fallback ?? key, params);

  String tn(String key, int n, [Map<String, Object?> params = const {}]) {
    final form = pluralForm(_lang, n);
    final text = _files[_lang]?['$key.$form'] ?? _files[_lang]?['$key.other'] ?? lookup('$key.${pluralForm('en', n)}');
    return _fill(text ?? key, {'n': n, ...params});
  }

  /// CLDR plural form for an integer: English one / other; Romanian one
  /// (1), few (0, 2-19, and x01-x19), other (20+: "20 DE SERII").
  static String pluralForm(String lang, int n) {
    if (lang == 'ro') {
      if (n == 1) return 'one';
      final r = n.abs() % 100;
      return n == 0 || (r >= 1 && r <= 19) ? 'few' : 'other';
    }
    return n == 1 ? 'one' : 'other';
  }

  static String _fill(String text, Map<String, Object?> params) {
    if (params.isEmpty || !text.contains('{')) return text;
    return text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final k = m[1]!;
      return params.containsKey(k) ? '${params[k]}' : m[0]!;
    });
  }
}

/// The text of [key] in the current language, {placeholders} filled.
String t(String key, [Map<String, Object?> params = const {}]) => I18n.instance.t(key, params);

/// [key] with a [fallback] for keys that may not be there (data labels).
String tOr(String key, String fallback, [Map<String, Object?> params = const {}]) =>
    I18n.instance.t(key, params, fallback);

/// The plural form of [key] for [n] (`key.one` / `key.few` / `key.other`).
String tn(String key, int n, [Map<String, Object?> params = const {}]) => I18n.instance.tn(key, n, params);

/// An exercise's name: its special name `exercise.<id>`, else the name
/// composed from its move and modifiers in the current language (D80,
/// composeName), else the English [name] (a forged move, an old id).
String exerciseLabel(String id, String name) {
  final special = I18n.instance.lookup('exercise.$id');
  if (special != null) return special;
  final e = exerciseCatalog.byId[id];
  final g = e == null || !e.isMove ? null : exerciseCatalog.groupOf(id);
  return g == null ? name : composeName(e!, g, I18n.instance.lookup);
}

/// A workout card's name: `move.<base>` for a move (key `move:<base>`),
/// else the exercise's `exercise.<id>`; the English [name] as the fallback.
String groupLabel(String key, String name) =>
    key.startsWith('move:') ? tOr('move.${key.substring(5)}', name) : exerciseLabel(key, name);

/// A decimal number with the language's separator ("1.75" / "1,75").
String decimal(double v, int digits) => v.toStringAsFixed(digits).replaceAll('.', t('num.decimal'));

/// Changes the language, saves it and rebuilds every widget (const
/// widgets too, so no old text stays on screen).
void switchLanguage(String lang) {
  I18n.instance.setLanguage(lang);
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}
