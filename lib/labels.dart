// Exercise labels in the current language (D68). The English names in
// lib/game/exercises.dart and the exercise list are the fallback.

import 'game/exercises.dart';
import 'i18n.dart';

/// A body part's name: `part.<id>`.
String bodyPartLabel(String id) => tOr('part.$id', bodyPartById(id)?.name ?? id);

/// A database muscle ("middle back"): `muscle.<muscle>`.
String muscleLabel(String muscle) => tOr('muscle.$muscle', muscle);

/// A modifier row's title: `axis.<id>`.
String axisLabel(ModifierAxis a) => tOr('axis.${a.id}', a.label);

/// A modifier row's "no value" chip (Flat, Both...): `axis.<id>.none`.
String axisNone(ModifierAxis a) => tOr('axis.${a.id}.none', a.none);

/// A modifier value from the exercise list ("Close Grip"): `mod.<value>`.
String modLabel(String value) => tOr('mod.$value', value);
