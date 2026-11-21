/* PUMPLEX demo: shared data, state and helpers.
   Every screen loads this file before its own script. Everything hangs off window.PX.
   State lives in localStorage so the demo flows across pages like one app. */
(function () {
  "use strict";

  var KEY = "pumplex-demo-v1";

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

  /* ---------- game data (proposals from docs/moodboard/README.md) ---------- */
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

  /* Fantasy-named difficulty levels, beginner to expert (brief 4.3). Our own names, Borderlands tone. */
  var DIFFICULTIES = [
    { id: "larva",    name: "Couch Larva",       line: "Never lifted. The remote counts as cardio.",        mult: 1.0,  color: "muted" },
    { id: "noodle",   name: "Noodle Squire",     line: "Tried a gym once. It was loud.",                    mult: 1.1,  color: "muted" },
    { id: "curious",  name: "Iron Curious",      line: "A few months in. Knows where the rack lives.",      mult: 1.25, color: "lime" },
    { id: "bandit",   name: "Rep Bandit",        line: "Trains most weeks. Has opinions about shoes.",      mult: 1.4,  color: "sky" },
    { id: "knight",   name: "Chalk Knight",      line: "A year or two. Owns a belt and uses it.",           mult: 1.6,  color: "violet" },
    { id: "warlord",  name: "Plate Warlord",     line: "Years of lifting. Grunts with purpose.",            mult: 1.8,  color: "violet" },
    { id: "titan",    name: "Gym Titan",         line: "Many years. Other lifters ask you for form tips.",  mult: 2.0,  color: "orange" },
    { id: "prime",    name: "Swolemancer Prime", line: "Beyond reason. The weights are scared of you.",     mult: 2.25, color: "pink" }
  ];

  /* Starting areas (moodboard "Starting areas"). */
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

  /* Preset workouts per class (placeholder: brief §8 says the lists come later). */
  var WORKOUTS = {
    scrapper:    [{ name: "Push-ups", target: 3 }, { name: "Burpees", target: 3 }, { name: "Sprints", target: 3 }],
    bruiser:     [{ name: "Goblet squats", target: 3 }, { name: "Dumbbell rows", target: 3 }, { name: "KB swings", target: 3 }],
    paladin:     [{ name: "Back squats", target: 4 }, { name: "Bench press", target: 3 }, { name: "Deadlifts", target: 3 }],
    cablemancer: [{ name: "Leg press", target: 3 }, { name: "Lat pulldown", target: 3 }, { name: "Cable rows", target: 3 }]
  };

  /* Level titles shown on level-up and in the profile. */
  var LEVEL_TITLES = ["Fresh Spawn", "Sweat Rookie", "Rep Goblin", "Pump Raider", "Iron Ronin", "Gain Lord", "Mythic Meathead"];

  /* ---------- XP rules (placeholder: brief 4.8 says progress is still open) ---------- */
  var XP_PER_SET = 10;
  function xpForSets(sets, difficultyId) {
    var d = difficulty(difficultyId) || DIFFICULTIES[0];
    return Math.round(sets * XP_PER_SET * d.mult);
  }
  /* total XP needed to reach level L (level 1 = 0 XP) */
  function xpToReach(L) { return 50 * L * (L - 1); }
  function levelInfo(totalXp) {
    var L = 1;
    while (totalXp >= xpToReach(L + 1)) L++;
    var from = xpToReach(L), to = xpToReach(L + 1);
    return {
      level: L,
      title: LEVEL_TITLES[Math.min(L - 1, LEVEL_TITLES.length - 1)],
      into: totalXp - from,
      span: to - from,
      toNext: to - totalXp,
      pct: Math.round(100 * (totalXp - from) / (to - from))
    };
  }

  /* ---------- state ---------- */
  function blank() {
    return {
      setupDone: false,
      character: { sex: "male", fat: 50, muscle: 50 },
      cls: null,
      difficulty: null,
      area: null,
      xp: 0,
      sessions: [],        // [{id, start, end, cls, area, sets: {name: n}, xp}]
      current: null,       // {start, active, sets: {name: n}} while a workout runs
      lastReward: null,    // {sessionId, xp, levelBefore, levelAfter}
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
    try { localStorage.setItem(KEY, JSON.stringify(s)); } catch (e) {}
    return s;
  }
  function reset() { mem = blank(); try { localStorage.removeItem(KEY); } catch (e) {} return mem; }

  /* A returning player with history, so any screen can be opened on its own. */
  function seedReturning() {
    var s = blank();
    s.setupDone = true;
    s.character = { sex: "female", fat: 25, muscle: 50 };
    s.cls = "scrapper"; s.difficulty = "curious"; s.area = "rustbelt";
    s.seenSetTip = true;
    var now = Date.now(), day = 864e5, list = WORKOUTS.scrapper;
    var plan = [[13, 41, [3, 3, 3]], [11, 36, [3, 2, 3]], [8, 44, [4, 3, 3]], [6, 29, [2, 2, 1]], [3, 38, [3, 3, 4]], [1, 47, [3, 4, 3]]];
    plan.forEach(function (p, i) {
      var start = now - p[0] * day - 18 * 36e5, sets = {}, n = 0;
      list.forEach(function (ex, j) { sets[ex.name] = p[2][j]; n += p[2][j]; });
      var xp = xpForSets(n, s.difficulty);
      s.sessions.push({ id: "s" + (i + 1), start: start, end: start + p[1] * 6e4, cls: s.cls, area: s.area, sets: sets, xp: xp });
      s.xp += xp;
    });
    mem = s; save();
    return s;
  }

  /* ---------- lookups ---------- */
  function cls(id) { return CLASSES[id || get().cls] || null; }
  function area(id) { return AREAS[id || get().area] || null; }
  function difficulty(id) {
    id = id || get().difficulty;
    for (var i = 0; i < DIFFICULTIES.length; i++) if (DIFFICULTIES[i].id === id) return DIFFICULTIES[i];
    return null;
  }
  function workout(clsId) { return WORKOUTS[clsId || get().cls] || WORKOUTS.scrapper; }
  /* CSS colour value for a neon name: c("lime") -> "var(--lime)", c("lime", "hi") -> "var(--lime-hi)" */
  function c(name, tone) { return "var(--" + (name || "lime") + (tone ? "-" + tone : "") + ")"; }

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

  /* Send the visitor back into the flow when a screen is opened without the state it needs. */
  function require(fields, fallback) {
    var s = get();
    for (var i = 0; i < fields.length; i++) if (!s[fields[i]]) { go(fallback || "character", { replace: true }); return false; }
    return true;
  }

  /* ---------- character sprite ---------- */
  function snap(v) { return Math.max(0, Math.min(100, Math.round(v / 25) * 25)); }
  /* Paint an atlas cell on el at a whole-number scale. char = {sex, fat, muscle} (0-100). */
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
    flame: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 2h2v3h2v3h2v4h1v6h-2v2h-2v2H10v-2H8v-2H6v-6h2V9h2V6h1z"/></svg>'
  };
  function icon(name) { return ICONS[name] || ""; }

  var toastTimer = null;
  /* Show a toast inside the phone. opts: {action: "UNDO", onAction: fn, ms: 6000} */
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

  /* Freeze-frame stencil slam (class pick, level up, reward). Resolves when closed. */
  function slam(opts) {
    opts = opts || {};
    return new Promise(function (resolve) {
      var phone = document.querySelector(".phone") || document.body;
      var f = document.createElement("div");
      f.className = "freeze"; f.setAttribute("role", "dialog"); f.setAttribute("aria-label", opts.name || "");
      f.style.setProperty("--slam-c", c(opts.color || "lime"));
      var tag = document.createElement("div"); tag.className = "slam-tag"; tag.textContent = opts.name || "";
      f.appendChild(tag);
      if (opts.sub) { var s = document.createElement("div"); s.className = "slam-sub"; s.textContent = opts.sub; f.appendChild(s); }
      var done = false;
      function close() { if (done) return; done = true; f.remove(); resolve(); }
      f.addEventListener("click", close);
      phone.appendChild(f);
      setTimeout(close, opts.ms || 1800);
    });
  }

  function fmtClock(ms) {
    var t = Math.max(0, Math.floor(ms / 1000)), h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
    return (h ? h + ":" + String(m).padStart(2, "0") : String(m).padStart(2, "0")) + ":" + String(s).padStart(2, "0");
  }
  function fmtDate(ts) {
    return new Date(ts).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).toUpperCase();
  }
  function totalSets(sets) { var n = 0; for (var k in sets) n += sets[k] || 0; return n; }

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

  /* ---------- demo chrome: a small bar outside the phone (desktop only) ---------- */
  function demoBar() {
    if (document.querySelector(".demo-bar")) return;
    var here = (location.pathname.split("/").pop() || "").toLowerCase();
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

  /* ?demo=returning seeds a finished profile, ?demo=new wipes state. For screenshots and tests. */
  (function () {
    var m = /[?&]demo=(returning|new)\b/.exec(location.search);
    if (m) { if (m[1] === "returning") seedReturning(); else reset(); }
  })();

  applySettings();
  document.addEventListener("DOMContentLoaded", function () { if (!document.body.classList.contains("idx")) demoBar(); });

  window.PX = {
    SCREENS: SCREENS, SETUP_STEPS: SETUP_STEPS,
    CLASSES: CLASSES, CLASS_ORDER: CLASS_ORDER, DIFFICULTIES: DIFFICULTIES,
    AREAS: AREAS, AREA_ORDER: AREA_ORDER, WORKOUTS: WORKOUTS, LEVEL_TITLES: LEVEL_TITLES,
    XP_PER_SET: XP_PER_SET, xpForSets: xpForSets, xpToReach: xpToReach, levelInfo: levelInfo,
    get: get, save: save, reset: reset, seedReturning: seedReturning,
    cls: cls, area: area, difficulty: difficulty, workout: workout, c: c,
    screen: screen, go: go, homeId: homeId, require: require,
    sprite: sprite, snap: snap, icon: icon, toast: toast, slam: slam, press: press,
    fmtClock: fmtClock, fmtDate: fmtDate, totalSets: totalSets, applySettings: applySettings
  };
})();
