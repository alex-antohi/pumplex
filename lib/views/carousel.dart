// Swipe carousels: the class and area setup cards (D46, D47) and the
// workout's exercise carousel (D48). Swipe left for the next item, right
// for the one before, round and round; dots show where you are.

import 'package:flutter/material.dart';

import '../pumplex.dart';

/// Swipe handling for a carousel of [count] items. Mix it into the State
/// of a view and use [swipe] around the card and [slide] for its content.
mixin SwipeCarousel<T extends StatefulWidget> on State<T> {
  /// 1: the new item comes in from the right (swipe left), -1: from the left.
  int dir = 1;
  double _dx = 0;

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
        onHorizontalDragStart: (_) => _dx = 0,
        onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (_dx < -40 || v < -300) {
            step(1);
          } else if (_dx > 40 || v > 300) {
            step(-1);
          }
        },
        child: child,
      );

  /// [child] sliding in the swipe direction when [id] changes.
  Widget slide(String id, Widget child) => ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (c, anim) {
            final incoming = c.key == ValueKey(id);
            return SlideTransition(
              position: Tween(
                begin: Offset(incoming ? dir.toDouble() : -dir.toDouble(), 0),
                end: Offset.zero,
              ).animate(anim),
              child: c,
            );
          },
          child: KeyedSubtree(key: ValueKey(id), child: child),
        ),
      );
}

/// Dots under a carousel: where you are. Tap one to jump.
class CarouselDots extends StatelessWidget {
  const CarouselDots({
    super.key,
    required this.prefix,
    required this.ids,
    required this.names,
    required this.current,
    required this.colorOf,
    required this.onTap,
  });

  /// Key prefix: the dots are keyed `<prefix>-dot-<id>`.
  final String prefix;
  final List<String> ids, names;
  final String current;
  final Color Function(String id) colorOf;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, id) in ids.indexed)
          GestureDetector(
            key: ValueKey('$prefix-dot-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Semantics(
              label: names[i],
              selected: id == current,
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: id == current ? 26 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: id == current ? colorOf(id) : p.panel2,
                    border: Border.all(color: p.ink, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A vertical carousel that follows the finger (D54): drag up for the next
/// item, down for the one before, round and round. The neighbour shows
/// while dragging; let go past a fifth of the height (or flick) to move on.
/// The items' own lists should not scroll vertically, so the drag is ours.
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

class _VerticalCarouselState extends State<VerticalCarousel> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  }

  /// How far the current item is dragged (px, negative = up).
  double _dy = 0;
  double _height = 1;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _wrap(int i) => i % widget.count;

  void _settle(double velocity) {
    final h = _height;
    final target = _dy < -h * 0.2 || velocity < -600
        ? -h
        : _dy > h * 0.2 || velocity > 600
            ? h
            : 0.0;
    final from = _dy;
    _c.stop();
    _c.value = 0;
    void tick() => setState(() => _dy = from + (target - from) * Curves.easeOutCubic.transform(_c.value));
    _c.addListener(tick);
    _c.forward().whenComplete(() {
      _c.removeListener(tick);
      if (!mounted) return;
      if (target != 0) widget.onIndex(_wrap(widget.index + (target < 0 ? 1 : -1)));
      setState(() => _dy = 0);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        _height = box.maxHeight;
        final h = box.maxHeight;
        final shown = [
          0,
          if (_dy < 0) 1,
          if (_dy > 0) -1,
        ];
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) => _c.stop(),
          onVerticalDragUpdate: (d) => setState(() => _dy = (_dy + d.delta.dy).clamp(-h, h)),
          onVerticalDragEnd: (d) => _settle(d.primaryVelocity ?? 0),
          child: ClipRect(
            child: Stack(
              children: [
                for (final o in shown)
                  Positioned(
                    key: ValueKey('vc-${_wrap(widget.index + o)}'),
                    left: 0,
                    right: 0,
                    top: o * h + _dy,
                    height: h,
                    child: widget.builder(context, _wrap(widget.index + o)),
                  ),
              ],
            ),
          ),
        );
      });
}
