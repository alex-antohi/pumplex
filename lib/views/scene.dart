// One screen, many scenes. The app never pushes a route to change view:
// SceneSwitcher animates the old scene out and the new one in at the same
// time, so there is never a blank frame between them.

import 'package:flutter/material.dart';

/// How the "camera" moves to the next scene.
enum Motion {
  /// Camera moves forward: the old scene grows and fades, the new one comes
  /// up from small.
  zoomIn,

  /// Camera moves back: the reverse of [zoomIn].
  zoomOut,

  /// The new scene slides in from the left (going back in time).
  slideRight,

  /// The new scene slides in from the right.
  slideLeft,
}

const sceneDuration = Duration(milliseconds: 480);

class SceneSwitcher extends StatefulWidget {
  const SceneSwitcher({
    super.key,
    required this.scene,
    required this.motion,
    required this.child,
  });

  /// Identity of the scene. A new value starts a transition.
  final Object scene;
  final Motion motion;
  final Widget child;

  @override
  State<SceneSwitcher> createState() => _SceneSwitcherState();
}

class _SceneSwitcherState extends State<SceneSwitcher> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: sceneDuration, value: 1)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && _old != null) setState(() => _old = null);
    });

  Widget? _old;
  Object? _oldScene;

  @override
  void didUpdateWidget(SceneSwitcher old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) {
      _old = old.child;
      _oldScene = old.scene;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _place(Widget child, double t, {required bool incoming}) {
    // t: 0 = start of the change, 1 = done.
    final w = MediaQuery.sizeOf(context).width;
    final fade = incoming ? t : 1 - t;
    switch (widget.motion) {
      case Motion.zoomIn:
      case Motion.zoomOut:
        final forward = widget.motion == Motion.zoomIn;
        final from = incoming ? (forward ? 0.86 : 1.18) : 1.0;
        final to = incoming ? 1.0 : (forward ? 1.18 : 0.86);
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Transform.scale(scale: from + (to - from) * t, child: child),
        );
      case Motion.slideRight:
      case Motion.slideLeft:
        final dir = widget.motion == Motion.slideRight ? 1.0 : -1.0;
        final dx = incoming ? -dir * w * (1 - t) : dir * w * 0.35 * t;
        return Opacity(
          opacity: (incoming ? 1.0 : 1 - t).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Same shape for both layers, keyed by scene, so the old scene keeps its
    // state while it animates out.
    Widget layer(Object? scene, Widget child, double t, bool incoming) => KeyedSubtree(
          key: ValueKey(scene),
          child: IgnorePointer(
            ignoring: !incoming,
            child: _place(child, t, incoming: incoming),
          ),
        );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_old != null) layer(_oldScene, _old!, t, false),
            layer(widget.scene, widget.child, t, true),
          ],
        );
      },
    );
  }
}
