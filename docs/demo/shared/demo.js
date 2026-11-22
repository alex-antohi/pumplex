/* PUMPLEX demo: shared data, state and helpers.
   Every screen loads this file before its own script. Everything hangs off window.PX.
   State lives in localStorage so the demo flows across pages like one app.

   Sources of truth (the demo follows these, never the other way round):
   - docs/app-brief.md, docs/app-flow.md   product rules and the flow
   - docs/data-schema.md                    sessions (one per day), workouts, set targets
   - docs/rules.md                          XP, level curve, streak, embers, mastery, bounties, gear
   - docs/moodboard/README.md               classes, difficulty rungs, areas, look
   Numbers marked PLACEHOLDER are not decided yet. */
(function () {
  "use strict";

  var KEY = "pumplex-demo-v2";

  /* ---------- screens (order = demo order) ---------- */
  /* No preloader (D29) and no reward screen (D7, D19): files 01 and 09 are gone, the others keep their numbers. */
  var SCREENS = [
    { id: "character",  file: "02-character.html",  title: "Character creation", step: 1 },
    { id: "class",      file: "03-class.html",      title: "Class (path)",        step: 2 },
    { id: "difficulty", file: "04-difficulty.html", title: "Difficulty",          step: 3 },
    { id: "area",       file: "05-area.html",       title: "Starting area",       step: 4 },
    { id: "summary",    file: "06-summary.html",    title: "Setup summary",       step: 5 },
    { id: "hub",        file: "07-hub.html",        title: "Hub" },
    { id: "workout",    file: "08-workout.html",    title: "Workout" },
    { id: "history",    file: "10-history.html",    title: "Past sessions" },
    { id: "profile",    file: "11-profile.html",    title: "Profile" },
    { id: "menu",       file: "12-menu.html",       title: "Menu" }
  ];
  var SETUP_STEPS = 5;

  /* ---------- classes (moodboard "Class select") ----------
     No preview body per class (D25): every screen draws the user's own body; the class colour shows the class. */
  var CLASSES = {
    scrapper: {
      id: "scrapper", name: "Scrapper", equipment: "No equipment", color: "orange",
      loadout: "Nothin'. Just you, the floor and the stairs.",
      tags: ["CARDIO", "BODYWEIGHT", "SPRINTS"],
      subtitle: "BUILT FROM STAIRS AND SPITE",
      description: "No gym, no gear, no problem. Builds every workout out of floors, stairs and pure spite. Homemade, held together with tape, and very loud about it.",
      area: "rustbelt"
    },
    bruiser: {
      id: "bruiser", name: "Bargain Bruiser", equipment: "Basic home gym", color: "sky",
      loadout: "Two dumbbells, one mat, a kettlebell of unknown origin.",
      tags: ["FLOOR WORK", "SOME CARDIO", "SOME WEIGHTS"],
      subtitle: "BUY ONE GAIN, GET ONE FREE",
      description: "Kitted out from the clearance aisle. Every piece of gear is store-brand, slightly wobbly and fully committed. Cheap kit, real gains.",
      area: "arcade"
    },
    paladin: {
      id: "paladin", name: "Plate Paladin", equipment: "Lots of free weights", color: "lime",
      loadout: "A barbell, a rack and a wall of plates.",
      tags: ["STRONGMAN", "BARBELL", "HEAVY"],
      subtitle: "OATH-SWORN TO THE BARBELL",
      description: "Sworn to the barbell. Carries plates like holy relics and drops them like thunder. Big, burly, unbothered.",
      area: "gainsgard"
    },
    cablemancer: {
      id: "cablemancer", name: "Cablemancer", equipment: "Lots of machines", color: "violet",
      loadout: "Cables, pin-stacks and every machine in the building.",
      tags: ["MACHINES", "CABLES", "LEAN POWER"],
      subtitle: "SPEAKS FLUENT PULLEY",
      description: "Bends steel cables and pin-stacks to their will. Thin as a wire, strong as the machine. Never waits for the squat rack.",
      area: "frostbite"
    }
  };
  var CLASS_ORDER = ["scrapper", "bruiser", "paladin", "cablemancer"];

  /* ---------- difficulty: the six modes of moodboard "Difficulty" (D28, the app's ids and names) ----------
     mult: rules.md §1, 1.0 at the lowest rung rising in even steps to 2.0.
     gems: the picture of the multiplier (no numbers on screen).
     exercises: data-schema, 3 at the easiest, 8 at the hardest.
     targetSets, streakN: PLACEHOLDER (data-schema: from the difficulty, values TBD). */
  var DIFFICULTIES = [
    { id: "sofa",    name: "Sofa Mode",          color: "muted",  gems: 1, mult: 1.0, exercises: 3, targetSets: 2, streakN: 2,
      line: "Never lifted, or not for years. The gentlest workouts.", joke: "THE SOFA WILL REMEMBER YOU" },
    { id: "warmup",   name: "Warm-up Mode",      color: "lime",   gems: 2, mult: 1.2, exercises: 4, targetSets: 3, streakN: 2,
      line: "A few weeks to a few months in. Easy, steady workouts.", joke: "EVERY LEGEND STARTS HERE" },
    { id: "sweat",   name: "Sweat Mode",           color: "sky",    gems: 3, mult: 1.4, exercises: 5, targetSets: 3, streakN: 3,
      line: "Training most weeks, for about a year. Proper sweaty workouts.", joke: "TOWEL STRONGLY RECOMMENDED" },
    { id: "pain",  name: "Pain Mode",         color: "violet", gems: 4, mult: 1.6, exercises: 6, targetSets: 4, streakN: 3,
      line: "About two years in. Hard workouts, real effort.", joke: "OUCH, BUT MAKE IT GAINS" },
    { id: "brutal",  name: "Brutal Mode",      color: "orange", gems: 5, mult: 1.8, exercises: 7, targetSets: 4, streakN: 4,
      line: "Years of serious lifting. Very hard workouts.", joke: "THE RACK FEARS YOU NOW" },
    { id: "nightmare", name: "Nightmare Mode", color: "pink",   gems: 6, mult: 2.0, exercises: 8, targetSets: 5, streakN: 4,
      line: "Many years, competition level. The hardest workouts there are.", joke: "GRAVITY FILED A COMPLAINT" }
  ];

  /* ---------- starting areas (moodboard "Starting areas") ---------- */
  var AREAS = {
    riptide:   { id: "riptide",   name: "Riptide Shore",    color: "pink",   sky: "#12061f", floor: "#ad9293",
                 object: "Treasure chest", hint: "TAP THE CHEST",     record: "Shells in the loot pile", fifth: "PEARL!",  defaultFor: null },
    gainsgard: { id: "gainsgard", name: "Gainsgard Keep",   color: "orange", sky: "#3a2a52", floor: "#8672a5",
                 object: "Stone wall",     hint: "SCRATCH THE WALL",  record: "Tally marks on the wall", fifth: "SLASHED!", defaultFor: "paladin" },
    rustbelt:  { id: "rustbelt",  name: "Rustbelt Flats",   color: "orange", sky: "#1f0d36", floor: "#a6643c",
                 object: "Hazard barrel",  hint: "BLOW UP THE BARREL", record: "Spray-painted Xs on the sign", fifth: "TAGGED!", defaultFor: "scrapper" },
    arcade:    { id: "arcade",    name: "Arcade Underpass", color: "lime",   sky: "#12061f", floor: "#724eb2",
                 object: "PUNCH-O-TRON",   hint: "PUNCH THE MACHINE", record: "Tickets on the floor",    fifth: "COMBO!",  defaultFor: "bruiser" },
    frostbite: { id: "frostbite", name: "Frostbite Summit", color: "sky",    sky: "#1a0b3b", floor: "#c9b8e8",
                 object: "Ice block",      hint: "SMASH THE ICE",     record: "A flag up the slope",     fifth: "SUMMIT!", defaultFor: "cablemancer" }
  };
  var AREA_ORDER = ["riptide", "gainsgard", "rustbelt", "arcade", "frostbite"];

  /* ---------- exercise pools per class (PLACEHOLDER: brief §8, pools TBD) ----------
     kind (data-schema): bodyweight | weights | machine | cardio. The workout takes the first N of the pool
     (N from the difficulty); the rest are swaps and adds. Never reuse or rename an id. */
  function ex(id, name, kind) { return { id: id, name: name, kind: kind }; }
  var POOLS = {
    scrapper: [ex("pushup", "Push-ups", "bodyweight"), ex("burpee", "Burpees", "cardio"), ex("sprint", "Sprints", "cardio"),
      ex("squatjump", "Squat jumps", "bodyweight"), ex("lunge", "Lunges", "bodyweight"), ex("climber", "Mountain climbers", "cardio"),
      ex("plank", "Planks", "bodyweight"), ex("stairs", "Stair runs", "cardio"), ex("pikepush", "Pike push-ups", "bodyweight"), ex("jacks", "Jumping jacks", "cardio")],
    bruiser: [ex("goblet", "Goblet squats", "weights"), ex("dbrow", "Dumbbell rows", "weights"), ex("kbswing", "KB swings", "weights"),
      ex("floorpress", "Floor press", "weights"), ex("lunge", "Lunges", "bodyweight"), ex("pushup", "Push-ups", "bodyweight"),
      ex("burpee", "Burpees", "cardio"), ex("dbpress", "DB shoulder press", "weights"), ex("bridge", "Glute bridges", "bodyweight"), ex("rope", "Jump rope", "cardio")],
    paladin: [ex("backsquat", "Back squats", "weights"), ex("bench", "Bench press", "weights"), ex("deadlift", "Deadlifts", "weights"),
      ex("ohp", "Overhead press", "weights"), ex("bbrow", "Barbell rows", "weights"), ex("farmer", "Farmer carries", "weights"),
      ex("frontsquat", "Front squats", "weights"), ex("pullup", "Pull-ups", "bodyweight"), ex("rdl", "Romanian deadlifts", "weights"), ex("curl", "Barbell curls", "weights")],
    cablemancer: [ex("legpress", "Leg press", "machine"), ex("pulldown", "Lat pulldown", "machine"), ex("cablerow", "Cable rows", "machine"),
      ex("chestpress", "Chest press", "machine"), ex("legcurl", "Leg curls", "machine"), ex("flye", "Cable flyes", "machine"),
      ex("legext", "Leg extensions", "machine"), ex("shoulderm", "Shoulder press", "machine"), ex("rower", "Rowing machine", "cardio"), ex("crunch", "Cable crunches", "machine")]
  };
  var EXERCISES = {};
  for (var pk in POOLS) POOLS[pk].forEach(function (e) { EXERCISES[e.id] = e; });

  /* Level titles shown on level-up and in the profile (design copy, not a rule). */
  var LEVEL_TITLES = ["Fresh Spawn", "Sweat Rookie", "Rep Goblin", "Pump Raider", "Iron Ronin", "Gain Lord", "Mythic Meathead"];

  /* ---------- gear (rules.md §6: 5 slots, 5 rarities, cosmetic in v1) ---------- */
  var RARITIES = [
    { id: "common", name: "Common", color: "muted", chance: 50 },
    { id: "uncommon", name: "Uncommon", color: "lime", chance: 30 },
    { id: "rare", name: "Rare", color: "sky", chance: 14 },
    { id: "epic", name: "Epic", color: "violet", chance: 5 },
    { id: "legendary", name: "Legendary", color: "orange", chance: 1 }
  ];
  var SLOTS = ["head", "top", "bottom", "shoes", "weapon"];
  var ITEM_NAMES = {
    head:   ["Sweaty Headband", "Bandana of Grit", "Chalk Crown", "Halo of Pump", "Helm of the Final Rep"],
    top:    ["Stretched Tank", "Neon Stringer", "Hoodie of Holding", "Plate Mail Tee", "Mantle of Swole"],
    bottom: ["Sweatpants", "Squat-Proof Shorts", "Cargo of Gains", "Leggings of Thunder", "Greaves of Gravity"],
    shoes:  ["Flat Sneakers", "Lifting Flats", "Boots of the Stairs", "Treads of Torque", "Sandals of the Titan"],
    weapon: ["Foam Roller", "Jump Rope", "Chalk Bag", "Kettlebell of Unknown Origin", "The Golden Barbell"]
  };
  var ITEMS = {};
  SLOTS.forEach(function (slot) {
    ITEM_NAMES[slot].forEach(function (name, r) {
      var id = slot + "_" + RARITIES[r].id;
      ITEMS[id] = { id: id, name: name, slot: slot, rarity: r };
    });
  });

  /* ---------- bounties (rules.md §5: 1-3 small missions a week) ---------- */
  var BOUNTIES = [
    { id: "sets12",  xp: 150, text: function (g) { return "12 sets of " + g.mainName.toLowerCase() + " this week"; },
      need: 12, got: function (w, g) { return w.setsOf(g.mainId); } },
    { id: "days3",   xp: 200, text: function () { return "Train on 3 days"; }, need: 3, got: function (w) { return w.days; } },
    { id: "newex",   xp: 100, text: function () { return "Try an exercise you have not done yet"; }, need: 1, got: function (w) { return w.newExercises; } },
    { id: "crush",   xp: 250, text: function () { return "Crush every target in one session"; }, need: 1, got: function (w) { return w.fullSessions; } },
    { id: "sets40",  xp: 300, text: function () { return "40 working sets this week"; }, need: 40, got: function (w) { return w.sets; } }
  ];

  /* ---------- numbers from rules.md (one place, easy to tune) ---------- */
  var RULES = {
    xpPerSet: 10, overTargetMult: 1.5, dayBonus: 50, critChance: 0.03, critMult: 2,
    streakStep: 0.05, streakMax: 0.25, legacyXp: 150, emberMax: 3,
    masteryChecksPerStar: 3, masteryMaxStars: 5, swapAfterDays: 21, climbWeeks: 3, climbStars: 3,
    setCap: 9
  };

  /* ---------- small utils ---------- */
  function hash(str) { var h = 2166136261; for (var i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  /* repeatable roll in [0, 1): same inputs, same result (rules.md: crits must be repeatable) */
  function roll(seed) { var t = hash(seed) + 0x6d2b79f5; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }
  function pad(n) { return String(n).padStart(2, "0"); }
  function dayKey(ts) { var d = new Date(ts); return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function dateOf(key) { var p = key.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function weekKey(key) { var d = dateOf(key); d.setDate(d.getDate() - ((d.getDay() + 6) % 7)); return dayKey(d.getTime()); }
  function addDays(key, n) { var d = dateOf(key); d.setDate(d.getDate() + n); return dayKey(d.getTime()); }

  /* ---------- state ---------- */
  function blank() {
    return {
      setupDone: false,
      character: { sex: "male", height: 50, fat: 50, muscle: 50 },
      bodyHistory: [],     // data-schema BODY_CHANGE: [{at, sex, height, fat, muscle}]
      cls: null,
      difficulty: null,
      area: null,
      sessions: [],        // data-schema SESSION, one per calendar day, oldest first
      current: null,       // today's workout list: {date, active, exercises: [SESSION_EXERCISE + skipped]}
      equipped: {},        // slot -> item id
      seenSetTip: false,
      settings: { cel: false, chaos: false, sound: true }
    };
  }
  function load() {
    try {
      var raw = localStorage.getItem(KEY);
      if (raw) {
        var s = JSON.parse(raw), b = blank();
        for (var k in b) if (!(k in s)) s[k] = b[k];
        return s;
      }
    } catch (e) { /* storage blocked: fall back to memory */ }
    return blank();
  }
  var mem = null;
  function get() { if (!mem) mem = load(); return mem; }
  function save(patch) {
    var s = get();
    if (patch) for (var k in patch) s[k] = patch[k];
    gameCache = null;
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) {}
    return s;
  }
  function reset() { mem = blank(); gameCache = null; try { localStorage.removeItem(KEY); } catch (e) {} return mem; }

  /* ---------- lookups ---------- */
  function cls(id) { return CLASSES[id || get().cls] || null; }
  function area(id) { return AREAS[id || get().area] || null; }
  function difficulty(id) {
    id = id || get().difficulty;
    for (var i = 0; i < DIFFICULTIES.length; i++) if (DIFFICULTIES[i].id === id) return DIFFICULTIES[i];
    return null;
  }
  function exercise(id) { return EXERCISES[id] || { id: id, name: id, kind: "bodyweight" }; }
  function pool(clsId) { return POOLS[clsId || get().cls] || POOLS.scrapper; }
  /* The workout the app picks (brief rule 4): N exercises from the class pool, target sets from the difficulty. */
  function planWorkout(clsId, diffId) {
    var d = difficulty(diffId) || DIFFICULTIES[0];
    return pool(clsId).slice(0, d.exercises).map(function (e, i) {
      return { position: i, exerciseId: e.id, originalExerciseId: e.id, targetSets: d.targetSets, sets: 0, added: false, removed: false };
    });
  }
  function live(exs) { return (exs || []).filter(function (e) { return !e.removed; }); }
  function sessionSets(sess) { var n = 0; live(sess && sess.exercises).forEach(function (e) { n += e.sets || 0; }); return n; }
  function sessionByDate(date, s) { s = s || get(); for (var i = 0; i < s.sessions.length; i++) if (s.sessions[i].date === date) return s.sessions[i]; return null; }
  function today() { return dayKey(Date.now()); }
  function c(name, tone) { return "var(--" + (name || "lime") + (tone ? "-" + tone : "") + ")"; }

  /* ---------- the game engine: every number is calculated from the sessions (data-schema §4) ---------- */
  function xpToNext(L) {
    if (L <= 4) return 25 * L;
    if (L === 5) return 150;
    return Math.round((0.25 * L * L + 10 * L + 139.75) / 10) * 10;
  }
  function xpToReach(L) { var t = 0; for (var i = 1; i < L; i++) t += xpToNext(i); return t; }
  function levelInfo(totalXp) {
    var L = 1;
    while (totalXp >= xpToReach(L + 1)) L++;
    var from = xpToReach(L), to = xpToReach(L + 1);
    return {
      level: L, title: LEVEL_TITLES[Math.min(L - 1, LEVEL_TITLES.length - 1)],
      into: totalXp - from, span: to - from, toNext: to - totalXp,
      pct: Math.round(100 * (totalXp - from) / (to - from))
    };
  }

  /* XP for one day's session (rules.md §1, order of calculation for one set). */
  function sessionXp(sess, streakWeeks) {
    if (sess.legacy) return { total: RULES.legacyXp, sets: 0, crits: 0, over: 0, wasted: 0, day: 0, streakPct: 0, legacy: true };
    var d = difficulty(sess.difficultyId) || DIFFICULTIES[0];
    var streakMult = 1 + Math.min(RULES.streakMax, RULES.streakStep * (streakWeeks || 0));
    var out = { total: 0, sets: 0, crits: 0, over: 0, wasted: 0, day: 0, streakPct: Math.round((streakMult - 1) * 100), mult: d.mult };
    live(sess.exercises).forEach(function (e) {
      for (var k = 1; k <= (e.sets || 0); k++) {
        var xp = RULES.xpPerSet * d.mult;
        if (k > e.targetSets) {
          if (k <= 2 * e.targetSets) { xp *= RULES.overTargetMult; out.over++; } else { xp = 0; out.wasted++; }
        }
        if (xp > 0 && roll(sess.date + "|" + e.exerciseId + "|" + k) < RULES.critChance) { xp *= RULES.critMult; out.crits++; }
        xp *= streakMult;
        out.sets += Math.round(xp);
      }
    });
    if (sessionSets(sess) > 0) out.day = RULES.dayBonus;
    out.total = out.sets + out.day;
    return out;
  }

  /* Weekly streak with embers (rules.md §3). Walks every finished week up to (not including) `upTo`. */
  function streakBefore(weeksSet, firstWeek, upTo, N) {
    var streak = 0, embers = 0, w = firstWeek;
    while (w && w < upTo) {
      var days = weeksSet[w] || 0;
      if (days >= N) { streak++; embers = Math.min(RULES.emberMax, embers + 1); }
      else if (embers > 0) { embers--; }
      else streak = 0;
      w = addDays(w, 7);
    }
    return { weeks: streak, embers: embers };
  }

  var gameCache = null;
  function game(s) {
    s = s || get();
    if (gameCache && gameCache.state === s) return gameCache.g;
    var sessions = s.sessions.slice().sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    var d = difficulty(s.difficulty) || DIFFICULTIES[0];
    var N = d.streakN;
    var daysPerWeek = {};
    sessions.forEach(function (x) { if (!x.legacy && sessionSets(x) > 0) daysPerWeek[weekKey(x.date)] = (daysPerWeek[weekKey(x.date)] || 0) + 1; });
    var real = sessions.filter(function (x) { return !x.legacy; });
    var firstWeek = real.length ? weekKey(real[0].date) : null;
    var thisWeek = weekKey(today());

    /* XP per session */
    var byDate = {}, total = 0;
    sessions.forEach(function (x) {
      var st = x.legacy ? { weeks: 0 } : streakBefore(daysPerWeek, firstWeek, weekKey(x.date), N);
      var xp = sessionXp(x, st.weeks);
      byDate[x.date] = xp; total += xp.total;
    });

    /* streak now */
    var streakNow = streakBefore(daysPerWeek, firstWeek, thisWeek, N);
    var streak = { weeks: streakNow.weeks, embers: streakNow.embers, N: N, thisWeek: daysPerWeek[thisWeek] || 0 };
    streak.bonusPct = Math.round(Math.min(RULES.streakMax, RULES.streakStep * streak.weeks) * 100);

    /* mastery (rules.md §4.1) and swap suggestions (§4.2) */
    var mastery = {}, now = dateOf(today()).getTime(), cutoff = now - RULES.swapAfterDays * 864e5;
    real.forEach(function (x) {
      var t = dateOf(x.date).getTime();
      live(x.exercises).forEach(function (e) {
        if (!(e.sets > 0)) return;
        var m = mastery[e.exerciseId] || (mastery[e.exerciseId] = { checks: 0, recentDone: 0, recentChecks: 0 });
        var hit = e.sets >= e.targetSets;
        if (hit) m.checks++;
        if (t >= cutoff) { m.recentDone++; if (hit) m.recentChecks++; }
      });
    });
    for (var id in mastery) {
      var m = mastery[id];
      m.stars = Math.min(RULES.masteryMaxStars, Math.floor(m.checks / RULES.masteryChecksPerStar));
      m.suggestSwap = m.recentDone >= 2 && m.recentChecks === 0;
    }

    /* stats (rules.md §4.4) */
    var stats = { STRENGTH: 0, ENDURANCE: 0, AGILITY: 0 };
    real.forEach(function (x) {
      live(x.exercises).forEach(function (e) {
        var k = exercise(e.exerciseId).kind;
        stats[k === "cardio" ? "ENDURANCE" : k === "bodyweight" ? "AGILITY" : "STRENGTH"] += e.sets || 0;
      });
    });

    /* bounties (rules.md §5): per week, picked from the list with a repeatable roll */
    var planned = planWorkout(s.cls, s.difficulty), main = planned[0] ? exercise(planned[0].exerciseId) : exercise("pushup");
    var ctx = { mainId: main.id, mainName: main.name };
    function weekBounties(wk) {
      var n = 1 + Math.floor(roll("bn|" + wk) * 3), order = BOUNTIES.slice().sort(function (a, b) { return roll(wk + a.id) - roll(wk + b.id); });
      var inWeek = real.filter(function (x) { return weekKey(x.date) === wk; });
      var before = {}; real.forEach(function (x) { if (weekKey(x.date) < wk) live(x.exercises).forEach(function (e) { if (e.sets) before[e.exerciseId] = 1; }); });
      var fresh = {};
      var w = {
        days: inWeek.filter(function (x) { return sessionSets(x) > 0; }).length,
        sets: inWeek.reduce(function (n, x) { return n + sessionSets(x); }, 0),
        setsOf: function (id) { return inWeek.reduce(function (n, x) { return n + live(x.exercises).reduce(function (m, e) { return m + (e.exerciseId === id ? e.sets : 0); }, 0); }, 0); },
        newExercises: 0,
        fullSessions: inWeek.filter(function (x) { var l = live(x.exercises); return l.length && l.every(function (e) { return e.sets >= e.targetSets; }); }).length
      };
      if (real.length && real[0].date < wk) inWeek.forEach(function (x) { live(x.exercises).forEach(function (e) { if (e.sets && !before[e.exerciseId]) fresh[e.exerciseId] = 1; }); });
      w.newExercises = Object.keys(fresh).length;
      return order.slice(0, n).map(function (b) {
        var got = Math.min(b.need, b.got(w, ctx));
        return { id: b.id, week: wk, text: b.text(ctx), xp: b.xp, need: b.need, got: got, done: got >= b.need };
      });
    }
    var weeks = {};
    real.forEach(function (x) { weeks[weekKey(x.date)] = 1; });
    weeks[thisWeek] = 1;
    var bountyDone = 0, bountyXp = 0;
    Object.keys(weeks).sort().forEach(function (wk) {
      weekBounties(wk).forEach(function (b) { if (b.done) { bountyDone++; bountyXp += b.xp; } });
    });
    total += bountyXp;

    /* gear: one drop per level-up, plus one per 3 bounty checkmarks (rules.md §2, §5, §6) */
    var lv = levelInfo(total), owned = [];
    function drop(seed) {
      var r = roll("rar|" + seed) * 100, acc = 0, rar = 0;
      for (var i = 0; i < RARITIES.length; i++) { acc += RARITIES[i].chance; if (r < acc) { rar = i; break; } }
      var slot = SLOTS[Math.floor(roll("slot|" + seed) * SLOTS.length)];
      return ITEMS[slot + "_" + RARITIES[rar].id];
    }
    for (var L = 2; L <= lv.level; L++) owned.push({ item: drop("lv" + L), from: "LEVEL " + L, level: L });
    for (var b = 1; b <= Math.floor(bountyDone / 3); b++) owned.push({ item: drop("bb" + b), from: "BOUNTY BOARD", board: b });

    /* difficulty climb (rules.md §4.3): a suggestion, never automatic */
    var di = DIFFICULTIES.indexOf(d), starred = planned.filter(function (p) { return (mastery[p.exerciseId] || {}).stars >= RULES.climbStars; }).length;
    var climb = di < DIFFICULTIES.length - 1 && streak.weeks >= RULES.climbWeeks && starred > planned.length / 2 ? DIFFICULTIES[di + 1] : null;

    var g = {
      total: total, level: lv, byDate: byDate, streak: streak, mastery: mastery, stats: stats,
      bounties: weekBounties(thisWeek), bountyDone: bountyDone, bountyXp: bountyXp, boardChecks: bountyDone % 3,
      owned: owned, climb: climb
    };
    gameCache = { state: s, g: g };
    return g;
  }

  /* ---------- today's workout (one session per calendar day, data-schema §1, D6) ----------
     There is no START or I WORKED (D7): every set is saved into today's session as it is marked,
     and the day closes by itself at midnight. A second visit on the same day tops up that session. */
  function startWorkout() {
    var s = get();
    if (s.current && s.current.date === today()) return s.current;
    var done = sessionByDate(today(), s);
    var exs = done ? JSON.parse(JSON.stringify(done.exercises)) : planWorkout(s.cls, s.difficulty);
    var cur = { date: today(), active: 0, exercises: exs };
    save({ current: cur });
    return cur;
  }
  /* Write the workout list into today's session. Returns what changed:
     { xp, crit, levelBefore, levelAfter, drops: [item ids] } so the screen can pop XP and slam a level-up. */
  function saveSet() {
    var s = get(), cur = s.current; if (!cur) return null;
    var before = game(s), lvBefore = before.level.level, bountiesBefore = before.bountyDone;
    var old = sessionByDate(cur.date, s), now = Date.now();
    var exs = cur.exercises.map(function (e, i) {
      return { position: i, exerciseId: e.exerciseId, originalExerciseId: e.originalExerciseId, targetSets: e.targetSets, sets: e.sets || 0, added: !!e.added, removed: !!e.removed };
    });
    var any = exs.some(function (e) { return !e.removed && e.sets > 0; });
    var list = s.sessions.filter(function (x) { return x.date !== cur.date; });
    if (any) list.push({
      date: cur.date, classId: s.cls, difficultyId: s.difficulty, areaId: s.area,
      firstMarkAt: old ? old.firstMarkAt : now, lastMarkAt: now, legacy: false, exercises: exs
    });
    list.sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    save({ sessions: list });
    var after = game();
    var drops = after.owned.filter(function (o) { return (o.level && o.level > lvBefore) || (o.board && o.board > Math.floor(bountiesBefore / 3)); });
    var critsBefore = (before.byDate[cur.date] || {}).crits || 0, critsAfter = (after.byDate[cur.date] || {}).crits || 0;
    return { xp: after.total - before.total, crit: critsAfter > critsBefore, levelBefore: lvBefore, levelAfter: after.level.level,
             drops: drops.map(function (o) { return o.item.id; }) };
  }

  /* A returning player with history, so any screen can be opened on its own. */
  function seedReturning() {
    var s = blank();
    s.setupDone = true;
    s.character = { sex: "female", height: 50, fat: 25, muscle: 50 };
    s.bodyHistory = [{ at: Date.now() - 40 * 864e5, sex: "female", height: 50, fat: 25, muscle: 50 }];
    s.cls = "scrapper"; s.difficulty = "sweat"; s.area = "rustbelt";
    s.seenSetTip = true;
    var monday = weekKey(today()), todayIdx = (dateOf(today()).getDay() + 6) % 7;
    /* [weeks back, weekday, minutes from first to last mark, sets per exercise] - week 2 misses the streak target, an ember covers it */
    var plan = [[4, 0, 41, [3, 3, 3, 3, 2]], [4, 2, 36, [3, 2, 3, 3, 3]], [4, 4, 44, [4, 3, 3, 3, 3]],
                [3, 1, 38, [3, 3, 4, 3, 3]], [3, 3, 29, [3, 3, 3, 3, 3]], [3, 5, 47, [5, 2, 3, 2, 3]],
                [2, 1, 33, [3, 0, 3, 3, 2]], [2, 4, 40, [3, 2, 3, 3, 3]],
                [1, 0, 42, [4, 2, 3, 3, 3]], [1, 2, 35, [3, 1, 2, 3, 3]], [1, 5, 39, [3, 2, 3, 3, 4]],
                [0, 0, 37, [3, 2, 3, 3, 3]], [0, 2, 45, [6, 2, 3, 3, 3]]];
    /* burpees stall for 3 weeks, so the card suggests a swap (rules.md §4.2) */
    plan.forEach(function (p) {
      if (p[0] === 0 && p[1] >= todayIdx) return;
      var date = addDays(monday, -7 * p[0] + p[1]);
      var start = dateOf(date).getTime() + 18 * 36e5;
      var exs = planWorkout(s.cls, s.difficulty);
      exs.forEach(function (e, j) { e.sets = p[3][j]; });
      if (p[0] === 1 && p[1] === 2) { exs[2].exerciseId = "squatjump"; } /* a swipe-swap, kept with its original */
      s.sessions.push({ date: date, classId: s.cls, difficultyId: s.difficulty, areaId: s.area,
        firstMarkAt: start, lastMarkAt: start + p[2] * 6e4, legacy: false, exercises: exs });
    });
    /* two sessions from the old app, turned into XP (brief 4.7, rules.md: 150 each) */
    [70, 66].forEach(function (back) {
      var date = addDays(today(), -back), start = dateOf(date).getTime() + 18 * 36e5;
      s.sessions.push({ date: date, classId: null, difficultyId: null, areaId: null, firstMarkAt: start, lastMarkAt: start + 50 * 6e4, legacy: true, exercises: [] });
    });
    s.sessions.sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    mem = s; save();
    return s;
  }

  /* ---------- navigation ---------- */
  function screen(id) { for (var i = 0; i < SCREENS.length; i++) if (SCREENS[i].id === id) return SCREENS[i]; return null; }
  function go(id, opts) {
    var sc = screen(id);
    if (!sc) { console.error("PX.go: unknown screen", id); return; }
    var url = sc.file + (opts && opts.query ? "?" + opts.query : "");
    if (opts && opts.replace) location.replace(url); else location.href = url;
  }
  /* Where the app opens (app-flow §1, D29: no preloader): the hub, or the creator at the first launch. */
  function homeId() { return get().setupDone ? "hub" : "character"; }
  /* Setup screens opened from the profile to change one choice (data-schema: all can change later). */
  function editMode() { return /[?&]edit=1\b/.test(location.search) && get().setupDone; }

  function require(fields, fallback) {
    var s = get();
    for (var i = 0; i < fields.length; i++) if (!s[fields[i]]) { go(fallback || "character", { replace: true }); return false; }
    return true;
  }

  /* ---------- character sprite ---------- */
  function snap(v) { return Math.max(0, Math.min(100, Math.round(v / 25) * 25)); }
  /* Height (D10, D11) stretches the frame vertically, 0.86x to 1.14x, like the app (lib/game/rules.dart). */
  function heightScale(h) { h = h == null ? 50 : Math.max(0, Math.min(100, h)); return 0.86 + 0.28 * h / 100; }
  function sprite(el, ch, scale) {
    ch = ch || get().character; scale = scale || 3;
    var fat = snap(ch.fat), mus = snap(ch.muscle), hy = heightScale(ch.height);
    var x = (fat / 25) * 52, y = ((ch.sex === "female" ? 5 : 0) + mus / 25) * 64;
    el.classList.add("sprite");
    el.style.width = 52 * scale + "px";
    el.style.height = 64 * scale * hy + "px";
    el.style.backgroundSize = 260 * scale + "px " + 640 * scale * hy + "px";
    el.style.backgroundPosition = -x * scale + "px " + -y * scale * hy + "px";
    el.setAttribute("role", "img");
    el.setAttribute("aria-label", (ch.sex === "female" ? "Female" : "Male") + " lifter, height " + (ch.height == null ? 50 : ch.height) + ", fat " + fat + ", muscle " + mus);
    return el;
  }

  /* ---------- UI helpers ---------- */
  /* ICONS:BEGIN (generated by tools/moodboard/icons.mjs: do not edit by hand) */
  var ICONS = {
    "back": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M14 2h2v1h-2zM13 3h4v1h-4zM12 4h5v1h-5zM11 5h5v1h-5zM10 6h5v1h-5zM9 7h5v1h-5zM8 8h5v1h-5zM7 9h5v1h-5zM6 10h5v1h-5zM5 11h5v1h-5zM5 12h5v1h-5zM6 13h5v1h-5zM7 14h5v1h-5zM8 15h5v1h-5zM9 16h5v1h-5zM10 17h5v1h-5zM11 18h5v1h-5zM12 19h5v1h-5zM13 20h4v1h-4zM14 21h2v1h-2z"/></svg>',
    "next": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M8 2h2v1h-2zM7 3h4v1h-4zM7 4h5v1h-5zM8 5h5v1h-5zM9 6h5v1h-5zM10 7h5v1h-5zM11 8h5v1h-5zM12 9h5v1h-5zM13 10h5v1h-5zM14 11h5v1h-5zM14 12h5v1h-5zM13 13h5v1h-5zM12 14h5v1h-5zM11 15h5v1h-5zM10 16h5v1h-5zM9 17h5v1h-5zM8 18h5v1h-5zM7 19h5v1h-5zM7 20h4v1h-4zM8 21h2v1h-2z"/></svg>',
    "menu": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 3h4v1h-4zM10 4h4v1h-4zM10 5h4v1h-4zM10 6h4v1h-4zM10 10h4v1h-4zM10 11h4v1h-4zM10 12h4v1h-4zM10 13h4v1h-4zM10 17h4v1h-4zM10 18h4v1h-4zM10 19h4v1h-4zM10 20h4v1h-4z"/></svg>',
    "close": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M4 3h2v1h-2zM18 3h2v1h-2zM3 4h4v1h-4zM17 4h4v1h-4zM3 5h5v1h-5zM16 5h5v1h-5zM4 6h5v1h-5zM15 6h5v1h-5zM5 7h5v1h-5zM14 7h5v1h-5zM6 8h5v1h-5zM13 8h5v1h-5zM7 9h10v1h-10zM8 10h8v1h-8zM9 11h6v1h-6zM9 12h6v1h-6zM8 13h8v1h-8zM7 14h10v1h-10zM6 15h5v1h-5zM13 15h5v1h-5zM5 16h5v1h-5zM14 16h5v1h-5zM4 17h5v1h-5zM15 17h5v1h-5zM3 18h5v1h-5zM16 18h5v1h-5zM3 19h4v1h-4zM17 19h4v1h-4zM4 20h2v1h-2zM18 20h2v1h-2z"/></svg>',
    "play": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M6 3h3v1h-3zM6 4h3v1h-3zM6 5h6v1h-6zM6 6h6v1h-6zM6 7h9v1h-9zM6 8h9v1h-9zM6 9h12v1h-12zM6 10h12v1h-12zM6 11h13v1h-13zM6 12h13v1h-13zM6 13h12v1h-12zM6 14h12v1h-12zM6 15h9v1h-9zM6 16h9v1h-9zM6 17h6v1h-6zM6 18h6v1h-6zM6 19h3v1h-3zM6 20h3v1h-3z"/></svg>',
    "history": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 2h4v1h-4zM2 3h4v1h-4zM8 3h8v1h-8zM2 4h16v1h-16zM2 5h17v1h-17zM2 6h12v1h-12zM15 6h5v1h-5zM2 7h12v1h-12zM17 7h3v1h-3zM2 8h12v1h-12zM17 8h4v1h-4zM2 9h12v1h-12zM18 9h3v1h-3zM10 10h4v1h-4zM18 10h3v1h-3zM10 11h4v1h-4zM18 11h3v1h-3zM3 12h3v1h-3zM10 12h4v1h-4zM18 12h3v1h-3zM3 13h3v1h-3zM10 13h5v1h-5zM18 13h3v1h-3zM3 14h3v1h-3zM10 14h7v1h-7zM18 14h3v1h-3zM3 15h4v1h-4zM13 15h3v1h-3zM17 15h4v1h-4zM4 16h3v1h-3zM15 16h1v1h-1zM17 16h3v1h-3zM4 17h5v1h-5zM15 17h5v1h-5zM5 18h14v1h-14zM6 19h12v1h-12zM8 20h8v1h-8z"/></svg>',
    "user": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M8 3h8v1h-8zM8 4h8v1h-8zM8 5h8v1h-8zM8 6h8v1h-8zM8 7h8v1h-8zM8 8h8v1h-8zM8 9h8v1h-8zM8 10h8v1h-8zM4 14h16v1h-16zM4 15h16v1h-16zM4 16h16v1h-16zM4 17h16v1h-16zM4 18h16v1h-16zM4 19h16v1h-16zM4 20h16v1h-16z"/></svg>',
    "check": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M19 4h2v1h-2zM18 5h4v1h-4zM17 6h5v1h-5zM16 7h5v1h-5zM15 8h5v1h-5zM14 9h5v1h-5zM3 10h2v1h-2zM13 10h5v1h-5zM2 11h4v1h-4zM12 11h5v1h-5zM2 12h5v1h-5zM11 12h5v1h-5zM3 13h5v1h-5zM10 13h5v1h-5zM4 14h10v1h-10zM5 15h8v1h-8zM6 16h6v1h-6zM7 17h4v1h-4zM8 18h2v1h-2z"/></svg>',
    "bolt": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M12 3h1v1h-1zM11 4h2v1h-2zM10 5h3v1h-3zM10 6h2v1h-2zM9 7h3v1h-3zM8 8h4v1h-4zM7 9h5v1h-5zM7 10h11v1h-11zM6 11h11v1h-11zM5 12h11v1h-11zM4 13h11v1h-11zM10 14h5v1h-5zM10 15h4v1h-4zM10 16h3v1h-3zM10 17h2v1h-2zM9 18h3v1h-3zM9 19h2v1h-2zM9 20h1v1h-1z"/></svg>',
    "save": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M4 3h13v1h-13zM4 4h14v1h-14zM4 5h4v1h-4zM16 5h3v1h-3zM4 6h4v1h-4zM16 6h4v1h-4zM4 7h4v1h-4zM16 7h4v1h-4zM4 8h4v1h-4zM16 8h4v1h-4zM4 9h4v1h-4zM16 9h4v1h-4zM4 10h16v1h-16zM4 11h16v1h-16zM4 12h16v1h-16zM4 13h16v1h-16zM4 14h4v1h-4zM16 14h4v1h-4zM4 15h4v1h-4zM16 15h4v1h-4zM4 16h4v1h-4zM16 16h4v1h-4zM4 17h4v1h-4zM16 17h4v1h-4zM4 18h4v1h-4zM16 18h4v1h-4zM4 19h16v1h-16zM4 20h16v1h-16z"/></svg>',
    "restore": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 2h20v1h-20zM2 3h20v1h-20zM2 4h20v1h-20zM2 5h20v1h-20zM10 6h4v1h-4zM10 7h4v1h-4zM9 8h6v1h-6zM8 9h8v1h-8zM7 10h10v1h-10zM6 11h12v1h-12zM5 12h14v1h-14zM5 13h4v1h-4zM10 13h4v1h-4zM15 13h4v1h-4zM6 14h2v1h-2zM10 14h4v1h-4zM16 14h2v1h-2zM10 15h4v1h-4zM10 16h4v1h-4zM10 17h4v1h-4zM10 18h4v1h-4zM10 19h4v1h-4zM10 20h4v1h-4zM10 21h4v1h-4z"/></svg>',
    "flame": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 2h2v1h-2zM11 3h2v1h-2zM11 4h2v1h-2zM11 5h4v1h-4zM10 6h5v1h-5zM10 7h5v1h-5zM10 8h7v1h-7zM8 9h9v1h-9zM8 10h9v1h-9zM8 11h9v1h-9zM6 12h12v1h-12zM6 13h12v1h-12zM6 14h12v1h-12zM6 15h12v1h-12zM6 16h12v1h-12zM6 17h12v1h-12zM8 18h8v1h-8zM8 19h8v1h-8zM10 20h4v1h-4zM10 21h4v1h-4z"/></svg>',
    "gem": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M7 3h10v1h-10zM6 4h12v1h-12zM5 5h14v1h-14zM4 6h16v1h-16zM3 7h18v1h-18zM2 8h20v1h-20zM2 9h20v1h-20zM3 10h18v1h-18zM4 11h16v1h-16zM5 12h14v1h-14zM6 13h12v1h-12zM7 14h10v1h-10zM7 15h10v1h-10zM8 16h8v1h-8zM9 17h6v1h-6zM10 18h4v1h-4zM11 19h2v1h-2z"/></svg>',
    "star": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 2h4v1h-4zM10 3h4v1h-4zM10 4h4v1h-4zM10 5h4v1h-4zM10 6h4v1h-4zM10 7h4v1h-4zM4 8h18v1h-18zM4 9h18v1h-18zM4 10h18v1h-18zM4 11h18v1h-18zM7 12h12v1h-12zM7 13h12v1h-12zM7 14h12v1h-12zM5 15h16v1h-16zM5 16h16v1h-16zM5 17h8v1h-8zM15 17h6v1h-6zM5 18h8v1h-8zM15 18h6v1h-6zM5 19h4v1h-4zM17 19h4v1h-4zM5 20h4v1h-4zM17 20h4v1h-4zM5 21h4v1h-4zM17 21h4v1h-4z"/></svg>',
    "ember": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 3h2v1h-2zM11 4h2v1h-2zM9 5h6v1h-6zM9 6h6v1h-6zM9 7h8v1h-8zM9 8h8v1h-8zM7 9h10v1h-10zM7 10h10v1h-10zM5 11h14v1h-14zM5 12h14v1h-14zM5 13h6v1h-6zM13 13h6v1h-6zM5 14h6v1h-6zM13 14h6v1h-6zM5 15h6v1h-6zM13 15h6v1h-6zM5 16h6v1h-6zM13 16h6v1h-6zM7 17h10v1h-10zM7 18h10v1h-10zM9 19h6v1h-6zM9 20h6v1h-6z"/></svg>',
    "swap": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M15 4h2v1h-2zM15 5h2v1h-2zM15 6h4v1h-4zM4 7h15v1h-15zM4 8h17v1h-17zM4 9h17v1h-17zM4 10h15v1h-15zM7 11h2v1h-2zM15 11h4v1h-4zM5 12h4v1h-4zM15 12h2v1h-2zM5 13h15v1h-15zM3 14h17v1h-17zM3 15h17v1h-17zM5 16h15v1h-15zM5 17h4v1h-4zM7 18h2v1h-2zM7 19h2v1h-2z"/></svg>',
    "plus": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 3h4v1h-4zM10 4h4v1h-4zM10 5h4v1h-4zM10 6h4v1h-4zM10 7h4v1h-4zM10 8h4v1h-4zM10 9h4v1h-4zM3 10h18v1h-18zM3 11h18v1h-18zM3 12h18v1h-18zM3 13h18v1h-18zM10 14h4v1h-4zM10 15h4v1h-4zM10 16h4v1h-4zM10 17h4v1h-4zM10 18h4v1h-4zM10 19h4v1h-4zM10 20h4v1h-4z"/></svg>',
    "skip": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M3 4h3v1h-3zM12 4h3v1h-3zM3 5h3v1h-3zM12 5h3v1h-3zM3 6h5v1h-5zM12 6h5v1h-5zM3 7h5v1h-5zM12 7h5v1h-5zM3 8h7v1h-7zM12 8h7v1h-7zM3 9h7v1h-7zM12 9h7v1h-7zM3 10h18v1h-18zM3 11h18v1h-18zM3 12h18v1h-18zM3 13h18v1h-18zM3 14h7v1h-7zM12 14h7v1h-7zM3 15h7v1h-7zM12 15h7v1h-7zM3 16h5v1h-5zM12 16h5v1h-5zM3 17h5v1h-5zM12 17h5v1h-5zM3 18h3v1h-3zM12 18h3v1h-3zM3 19h3v1h-3zM12 19h3v1h-3z"/></svg>',
    "trash": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 2h6v1h-6zM9 3h6v1h-6zM3 4h18v1h-18zM3 5h18v1h-18zM3 6h18v1h-18zM5 8h14v1h-14zM5 9h14v1h-14zM5 10h14v1h-14zM5 11h4v1h-4zM11 11h2v1h-2zM15 11h4v1h-4zM5 12h4v1h-4zM11 12h2v1h-2zM15 12h4v1h-4zM5 13h4v1h-4zM11 13h2v1h-2zM15 13h4v1h-4zM5 14h4v1h-4zM11 14h2v1h-2zM15 14h4v1h-4zM5 15h4v1h-4zM11 15h2v1h-2zM15 15h4v1h-4zM5 16h4v1h-4zM11 16h2v1h-2zM15 16h4v1h-4zM5 17h4v1h-4zM11 17h2v1h-2zM15 17h4v1h-4zM5 18h4v1h-4zM11 18h2v1h-2zM15 18h4v1h-4zM5 19h14v1h-14zM5 20h14v1h-14zM5 21h14v1h-14z"/></svg>',
    "undo": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M8 3h2v1h-2zM8 4h2v1h-2zM6 5h4v1h-4zM6 6h4v1h-4zM4 7h12v1h-12zM4 8h12v1h-12zM6 9h4v1h-4zM16 9h2v1h-2zM6 10h4v1h-4zM16 10h2v1h-2zM8 11h2v1h-2zM16 11h4v1h-4zM8 12h2v1h-2zM17 12h3v1h-3zM17 13h3v1h-3zM17 14h3v1h-3zM17 15h3v1h-3zM17 16h3v1h-3zM17 17h3v1h-3zM17 18h3v1h-3z"/></svg>',
    "edit": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M18 2h2v1h-2zM17 3h4v1h-4zM16 4h6v1h-6zM15 5h7v1h-7zM14 6h3v1h-3zM18 6h3v1h-3zM13 7h3v1h-3zM17 7h3v1h-3zM12 8h3v1h-3zM16 8h3v1h-3zM11 9h7v1h-7zM10 10h7v1h-7zM9 11h7v1h-7zM8 12h7v1h-7zM7 13h7v1h-7zM6 14h7v1h-7zM5 15h7v1h-7zM4 16h7v1h-7zM3 17h7v1h-7zM3 18h6v1h-6zM3 19h5v1h-5zM2 20h5v1h-5zM2 21h2v1h-2z"/></svg>',
    "gear": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 2h4v1h-4zM17 2h5v1h-5zM2 3h5v1h-5zM16 3h6v1h-6zM2 4h6v1h-6zM15 4h7v1h-7zM2 5h7v1h-7zM14 5h8v1h-8zM2 6h8v1h-8zM13 6h8v1h-8zM3 7h8v1h-8zM12 7h8v1h-8zM4 8h7v1h-7zM12 8h7v1h-7zM5 9h5v1h-5zM13 9h5v1h-5zM4 10h5v1h-5zM14 10h3v1h-3zM18 10h2v1h-2zM3 11h5v1h-5zM15 11h1v1h-1zM17 11h4v1h-4zM3 12h5v1h-5zM15 12h6v1h-6zM4 13h5v1h-5zM14 13h6v1h-6zM5 14h5v1h-5zM13 14h6v1h-6zM6 15h5v1h-5zM12 15h6v1h-6zM5 16h14v1h-14zM4 17h16v1h-16zM3 18h5v1h-5zM9 18h6v1h-6zM16 18h5v1h-5zM2 19h5v1h-5zM10 19h4v1h-4zM17 19h5v1h-5zM1 20h5v1h-5zM11 20h2v1h-2zM18 20h5v1h-5zM1 21h4v1h-4zM19 21h4v1h-4zM2 22h2v1h-2zM20 22h2v1h-2z"/></svg>',
    "arm": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 4h5v1h-5zM10 5h5v1h-5zM10 6h5v1h-5zM8 7h5v1h-5zM8 8h5v1h-5zM8 9h4v1h-4zM6 10h6v1h-6zM6 11h6v1h-6zM14 11h4v1h-4zM6 12h6v1h-6zM14 12h4v1h-4zM3 13h17v1h-17zM3 14h17v1h-17zM3 15h17v1h-17zM3 16h17v1h-17zM3 17h15v1h-15zM3 18h15v1h-15zM3 19h12v1h-12zM3 20h12v1h-12zM5 21h7v1h-7zM10 22h2v1h-2z"/></svg>',
    "dice": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 2h20v1h-20zM2 3h20v1h-20zM2 4h20v1h-20zM2 5h3v1h-3zM9 5h13v1h-13zM2 6h3v1h-3zM9 6h13v1h-13zM2 7h3v1h-3zM9 7h13v1h-13zM2 8h3v1h-3zM9 8h13v1h-13zM2 9h20v1h-20zM2 10h8v1h-8zM14 10h8v1h-8zM2 11h8v1h-8zM14 11h8v1h-8zM2 12h8v1h-8zM14 12h8v1h-8zM2 13h8v1h-8zM14 13h8v1h-8zM2 14h20v1h-20zM2 15h13v1h-13zM19 15h3v1h-3zM2 16h13v1h-13zM19 16h3v1h-3zM2 17h13v1h-13zM19 17h3v1h-3zM2 18h13v1h-13zM19 18h3v1h-3zM2 19h20v1h-20zM2 20h20v1h-20zM2 21h20v1h-20z"/></svg>',
    "male": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M13 3h8v1h-8zM13 4h8v1h-8zM13 5h8v1h-8zM15 6h6v1h-6zM7 7h6v1h-6zM14 7h7v1h-7zM6 8h15v1h-15zM5 9h12v1h-12zM18 9h3v1h-3zM4 10h4v1h-4zM11 10h5v1h-5zM18 10h3v1h-3zM3 11h4v1h-4zM12 11h5v1h-5zM3 12h3v1h-3zM13 12h4v1h-4zM3 13h3v1h-3zM14 13h3v1h-3zM3 14h3v1h-3zM14 14h3v1h-3zM3 15h3v1h-3zM14 15h3v1h-3zM3 16h4v1h-4zM13 16h4v1h-4zM4 17h4v1h-4zM12 17h4v1h-4zM5 18h10v1h-10zM6 19h8v1h-8zM7 20h6v1h-6z"/></svg>',
    "female": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M8 2h8v1h-8zM7 3h10v1h-10zM6 4h12v1h-12zM6 5h3v1h-3zM15 5h3v1h-3zM5 6h4v1h-4zM15 6h4v1h-4zM5 7h3v1h-3zM16 7h3v1h-3zM5 8h3v1h-3zM16 8h3v1h-3zM5 9h3v1h-3zM16 9h3v1h-3zM5 10h4v1h-4zM15 10h4v1h-4zM6 11h3v1h-3zM15 11h3v1h-3zM6 12h12v1h-12zM7 13h10v1h-10zM8 14h8v1h-8zM11 15h2v1h-2zM11 16h2v1h-2zM7 17h10v1h-10zM7 18h10v1h-10zM7 19h10v1h-10zM11 20h2v1h-2zM11 21h2v1h-2zM11 22h2v1h-2z"/></svg>',
    "body": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 2h6v1h-6zM9 3h6v1h-6zM9 4h6v1h-6zM9 5h6v1h-6zM9 6h6v1h-6zM9 7h6v1h-6zM3 9h18v1h-18zM3 10h18v1h-18zM3 11h18v1h-18zM8 12h8v1h-8zM8 13h8v1h-8zM8 14h8v1h-8zM8 15h8v1h-8zM8 16h3v1h-3zM13 16h3v1h-3zM8 17h3v1h-3zM13 17h3v1h-3zM8 18h3v1h-3zM13 18h3v1h-3zM8 19h3v1h-3zM13 19h3v1h-3zM8 20h3v1h-3zM13 20h3v1h-3zM8 21h3v1h-3zM13 21h3v1h-3z"/></svg>',
    "lock": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M8 3h8v1h-8zM8 4h8v1h-8zM6 5h12v1h-12zM6 6h3v1h-3zM15 6h3v1h-3zM6 7h3v1h-3zM15 7h3v1h-3zM6 8h3v1h-3zM15 8h3v1h-3zM6 9h3v1h-3zM15 9h3v1h-3zM4 10h16v1h-16zM4 11h16v1h-16zM4 12h16v1h-16zM4 13h7v1h-7zM13 13h7v1h-7zM4 14h7v1h-7zM13 14h7v1h-7zM4 15h7v1h-7zM13 15h7v1h-7zM4 16h7v1h-7zM13 16h7v1h-7zM4 17h7v1h-7zM13 17h7v1h-7zM4 18h16v1h-16zM4 19h16v1h-16zM4 20h16v1h-16zM4 21h16v1h-16z"/></svg>',
    "sound": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 4h3v1h-3zM10 5h4v1h-4zM9 6h5v1h-5zM19 6h2v1h-2zM8 7h6v1h-6zM19 7h2v1h-2zM7 8h7v1h-7zM19 8h2v1h-2zM3 9h11v1h-11zM16 9h2v1h-2zM19 9h2v1h-2zM3 10h11v1h-11zM16 10h2v1h-2zM19 10h2v1h-2zM3 11h11v1h-11zM16 11h2v1h-2zM19 11h2v1h-2zM3 12h11v1h-11zM16 12h2v1h-2zM19 12h2v1h-2zM3 13h11v1h-11zM16 13h2v1h-2zM19 13h2v1h-2zM3 14h11v1h-11zM16 14h2v1h-2zM19 14h2v1h-2zM7 15h7v1h-7zM19 15h2v1h-2zM8 16h6v1h-6zM19 16h2v1h-2zM9 17h5v1h-5zM19 17h2v1h-2zM10 18h4v1h-4zM11 19h3v1h-3z"/></svg>',
    "chaos": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 3h2v1h-2zM4 4h1v1h-1zM11 4h2v1h-2zM19 4h1v1h-1zM5 5h2v1h-2zM11 5h2v1h-2zM17 5h2v1h-2zM5 6h3v1h-3zM10 6h4v1h-4zM16 6h3v1h-3zM6 7h12v1h-12zM7 8h10v1h-10zM7 9h10v1h-10zM6 10h4v1h-4zM14 10h4v1h-4zM3 11h7v1h-7zM14 11h7v1h-7zM3 12h7v1h-7zM14 12h7v1h-7zM6 13h4v1h-4zM14 13h4v1h-4zM7 14h10v1h-10zM7 15h10v1h-10zM6 16h12v1h-12zM5 17h3v1h-3zM10 17h4v1h-4zM16 17h3v1h-3zM5 18h2v1h-2zM11 18h2v1h-2zM17 18h2v1h-2zM4 19h1v1h-1zM11 19h2v1h-2zM19 19h1v1h-1zM11 20h2v1h-2z"/></svg>',
    "cel": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 2h6v1h-6zM7 3h10v1h-10zM5 4h14v1h-14zM4 5h8v1h-8zM15 5h5v1h-5zM4 6h8v1h-8zM16 6h4v1h-4zM3 7h9v1h-9zM17 7h4v1h-4zM3 8h9v1h-9zM18 8h3v1h-3zM2 9h10v1h-10zM19 9h3v1h-3zM2 10h10v1h-10zM19 10h3v1h-3zM2 11h10v1h-10zM19 11h3v1h-3zM2 12h10v1h-10zM19 12h3v1h-3zM2 13h10v1h-10zM19 13h3v1h-3zM2 14h10v1h-10zM19 14h3v1h-3zM3 15h9v1h-9zM18 15h3v1h-3zM3 16h9v1h-9zM17 16h4v1h-4zM4 17h8v1h-8zM16 17h4v1h-4zM4 18h8v1h-8zM15 18h5v1h-5zM5 19h14v1h-14zM7 20h10v1h-10zM9 21h6v1h-6z"/></svg>',
    "drop": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 2h2v1h-2zM11 3h2v1h-2zM11 4h2v1h-2zM9 5h6v1h-6zM9 6h6v1h-6zM9 7h6v1h-6zM7 8h10v1h-10zM7 9h10v1h-10zM7 10h10v1h-10zM5 11h14v1h-14zM5 12h14v1h-14zM5 13h14v1h-14zM5 14h14v1h-14zM5 15h14v1h-14zM5 16h14v1h-14zM5 17h14v1h-14zM7 18h10v1h-10zM7 19h10v1h-10zM9 20h6v1h-6zM9 21h6v1h-6z"/></svg>',
    "fire": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 1h2v1h-2zM10 2h2v1h-2zM10 3h4v1h-4zM10 4h4v1h-4zM8 5h6v1h-6zM16 5h2v1h-2zM8 6h6v1h-6zM16 6h2v1h-2zM8 7h10v1h-10zM8 8h10v1h-10zM8 9h12v1h-12zM8 10h12v1h-12zM4 11h2v1h-2zM8 11h12v1h-12zM4 12h2v1h-2zM8 12h12v1h-12zM4 13h16v1h-16zM4 14h16v1h-16zM4 15h16v1h-16zM4 16h16v1h-16zM6 17h12v1h-12zM6 18h12v1h-12zM6 19h12v1h-12zM8 20h8v1h-8zM8 21h8v1h-8z"/></svg>',
    "bell": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M4 7h3v1h-3zM17 7h3v1h-3zM4 8h3v1h-3zM17 8h3v1h-3zM1 9h6v1h-6zM17 9h6v1h-6zM1 10h22v1h-22zM1 11h22v1h-22zM1 12h22v1h-22zM1 13h22v1h-22zM1 14h6v1h-6zM17 14h6v1h-6zM4 15h3v1h-3zM17 15h3v1h-3zM4 16h3v1h-3zM17 16h3v1h-3z"/></svg>',
    "crown": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 6h3v1h-3zM7 6h3v1h-3zM14 6h3v1h-3zM19 6h3v1h-3zM2 7h3v1h-3zM7 7h3v1h-3zM14 7h3v1h-3zM19 7h3v1h-3zM2 8h3v1h-3zM7 8h3v1h-3zM14 8h3v1h-3zM19 8h3v1h-3zM2 9h3v1h-3zM7 9h10v1h-10zM19 9h3v1h-3zM2 10h20v1h-20zM2 11h20v1h-20zM2 12h20v1h-20zM2 13h20v1h-20zM2 14h20v1h-20zM2 15h20v1h-20zM2 16h20v1h-20zM2 17h20v1h-20zM2 19h20v1h-20zM2 20h20v1h-20zM2 21h20v1h-20z"/></svg>',
    "skull": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M6 2h12v1h-12zM6 3h12v1h-12zM4 4h16v1h-16zM4 5h16v1h-16zM4 6h16v1h-16zM4 7h16v1h-16zM4 8h3v1h-3zM11 8h2v1h-2zM17 8h3v1h-3zM4 9h3v1h-3zM11 9h2v1h-2zM17 9h3v1h-3zM4 10h3v1h-3zM11 10h2v1h-2zM17 10h3v1h-3zM4 11h3v1h-3zM11 11h2v1h-2zM17 11h3v1h-3zM4 12h16v1h-16zM4 13h16v1h-16zM6 14h5v1h-5zM13 14h5v1h-5zM6 15h5v1h-5zM13 15h5v1h-5zM6 16h12v1h-12zM8 17h8v1h-8zM8 18h8v1h-8zM8 19h8v1h-8zM8 20h8v1h-8zM8 21h8v1h-8z"/></svg>',
    "class-scrapper": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M7 8h5v1h-5zM7 9h5v1h-5zM7 10h5v1h-5zM15 10h2v1h-2zM1 11h4v1h-4zM7 11h11v1h-11zM1 12h4v1h-4zM7 12h12v1h-12zM7 13h13v1h-13zM7 14h14v1h-14zM2 15h4v1h-4zM7 15h15v1h-15zM2 16h4v1h-4zM7 16h15v1h-15zM7 17h15v1h-15zM7 19h15v1h-15z"/></svg>',
    "class-bruiser": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 2h6v1h-6zM8 3h8v1h-8zM7 4h10v1h-10zM6 5h4v1h-4zM14 5h4v1h-4zM6 6h3v1h-3zM15 6h3v1h-3zM6 7h3v1h-3zM15 7h3v1h-3zM6 8h3v1h-3zM15 8h3v1h-3zM6 9h1v1h-1zM9 9h6v1h-6zM17 9h1v1h-1zM8 10h8v1h-8zM7 11h10v1h-10zM6 12h12v1h-12zM6 13h2v1h-2zM10 13h8v1h-8zM6 14h2v1h-2zM10 14h8v1h-8zM5 15h14v1h-14zM6 16h12v1h-12zM6 17h12v1h-12zM6 18h12v1h-12zM7 19h10v1h-10zM8 20h8v1h-8zM9 21h6v1h-6z"/></svg>',
    "class-paladin": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M3 3h18v1h-18zM3 4h18v1h-18zM3 5h18v1h-18zM3 6h8v1h-8zM13 6h8v1h-8zM3 7h8v1h-8zM13 7h8v1h-8zM3 8h8v1h-8zM13 8h8v1h-8zM3 9h8v1h-8zM13 9h8v1h-8zM3 10h3v1h-3zM18 10h3v1h-3zM3 11h3v1h-3zM18 11h3v1h-3zM3 12h8v1h-8zM13 12h8v1h-8zM4 13h7v1h-7zM13 13h7v1h-7zM4 14h7v1h-7zM13 14h7v1h-7zM5 15h6v1h-6zM13 15h6v1h-6zM6 16h5v1h-5zM13 16h5v1h-5zM7 17h4v1h-4zM13 17h4v1h-4zM8 18h8v1h-8zM9 19h6v1h-6zM10 20h4v1h-4zM11 21h2v1h-2z"/></svg>',
    "class-cablemancer": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 2h20v1h-20zM2 3h20v1h-20zM2 4h20v1h-20zM9 5h6v1h-6zM8 6h8v1h-8zM8 7h3v1h-3zM13 7h3v1h-3zM8 8h2v1h-2zM14 8h2v1h-2zM8 9h3v1h-3zM13 9h3v1h-3zM8 10h8v1h-8zM9 11h6v1h-6zM11 12h2v1h-2zM11 13h2v1h-2zM5 14h14v1h-14zM5 15h14v1h-14zM11 16h2v1h-2zM5 17h14v1h-14zM5 18h14v1h-14zM11 19h2v1h-2zM5 20h14v1h-14zM5 21h14v1h-14z"/></svg>',
    "area-riptide": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 5h6v1h-6zM11 6h6v1h-6zM8 7h12v1h-12zM8 8h12v1h-12zM5 9h3v1h-3zM11 9h3v1h-3zM15 9h2v1h-2zM5 10h3v1h-3zM11 10h2v1h-2zM15 10h2v1h-2zM11 11h2v1h-2zM11 12h2v1h-2zM11 13h2v1h-2zM10 14h2v1h-2zM10 15h2v1h-2zM10 16h2v1h-2zM5 17h14v1h-14zM5 18h14v1h-14zM2 19h20v1h-20zM2 20h20v1h-20z"/></svg>',
    "area-gainsgard": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 5h4v1h-4zM8 5h3v1h-3zM13 5h3v1h-3zM18 5h4v1h-4zM2 6h4v1h-4zM8 6h3v1h-3zM13 6h3v1h-3zM18 6h4v1h-4zM2 7h4v1h-4zM8 7h3v1h-3zM13 7h3v1h-3zM18 7h4v1h-4zM2 8h20v1h-20zM2 9h20v1h-20zM2 10h20v1h-20zM2 11h20v1h-20zM2 12h20v1h-20zM2 13h20v1h-20zM2 14h20v1h-20zM2 15h20v1h-20zM2 16h8v1h-8zM14 16h8v1h-8zM2 17h8v1h-8zM14 17h8v1h-8zM2 18h8v1h-8zM14 18h8v1h-8zM2 19h8v1h-8zM14 19h8v1h-8zM2 20h8v1h-8zM14 20h8v1h-8zM2 21h8v1h-8zM14 21h8v1h-8z"/></svg>',
    "area-rustbelt": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M17 2h3v1h-3zM16 3h5v1h-5zM16 4h5v1h-5zM16 5h5v1h-5zM16 6h5v1h-5zM17 7h3v1h-3zM8 11h8v1h-8zM8 12h8v1h-8zM8 13h8v1h-8zM5 14h14v1h-14zM5 15h14v1h-14zM5 16h14v1h-14zM5 17h14v1h-14zM2 19h20v1h-20zM2 20h20v1h-20z"/></svg>',
    "area-arcade": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M10 2h4v1h-4zM9 3h6v1h-6zM8 4h8v1h-8zM8 5h8v1h-8zM8 6h8v1h-8zM8 7h8v1h-8zM9 8h6v1h-6zM10 9h4v1h-4zM11 10h2v1h-2zM11 11h2v1h-2zM11 12h2v1h-2zM11 13h2v1h-2zM11 14h2v1h-2zM11 15h2v1h-2zM3 16h18v1h-18zM3 17h18v1h-18zM3 18h2v1h-2zM8 18h13v1h-13zM3 19h2v1h-2zM8 19h13v1h-13zM3 20h18v1h-18zM3 21h18v1h-18z"/></svg>',
    "area-frostbite": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M7 9h1v1h-1zM15 9h1v1h-1zM7 10h5v1h-5zM14 10h3v1h-3zM6 11h11v1h-11zM6 12h12v1h-12zM5 13h14v1h-14zM4 14h15v1h-15zM4 15h16v1h-16zM3 16h17v1h-17zM3 17h18v1h-18zM2 18h20v1h-20zM2 19h20v1h-20zM1 20h22v1h-22z"/></svg>',
    "object-chest": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M5 4h14v1h-14zM5 5h14v1h-14zM3 6h18v1h-18zM3 7h18v1h-18zM3 8h7v1h-7zM14 8h7v1h-7zM11 9h2v1h-2zM3 10h7v1h-7zM11 10h2v1h-2zM14 10h7v1h-7zM3 11h7v1h-7zM11 11h2v1h-2zM14 11h7v1h-7zM3 12h7v1h-7zM14 12h7v1h-7zM3 13h18v1h-18zM3 14h18v1h-18zM3 15h18v1h-18zM3 16h18v1h-18zM3 17h18v1h-18zM3 18h18v1h-18zM3 19h18v1h-18zM3 20h18v1h-18z"/></svg>',
    "object-wall": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 4h6v1h-6zM9 4h7v1h-7zM17 4h5v1h-5zM2 5h6v1h-6zM9 5h7v1h-7zM17 5h5v1h-5zM2 6h6v1h-6zM9 6h7v1h-7zM17 6h5v1h-5zM2 7h6v1h-6zM9 7h7v1h-7zM17 7h5v1h-5zM2 8h6v1h-6zM9 8h7v1h-7zM17 8h5v1h-5zM2 10h2v1h-2zM5 10h7v1h-7zM13 10h7v1h-7zM21 10h1v1h-1zM2 11h2v1h-2zM5 11h7v1h-7zM13 11h7v1h-7zM21 11h1v1h-1zM2 12h2v1h-2zM5 12h7v1h-7zM13 12h7v1h-7zM21 12h1v1h-1zM2 13h2v1h-2zM5 13h7v1h-7zM13 13h7v1h-7zM21 13h1v1h-1zM2 14h2v1h-2zM5 14h7v1h-7zM13 14h7v1h-7zM21 14h1v1h-1zM2 16h6v1h-6zM9 16h7v1h-7zM17 16h5v1h-5zM2 17h6v1h-6zM9 17h7v1h-7zM17 17h5v1h-5zM2 18h6v1h-6zM9 18h7v1h-7zM17 18h5v1h-5zM2 19h6v1h-6zM9 19h7v1h-7zM17 19h5v1h-5zM2 20h6v1h-6zM9 20h7v1h-7zM17 20h5v1h-5z"/></svg>',
    "object-barrel": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M5 3h14v1h-14zM5 4h14v1h-14zM5 5h14v1h-14zM5 6h14v1h-14zM5 8h14v1h-14zM5 9h2v1h-2zM10 9h2v1h-2zM15 9h4v1h-4zM5 10h2v1h-2zM9 10h2v1h-2zM14 10h5v1h-5zM5 11h2v1h-2zM8 11h2v1h-2zM13 11h3v1h-3zM17 11h2v1h-2zM5 12h4v1h-4zM12 12h3v1h-3zM17 12h2v1h-2zM5 13h3v1h-3zM11 13h3v1h-3zM17 13h2v1h-2zM5 14h2v1h-2zM10 14h3v1h-3zM16 14h3v1h-3zM5 15h14v1h-14zM5 17h14v1h-14zM5 18h14v1h-14zM5 19h14v1h-14zM5 20h14v1h-14z"/></svg>',
    "object-punch": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M6 4h10v1h-10zM6 5h10v1h-10zM6 6h12v1h-12zM6 7h12v1h-12zM6 8h8v1h-8zM15 8h5v1h-5zM6 9h8v1h-8zM15 9h5v1h-5zM6 10h8v1h-8zM15 10h5v1h-5zM15 11h5v1h-5zM6 12h14v1h-14zM6 13h14v1h-14zM6 14h14v1h-14zM6 15h12v1h-12zM6 16h12v1h-12zM8 18h9v1h-9zM8 19h9v1h-9zM8 20h9v1h-9zM8 21h9v1h-9z"/></svg>',
    "object-ice": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M11 3h2v1h-2zM9 4h6v1h-6zM7 5h10v1h-10zM5 6h14v1h-14zM6 7h12v1h-12zM4 8h1v1h-1zM8 8h8v1h-8zM19 8h1v1h-1zM4 9h4v1h-4zM10 9h4v1h-4zM16 9h4v1h-4zM4 10h6v1h-6zM14 10h6v1h-6zM4 11h7v1h-7zM13 11h7v1h-7zM4 12h7v1h-7zM13 12h7v1h-7zM4 13h7v1h-7zM13 13h7v1h-7zM4 14h7v1h-7zM13 14h7v1h-7zM4 15h7v1h-7zM13 15h7v1h-7zM4 16h7v1h-7zM13 16h7v1h-7zM5 17h6v1h-6zM13 17h6v1h-6zM7 18h4v1h-4zM13 18h4v1h-4zM9 19h2v1h-2zM13 19h2v1h-2z"/></svg>',
    "mark-riptide": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 3h6v1h-6zM9 4h6v1h-6zM6 5h12v1h-12zM6 6h12v1h-12zM4 7h7v1h-7zM13 7h7v1h-7zM4 8h7v1h-7zM13 8h7v1h-7zM4 9h3v1h-3zM9 9h2v1h-2zM13 9h2v1h-2zM17 9h3v1h-3zM4 10h3v1h-3zM9 10h2v1h-2zM13 10h2v1h-2zM17 10h3v1h-3zM2 11h5v1h-5zM9 11h2v1h-2zM13 11h2v1h-2zM17 11h5v1h-5zM2 12h5v1h-5zM9 12h2v1h-2zM13 12h2v1h-2zM17 12h5v1h-5zM2 13h5v1h-5zM9 13h2v1h-2zM13 13h2v1h-2zM17 13h5v1h-5zM2 14h5v1h-5zM9 14h2v1h-2zM13 14h2v1h-2zM17 14h5v1h-5zM2 15h5v1h-5zM9 15h2v1h-2zM13 15h2v1h-2zM17 15h5v1h-5zM2 16h9v1h-9zM13 16h9v1h-9zM4 17h16v1h-16zM4 18h16v1h-16zM7 19h10v1h-10zM7 20h10v1h-10z"/></svg>',
    "mark-gainsgard": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M4 3h2v1h-2zM8 3h2v1h-2zM12 3h2v1h-2zM16 3h2v1h-2zM4 4h2v1h-2zM8 4h2v1h-2zM12 4h2v1h-2zM16 4h2v1h-2zM4 5h2v1h-2zM8 5h2v1h-2zM12 5h2v1h-2zM16 5h2v1h-2zM4 6h2v1h-2zM8 6h2v1h-2zM12 6h2v1h-2zM16 6h2v1h-2zM4 7h2v1h-2zM8 7h2v1h-2zM12 7h2v1h-2zM16 7h6v1h-6zM4 8h2v1h-2zM8 8h2v1h-2zM12 8h2v1h-2zM16 8h6v1h-6zM4 9h2v1h-2zM8 9h2v1h-2zM12 9h10v1h-10zM4 10h2v1h-2zM8 10h2v1h-2zM12 10h6v1h-6zM4 11h2v1h-2zM8 11h10v1h-10zM4 12h2v1h-2zM8 12h6v1h-6zM16 12h2v1h-2zM4 13h10v1h-10zM16 13h2v1h-2zM4 14h6v1h-6zM12 14h2v1h-2zM16 14h2v1h-2zM2 15h8v1h-8zM12 15h2v1h-2zM16 15h2v1h-2zM2 16h4v1h-4zM8 16h2v1h-2zM12 16h2v1h-2zM16 16h2v1h-2zM2 17h4v1h-4zM8 17h2v1h-2zM12 17h2v1h-2zM16 17h2v1h-2zM4 18h2v1h-2zM8 18h2v1h-2zM12 18h2v1h-2zM16 18h2v1h-2zM4 19h2v1h-2zM8 19h2v1h-2zM12 19h2v1h-2zM16 19h2v1h-2zM4 20h2v1h-2zM8 20h2v1h-2zM12 20h2v1h-2zM16 20h2v1h-2z"/></svg>',
    "mark-rustbelt": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M3 3h4v1h-4zM17 3h4v1h-4zM3 4h4v1h-4zM17 4h4v1h-4zM3 5h6v1h-6zM15 5h6v1h-6zM3 6h6v1h-6zM15 6h6v1h-6zM5 7h6v1h-6zM13 7h6v1h-6zM5 8h6v1h-6zM13 8h6v1h-6zM7 9h10v1h-10zM7 10h10v1h-10zM9 11h6v1h-6zM9 12h6v1h-6zM7 13h10v1h-10zM7 14h10v1h-10zM5 15h6v1h-6zM13 15h6v1h-6zM5 16h6v1h-6zM13 16h6v1h-6zM3 17h6v1h-6zM15 17h6v1h-6zM3 18h6v1h-6zM15 18h6v1h-6zM3 19h4v1h-4zM17 19h4v1h-4zM3 20h4v1h-4zM17 20h4v1h-4z"/></svg>',
    "mark-arcade": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M2 6h20v1h-20zM2 7h20v1h-20zM2 8h20v1h-20zM2 9h7v1h-7zM11 9h2v1h-2zM15 9h7v1h-7zM4 10h5v1h-5zM11 10h2v1h-2zM15 10h5v1h-5zM4 11h5v1h-5zM11 11h2v1h-2zM15 11h5v1h-5zM4 12h5v1h-5zM11 12h2v1h-2zM15 12h5v1h-5zM4 13h5v1h-5zM11 13h2v1h-2zM15 13h5v1h-5zM2 14h7v1h-7zM11 14h2v1h-2zM15 14h7v1h-7zM2 15h20v1h-20zM2 16h20v1h-20zM2 17h20v1h-20z"/></svg>',
    "mark-frostbite": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M5 2h3v1h-3zM5 3h14v1h-14zM5 4h14v1h-14zM5 5h12v1h-12zM5 6h12v1h-12zM5 7h14v1h-14zM5 8h14v1h-14zM5 9h16v1h-16zM5 10h16v1h-16zM5 11h3v1h-3zM5 12h3v1h-3zM5 13h3v1h-3zM5 14h3v1h-3zM5 15h3v1h-3zM5 16h3v1h-3zM5 17h3v1h-3zM5 18h3v1h-3zM5 19h3v1h-3zM5 20h3v1h-3zM5 21h3v1h-3z"/></svg>',
    "slot-head": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M9 4h6v1h-6zM9 5h6v1h-6zM7 6h10v1h-10zM7 7h10v1h-10zM5 8h14v1h-14zM5 9h14v1h-14zM3 10h18v1h-18zM3 11h18v1h-18zM3 12h18v1h-18zM3 13h18v1h-18zM2 15h20v1h-20zM2 16h20v1h-20zM2 17h20v1h-20zM2 18h20v1h-20z"/></svg>',
    "slot-top": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M6 3h4v1h-4zM14 3h4v1h-4zM5 4h5v1h-5zM14 4h5v1h-5zM4 5h16v1h-16zM3 6h18v1h-18zM2 7h20v1h-20zM3 8h18v1h-18zM3 9h18v1h-18zM4 10h16v1h-16zM7 11h10v1h-10zM7 12h10v1h-10zM7 13h10v1h-10zM7 14h10v1h-10zM7 15h10v1h-10zM7 16h10v1h-10zM7 17h10v1h-10zM7 18h10v1h-10zM7 19h10v1h-10zM7 20h10v1h-10z"/></svg>',
    "slot-bottom": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M4 4h16v1h-16zM4 5h16v1h-16zM4 6h16v1h-16zM4 8h16v1h-16zM4 9h16v1h-16zM4 10h16v1h-16zM4 11h16v1h-16zM4 12h7v1h-7zM13 12h7v1h-7zM4 13h7v1h-7zM13 13h7v1h-7zM4 14h7v1h-7zM13 14h7v1h-7zM4 15h6v1h-6zM13 15h7v1h-7zM4 16h6v1h-6zM14 16h6v1h-6zM4 17h6v1h-6zM14 17h6v1h-6zM4 18h6v1h-6zM14 18h6v1h-6z"/></svg>',
    "slot-shoes": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M3 8h6v1h-6zM3 9h6v1h-6zM3 10h6v1h-6zM13 10h3v1h-3zM3 11h14v1h-14zM3 12h15v1h-15zM3 13h16v1h-16zM3 14h17v1h-17zM3 15h18v1h-18zM3 16h18v1h-18zM3 18h18v1h-18z"/></svg>',
    "slot-weapon": '<svg viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="M5 6h3v1h-3zM16 6h3v1h-3zM5 7h3v1h-3zM16 7h3v1h-3zM2 8h6v1h-6zM16 8h6v1h-6zM2 9h6v1h-6zM16 9h6v1h-6zM2 10h20v1h-20zM2 11h20v1h-20zM2 12h20v1h-20zM2 13h20v1h-20zM2 14h6v1h-6zM16 14h6v1h-6zM2 15h6v1h-6zM16 15h6v1h-6zM5 16h3v1h-3zM16 16h3v1h-3zM5 17h3v1h-3zM16 17h3v1h-3z"/></svg>'
  };
  /* ICONS:END */
  function icon(name) { return ICONS[name] || ""; }
  /* Difficulty as gems, never as a number (moodboard "Difficulty"). */
  function gems(d, size) {
    d = d || difficulty(); if (!d) return "";
    var h = '<span class="gems" role="img" aria-label="' + d.gems + " of 6 XP gems" + '" style="--gem-c:' + c(d.color) + (size ? ";--gem-s:" + size + "px" : "") + '">';
    for (var i = 1; i <= 6; i++) h += '<i class="' + (i <= d.gems ? "on" : "") + '">' + ICONS.gem + "</i>";
    return h + "</span>";
  }
  function stars(n, size) {
    var h = '<span class="stars" role="img" aria-label="' + n + ' of 5 mastery stars"' + (size ? ' style="--star-s:' + size + 'px"' : "") + ">";
    for (var i = 1; i <= 5; i++) h += '<i class="' + (i <= n ? "on" : "") + '">' + ICONS.star + "</i>";
    return h + "</span>";
  }

  var toastTimer = null;
  function toast(msg, opts) {
    opts = opts || {};
    var phone = document.querySelector(".phone") || document.body;
    var old = phone.querySelector(".toast"); if (old) old.remove();
    clearTimeout(toastTimer);
    var t = document.createElement("div");
    t.className = "toast"; t.setAttribute("role", "status");
    t.innerHTML = "<span></span>";
    t.firstChild.textContent = msg;
    if (opts.action) {
      var b = document.createElement("button");
      b.type = "button"; b.textContent = opts.action;
      b.onclick = function () { t.remove(); clearTimeout(toastTimer); if (opts.onAction) opts.onAction(); };
      t.appendChild(b);
    }
    phone.appendChild(t);
    toastTimer = setTimeout(function () { t.remove(); if (opts.onTimeout) opts.onTimeout(); }, opts.ms || 2500);
    return t;
  }

  /* Freeze-frame stencil slam (class pick, difficulty pick, level up). Resolves when closed. */
  function slam(opts) {
    opts = opts || {};
    return new Promise(function (resolve) {
      var host = opts.host || document.querySelector(".phone") || document.body;
      var f = document.createElement("div");
      f.className = "freeze"; f.setAttribute("role", "dialog"); f.setAttribute("aria-label", opts.name || "");
      f.style.setProperty("--slam-c", c(opts.color || "lime"));
      var tag = document.createElement("div"); tag.className = "slam-tag"; tag.textContent = opts.name || "";
      f.appendChild(tag);
      if (opts.sub) { var s = document.createElement("div"); s.className = "slam-sub"; s.textContent = opts.sub; f.appendChild(s); }
      var done = false;
      function close() { if (done) return; done = true; f.remove(); resolve(); }
      f.addEventListener("click", close);
      host.appendChild(f);
      setTimeout(close, opts.ms || 1800);
      if (opts.onOpen) opts.onOpen(close);
    });
  }

  function fmtDate(ts) {
    if (typeof ts === "string") ts = dateOf(ts).getTime();
    return new Date(ts).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).toUpperCase();
  }

  /* Long-press helper: fires onTap for a short press, onHold after ms (default 550). */
  function press(el, onTap, onHold, ms) {
    var timer = null, held = false;
    function down(e) { if (e.button && e.button !== 0) return; held = false; timer = setTimeout(function () { held = true; if (onHold) onHold(e); }, ms || 550); }
    function up(e) { if (timer) { clearTimeout(timer); timer = null; if (!held && onTap) onTap(e); } }
    function cancel() { if (timer) { clearTimeout(timer); timer = null; } }
    el.addEventListener("pointerdown", down);
    el.addEventListener("pointerup", up);
    el.addEventListener("pointerleave", cancel);
    el.addEventListener("pointercancel", cancel);
    el.addEventListener("contextmenu", function (e) { e.preventDefault(); });
    el.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); if (e.shiftKey) { if (onHold) onHold(e); } else if (onTap) onTap(e); } });
  }

  /* Horizontal swipe on el (touch or mouse drag). onDrag(dx) while dragging, onSwipe(dir) on release:
     dir 1 = next (swiped left), -1 = previous. Taps (small moves) are left alone. */
  function swipe(el, onSwipe, onDrag) {
    var x0 = null, y0 = 0, id = null, dragging = false;
    el.style.touchAction = "pan-y";
    el.addEventListener("pointerdown", function (e) {
      if (e.button && e.button !== 0) return;
      x0 = e.clientX; y0 = e.clientY; id = e.pointerId; dragging = false;
    });
    el.addEventListener("pointermove", function (e) {
      if (x0 === null || e.pointerId !== id) return;
      var dx = e.clientX - x0;
      if (!dragging && Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(e.clientY - y0)) {
        dragging = true; try { el.setPointerCapture(id); } catch (err) {}
      }
      if (dragging && onDrag) onDrag(dx);
    });
    function end(e) {
      if (x0 === null || e.pointerId !== id) return;
      var dx = e.clientX - x0; x0 = null;
      if (!dragging) return;
      if (onDrag) onDrag(0);
      if (Math.abs(dx) > 40) onSwipe(dx < 0 ? 1 : -1);
      /* swallow the click that follows a drag */
      function stop(ev) { ev.stopPropagation(); ev.preventDefault(); }
      el.addEventListener("click", stop, { capture: true, once: true });
      setTimeout(function () { dragging = false; el.removeEventListener("click", stop, { capture: true }); }, 0);
    }
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", function (e) { if (onDrag) onDrag(0); x0 = null; });
  }

  /* ---------- demo chrome: a small bar outside the phone (desktop only) ---------- */
  function demoBar() {
    if (document.querySelector(".demo-bar")) return;
    var here = (location.pathname.split("/").pop() || "").toLowerCase();
    /* the initial setup plays clean: no PUMPLEX DEMO bar over steps 1-5 */
    for (var si = 0; si < SCREENS.length; si++) if (SCREENS[si].file === here && SCREENS[si].step) return;
    var bar = document.createElement("nav");
    bar.className = "demo-bar"; bar.setAttribute("aria-label", "Demo controls");
    var opts = SCREENS.map(function (sc) {
      return '<option value="' + sc.id + '"' + (sc.file === here ? " selected" : "") + ">" + sc.file.slice(0, 2) + " " + sc.title + "</option>";
    }).join("");
    bar.innerHTML = '<a href="index.html">PUMPLEX DEMO</a><select aria-label="Jump to screen">' + opts + "</select>" +
      '<button type="button" data-act="returning">Returning player</button><button type="button" data-act="reset">Restart</button>';
    bar.querySelector("select").onchange = function (e) { go(e.target.value); };
    bar.querySelector('[data-act="reset"]').onclick = function () { reset(); go(homeId()); };
    bar.querySelector('[data-act="returning"]').onclick = function () { seedReturning(); go("hub"); };
    document.body.appendChild(bar);
  }

  function applySettings() {
    var st = get().settings || {};
    document.documentElement.classList.toggle("cel", !!st.cel);
    document.documentElement.classList.toggle("chaos", !!st.chaos);
  }

  (function () {
    var m = /[?&]demo=(returning|new)\b/.exec(location.search);
    if (m) { if (m[1] === "returning") seedReturning(); else reset(); }
  })();

  applySettings();
  document.addEventListener("DOMContentLoaded", function () { if (!document.body.classList.contains("idx")) demoBar(); });

  window.PX = {
    SCREENS: SCREENS, SETUP_STEPS: SETUP_STEPS, VERSION: "v0.3",
    CLASSES: CLASSES, CLASS_ORDER: CLASS_ORDER, DIFFICULTIES: DIFFICULTIES,
    AREAS: AREAS, AREA_ORDER: AREA_ORDER, POOLS: POOLS, EXERCISES: EXERCISES, LEVEL_TITLES: LEVEL_TITLES,
    RARITIES: RARITIES, SLOTS: SLOTS, ITEMS: ITEMS, RULES: RULES,
    xpToNext: xpToNext, xpToReach: xpToReach, levelInfo: levelInfo, sessionXp: sessionXp, game: game,
    get: get, save: save, reset: reset, seedReturning: seedReturning,
    cls: cls, area: area, difficulty: difficulty, exercise: exercise, pool: pool, planWorkout: planWorkout,
    live: live, sessionSets: sessionSets, sessionByDate: sessionByDate, today: today, dayKey: dayKey, weekKey: weekKey,
    startWorkout: startWorkout, saveSet: saveSet, c: c,
    screen: screen, go: go, homeId: homeId, editMode: editMode, require: require,
    sprite: sprite, snap: snap, heightScale: heightScale, icon: icon, gems: gems, stars: stars, toast: toast, slam: slam, press: press, swipe: swipe,
    fmtDate: fmtDate, applySettings: applySettings
  };
})();

/* Swipe picker: one card, swipe left/right or tap the arrows / dots. Used by class and difficulty.
   opts: { root, count, index, color(i), render(cardEl, i), onChange(i), label(i), loop } */
window.PX.picker = function (opts) {
  var root = opts.root, n = opts.count, i = opts.index || 0;
  root.classList.add("swp");
  root.innerHTML =
    '<div class="swp-view"><div class="swp-card"></div>' +
    '<button class="swp-arrow is-prev" type="button" aria-label="Previous">' + PX.icon("back") + "</button>" +
    '<button class="swp-arrow is-next" type="button" aria-label="Next">' + PX.icon("back") + "</button></div>" +
    '<div class="swp-dots" role="tablist"></div>';
  var view = root.querySelector(".swp-view"), card = root.querySelector(".swp-card");
  var prev = root.querySelector(".is-prev"), next = root.querySelector(".is-next"), dots = root.querySelector(".swp-dots");
  for (var d = 0; d < n; d++) (function (d) {
    var b = document.createElement("button"); b.type = "button"; b.setAttribute("role", "tab");
    b.setAttribute("aria-label", opts.label ? opts.label(d) : "Option " + (d + 1));
    b.onclick = function () { go(d); };
    dots.appendChild(b);
  })(d);
  function paint(dir) {
    var c = opts.color ? opts.color(i) : "var(--lime)";
    root.style.setProperty("--swp-c", c);
    dots.style.setProperty("--dot-c", c);
    opts.render(card, i);
    prev.disabled = !opts.loop && i === 0; next.disabled = !opts.loop && i === n - 1;
    dots.querySelectorAll("button").forEach(function (b, j) { b.setAttribute("aria-current", String(j === i)); b.setAttribute("aria-selected", String(j === i)); });
    if (dir) { card.classList.remove("in-next", "in-prev"); void card.offsetWidth; card.classList.add(dir > 0 ? "in-next" : "in-prev"); }
  }
  function go(j, dir) {
    if (opts.loop) j = (j + n) % n; else j = Math.max(0, Math.min(n - 1, j));
    if (j === i) { paint(0); return; }
    dir = dir || (j > i ? 1 : -1); i = j; paint(dir);
    if (opts.onChange) opts.onChange(i);
  }
  prev.onclick = function () { go(i - 1, -1); };
  next.onclick = function () { go(i + 1, 1); };
  root.addEventListener("keydown", function (e) {
    if (e.key === "ArrowRight") { e.preventDefault(); go(i + 1, 1); }
    else if (e.key === "ArrowLeft") { e.preventDefault(); go(i - 1, -1); }
  });
  PX.swipe(view, function (dir) { go(i + dir, dir); }, function (dx) {
    card.classList.toggle("is-drag", !!dx);
    card.style.transform = dx ? "translateX(" + dx * .6 + "px) rotate(" + dx / 60 + "deg)" : "";
  });
  paint(0);
  return { go: go, index: function () { return i; } };
};

/* ---------- the lifter's look (skin, hair, facial hair, clothes) ----------
   PX.sprite draws the plain atlas frame; when the character has a look (set on the character screen)
   the frame is recoloured pixel by pixel and used as the sprite's background instead, so every screen
   shows the same lifter. The atlas loads as a data URL (shared/atlas.js) so this works from file:// too. */
(function () {
  "use strict";
  var PX = window.PX, plainSprite = PX.sprite;
  var LOOK = {
    SKIN: [
      { id: "porcelain", name: "Porcelain", r: ["#f7dcc8", "#ecb994", "#b98068"] },
      { id: "peach",     name: "Peach",     r: ["#e4bc97", "#d39a6a", "#8c605c"] },
      { id: "tan",       name: "Tan",       r: ["#d6a274", "#b47848", "#734832"] },
      { id: "brown",     name: "Brown",     r: ["#a06c48", "#7c4c2e", "#4c2c1c"] },
      { id: "deep",      name: "Deep",      r: ["#74483a", "#523022", "#301a12"] },
      { id: "orc",       name: "Gym orc",   r: ["#c6ec86", "#8cbc4c", "#527a2c"] }
    ],
    HAIRC: [
      { id: "brown",  name: "Brown",  r: ["#997d6b", "#5a3424", "#462533"] },
      { id: "black",  name: "Black",  r: ["#5a4a5e", "#2e2032", "#180e1a"] },
      { id: "blonde", name: "Blonde", r: ["#ffe9a0", "#e8b84a", "#9c7226"] },
      { id: "ginger", name: "Ginger", r: ["#ffb070", "#e86e2c", "#8e3c1a"] },
      { id: "pink",   name: "Pink",   r: ["#ff98c2", "#ff5fb0", "#a63e84"] },
      { id: "silver", name: "Silver", r: ["#f6eeff", "#c9b8e8", "#8672a5"] }
    ],
    CLOTH: [
      { id: "lilac",  name: "Lilac",  r: ["#decfe5", "#c9b8e8", "#8672a5"] },
      { id: "violet", name: "Violet", r: ["#ad8ed6", "#7b4fd0", "#593597"] },
      { id: "slate",  name: "Slate",  r: ["#857788", "#3a2a52", "#33204e"] },
      { id: "pink",   name: "Pink",   r: ["#ff98c2", "#ff5fb0", "#a63e84"] },
      { id: "lime",   name: "Lime",   r: ["#dcfb7b", "#c6ff3d", "#849b42"] },
      { id: "orange", name: "Orange", r: ["#ffc075", "#ffa033", "#a6643c"] },
      { id: "sky",    name: "Sky",    r: ["#88dff3", "#3fd2ff", "#3681b2"] }
    ],
    HAIR: [{ id: "crop", name: "Crop" }, { id: "buzz", name: "Buzz" }, { id: "mohawk", name: "Mohawk" }, { id: "afro", name: "Afro" }, { id: "long", name: "Long" }, { id: "bald", name: "Bald" }],
    FACE: [{ id: "none", name: "None" }, { id: "stubble", name: "Stubble" }, { id: "stache", name: "Stache" }, { id: "beard", name: "Beard" }],
    TOPS: [{ id: "tee", name: "Tee" }, { id: "crop", name: "Crop" }, { id: "sleeves", name: "Sleeves" }],
    BOTTOMS: [{ id: "shorts", name: "Shorts" }, { id: "bike", name: "Bike" }, { id: "pants", name: "Pants" }],
    SHOES: [{ id: "sneakers", name: "Sneakers" }, { id: "hightops", name: "High-tops" }, { id: "barefoot", name: "Barefoot" }],
    DEFAULT: { skin: "peach", hair: "crop", hairColor: "brown", face: "none",
               top: "tee", topColor: "lilac", bottom: "shorts", bottomColor: "violet", shoes: "sneakers", shoesColor: "slate" }
  };
  function find(list, id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return list[0]; }

  /* atlas: null while loading, false if unusable (the plain sprite stays), else the image */
  var atlas = null, waiting = [], cache = {};
  var base = ((document.currentScript && document.currentScript.src) || "").replace(/[^\/]*$/, "");
  function flush() { var w = waiting; waiting = []; w.forEach(function (f) { f(); }); }
  function loadImg() {
    var img = new Image();
    img.onload = function () {
      try { var c = document.createElement("canvas"); c.width = c.height = 1; c.getContext("2d").drawImage(img, 0, 0); c.getContext("2d").getImageData(0, 0, 1, 1); atlas = img; }
      catch (e) { atlas = false; }
      flush();
    };
    img.onerror = function () { atlas = false; flush(); };
    img.src = window.PX_ATLAS;
  }
  if (window.PX_ATLAS) loadImg();
  else {
    var sc = document.createElement("script");
    sc.src = base + "atlas.js";
    sc.onload = function () { if (window.PX_ATLAS) loadImg(); else { atlas = false; flush(); } };
    sc.onerror = function () { atlas = false; flush(); };
    (document.head || document.documentElement).appendChild(sc);
  }

  /* Atlas ramps: skin (s), top (t), bottoms (b), shoes (f), hair (h); step 0 highlight, 1 base, 2 shadow.
     Pixels are labelled, styles edit the labels, then each label is painted with the chosen ramp. */
  var ORIG = { "#e4bc97": "s0", "#d39a6a": "s1", "#8c605c": "s2", "#decfe5": "t0", "#c9b8e8": "t1", "#8672a5": "t2",
               "#ad8ed6": "b0", "#7b4fd0": "b1", "#593597": "b2", "#857788": "f0", "#3a2a52": "f1", "#33204e": "f2",
               "#997d6b": "h0", "#5a3424": "h1", "#462533": "h2", "#0b0414": "k", "#281424": "e" };
  var W = 52, H = 64;
  function hex(r, g, b) { return "#" + [r, g, b].map(function (v) { return v.toString(16).padStart(2, "0"); }).join(""); }

  function paintLook(ch) {
    var lk = {}; for (var k in LOOK.DEFAULT) lk[k] = ch[k] || LOOK.DEFAULT[k];
    var canvas = document.createElement("canvas"); canvas.width = W; canvas.height = H;
    var ctx = canvas.getContext("2d");
    var fx = PX.snap(ch.fat) / 25, fy = (ch.sex === "female" ? 5 : 0) + PX.snap(ch.muscle) / 25;
    ctx.drawImage(atlas, fx * W, fy * H, W, H, 0, 0, W, H);
    var img = ctx.getImageData(0, 0, W, H), d = img.data, L = new Array(W * H), x, y, i;
    for (i = 0; i < W * H; i++) {
      if (!d[i * 4 + 3]) { L[i] = null; continue; }
      var hx = hex(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]);
      L[i] = ORIG[hx] || "x" + hx;
    }
    function at(x, y) { return x < 0 || y < 0 || x >= W || y >= H ? null : L[y * W + x]; }
    function set(x, y, v) { if (x >= 0 && y >= 0 && x < W && y < H) L[y * W + x] = v; }
    function is(v, r) { return !!v && v.charAt(0) === r && v.length === 2; }
    function swapRamp(x, y, from, to) { var v = at(x, y); if (is(v, from)) set(x, y, to + v.charAt(1)); }

    /* face geometry: eyes on row 8, head outline from row 10 */
    var ex = []; for (x = 0; x < W; x++) if (at(x, 8) === "e") ex.push(x);
    var cx = ex.length ? Math.round((ex[0] + ex[ex.length - 1]) / 2) : 26;
    var hl = cx - 6; for (x = 0; x < cx; x++) if (at(x, 10) === "k" && is(at(x + 1, 10), "s")) { hl = x; break; }
    var hr = 2 * cx - hl - 2; /* last interior column of the head, mirrored from the left outline */

    /* torso skin (midriff) has clothes on both sides; other skin in rows 17-41 is arm */
    function isArm(x, y) {
      if (y < 17 || y > 41 || !is(at(x, y), "s")) return false;
      var l = false, r = false, j;
      for (j = x - 1; j >= 0; j--) if (is(at(j, y), "t") || is(at(j, y), "b")) { l = true; break; }
      for (j = x + 1; j < W; j++) if (is(at(j, y), "t") || is(at(j, y), "b")) { r = true; break; }
      return !(l && r);
    }

    /* hair */
    if (lk.hair !== "crop" && lk.hair !== "long") {
      for (y = 0; y <= 20; y++) for (x = 0; x < W; x++) {
        var v = at(x, y);
        if (is(v, "h")) set(x, y, x > hl && x <= hr && y >= 3 ? "s" + v.charAt(1) : null);
      }
      for (y = 0; y <= 14; y++) for (x = 0; x < W; x++) if (at(x, y) === "k" && (x < hl || x > hr + 1)) set(x, y, null);
      if (lk.hair === "buzz") for (y = 3; y <= 5; y++) for (x = hl + 1; x <= hr; x++) if (is(at(x, y), "s") && (y < 5 || (x + y) % 2)) set(x, y, "h2");
      if (lk.hair === "mohawk") for (y = 0; y <= 5; y++) { set(cx - 1, y, "h0"); set(cx, y, "h1"); }
      if (lk.hair === "afro") {
        for (y = 0; y <= 13; y++) for (x = cx - 11; x <= cx + 10; x++) {
          var dx = x - cx + .5, dy = y - 5.5, cur = at(x, y);
          if (dx * dx + dy * dy > 92) continue;
          if (y >= 6 && x > hl && x <= hr) continue;
          if (cur && !is(cur, "h") && cur !== "k" && !(is(cur, "s") && y < 6)) continue;
          set(x, y, dx + dy < -9 ? "h0" : dx + dy > 7 ? "h2" : "h1");
        }
      }
    }
    if (lk.hair === "long") {
      for (y = 4; y <= 18; y++) [hl - 2, hl - 1, hl, hr + 1, hr + 2, hr + 3].forEach(function (xx, n) {
        var cur = at(xx, y);
        if (cur === null || cur === "k" || is(cur, "h")) set(xx, y, n === 0 || n === 5 ? "h2" : "h1");
      });
    }

    /* facial hair */
    if (lk.face === "stubble") for (y = 11; y <= 14; y++) for (x = hl + 1; x <= hr; x++) if (is(at(x, y), "s") && (x + y) % 2 === 0) set(x, y, "h2");
    if (lk.face === "stache") {
      for (x = cx - 3; x <= cx + 2; x++) if (is(at(x, 11), "s")) set(x, 11, "h1");
      if (is(at(cx - 3, 12), "s")) set(cx - 3, 12, "h1");
      if (is(at(cx + 2, 12), "s")) set(cx + 2, 12, "h1");
    }
    if (lk.face === "beard") {
      for (y = 9; y <= 14; y++) for (x = hl + 1; x <= hr; x++) {
        if (!is(at(x, y), "s")) continue;
        var side = x <= hl + 1 || x >= hr;
        if (y < 11 && !side) continue;
        if (y === 12 && x >= cx - 1 && x <= cx) continue;
        set(x, y, y === 14 || side ? "h2" : "h1");
      }
    }

    /* clothes */
    for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
      var p = at(x, y);
      if (lk.top === "crop" && y >= 30 && y <= 33) swapRamp(x, y, "t", "s");
      if (lk.top === "sleeves" && y <= 35 && isArm(x, y)) set(x, y, "t" + p.charAt(1));
      if (lk.bottom === "pants" && y >= 42 && y <= 53) swapRamp(x, y, "s", "b");
      if (lk.bottom === "bike" && y >= 42 && y <= 46) swapRamp(x, y, "s", "b");
      if (lk.shoes === "hightops" && y >= 49 && y <= 53) swapRamp(x, y, "s", "f");
      if (lk.shoes === "barefoot" && y >= 54) swapRamp(x, y, "f", "s");
    }

    /* ink outline around anything that now touches the void */
    var add = [];
    for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
      if (at(x, y) !== null) continue;
      if ([at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)].some(function (n) { return n && n.length === 2 && "stbfh".indexOf(n.charAt(0)) >= 0; })) add.push([x, y]);
    }
    add.forEach(function (a) { set(a[0], a[1], "k"); });

    var R = { s: find(LOOK.SKIN, lk.skin).r, h: find(LOOK.HAIRC, lk.hairColor).r, t: find(LOOK.CLOTH, lk.topColor).r, b: find(LOOK.CLOTH, lk.bottomColor).r, f: find(LOOK.CLOTH, lk.shoesColor).r };
    for (i = 0; i < W * H; i++) {
      var lab = L[i], col;
      if (lab === null) { d[i * 4 + 3] = 0; continue; }
      col = lab === "k" ? "#0b0414" : lab === "e" ? "#281424" : lab.charAt(0) === "x" ? lab.slice(1) : R[lab.charAt(0)][+lab.charAt(1)];
      d[i * 4] = parseInt(col.slice(1, 3), 16); d[i * 4 + 1] = parseInt(col.slice(3, 5), 16); d[i * 4 + 2] = parseInt(col.slice(5, 7), 16); d[i * 4 + 3] = 255;
    }
    ctx.putImageData(img, 0, 0);
    return canvas.toDataURL();
  }

  function lookURL(ch) {
    var key = [ch.sex, PX.snap(ch.fat), PX.snap(ch.muscle)].concat(Object.keys(LOOK.DEFAULT).map(function (k) { return ch[k] || ""; })).join("|");
    return cache[key] || (cache[key] = paintLook(ch));
  }

  PX.sprite = function (el, ch, scale) {
    ch = ch || PX.get().character; scale = scale || 3;
    plainSprite(el, ch, scale);
    if (!ch || !ch.skin) return el;                 /* no look picked: the plain atlas frame */
    var copy = {}; for (var k in ch) copy[k] = ch[k];
    if (atlas === null) { waiting.push(function () { PX.sprite(el, copy, scale); }); return el; }
    if (!atlas) return el;
    el.style.backgroundImage = "url(" + lookURL(ch) + ")";
    el.style.backgroundSize = 52 * scale + "px " + 64 * scale * PX.heightScale(ch.height) + "px";
    el.style.backgroundPosition = "0 0";
    return el;
  };
  PX.LOOK = LOOK;
  PX.onAtlas = function (cb) { if (atlas === null) waiting.push(function () { cb(!!atlas); }); else cb(!!atlas); };
})();
