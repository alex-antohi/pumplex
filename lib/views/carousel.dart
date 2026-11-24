// Swipe carousels: the class and area setup cards (D46, D47), the
// workout's exercise carousel (D48) and the lifter editor (D63). Swipe left
// (or up) for the next item, right (or down) for the one before, round and
// round; dots show where you are. Both directions share one flick rule
// ([swipeStep]) and one slide ([SwipeSwitcher]).

import 'package:flutter/material.dart';

import '../pumplex.dart';

/// The flick rule of every carousel: a drag of more than 40 px, or a fling
/// faster than 300 px/s, along the carousel's axis. [distance] and
/// [velocity] are along that axis (negative: left / up). Gives 1 for the
/// next item, -1 for the one before, 0 for nothing.
int swipeStep(double distance, double velocity) {
  if (distance < -40 || velocity < -300) return 1;
  if (distance > 40 || velocity > 300) return -1;
  return 0;
}

/// [child] sliding in along [axis] when [id] changes: from the end side
/// for [dir] 1 (the next item), from the start side for -1.
class SwipeSwitcher extends StatelessWidget {
  const SwipeSwitcher({
    super.key,
    required this.axis,
    required this.id,
    required this.dir,
    required this.duration,
    required this.child,
  });

  final Axis axis;
  final String id;
  final int dir;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (c, anim) {
            final d = (c.key == ValueKey(id) ? dir : -dir).toDouble();
            return SlideTransition(
              position: Tween(
                begin: axis == Axis.horizontal ? Offset(d, 0) : Offset(0, d),
                end: Offset.zero,
              ).animate(anim),
              child: c,
            );
          },
          child: KeyedSubtree(key: ValueKey(id), child: child),
        ),
      );
}

/// Swipe handling for a carousel of [count] items. Mix it into the State
/// of a view and use [swipe] around the card and [slide] for its content.
mixin SwipeCarousel<T extends StatefulWidget> on State<T> {
  /// 1: the new item comes in from the right (swipe left), -1: from the left.
  int dir = 1;
  /// Where the finger went down and where it is now (both axes).
  Offset _from = Offset.zero, _to = Offset.zero;

  int get count;
  int get index;
  void select(int i);

  /// The item [d] steps away, round and round.
  void step(int d) {
    if (count == 0) return;
    setState(() => dir = d);
    select((index + d) % count);
  }

  /// Straight to item [i] (a dot tap). Slides from the side it lies on.
  void jump(int i) {
    if (i == index) return;
    setState(() => dir = i > index ? 1 : -1);
    select(i);
  }

  /// A swipeable area around [child].
  Widget swipe({required Key key, required Widget child}) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onHorizontalDragDown: (d) => _from = _to = d.globalPosition,
        onHorizontalDragUpdate: (d) => _to = d.globalPosition,
        onHorizontalDragEnd: (d) {
          // Only a sideways swipe counts: one that went mostly up or down
          // (with a little drift) does nothing (D66).
          final move = _to - _from;
          if (move.dx.abs() < move.dy.abs() * 1.5) return;
          final s = swipeStep(move.dx, d.primaryVelocity ?? 0);
          if (s != 0) step(s);
        },
        child: child,
      );

  /// [child] sliding in the swipe direction when [id] changes.
  Widget slide(String id, Widget child) => SwipeSwitcher(
        axis: Axis.horizontal,
        id: id,
        dir: dir,
        duration: const Duration(milliseconds: 240),
        child: child,
      );
}

/// Dots beside a carousel: where you are. Tap one to jump ([onTap] null:
/// the dots only show). Along [axis]: a row under a sideways carousel, a
/// column beside a vertical one (smaller, the lifter editor's properties).
class CarouselDots extends StatelessWidget {
  const CarouselDots({
    super.key,
    this.axis = Axis.horizontal,
    required this.prefix,
    required this.ids,
    this.names,
    required this.current,
    required this.colorOf,
    this.onTap,
  });

  final Axis axis;

  /// Key prefix: the dots are keyed `<prefix>-dot-<id>`.
  final String prefix;
  final List<String> ids;

  /// For screen readers (null: the dots are not announced).
  final List<String>? names;
  final String current;
  final Color Function(String id) colorOf;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final across = axis == Axis.horizontal;
    Widget dot(int i, String id) {
      final on = id == current;
      final box = across
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: on ? 26 : 12,
                height: 12,
                decoration: BoxDecoration(color: on ? colorOf(id) : p.panel2, border: Border.all(color: p.ink, width: 2)),
              ),
            )
          : Container(
              width: 10,
              height: on ? 22 : 10,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(color: on ? colorOf(id) : p.panel2, border: Border.all(color: p.ink, width: 2)),
            );
      final shown = names == null ? box : Semantics(label: names![i], selected: on, button: onTap != null, child: box);
      return onTap == null
          ? KeyedSubtree(key: ValueKey('$prefix-dot-$id'), child: shown)
          : GestureDetector(
              key: ValueKey('$prefix-dot-$id'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap!(i),
              child: shown,
            );
    }

    final dots = [for (final (i, id) in ids.indexed) dot(i, id)];
    return across ? Row(mainAxisAlignment: MainAxisAlignment.center, children: dots) : Column(children: dots);
  }
}

/// A vertical carousel (D63, D64): flick up for the next item, down for the
/// one before, round and round. Like the sideways carousels it reacts to the
/// flick, it does not follow the finger: the next item slides in from the
/// side of the swipe.
class VerticalCarousel extends StatefulWidget {
  const VerticalCarousel({
    super.key,
    required this.index,
    required this.count,
    required this.onIndex,
    required this.builder,
  });

  final int index, count;
  final ValueChanged<int> onIndex;

  /// Builds item [i] (0 <= i < count).
  final Widget Function(BuildContext context, int i) builder;

  @override
  State<VerticalCarousel> createState() => _VerticalCarouselState();
}

class _VerticalCarouselState extends State<VerticalCarousel> {
  /// 1: the new item comes in from below (swipe up), -1: from above.
  int _dir = 1;
  double _dy = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (_) => _dy = 0,
        onVerticalDragUpdate: (d) => _dy += d.delta.dy,
        onVerticalDragEnd: (d) {
          final s = swipeStep(_dy, d.primaryVelocity ?? 0);
          if (s == 0) return;
          setState(() => _dir = s);
          widget.onIndex((widget.index + s) % widget.count);
        },
        child: SwipeSwitcher(
          axis: Axis.vertical,
          id: 'vc-${widget.index}',
          dir: _dir,
          duration: const Duration(milliseconds: 260),
          child: widget.builder(context, widget.index),
        ),
      );
}
