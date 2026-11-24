// MINIMAL weight and reps (D84, docs/moodboard/today-logging/MINIMAL.md).
// After a set on a weighted move, a small strip on the exercise card lets
// the lifter fix the weight and the reps of that set. Doing nothing is
// fine: the values carry over from the set before (muted until touched).
//
// - The header names the set the strip edits; "SAME AS SET n" while the
//   values are carried and untouched.
// - Steppers: 2.5 kg and 1 rep; a hold repeats. A tap on a number opens
//   the arcade keypad (digits only) for a direct value.
// - The trail: today's sets as pips (weight×reps); a tap edits that set,
//   a tap on the last goes back to the newest.
// Log only: weight and reps never change XP.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/model.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';

/// Weight as text: 24, 22.5; null: —.
String kgText(double? kg) => kg == null ? '—' : (kg == kg.roundToDouble() ? '${kg.toInt()}' : kg.toStringAsFixed(1));

/// One set in the trail: 22×10, —×8.
String pipText(SetLog l) => '${kgText(l.kg)}×${l.reps ?? '—'}';

/// The strip for exercise [id]. Hidden (empty) before its first set today
/// and on moves that are not weighted.
class LogStrip extends StatefulWidget {
  const LogStrip({super.key, required this.store, required this.id});

  final LogStore store;
  final String id;

  @override
  State<LogStrip> createState() => _LogStripState();
}

class _LogStripState extends State<LogStrip> {
  /// The set the strip edits (0 = the first); null: the newest.
  int? _editing;
  int _lastCount = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = Pal.of(context);
    final logs = store.setLogs(widget.id);
    if (!store.isWeighted(widget.id) || logs.isEmpty) return const SizedBox.shrink();
    // A new set (or an undo): back to the newest.
    if (logs.length != _lastCount) {
      _lastCount = logs.length;
      _editing = null;
    }
    final at = (_editing ?? logs.length - 1).clamp(0, logs.length - 1);
    final l = logs[at];
    final same = at > 0 && !l.kgTyped && !l.repsTyped && !l.isEmpty;
    void setKg(double v) => store.setSetLog(widget.id, at, kg: (v.clamp(0, 999) * 2).round() / 2);
    void setReps(int v) => store.setSetLog(widget.id, at, reps: v.clamp(0, 999));
    // The value now (a held stepper repeats from the newest value).
    SetLog now() {
      final all = store.setLogs(widget.id);
      return at < all.length ? all[at] : const SetLog();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 18, 6),
      child: Container(
        key: const ValueKey('log-strip'),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: p.panel,
          border: Border.all(color: p.ink, width: 3),
          boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(t('log.set', {'n': at + 1}), key: const ValueKey('log-set'), style: display(15, p.ink)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [t('log.optional'), if (same) t('log.sameAs', {'n': at})].join(' · '),
                    key: const ValueKey('log-note'),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(10, p.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _Stepper(
                    id: 'kg',
                    value: kgText(l.kg),
                    unit: t('log.kg'),
                    typed: l.kgTyped,
                    onStep: (d) => setKg((now().kg ?? 0) + d * 2.5),
                    onType: () => _type(context, kgText(l.kg), decimal: true, (s) {
                      final v = double.tryParse(s);
                      if (v != null) setKg(v);
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stepper(
                    id: 'reps',
                    value: '${l.reps ?? '—'}',
                    unit: t('log.reps'),
                    typed: l.repsTyped,
                    onStep: (d) => setReps((now().reps ?? 0) + d),
                    onType: () => _type(context, '${l.reps ?? ''}', decimal: false, (s) {
                      final v = int.tryParse(s);
                      if (v != null) setReps(v);
                    }),
                  ),
                ),
              ],
            ),
            if (logs.length > 1) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                key: const ValueKey('log-trail'),
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  spacing: 5,
                  children: [
                    for (final (i, s) in logs.indexed)
                      GestureDetector(
                        key: ValueKey('log-pip-$i'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _editing = i == logs.length - 1 ? null : i);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: i == at ? p.lime : p.panel,
                            border: Border.all(color: p.ink, width: 2),
                          ),
                          child: Text('${i + 1} · ${pipText(s)}', style: mono(10, s.kgTyped || s.repsTyped ? p.ink : p.inkSoft)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _type(BuildContext context, String start, ValueChanged<String> done, {required bool decimal}) async {
    final s = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kNight,
      builder: (_) => ArcadeKeypad(start: start == '—' ? '' : start, decimal: decimal),
    );
    if (s != null && s.isNotEmpty) done(s);
  }
}

/// [−] value unit [+]. A hold on a button repeats it. The value is muted
/// while it is carried, in full ink once typed.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.value,
    required this.unit,
    required this.typed,
    required this.onStep,
    required this.onType,
  });

  final String id, value, unit;
  final bool typed;
  final ValueChanged<int> onStep;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        _RepeatButton(id: 'log-$id-minus', label: '−', onStep: () => onStep(-1)),
        Expanded(
          child: GestureDetector(
            key: ValueKey('log-$id-value'),
            behavior: HitTestBehavior.opaque,
            onTap: onType,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: display(24, typed ? p.ink : p.inkSoft)),
                  const SizedBox(width: 3),
                  Text(unit, style: mono(10, typed ? p.ink : p.inkSoft)),
                ],
              ),
            ),
          ),
        ),
        _RepeatButton(id: 'log-$id-plus', label: '+', onStep: () => onStep(1)),
      ],
    );
  }
}

/// A stepper button: a tap steps once, a hold repeats.
class _RepeatButton extends StatefulWidget {
  const _RepeatButton({required this.id, required this.label, required this.onStep});

  final String id, label;
  final VoidCallback onStep;

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  Timer? _timer;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      key: ValueKey(widget.id),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onStep();
      },
      onLongPressStart: (_) {
        widget.onStep();
        _timer = Timer.periodic(const Duration(milliseconds: 110), (_) => widget.onStep());
      },
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.sky,
          border: Border.all(color: p.ink, width: 2),
          boxShadow: [BoxShadow(color: p.ink, offset: const Offset(2, 2))],
        ),
        child: Text(widget.label, style: display(20, p.on)),
      ),
    );
  }
}

/// The arcade keypad (D84): digits only (and a point for kg), DEL and OK,
/// in the style of the FORJA keyboard. Pops with the text typed.
class ArcadeKeypad extends StatefulWidget {
  const ArcadeKeypad({super.key, required this.start, required this.decimal});

  final String start;
  final bool decimal;

  @override
  State<ArcadeKeypad> createState() => _ArcadeKeypadState();
}

class _ArcadeKeypadState extends State<ArcadeKeypad> {
  late String _s = widget.start;

  void _key(String k) => setState(() {
        if (k == '.' && (_s.contains('.') || _s.isEmpty)) return;
        if (_s.length >= 6) return;
        _s += k;
      });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget key(String id, String label, VoidCallback? onTap, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: GestureDetector(
              key: ValueKey('pad-$id'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onTap();
                    },
              child: Opacity(
                opacity: onTap == null ? 0.3 : 1,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color ?? p.panel, border: Border.all(color: p.ink, width: 2)),
                  child: Text(label, style: display(20, p.ink)),
                ),
              ),
            ),
          ),
        );
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('arcade-keypad'),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(border: Border.all(color: p.lime, width: 2)),
              child: Text(_s.isEmpty ? '—' : '${_s}_', key: const ValueKey('pad-value'), style: display(28, p.lime)),
            ),
            for (final row in ['123', '456', '789'])
              Row(children: [for (final c in row.split('')) key(c, c, () => _key(c))]),
            Row(children: [
              key('point', '.', widget.decimal ? () => _key('.') : null),
              key('0', '0', () => _key('0')),
              key('del', t('kb.del'), () => setState(() => _s = _s.isEmpty ? '' : _s.substring(0, _s.length - 1)), color: p.orange),
            ]),
            Row(children: [key('ok', t('kb.ok'), () => Navigator.of(context).pop(_s), color: p.lime)]),
          ],
        ),
      ),
    );
  }
}
