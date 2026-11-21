// The weekly schedule: which program days are workouts and which are rest.
//
// Placeholder. The old system (fixed exercises, sets and reps from a
// spreadsheet) is gone. The new workout system will build workouts from the
// class, the starting area (equipment) and the difficulty. See
// docs/app-brief.md and docs/app-flow.md.
//
// The program does not follow the calendar: the next day only comes up after
// "I WORKED" / "I RESTED" (see LogStore.complete).

class Workout {
  const Workout(this.title);

  final String title;
}

/// Program day (1..7) -> workout. Days without an entry are rest days.
const program = <int, Workout>{
  1: Workout('Light Upper'),
  2: Workout('Heavy Lower'),
  4: Workout('Heavy Upper'),
  6: Workout('Light Lower'),
};
