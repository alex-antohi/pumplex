// The old BODY PART filter sheet is gone (D82: CHALK is the only way to the
// catalog). The labels live in lib/labels.dart; this shim keeps the old
// import in workout.dart working until it imports labels.dart itself.

export '../labels.dart' show axisLabel, axisNone, bodyPartLabel, modLabel, muscleLabel;
