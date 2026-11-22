// The filter sheet of the workout (D51-D53). A tap on the CLASS,
// DIFFICULTY or BODY PART tag opens it at that section. The sections
// cascade: each chip shows how many exercises it gives, counted with the
// filters before it only; a chip with 0 is greyed out. Changes apply at
// once; SHOW N EXERCISES closes the sheet, RESET TO MINE goes back to your
// class, your mode and all body parts.

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/exercises.dart';
import '../pumplex.dart';
import '../store.dart';
import 'setup.dart' show difficultyColor;
import 'sprite.dart' show classColor;

enum FilterSection { classes, difficulty, body }

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
  final _keys = {for (final s in FilterSection.values) s: GlobalKey()};

  @override
  void initState() {
    super.initState();
    // Open at the section of the tag that was tapped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[widget.at]!.currentContext;
      if (c != null && c.mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 200));
    });
  }

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
        final total = store.exercises.length;
        void set(ExerciseFilter n) => store.setFilter(n);
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
                        _Section(key: _keys[FilterSection.classes], title: 'Class', children: [
                          for (final c in gameClasses)
                            _Chip(
                              id: 'chip-class-${c.id}',
                              label: c.name,
                              count: f.countClass(cat, favs, c.id),
                              selected: f.classId == c.id,
                              color: classColor(p, c.id),
                              onTap: () => set(f.copyWith(classId: c.id)),
                            ),
                        ]),
                        _Section(key: _keys[FilterSection.difficulty], title: 'Difficulty', children: [
                          for (final (i, d) in difficulties.indexed)
                            _Chip(
                              id: 'chip-difficulty-${d.id}',
                              label: d.name,
                              count: f.countDifficulty(cat, favs, i),
                              selected: f.difficulty == i,
                              color: difficultyColor(p, i),
                              onTap: () => set(f.copyWith(difficulty: i)),
                            ),
                        ]),
                        _Section(key: _keys[FilterSection.body], title: 'Body part', children: [
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
                        ]),
                        // The muscles of the body part picked.
                        if (part != null)
                          _Section(title: 'Muscle', children: [
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
                          ]),
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
                        color: p.panel,
                        onTap: store.resetFilter,
                        child: const Text('RESET TO MINE'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrutalButton(
                          key: const ValueKey('filter-show'),
                          color: p.lime,
                          onTap: () => Navigator.of(context).pop(),
                          child: Text('SHOW $total ${total == 1 ? 'EXERCISE' : 'EXERCISES'}'),
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

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children});

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
                Text(label.toUpperCase(), style: display(14, fg)),
                const SizedBox(width: 6),
                Text('$count', style: mono(11, fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
