# PUMPLEX data schema

Date: 22 November 2026. Status: draft v1.1 (matches the code on `main`).
Read with [decisions.md](decisions.md) (it wins), [app-brief.md](app-brief.md) and [app-flow.md](app-flow.md).
The code is in `lib/game/model.dart` and `lib/store.dart`.

All data stays on the phone (`shared_preferences`, JSON values). One user, one character.

## 1. Decisions behind this schema (owner, 21 Nov 2026)

| Topic | Decision |
|---|---|
| Session | **One session per calendar day.** All set marks on one day are one session. |
| Body | The user can open the sliders again any time. Keep the history of changes. |
| Class, difficulty, area | All can change later. Each session saves the ones it used. |
| Workouts | A set number of exercises (3 at the easiest difficulty, 8 at the hardest), taken from the class pool. Switch an exercise (SWAP); add, remove, skip (no sets); "back to the first exercise" button (FIRST). Pools are TBD. |
| Set target | Each exercise has a target number of working sets, from the difficulty. More sets than the target give bonus XP. |
| XP sources | Working sets, training on a day, streaks, achievements. |
| Level | The level unlocks gear. The body stays as the sliders set it. |
| Gear | Unlock items; equip one item per slot. |
| Streak | **N training days per week**, with N from the difficulty. Missing days inside a week never break it. |
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
    CLASS ||--|{ EXERCISE : "pool"
    SESSION }o--|| CLASS : "used"
    SESSION }o--|| DIFFICULTY : "used"
    SESSION }o--|| AREA : "used"
    PROFILE ||--o{ XP_EVENT : earns
    PROFILE ||--o{ ACHIEVEMENT_UNLOCK : unlocks
    ACHIEVEMENT_UNLOCK }o--|| ACHIEVEMENT : "is"
    PROFILE ||--o{ OWNED_ITEM : owns
    OWNED_ITEM }o--|| ITEM : "is"
    PROFILE ||--o{ EQUIPPED : wears
    EQUIPPED }o--|| ITEM : "slot holds"

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
        int fat "0-100"
        string name "optional"
    }
    BODY_CHANGE {
        string at "ISO time"
        int height
        int muscle
        int fat
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
        int position
        string exerciseId
        string originalExerciseId "for the back button"
        int targetSets
        int sets "working sets done"
        bool added "added by the user"
        bool removed
    }
    EXERCISE {
        string id PK
        string name
        string classId
        string kind "bodyweight | weights | machine | cardio"
    }
    XP_EVENT {
        string at
        string source "sets | day | streak | achievement | legacy"
        int amount
        string ref "session date or achievement id"
    }
```

Fixed game data (in code, not in storage): `CLASS`, `DIFFICULTY`, `AREA`, `EXERCISE`, `ACHIEVEMENT`, `ITEM`.

## 3. Fixed game data (in code)

| Table | Fields | Notes |
|---|---|---|
| Class | `id`, `name`, `equipment` (none / home / free weights / machines), `exercisePool` | One class per equipment type. Ids (D31): `scrapper`, `bruiser`, `paladin`, `cablemancer`. Names are working names (D9). |
| Difficulty | `id`, `name`, `order`, `exercisesPerWorkout` (3–8), `targetSets`, `xpMultiplier`, `streakN` | 6 levels (D28). Ids: `sofa`, `warmup`, `sweat`, `pain`, `brutal`, `nightmare`. Names are design proposals. |
| Area | `id`, `name`, `palette`, `markStyle` (shells, wall marks…) | From the mood board. Ids: `beach`, `castle`, `rustbelt`, `arcade`, `summit`. The art id (design folder name) differs for 3: `beach` → `riptide`, `castle` → `gainsgard`, `summit` → `frostbite`. |
| Exercise | `id`, `name`, `classId`, `kind` | Id = `<class id>.<name>`, for example `paladin.squat`. Pools TBD. |
| Achievement | `id`, `name`, `condition`, `xp` | List TBD. |
| Item | `id`, `name`, `slot` (top, bottom, shoes, head, weapon), `unlockLevel`, `sprite` | Id = `<slot>.<name>`, for example `head.crown`. Sprites in `assets/gear/`. |

Rule: never reuse or rename an `id`. Saved data points to it.
The one exception is the class id change in D31 (owner decision). The app migrates it once (§5.2).

## 4. Saved data (in storage)

| Key | Content |
|---|---|
| `profile_v1` | PROFILE + CHARACTER (current values). |
| `body_history_v1` | List of BODY_CHANGE. |
| `sessions_v3` | Map date → SESSION with its SESSION_EXERCISE list. |
| `xp_events_v1` | List of XP_EVENT. |
| `achievements_v1` | Map achievement id → unlock time. |
| `gear_v1` | Owned item ids, and slot → equipped item id. |
| `chaos`, `cel`, `sound` | Menu settings (true / false). `sound` is on by default. |
| `class_ids_v0_backup` | Written once by the class id migration (§5.2): the old `profile_v1` and `sessions_v3` text. |

**Calculated, never saved:** total XP (sum of XP_EVENT), level (from the level curve), streak (from sessions), set totals.
This keeps the numbers consistent: change a rule, and the values update.

### Example session

```json
"2026-11-21": {
  "classId": "paladin", "difficultyId": "pain", "areaId": "castle",
  "firstMarkAt": "2026-11-21T18:02:11", "lastMarkAt": "2026-11-21T19:01:40",
  "legacy": false,
  "exercises": [
    {"position": 0, "exerciseId": "paladin.squat", "originalExerciseId": "paladin.squat",
     "targetSets": 4, "sets": 5, "added": false, "removed": false},
    {"position": 1, "exerciseId": "paladin.pullups", "originalExerciseId": "paladin.dips",
     "targetSets": 4, "sets": 3, "added": false, "removed": false}
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

### 5.3 Backup files

The backup file (version 3) holds the keys `profile_v1`, `body_history_v1`, `sessions_v3`, `xp_events_v1`, `achievements_v1` and `gear_v1`.
The menu settings are not in it. The app still reads old backups (version 2): it runs the §5.1 migration on them.

## 6. Open items

1. ~~Streak unit~~: decided, training days per week.
2. **Progress:** how to measure it. The schema keeps the sets per exercise per day, so many rules are possible later.
3. **Rules table:** draft in [rules.md](rules.md). Add to this schema: embers, weekly bounties, bounty board, rebirth count.
4. **Lists from the design team:** final class names, items, achievements, exercise pools (D27). Areas and the 6 difficulty modes are in the app (D28).
