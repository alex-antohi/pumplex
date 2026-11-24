// The workout's layout maths (D75): where the world, the scene, the arena,
// the lifter and the set-count badge go for a view size. No widgets here.

import 'dart:math';

import 'package:flutter/widgets.dart';

import '../game/area_art.dart';
import 'area_scene.dart';

/// The least room the exercise part under the world keeps (D75): the
/// exercise (title, star, modifier rows) and the dots row.
const _exerciseMin = 240.0;

/// The scene's part of the world in a workout view of [area] (D75): the whole
/// width, from the top, just tall enough for the scene at the biggest
/// whole-number scale for the width. It depends on the size only, so the
/// scene (and the lifter the shell draws in it) never moves. The exercise
/// part is only as tall as its content, at the bottom; the world's floor
/// colour fills the space between them. The workout is no card (only when
/// minimised).
Rect workoutWorld(Size area, [double bottomInset = 0]) {
  final byWidth = max(1, (area.width / sceneSize.width).floor());
  final h = min(sceneSize.height * byWidth + 8, area.height - bottomInset - _exerciseMin);
  return Rect.fromLTWH(0, 0, area.width, h);
}

/// The scene's rect and whole-number scale in a workout view of [area]: the
/// biggest scale at which the whole scene fits in [workoutWorld], so no mark
/// is ever cut off (D75). It stands on the bottom of that rect; the area's
/// sky and floor colours fill the rest of the world.
(Rect, int) workoutLayout(Size area, [double bottomInset = 0]) {
  final world = workoutWorld(area, bottomInset);
  final scale = max(1, min(world.width / sceneSize.width, world.height / sceneSize.height).floor());
  final w = sceneSize.width * scale, h = sceneSize.height * scale;
  return (Rect.fromLTWH(world.center.dx - w / 2, world.bottom - h, w, h), scale);
}

/// The arena only (D61): the scene cut to a square around its middle. The
/// minimised workout shows this.
Rect workoutArena(Size area, [double bottomInset = 0]) {
  final (scene, _) = workoutLayout(area, bottomInset);
  final side = min(scene.width, scene.height);
  return Rect.fromCenter(center: scene.center, width: side, height: side);
}

/// The lifter's place in the scene: the design's lifter position (the same
/// in every area), feet on the shadow.
Rect workoutStage(Size area, [double bottomInset = 0]) {
  final (scene, scale) = workoutLayout(area, bottomInset);
  return sceneLifterRect(areaArt.values.first, scene, scale);
}

/// Where the set-count badge goes (size [badge]) for a scene at [scene],
/// scale [scale], in a view whose free world is [bounds]: next to the marks'
/// box (above it first), inside [bounds], off the object to hit, the marks
/// and [avoid] (the hint over the sky). The least covering spot when none is
/// free.
Offset sceneCountPos(AreaArt art, Rect scene, int scale, Size badge, Rect bounds, {Rect avoid = Rect.zero}) {
  final s = scale.toDouble();
  final marks = markBox(art, scene, scale);
  final object = Rect.fromLTWH(
      scene.left + art.hitBox.left * s, scene.top + art.hitBox.top * s, art.hitBox.width * s, art.hitBox.height * s);
  // Marks on the object (the Gainsgard wall): go round both.
  final m = marks.overlaps(object) ? marks.expandToInclude(object) : marks;
  const gap = 6.0;
  final w = badge.width, h = badge.height;
  final above = m.top - gap - h, below = m.bottom + gap;
  final candidates = [
    Offset(m.right - w, above),
    Offset(m.center.dx - w / 2, above),
    Offset(m.left, above),
    Offset(m.right + gap, m.top),
    Offset(m.left - gap - w, m.top),
    Offset(m.right - w, below),
    Offset(m.left, below),
  ];
  double cover(Rect r, Rect o) {
    final i = r.intersect(o);
    return i.width > 0 && i.height > 0 ? i.width * i.height : 0;
  }

  var best = Offset.zero;
  var least = double.infinity;
  for (final c in candidates) {
    final x = c.dx.clamp(bounds.left, max(bounds.left, bounds.right - w)).toDouble();
    final y = c.dy.clamp(bounds.top, max(bounds.top, bounds.bottom - h)).toDouble();
    final r = Rect.fromLTWH(x, y, w, h);
    final k = cover(r, object) + cover(r, marks) + cover(r, avoid);
    if (k < least) {
      least = k;
      best = Offset(x, y);
      if (k == 0) break;
    }
  }
  return best;
}

/// The box around every mark spot of [art] for a scene at [scene], scale [scale].
Rect markBox(AreaArt art, Rect scene, int scale) {
  final s = scale.toDouble();
  var box = Rect.zero;
  for (final (i, p) in art.markPositions.indexed) {
    final size = art.markFifth != null && i % 5 == 4 ? art.markFifth!.size : art.mark.size;
    final r = Rect.fromLTWH(scene.left + p.dx * s, scene.top + p.dy * s, size.width * s, size.height * s);
    box = i == 0 ? r : box.expandToInclude(r);
  }
  return box;
}
