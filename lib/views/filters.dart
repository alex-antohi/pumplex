// The filter sheet of the workout (D51-D53, D73). A tap on the CLASS,
// DIFFICULTY or BODY PART tag opens a sheet with only that tag's options.
// CLASS and DIFFICULTY use the selection cards of the class screen: the
// class card (your lifter in that class's gear, swipe both ways round and
// round, dots under it) and the difficulty card (slider). BODY PART shows
// chips, and the muscles of the part picked; a chip that gives no exercises
// (counted with the earlier filters only) is greyed out; the chips show no
// numbers (D74). Changes apply at once and only to the filter, never to the
// profile; SHOW N EXERCISES closes the sheet, RESET TO MINE puts that tag
// back to yours (your class, your mode, all body parts).

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'carousel.dart';
import 'setup.dart' show ClassCardText, DifficultyCard, classTextHeight;
import 'sprite.dart' show CharacterSprite, classColor;

enum FilterSection { classes, difficulty, body }

// Exercise labels in the current language (D68). The English names in
// lib/game/exercises.dart and the exercise list are the fallback.

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

Future<void> showFilterSheet(BuildContext context, LogStore store, FilterSection at) {
  final p = Pal.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.bg,
    shape: Border(top: BorderSide(color: p.ink, width: 4)),
    builder: (_) => FilterSheet(store: store, at: at),
  );
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.store, required this.at});

  final LogStore store;
  final FilterSection at;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final f = store.filter;
        final favs = store.favorites;
        final cat = exerciseCatalog;
        final part = bodyPartById(f.body);
        final total = store.cards.length;
        void set(ExerciseFilter n) => store.setFilter(n);
        final at = widget.at;
        final mine = store.defaultFilter;
        // RESET TO MINE: only the tag this sheet is for (D73).
        void reset() => set(switch (at) {
          FilterSection.classes => f.copyWith(classId: mine.classId),
          FilterSection.difficulty => f.copyWith(difficulty: mine.difficulty),
          FilterSection.body => f.withBody(mine.body),
        });
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only the options of the tag that was tapped (D73).
                        if (at == FilterSection.classes) _ClassPicker(store: store),
                        if (at == FilterSection.difficulty)
                          Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 14),
                            child: SizedBox(
                              height: 120,
                              child: DifficultyCard(
                                index: f.difficulty,
                                onChanged: (i) => set(f.copyWith(difficulty: i)),
                              ),
                            ),
                          ),
                        if (at == FilterSection.body)
                          _Section(
                            title: t('label.bodyPart'),
                            children: [
                              _Chip(
                                id: 'chip-body-all',
                                label: 'All',
                                count: f.countBody(cat, favs, null),
                                selected: f.body == null,
                                color: p.sky,
                                onTap: () => set(f.withBody(null)),
                              ),
                              for (final b in bodyParts)
                                _Chip(
                                  id: 'chip-body-${b.id}',
                                  label: b.name,
                                  count: f.countBody(cat, favs, b.id),
                                  selected: f.body == b.id,
                                  color: p.sky,
                                  onTap: () => set(f.withBody(b.id)),
                                ),
                            ],
                          ),
                        // The muscles of the body part picked.
                        if (at == FilterSection.body && part != null)
                          _Section(
                            title: t('label.muscle'),
                            children: [
                              _Chip(
                                id: 'chip-muscle-all',
                                label: 'All ${part.name}',
                                count: f.countMuscle(cat, favs, null),
                                selected: f.muscle == null,
                                color: p.violet,
                                onTap: () => set(f.withMuscle(null)),
                              ),
                              for (final m in part.muscles)
                                _Chip(
                                  id: 'chip-muscle-$m',
                                  label: m,
                                  count: f.countMuscle(cat, favs, m),
                                  selected: f.muscle == m,
                                  color: p.violet,
                                  onTap: () => set(f.withMuscle(m)),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 24, 16),
                  child: Row(
                    children: [
                      BrutalButton(
                        key: const ValueKey('filter-reset'),
                        small: true,
                        color: p.sky,
                        onTap: reset,
                        child: Text(t('filter.reset')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrutalButton(
                          key: const ValueKey('filter-show'),
                          color: p.lime,
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(t('filter.show', {'exercises': tn('exercises', total)})),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The class card of the class screen, for the filter: your lifter in the
/// picked class's gear, the class name and equipment; swipe it (both ways,
/// round and round) or tap a dot to change the filter's class.
class _ClassPicker extends StatefulWidget {
  const _ClassPicker({required this.store});

  final LogStore store;

  @override
  State<_ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<_ClassPicker> with SwipeCarousel<_ClassPicker> {
  /// Room for the lifter on its pedestal (a 3x sprite on a phone).
  static const _stageHeight = 230.0;

  ExerciseFilter get _f => widget.store.filter;

  @override
  int get count => gameClasses.length;

  @override
  int get index => max(0, gameClasses.indexWhere((c) => c.id == _f.classId));

  @override
  void select(int i) => widget.store.setFilter(_f.copyWith(classId: gameClasses[i].id));

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(_f.classId);
    final color = classColor(p, cls.id);
    final character = widget.store.profile?.character;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          swipe(
            key: const ValueKey('class-card'),
            child: Brutal(
              shadow: color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (character != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SizedBox(
                        height: _stageHeight,
                        child: IgnorePointer(
                          child: CharacterSprite(
                            key: const ValueKey('filter-lifter'),
                            character: character,
                            classId: cls.id,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: classTextHeight,
                    child: slide(cls.id, ClassCardText(cls: cls, color: color)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          CarouselDots(
            prefix: 'class',
            ids: [for (final c in gameClasses) c.id],
            names: [for (final c in gameClasses) c.name],
            current: cls.id,
            colorOf: (id) => classColor(p, id),
            onTap: jump,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shout(title, color: Pal.of(context).ink),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      );
}

/// One option: its name and how many exercises it gives. Greyed out (and
/// not tappable) at 0, unless it is the current choice.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.id,
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String id, label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final off = count == 0 && !selected;
    final fg = selected ? p.on : p.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      child: GestureDetector(
        key: ValueKey(id),
        behavior: HitTestBehavior.opaque,
        onTap: off || selected ? null : onTap,
        child: Opacity(
          opacity: off ? 0.35 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color : p.panel,
              border: Border.all(color: p.ink, width: 3),
              boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // No number on the chip (D74); it is still greyed out at 0.
                Text(label.toUpperCase(), style: display(14, fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
