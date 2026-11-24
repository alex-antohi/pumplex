// MINIMAL weight and reps (D84, D85, docs/moodboard/today-logging/
// MINIMAL.md). On a weighted move, a small strip on the exercise card shows
// from the start: before the first set it sets the coming set (SET 1),
// after a set it fixes the set just done. Doing nothing is fine: the values
// carry over from the set before (muted until touched).
//
// - The header names the set the strip edits (no other text, D85).
// - Steppers: a tap steps 2.5 kg or 1 rep; a hold repeats by 5 (kg and
//   reps, D85). A tap on a number opens the arcade keypad (digits only).
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
    if (!store.isWeighted(widget.id)) return const SizedBox.shrink();
    // Before the first set: the coming set (D85).
    final coming = logs.isEmpty;
    // A new set (or an undo): back to the newest.
    if (logs.length != _lastCount) {
      _lastCount = logs.length;
      _editing = null;
    }
    final at = coming ? 0 : (_editing ?? logs.length - 1).clamp(0, logs.length - 1);
    final l = coming ? store.nextSetLog(widget.id) : logs[at];
    void save({double? kg, int? reps}) =>
        coming ? store.setNextSetLog(widget.id, kg: kg, reps: reps) : store.setSetLog(widget.id, at, kg: kg, reps: reps);
    void setKg(double v) => save(kg: (v.clamp(0, 999) * 2).round() / 2);
    void setReps(int v) => save(reps: v.clamp(0, 999));
    // The value now (a held stepper repeats from the newest value).
    SetLog now() {
      if (store.setLogs(widget.id).isEmpty) return store.nextSetLog(widget.id);
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
            Text(t('log.set', {'n': at + 1}), key: const ValueKey('log-set'), style: display(15, p.ink)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _Stepper(
                    id: 'kg',
                    value: kgText(l.kg),
                    unit: t('log.kg'),
                    typed: l.kgTyped,
                    onStep: (d, hold) => setKg((now().kg ?? 0) + d * (hold ? 5 : 2.5)),
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
                    onStep: (d, hold) => setReps((now().reps ?? 0) + d * (hold ? 5 : 1)),
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

/// [−] value unit [+]. A hold on a button repeats it, by 5 (D85). The value is muted
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
  /// A step of [sign] (−1 or +1); [hold]: the repeat of a hold.
  final void Function(int sign, bool hold) onStep;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        _RepeatButton(id: 'log-$id-minus', label: '−', onStep: (hold) => onStep(-1, hold)),
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
        _RepeatButton(id: 'log-$id-plus', label: '+', onStep: (hold) => onStep(1, hold)),
      ],
    );
  }
}

/// A stepper button: a tap steps once; a hold repeats (onStep(true)).
class _RepeatButton extends StatefulWidget {
  const _RepeatButton({required this.id, required this.label, required this.onStep});

  final String id, label;
  final ValueChanged<bool> onStep;

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
        widget.onStep(false);
      },
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        widget.onStep(true);
        _timer = Timer.periodic(const Duration(milliseconds: 160), (_) => widget.onStep(true));
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
