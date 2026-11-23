# PUMPLEX data schema

Date: 22 November 2026. Status: draft v1.3 (matches the code on `main`, with D50–D54).
Read with [decisions.md](decisions.md) (it wins), [app-brief.md](app-brief.md) and [app-flow.md](app-flow.md).
The code is in `lib/game/model.dart` and `lib/store.dart`.

All data stays on the phone (`shared_preferences`, JSON values). One user, one character.

## 1. Decisions behind this schema (owner, 21 Nov 2026)

| Topic | Decision |
|---|---|
| Session | **One session per calendar day.** All set marks on one day are one session. |
| Body | The user can open the sliders again any time. Keep the history of changes. |
| Class, difficulty, area | All can change later. Each session saves the ones it used. |
| Workouts | No daily list (D50): the user picks from every exercise the filters (class, difficulty, body part, favorites) show. The exercises come from free-exercise-db. |
| Set target | **Removed** (D52). No targets. Only the first 10 sets of one exercise a day give XP. |
| Favorites | The user can star exercises (D53). |
| XP sources | Working sets, training on a day. Old saved XP (legacy, streak, achievement, old workout) stays. |
| Level | The level gives a level title. The body stays as the sliders set it. |
| Gear | **Removed** (D38, 22 Nov 2026). The class outfit stays. |
| Streak | **Removed** (D34, 22 Nov 2026). The streak XP that old sessions earned is saved once as XP events (§5.4). |
| Achievements | **Removed** (D35, 22 Nov 2026). Saved `achievement` XP events stay. |
| Old data | Delete the old kg/reps sets and swaps. Keep the old sessions, and turn them into XP. |
| Progress | How to measure progress is **open**. |

## 2. Diagram

```mermaid
erDiagram
    PROFILE ||--|| CHARACTER : has
    CHARACTER ||--o{ BODY_CHANGE : "slider history"
    PROFILE ||--o{ SESSION : plays
    SESSION ||--|{ SESSION_EXERCISE : contains
    SESSION_EXERCISE }o--|| EXERCISE : "is one of"
    CLASS ||--|{ EXERCISE : "filter: equipment, category"
    PROFILE ||--o{ FAVORITE : stars
    FAVORITE }o--|| EXERCISE : "is"
    SESSION }o--|| CLASS : "used"
    SESSION }o--|| DIFFICULTY : "used"
    SESSION }o--|| AREA : "used"
    PROFILE ||--o{ XP_EVENT : earns

    PROFILE {
        int schemaVersion
        string classId "current"
        string difficultyId "current"
        string areaId "current"
        string createdAt
    }
    CHARACTER {
        string sex "male | female"
        int height "0-100"
        int muscle "0-100"
        int fat "0-100, shown as weight 50-200 kg"
        string skin "light | deep"
        string hair "brown | blonde"
        string facialHair "none | beard"
        string name "optional"
    }
    BODY_CHANGE {
        string at "ISO time"
        string sex
        int height
        int muscle
        int fat
        string skin
        string hair
        string facialHair
    }
    SESSION {
        string date PK "yyyy-MM-dd, one per day"
        string classId
        string difficultyId
        string areaId
        string firstMarkAt
        string lastMarkAt
        bool legacy "true = from the old app"
    }
    SESSION_EXERCISE {
        string exerciseId "free-exercise-db id"
        int sets "working sets done"
    }
    EXERCISE {
        string id PK
        string name
        string category
        string equipment
        string level "beginner | intermediate | expert"
        string force "push | pull | static | null"
        string mechanic "compound | isolation | null"
        string primaryMuscles
    }
    FAVORITE {
        string exerciseId
    }
    XP_EVENT {
        string at
        string source "sets | day | legacy | streak (old) | achievement (old) | workout (old)"
        int amount
        string ref "session date (old achievement: its id)"
    }
```

Fixed game data (in code and assets, not in storage): `CLASS`, `DIFFICULTY`, `AREA`, `EXERCISE`.

A session lists only the exercises with sets that day, in the order of the first set. Entries from
before D50 also had `position`, `originalExerciseId`, `targetSets`, `added` and `removed`; the app
ignores them, and §5.6 drops those old lists.

## 3. Fixed game data (in code)

| Table | Fields | Notes |
|---|---|---|
| Class | `id`, `name`, `equipment` (none / home / free weights / machines); the filter equipment and categories in `lib/game/exercises.dart` (D50) | One class per equipment type. Ids (D31): `scrapper`, `bruiser`, `paladin`, `cablemancer`. Names are working names (D9). |
| Difficulty | `id`, `name`, `order`, `xpMultiplier`; the hardest exercise level it shows (D51); which cards it shows is in the exercise list (`unlock`, D67) | 6 levels (D28). Ids: `sofa`, `warmup`, `sweat`, `pain`, `brutal`, `nightmare`. Names are design proposals. No `streakN` (D34). |
| Area | `id`, `name`, `palette`, `markStyle` (shells, wall marks…) | From the mood board. Ids (D36): `riptide`, `gainsgard`, `rustbelt`, `arcade`, `frostbite`. The id is also the design folder name for the art. |
| Exercise | `id`, `name`, `category`, `equipment`, `level`, `force`, `mechanic`, `primaryMuscles`; `base` (the move name; every exercise has one since the D69 clean-up) and `mods` (axis → value, D55); `rank` (commonness of the card, 1 = most common), `pattern` (movement pattern of the card, D69) and `unlock` (class id → first difficulty mode 0-5 that shows the card, D67) | From free-exercise-db (Unlicense), in `assets/exercises/exercises.json` (D50): the 479 common exercises in 164 moves (D67, D69). `tools/exercise_select.mjs` writes it from the full list `tools/exercise_db.json` (758: 692 from the database, 66 added, D57 and D69). `level` is the app level (D69). Id = the database id, for example `Barbell_Squat`. Null equipment = `body only`. |

Rule: never reuse or rename an `id`. Saved data points to it.
The two exceptions are the class id change in D31 and the area id change in D36 (owner decisions).
The app migrates each one once (§5.2, §5.3).

## 4. Saved data (in storage)

| Key | Content |
|---|---|
| `profile_v1` | PROFILE + CHARACTER (current values). |
| `body_history_v1` | List of BODY_CHANGE. |
| `sessions_v3` | Map date → SESSION with its SESSION_EXERCISE list. |
| `xp_events_v1` | List of the saved XP_EVENTs: `legacy`, and the old `streak`, `achievement` and `workout` XP. |
| `favorites_v1` | List of favorite cards (D53): `move:<move name>` for a move with variations (D55), else the exercise id. An old favorite exercise id of a move is changed to its move. |
| `old_exercises_v0_backup` | Written once by §5.6: the old `sessions_v3` text. |
| `gear_v1`, `chaos`, `cel`, `sound` | **Removed** (D38–D41). The app deletes these keys on every start. |
| `class_ids_v0_backup` | Written once by the class id migration (§5.2): the old `profile_v1` and `sessions_v3` text. |
| `area_ids_v0_backup` | Written once by the area id migration (§5.3): the old `profile_v1` and `sessions_v3` text. |
| `streak_xp_frozen_v1` | `true` once the old streak XP is saved as XP events (§5.4). |

Removed key: `achievements_v1` (map achievement id → unlock time). The app deletes it on start (D35, §5.4).

**Calculated, never saved:** total XP (sum of XP_EVENT), level (from the level curve), set totals.
The `sets` and `day` XP events are calculated from the sessions. Only `legacy`, `streak` and `achievement` events are saved.
This keeps the numbers consistent: change a rule, and the values update.

### Example session

```json
"2026-11-21": {
  "classId": "paladin", "difficultyId": "pain", "areaId": "gainsgard",
  "firstMarkAt": "2026-11-21T18:02:11", "lastMarkAt": "2026-11-21T19:01:40",
  "legacy": false,
  "exercises": [
    {"exerciseId": "Barbell_Squat", "sets": 5},
    {"exerciseId": "Dips_-_Triceps_Version", "sets": 3}
  ]
}
```

## 5. Migrations

### 5.1 From the old app

On the first launch of the new version, one time:

1. **Save a backup file first** (the old format, all keys). If that fails, stop and keep the old data.
2. Turn each old session in `sessions_v2` into a SESSION with `legacy: true`, keyed by its date. Two old sessions on one date become one. Old rest-day sessions are dropped.
3. Add one XP_EVENT per legacy session (`source: legacy`; the amount comes from the rules table).
4. Delete the old keys: `sessions_v2`, `logs_v2`, `swaps_v2`, `snooze2_*`, `session_started_ms`.
5. Set `profile_v1.schemaVersion = 1`. Then run the initial setup (character, class, difficulty, area).

### 5.2 Class ids (D31, 22 Nov 2026)

The first app build used the class ids `speedy`, `rogue`, `warrior` and `mage`. D31 replaces them with the design ids.

| Old id | New id |
|---|---|
| `speedy` | `scrapper` |
| `rogue` | `bruiser` |
| `warrior` | `paladin` |
| `mage` | `cablemancer` |

1. On load, the app maps old ids in `profile_v1` and `sessions_v3` to the new ids. Exercise ids change too: `warrior.squat` becomes `paladin.squat`.
2. If the saved text still has an old id, the app first copies the old text to `class_ids_v0_backup` (only if that key does not exist yet).
3. Then it saves `profile_v1` and `sessions_v3` again with the new ids. This runs one time: after it, no old id is left.
4. A restored backup file goes through the same steps.

### 5.3 Area ids (D36, 22 Nov 2026)

The first app build used the area ids `beach`, `castle` and `summit`. D36 replaces them with the design ids.
`rustbelt` and `arcade` do not change.

| Old id | New id |
|---|---|
| `beach` | `riptide` |
| `castle` | `gainsgard` |
| `summit` | `frostbite` |

1. On load, the app maps old `areaId` values in `profile_v1` and `sessions_v3` to the new ids.
2. If the saved text still has an old area id, the app first copies the old text to `area_ids_v0_backup` (only if that key does not exist yet).
3. Then it saves `profile_v1` and `sessions_v3` again with the new ids. This runs one time.
4. The class id migration (§5.2) runs in the same step. Each one writes its own backup key.
5. A restored backup file goes through the same steps.
6. The area id is now also the art id (folder in `assets/areas/`). There is no separate art id.

### 5.4 Streak XP and achievements (D34, D35, 22 Nov 2026)

D34 removes the streak and D35 removes the achievements. No one loses XP. On start:

1. **Streak freeze.** If `streak_xp_frozen_v1` is not `true`, the app works out the streak bonus of each session by the old rules.
   - A week (Monday to Sunday) with N training days is a streak week. N by difficulty: 2, 2, 2, 3, 3, 4.
   - A session gets +5% set XP per streak week in a row before its week, at most +25%, rounded set by set.
   - Legacy sessions and days with no sets get no bonus.
2. For each session with a bonus, the app saves one XP_EVENT: `source: streak`, `ref` = the session date, `at` = its last mark.
   It skips a date that already has a `streak` event.
3. Then it sets `streak_xp_frozen_v1` to `true`. New sessions get no streak XP.
4. **Achievements.** The app deletes the key `achievements_v1` on every start. The saved `achievement` XP events in `xp_events_v1` stay.

### 5.5 Backup files

There is no save / restore button in the app now (D59); only the one-time upgrade writes a backup file. The code below stays.

The backup file (version 6) holds the keys `profile_v1`, `body_history_v1`, `sessions_v3`, `xp_events_v1` and `favorites_v1`.
The one-time flag and backup keys are not in it.

| Version | What the app does on import |
|---|---|
| 6 | Restores the keys. |
| 5 | Restores the keys. There are no favorites. Old exercise lists are dropped (§5.6). |
| 4 | Restores the keys and ignores `gear_v1` (D38). The old streak XP is already in `xp_events_v1`, so the app does not work it out again. |
| 3 | Restores the keys and ignores `achievements_v1` (its XP events stay) and `gear_v1`. The file has no saved streak XP, so the app works it out again (§5.4). |
| 2 (old app) | Runs the §5.1 migration: old workout days become legacy sessions with legacy XP. There is no profile, so the setup runs again. Legacy sessions get no streak XP. |

After each import, the class and area id migrations (§5.2, §5.3) and §5.6 run too.

### 5.6 Old exercise lists (D54, 22 Nov 2026)

Sessions from before D50 use the old class-pool ids (`paladin.squat`: they have a dot; the database
ids never do). On start, for each such session that is not legacy:

1. The app keeps a copy of the `sessions_v3` text in `old_exercises_v0_backup` (once).
2. It works out the session's XP by the old rules (target sets, ×1.5 over the target up to 2× the
   target, criticals) plus the first-set bonus, and saves one XP_EVENT: `source: workout`,
   `ref` = the date. It skips a date that already has one.
3. It saves the session as `legacy: true` with no exercises. It keeps the class, difficulty, area
   and times. A session with no sets is deleted.

History shows these days in the main list as OLD EXERCISE LIST. The streak freeze (§5.4) runs first.

## 6. Open items

1. ~~Streak unit~~: the streak is removed (D34).
2. **Progress:** how to measure it. The schema keeps the sets per exercise per day, so many rules are possible later.
3. **Rules table:** draft in [rules.md](rules.md). Add to this schema: weekly bounties, bounty board, rebirth count. (Embers went with the streak, D34.)
4. **Lists from the design team:** final class names, items (D27). Exercises: free-exercise-db (D50). No achievements list (D35). Areas and the 6 difficulty modes are in the app (D28, D36).
