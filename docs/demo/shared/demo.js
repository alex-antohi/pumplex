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
  var SCREENS = [
    { id: "preloader",  file: "01-preloader.html",  title: "Preloader" },
    { id: "character",  file: "02-character.html",  title: "Character creation", step: 1 },
    { id: "class",      file: "03-class.html",      title: "Class (path)",        step: 2 },
    { id: "difficulty", file: "04-difficulty.html", title: "Difficulty",          step: 3 },
    { id: "area",       file: "05-area.html",       title: "Starting area",       step: 4 },
    { id: "summary",    file: "06-summary.html",    title: "Setup summary",       step: 5 },
    { id: "hub",        file: "07-hub.html",        title: "Hub" },
    { id: "workout",    file: "08-workout.html",    title: "Workout" },
    { id: "reward",     file: "09-reward.html",     title: "Reward" },
    { id: "history",    file: "10-history.html",    title: "Past sessions" },
    { id: "profile",    file: "11-profile.html",    title: "Profile" },
    { id: "menu",       file: "12-menu.html",       title: "Menu" }
  ];
  var SETUP_STEPS = 5;

  /* ---------- classes (moodboard "Class select") ---------- */
  var CLASSES = {
    scrapper: {
      id: "scrapper", name: "Scrapper", equipment: "No equipment", color: "orange",
      loadout: "Nothin'. Just you, the floor and the stairs.",
      tags: ["CARDIO", "BODYWEIGHT", "SPRINTS"],
      subtitle: "BUILT FROM STAIRS AND SPITE",
      description: "No gym, no gear, no problem. Builds every workout out of floors, stairs and pure spite. Homemade, held together with tape, and very loud about it.",
      body: { sex: "female", fat: 0, muscle: 25 }, area: "rustbelt"
    },
    bruiser: {
      id: "bruiser", name: "Bargain Bruiser", equipment: "Basic home gym", color: "sky",
      loadout: "Two dumbbells, one mat, a kettlebell of unknown origin.",
      tags: ["FLOOR WORK", "SOME CARDIO", "SOME WEIGHTS"],
      subtitle: "BUY ONE GAIN, GET ONE FREE",
      description: "Kitted out from the clearance aisle. Every piece of gear is store-brand, slightly wobbly and fully committed. Cheap kit, real gains.",
      body: { sex: "male", fat: 25, muscle: 50 }, area: "arcade"
    },
    paladin: {
      id: "paladin", name: "Plate Paladin", equipment: "Lots of free weights", color: "lime",
      loadout: "A barbell, a rack and a wall of plates.",
      tags: ["STRONGMAN", "BARBELL", "HEAVY"],
      subtitle: "OATH-SWORN TO THE BARBELL",
      description: "Sworn to the barbell. Carries plates like holy relics and drops them like thunder. Big, burly, unbothered.",
      body: { sex: "male", fat: 75, muscle: 100 }, area: "gainsgard"
    },
    cablemancer: {
      id: "cablemancer", name: "Cablemancer", equipment: "Lots of machines", color: "violet",
      loadout: "Cables, pin-stacks and every machine in the building.",
      tags: ["MACHINES", "CABLES", "LEAN POWER"],
      subtitle: "SPEAKS FLUENT PULLEY",
      description: "Bends steel cables and pin-stacks to their will. Thin as a wire, strong as the machine. Never waits for the squat rack.",
      body: { sex: "female", fat: 0, muscle: 75 }, area: "frostbite"
    }
  };
  var CLASS_ORDER = ["scrapper", "bruiser", "paladin", "cablemancer"];

  /* ---------- difficulty: the six rungs of moodboard "Difficulty" ----------
     mult: rules.md §1, 1.0 at the lowest rung rising in even steps to 2.0.
     gems: the picture of the multiplier (no numbers on screen).
     exercises: data-schema, 3 at the easiest, 8 at the hardest.
     targetSets, streakN: PLACEHOLDER (data-schema: from the difficulty, values TBD). */
  var DIFFICULTIES = [
    { id: "spawn",    name: "Couch Spawn",          color: "muted",  gems: 1, mult: 1.0, exercises: 3, targetSets: 2, streakN: 2,
      line: "Never lifted, or not for years. Freshly respawned from the sofa.", joke: "THE SOFA WILL REMEMBER YOU" },
    { id: "squire",   name: "Dumbbell Squire",      color: "lime",   gems: 2, mult: 1.2, exercises: 4, targetSets: 3, streakN: 2,
      line: "A few weeks to a few months in. Knows where the mats live.", joke: "SQUIRE TODAY, LEGEND LATER" },
    { id: "ranger",   name: "Rep Ranger",           color: "sky",    gems: 3, mult: 1.4, exercises: 5, targetSets: 3, streakN: 3,
      line: "Trains most weeks, for about a year. Has opinions about grip.", joke: "RANGES REPS, NOT CATTLE" },
    { id: "warlock",  name: "Gain Warlock",         color: "violet", gems: 4, mult: 1.6, exercises: 6, targetSets: 4, streakN: 3,
      line: "About two years in. Summons the pump on demand.", joke: "CASTS PUMP ON SELF" },
    { id: "warlord",  name: "Barbell Warlord",      color: "orange", gems: 5, mult: 1.8, exercises: 7, targetSets: 4, streakN: 4,
      line: "Years of serious lifting. The squat rack fears them.", joke: "CONQUERS RACKS, RETURNS PLATES" },
    { id: "ascended", name: "Ascended Swolemancer", color: "pink",   gems: 6, mult: 2.0, exercises: 8, targetSets: 5, streakN: 4,
      line: "Many years, competition level. Gyms whisper their name.", joke: "HAS BEEN WARNED BY GRAVITY" }
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
    head:   ["Sweaty Headband", "Bandana of Grit", "Chalk Crown", "Halo of Pump", "Helm of the Final PR"],
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
      character: { sex: "male", fat: 50, muscle: 50 },
      bodyHistory: [],     // data-schema BODY_CHANGE: [{at, sex, fat, muscle}]
      cls: null,
      difficulty: null,
      area: null,
      sessions: [],        // data-schema SESSION, one per calendar day, oldest first
      current: null,       // the running workout: {date, start, active, exercises: [SESSION_EXERCISE + skipped]}
      lastReward: null,
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

  /* ---------- the running workout (one session per calendar day, data-schema §1) ---------- */
  /* Start or continue today's workout. Marks on a day that already has a session add to that session. */
  function startWorkout() {
    var s = get();
    if (s.current && s.current.date === today()) return s.current;
    var done = sessionByDate(today(), s);
    var exs = done ? JSON.parse(JSON.stringify(done.exercises)) : planWorkout(s.cls, s.difficulty);
    var cur = { date: today(), start: Date.now(), active: 0, exercises: exs, round: done ? 2 : 1 };
    save({ current: cur });
    return cur;
  }
  /* I WORKED: write the running workout into today's session; returns the reward record. */
  function finishWorkout() {
    var s = get(), cur = s.current; if (!cur) return null;
    var before = game(s), lvBefore = before.level.level, bountiesBefore = before.bountyDone;
    var old = sessionByDate(cur.date, s);
    var sess = {
      date: cur.date, classId: s.cls, difficultyId: s.difficulty, areaId: s.area,
      firstMarkAt: old ? old.firstMarkAt : cur.firstMarkAt || cur.start,
      lastMarkAt: Date.now(), start: old ? old.start : cur.start,
      minutes: (old ? old.minutes || 0 : 0) + Math.max(1, Math.round((Date.now() - cur.start) / 6e4)),
      legacy: false,
      exercises: cur.exercises.map(function (e, i) {
        return { position: i, exerciseId: e.exerciseId, originalExerciseId: e.originalExerciseId, targetSets: e.targetSets, sets: e.sets || 0, added: !!e.added, removed: !!e.removed };
      })
    };
    var list = s.sessions.filter(function (x) { return x.date !== cur.date; }).concat([sess]).sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    save({ sessions: list, current: null });
    var after = game();
    var drops = after.owned.filter(function (o) { return (o.level && o.level > lvBefore) || (o.board && o.board > Math.floor(bountiesBefore / 3)); });
    var reward = {
      date: cur.date, round: old ? 2 : 1, xp: after.total - before.total,
      levelBefore: lvBefore, levelAfter: after.level.level, xpBefore: before.total,
      parts: after.byDate[cur.date], bountiesDone: after.bountyDone - bountiesBefore,
      drops: drops.map(function (o) { return o.item.id; })
    };
    save({ lastReward: reward });
    return reward;
  }

  /* A returning player with history, so any screen can be opened on its own. */
  function seedReturning() {
    var s = blank();
    s.setupDone = true;
    s.character = { sex: "female", fat: 25, muscle: 50 };
    s.bodyHistory = [{ at: Date.now() - 40 * 864e5, sex: "female", fat: 25, muscle: 50 }];
    s.cls = "scrapper"; s.difficulty = "ranger"; s.area = "rustbelt";
    s.seenSetTip = true;
    var monday = weekKey(today()), todayIdx = (dateOf(today()).getDay() + 6) % 7;
    /* [weeks back, weekday, minutes, sets per exercise] - week 2 misses the streak target, an ember covers it */
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
      s.sessions.push({ date: date, classId: s.cls, difficultyId: s.difficulty, areaId: s.area, start: start,
        firstMarkAt: start, lastMarkAt: start + p[2] * 6e4, minutes: p[2], legacy: false, exercises: exs });
    });
    /* two sessions from the old app, turned into XP (brief 4.7, rules.md: 150 each) */
    [70, 66].forEach(function (back) {
      var date = addDays(today(), -back), start = dateOf(date).getTime() + 18 * 36e5;
      s.sessions.push({ date: date, classId: null, difficultyId: null, areaId: null, start: start, firstMarkAt: start, lastMarkAt: start + 50 * 6e4, minutes: 50, legacy: true, exercises: [] });
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
  /* Where the app sends you when it opens (app-flow §1). */
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
  function sprite(el, ch, scale) {
    ch = ch || get().character; scale = scale || 3;
    var fat = snap(ch.fat), mus = snap(ch.muscle);
    var x = (fat / 25) * 52, y = ((ch.sex === "female" ? 5 : 0) + mus / 25) * 64;
    el.classList.add("sprite");
    el.style.width = 52 * scale + "px";
    el.style.height = 64 * scale + "px";
    el.style.backgroundSize = 260 * scale + "px " + 640 * scale + "px";
    el.style.backgroundPosition = -x * scale + "px " + -y * scale + "px";
    el.setAttribute("role", "img");
    el.setAttribute("aria-label", (ch.sex === "female" ? "Female" : "Male") + " lifter, fat " + fat + ", muscle " + mus);
    return el;
  }

  /* ---------- UI helpers ---------- */
  var ICONS = {
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square"><path d="M15 4 7 12l8 8"/></svg>',
    menu: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="10" y="3" width="4" height="4"/><rect x="10" y="10" width="4" height="4"/><rect x="10" y="17" width="4" height="4"/></svg>',
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square"><path d="M5 5l14 14M19 5 5 19"/></svg>',
    play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 3h3v2h3v2h3v2h3v2h1v2h-1v2h-3v2h-3v2H9v2H6z"/></svg>',
    history: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square"><path d="M4 12a8 8 0 1 0 2.4-5.7M4 4v4h4M12 8v5l3 2"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="8" y="3" width="8" height="8"/><rect x="4" y="14" width="16" height="7"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="square"><path d="m4 12 5 5L20 6"/></svg>',
    bolt: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>',
    save: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 3h13l3 3v15H4zm4 2v5h8V5zm0 9v5h8v-5z"/></svg>',
    restore: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square"><path d="M12 20V8M7 13l5-5 5 5M4 4h16"/></svg>',
    flame: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 2h2v3h2v3h2v4h1v6h-2v2h-2v2H10v-2H8v-2H6v-6h2V9h2V6h1z"/></svg>',
    gem: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 3h10l5 6-10 12L2 9z"/></svg>',
    star: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 2h4v6h8v4h-3v3h2v7h-4v-3h-2v-2h-2v2H9v3H5v-7h2v-3H4V8h6z"/></svg>',
    ember: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 3h2v2h2v2h2v4h2v6h-2v2h-2v2H9v-2H7v-2H5v-6h2V9h2V5h2z"/><rect x="11" y="13" width="2" height="4" fill="#0b0414" opacity=".5"/></svg>',
    swap: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 7h11V4h2v2h2v2h2v2h-2v2h-2v2h-2v-3H4zM20 17H9v3H7v-2H5v-2H3v-2h2v-2h2v-2h2v3h11z"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z"/></svg>',
    skip: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 4h3v2h2v2h2v2h2v4h-2v2H8v2H6v2H3zM12 4h3v2h2v2h2v2h2v4h-2v2h-2v2h-2v2h-3z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 2h6v2h6v3H3V4h6zM5 8h14v14H5zm4 3v8h2v-8zm4 0v8h2v-8z" fill-rule="evenodd"/></svg>',
    undo: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 3h2v4h6v2h2v2h2v8h-3v-7h-1V9h-6v4H8v-2H6V9H4V7h2V5h2z"/></svg>'
  };
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

  /* Freeze-frame stencil slam (class pick, difficulty pick, level up, reward). Resolves when closed. */
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

  function fmtClock(ms) {
    var t = Math.max(0, Math.floor(ms / 1000)), h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
    return (h ? h + ":" + String(m).padStart(2, "0") : String(m).padStart(2, "0")) + ":" + String(s).padStart(2, "0");
  }
  function fmtMinutes(min) { var h = Math.floor(min / 60), m = min % 60; return (h ? h + "H " : "") + m + "M"; }
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
    bar.querySelector('[data-act="reset"]').onclick = function () { reset(); go("preloader"); };
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
    startWorkout: startWorkout, finishWorkout: finishWorkout, c: c,
    screen: screen, go: go, homeId: homeId, editMode: editMode, require: require,
    sprite: sprite, snap: snap, icon: icon, gems: gems, stars: stars, toast: toast, slam: slam, press: press, swipe: swipe,
    fmtClock: fmtClock, fmtMinutes: fmtMinutes, fmtDate: fmtDate, applySettings: applySettings
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
