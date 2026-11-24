// The scenes of the one screen and where the character stands in each
// (main.dart re-exports both).

import 'package:flutter/widgets.dart';

import 'setup.dart';
import 'workout_layout.dart';

/// Every view of the app. They are scenes of ONE screen (see GameShell).
enum Scene { migrate, create, classSelect, area, summary, workout }

/// Where the character stands in each scene, inside the content area.
/// The views leave this rect free; the shell draws the one character there,
/// so it glides from place to place when the scene changes.
/// [bottomInset] is the phone's navigation bar, for views that keep it.
/// [buttons] false: a setup screen without BACK / NEXT (the lifter editor).
Rect stageRect(Scene s, Size a, {double bottomInset = 0, bool buttons = true}) {
  final w = a.width, h = a.height;
  return switch (s) {
    // Inside the body card (D63).
    Scene.create => Rect.fromLTWH(20, 16, w - 42, h * 0.40),
    Scene.classSelect => classLayout(a, bottomInset, buttons: buttons).stage,
    Scene.area => areaLayout(a, bottomInset, buttons: buttons).stage,
    Scene.summary => Rect.fromLTWH(0, 10, w, h * 0.40),
    Scene.migrate => Rect.fromLTWH(0, 10, w, h * 0.34),
    Scene.workout => workoutStage(a, bottomInset),
  };
}
