import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'files.dart';
import 'game/content.dart';
import 'game/exercises.dart';
import 'game/model.dart';
import 'game/rules.dart';
import 'i18n.dart';
import 'pumplex.dart';
import 'store.dart';
import 'views/intro.dart';
import 'views/lifter_editor.dart';
import 'views/profile.dart';
import 'views/scene.dart';
import 'views/setup.dart';
import 'views/sprite.dart';
import 'views/stage.dart';
import 'views/workout.dart';
import 'views/workout_layout.dart';

export 'views/stage.dart' show Scene, stageRect;

/// The phone's bars are hidden (D81): immersive sticky, so a swipe from an
/// edge shows them for a moment and the back gesture still works. Both the
/// navigation bar and the status bar go (Android has no sticky mode for one
/// bar only). Set at start and again on every resume.
void hideSystemBars() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  hideSystemBars();
  final prefs = await SharedPreferences.getInstance();
  await I18n.instance.load(prefs);
  exerciseCatalog = await ExerciseCatalog.load();
  runApp(GymApp(store: LogStore(prefs)));
}

class GymApp extends StatelessWidget {
  const GymApp({super.key, required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PUMPLEX',
      debugShowCheckedModeBanner: false,
      theme: pumplexTheme(Brightness.light),
      darkTheme: pumplexTheme(Brightness.dark),
      home: GameShell(store: store),
    );
  }
}

/// The whole app is this one screen. Views change with a camera move
/// (SceneSwitcher) and the character moves with them. No routes are pushed,
/// so nothing ever flashes blank.
class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.store});

  final LogStore store;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  LogStore get _store => widget.store;

  late Scene _scene = _openingScene;
  Motion _motion = Motion.zoomIn;

  /// The upgrade scene while old data is on the phone, else [_startScene].
  Scene get _openingScene => _store.hasOldData ? Scene.migrate : _startScene;

  Scene get _startScene => _store.profile == null ? Scene.create : Scene.workout;

  // Setup draft (the profile is only saved on LET'S GO).
  late Character _char;
  late String _classId, _difficultyId, _areaId;
  bool _editing = false;
  bool _areaPicked = false;

  late final AppLifecycleListener _life;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _resetDraft();
    _life = AppLifecycleListener(onResume: () {
      hideSystemBars(); // the phone may show its bars again while away (D81)
      _onStore(); // one session per calendar day: a new day shows a new workout
    });
    _store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final a in allSpriteAssets) {
      precacheImage(AssetImage(a), context);
    }
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _life.dispose();
    super.dispose();
  }

  void _resetDraft() {
    final p = _store.profile;
    _char = p?.character ?? const Character();
    _classId = classById(p?.classId).id;
    _difficultyId = difficulties[difficultyIndex(p?.difficultyId)].id;
    _areaId = p == null ? defaultAreaFor(_classId).id : areaById(p.areaId).id;
    _areaPicked = p != null;
  }

  /// The one-time migration: backup file first, or nothing changes.
  Future<void> _upgrade() async {
    bool saved;
    try {
      saved = await saveTextFile(
        name: 'pumplex_old_data_${dateKey(DateTime.now())}.json',
        mime: 'application/json',
        content: _store.oldBackupJson(),
      );
    } on PlatformException catch (e) {
      if (mounted) _snack(t('migrate.saveFailed', {'error': e.message}));
      return;
    }
    if (!mounted) return;
    if (!saved) {
      _snack(t('migrate.noBackup'));
      return;
    }
    await _store.migrateOld();
    if (mounted) _go(_startScene);
  }

  /// SAVE BACKUP: the backup file (every key of docs/data-schema.md §4).
  Future<void> _saveBackup() async {
    try {
      final saved = await saveTextFile(
        name: 'pumplex_backup_${dateKey(DateTime.now())}.json',
        mime: 'application/json',
        content: _store.backupJson(),
      );
      if (mounted) _snack(t(saved ? 'backup.saved' : 'backup.notSaved'));
    } on PlatformException catch (e) {
      if (mounted) _snack(t('backup.saveFailed', {'error': e.message}));
    }
  }

  /// LOAD BACKUP: a confirm, then [LogStore.importBackup] replaces the data
  /// (only sessions and XP for a file with no profile).
  Future<void> _loadBackup() async {
    String? raw;
    try {
      raw = await openTextFile();
    } on PlatformException catch (e) {
      if (mounted) _snack(t('backup.loadFailed', {'error': e.message}));
      return;
    }
    if (!mounted) return;
    if (raw == null) {
      _snack(t('backup.noFile'));
      return;
    }
    Object? data;
    try {
      data = jsonDecode(raw.startsWith(bom) ? raw.substring(1) : raw);
    } on FormatException {
      data = null;
    }
    if (data is! Map || data['app'] != 'pumplex' || ![2, 3, 4, 5, 6, 7].contains(data['version'])) {
      _snack(t('backup.notBackup'));
      return;
    }
    final ok = await confirmReplaceBackup(context, keepsProfile: LogStore.backupKeepsProfile(data));
    if (ok != true || !mounted) return;
    try {
      await _store.importBackup(jsonEncode(data));
    } catch (e) {
      if (mounted) _snack(t('backup.loadFailed', {'error': e is FormatException ? e.message : '$e'}));
      return;
    }
    if (!mounted) return;
    _snack(t('backup.loaded'));
    setState(() {
      _resetDraft();
      _sessionIndex = 0;
    });
    if (_store.profile == null) _go(_startScene);
  }

  /// The creator's head looks are open (the camera is on the head).
  bool _head = false;

  /// The lifter profile is open: the workout is minimised (D59).
  bool _lifter = false;

  /// Which part of the lifter profile has the space (D62): lifter = the
  /// editor (the last session is a tile beside the arena); sessions = the
  /// sessions card (the lifter is a tile). none = the profile is closed.
  _Focus _focus = _Focus.none;

  /// The property the lifter editor shows, in [lifterProps]: 0 body, 1 class
  /// and difficulty, 2 area (the setup screens, D60). Swipe up for the next,
  /// down for the one before, round and round (D62, D63).
  int _prop = 0;

  /// The session the sessions card shows (0 = the newest).
  int _sessionIndex = 0;

  /// Opens the lifter profile: the workout shrinks (D59).
  void _openLifter() => setState(() {
        _resetDraft();
        _lifter = true;
        _focus = _Focus.lifter;
        _prop = 0;
        _sessionIndex = 0;
        _head = false;
      });

  /// Back to the full-screen workout.
  void _closeLifter() => setState(() {
        _lifter = false;
        _focus = _Focus.none;
        _head = false;
      });

  /// Saves the draft as the profile (the lifter editor saves every change).
  void _saveDraft() => _store.setProfile(Profile(
        character: _char,
        classId: _classId,
        difficultyId: _difficultyId,
        areaId: _areaId,
      ));

  /// The minimised workout at the top left, in a view of [size]: a square,
  /// the arena only (D61). Tile [i] of the top row: 0 the arena, 1 the
  /// lifter card, 2 the last session.
  static Rect _tileRect(Size size, int i) {
    final side = (size.width - 16 - 22 - 2 * 10) / 3;
    return Rect.fromLTWH(16 + i * (side + 10), 10, side, side);
  }

  /// The lifter editor (D60) for property [prop]: every change saves.
  Widget _editor(double inset, int prop) => LifterEditor(
        prop: prop,
        inset: inset,
        character: _char,
        classId: _classId,
        difficultyId: _difficultyId,
        areaId: _areaId,
        headOpen: _head,
        onCharacter: (c) => setState(() => _char = c),
        onSave: _saveDraft,
        onHead: (open) => setState(() => _head = open),
        onClass: (id) {
          setState(() => _classId = id);
          _saveDraft();
        },
        onDifficulty: (id) {
          setState(() => _difficultyId = id);
          _saveDraft();
        },
        onArea: (id) {
          setState(() => _areaId = id);
          _saveDraft();
        },
      );

  /// Under the minimised workout (D62).
  Widget _lifterPanel(double inset) => LifterPanel(
        store: _store,
        sessions: _focus == _Focus.sessions,
        sessionIndex: _sessionIndex,
        onSessionIndex: (i) => setState(() => _sessionIndex = i),
        prop: _prop,
        onProp: (i) => setState(() {
          _prop = i;
          _head = false;
        }),
        inset: inset,
        editor: (i) => _editor(inset, i),
      );

  void _go(Scene to, [Motion motion = Motion.zoomIn]) {
    if (to == _scene) return;
    setState(() {
      _head = false;
      _lifter = false;
      _focus = _Focus.none;
      _scene = to;
      _motion = motion;
      _intro = null;
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));

  // ------------------------------------------------------------------ setup

  void _finishSetup() {
    _saveDraft();
    final first = !_editing;
    _editing = false;
    _go(Scene.workout);
    if (first) {
      celebratePr(
        context,
        id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
        title: t('burst.go'),
      );
    }
  }

  void _pickClass(String id) {
    setState(() {
      _classId = id;
      // The class picks the default area, until the player picks one.
      if (!_areaPicked) _areaId = defaultAreaFor(id).id;
    });
    // No freeze-frame intro card on the class carousel (D46).
  }

  /// The difficulty slider on the class step (D47): no freeze-frame card.
  void _pickDifficulty(String id) => setState(() => _difficultyId = id);

  // ---------------------------------------------------------------- workout

  void _addSet(String id) {
    final before = levelFor(_store.totalXp).level;
    _store.addSet(id);
    final crit = _store.lastSetCritical(id);
    if (crit) {
      HapticFeedback.heavyImpact();
      _snack(t('workout.critical', {'n': critMultiplier}));
    }
    final after = levelFor(_store.totalXp).level;
    if (after > before) {
      HapticFeedback.heavyImpact();
      _showIntro((
        title: t('level.up', {'n': after}),
        subtitle: '', // only LEVEL n
        color: Pal.of(context).pink,
      ));
    }
    setState(() {});
  }

  void _removeSet(String id) => _store.removeSet(id);

  // ------------------------------------------------------- freeze-frame card

  IntroSpec? _intro;
  int _introRun = 0; // a new pick restarts the card

  void _showIntro(IntroSpec spec) => setState(() {
        _intro = spec;
        _introRun++;
      });

  Widget _introCard() => IntroCard(
        key: ValueKey(_introRun),
        spec: _intro!,
        onDone: () => setState(() => _intro = null),
      );

  // ------------------------------------------------------------------ build

  String get _info {
    final l = levelFor(_store.totalXp).level;
    return switch (_scene) {
      Scene.migrate => t('bar.migrate'),
      Scene.create => t('bar.create'),
      Scene.classSelect => t('bar.class'),
      Scene.area => t('bar.area'),
      Scene.summary => t('bar.summary'),
      Scene.workout => t('bar.workout', {'sets': tn('sets', _store.todaySession?.totalSets ?? 0), 'level': l}),
    };
  }

  /// Android back: one step back in the flow, never out of the app mid-flow.
  Scene? get _backTo => switch (_scene) {
        Scene.migrate => null,
        Scene.create => _editing ? Scene.workout : null,
        Scene.classSelect => Scene.create,
        Scene.area => Scene.classSelect,
        Scene.summary => Scene.area,
        // The workout is home (D49): back leaves the app (or closes the
        // lifter profile first, D59).
        Scene.workout => null,
      };

  void _back() {
    if (_head) return setState(() => _head = false);
    final to = _backTo;
    if (to == null) return;
    if (_scene == Scene.create) _editing = false;
    _go(to, Motion.zoomOut);
  }

  Widget _view(Scene s, Rect stage) => switch (s) {
        Scene.migrate => MigrateView(
            stage: stage,
            oldWorkouts: _store.oldWorkoutCount,
            onUpgrade: _upgrade,
            onLater: () => _go(_startScene),
          ),
        Scene.create => CreateView(
            stage: stage,
            character: _char,
            onCharacter: (c) => setState(() => _char = c),
            onNext: () => _go(_editing ? Scene.summary : Scene.classSelect),
            headOpen: _head,
            onHead: (open) => setState(() => _head = open),
          ),
        Scene.classSelect => ClassView(
            stage: stage,
            classId: _classId,
            difficultyId: _difficultyId,
            editing: _editing,
            onPick: _pickClass,
            onDifficulty: _pickDifficulty,
            onBack: _back,
            onNext: () => _go(_editing ? Scene.summary : Scene.area),
          ),
        Scene.area => AreaView(
            stage: stage,
            areaId: _areaId,
            classId: _classId,
            editing: _editing,
            onPick: (id) => setState(() {
              _areaId = id;
              _areaPicked = true;
            }),
            onBack: _back,
            onNext: () => _go(Scene.summary),
          ),
        Scene.summary => SummaryView(
            stage: stage,
            classId: _classId,
            difficultyId: _difficultyId,
            areaId: _areaId,
            editing: _editing,
            onEdit: (step) => _go(lifterProps[step], Motion.zoomOut),
            onBack: _back,
            onGo: _finishSetup,
          ),
        Scene.workout => WorkoutView(
            stage: stage,
            store: _store,
            onAdd: _addSet,
            onRemove: _removeSet,
            onBody: _openLifter,
          ),
      };

  static bool _isSetupScene(Scene s) => s.index <= Scene.summary.index;

  bool get _inSetup => _isSetupScene(_scene);

  /// The scene and the one character, shared by every scene; [shrink]
  /// moves both into the minimised window (D61).
  Widget _world(Matrix4 shrink, Rect stage, Character char, String classId, double? pixelScale) => Stack(
        children: [
          Positioned.fill(
            child: Transform(
              transform: shrink,
              child: IgnorePointer(
                ignoring: _lifter,
                child: SceneSwitcher(
                  scene: _scene,
                  motion: _motion,
                  child: _view(_scene, stage),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Transform(
              transform: shrink,
              child: Stack(
                children: [
                  AnimatedPositioned.fromRect(
                    rect: stage,
                    duration: const Duration(milliseconds: 560),
                    curve: Curves.easeInOutCubic,
                    child: IgnorePointer(
                      // Frozen in greyscale while the intro card shows.
                      child: ColorFiltered(
                        colorFilter: _intro == null
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                            : freezeFilter,
                        child: CharacterSprite(
                          character: char,
                          classId: classId,
                          // In an area scene the scene has its own ground.
                          pedestal: _scene != Scene.workout && _scene != Scene.area,
                          zoomHead: _scene == Scene.create && _head,
                          pixelScale: pixelScale,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // In setup the character shows the draft; in play, the saved profile.
    final profile = _store.profile;
    final char = _inSetup || profile == null ? _char : profile.character;
    final classId = _inSetup || profile == null ? _classId : profile.classId;
    // The phone's back button leaves the app, everywhere (D60).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DotBackground(
          child: Column(
            children: [
              // The phone status bar sits on the dark strip.
              Container(
                color: kNight,
                child: const SafeArea(bottom: false, child: SizedBox(width: double.infinity)),
              ),
              _TopBar(
                info: _info,
                // On the workout (home) the bar shows the level and XP (D49).
                // Tap it for the lifter profile (D59).
                level: _scene == Scene.workout
                    ? _TopLevel(xp: _store.totalXp, onTap: _openLifter)
                    : null,
              ),
              Container(height: 6, color: p.violet),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final inset = MediaQuery.paddingOf(context).bottom;
                  final stage = stageRect(_scene, box.biggest, bottomInset: inset);
                  final full = Offset.zero & box.biggest;
                  final mini = _tileRect(box.biggest, 0);
                  // The arena (a square of the workout) lands on the mini window.
                  final arena = workoutArena(box.biggest, inset);
                  final k = mini.width / arena.width;
                  final tiles = _focus != _Focus.none;
                  // The lifter profile (D59): the workout and the lifter shrink
                  // into a window at the top left; the profile shows under it.
                  return TweenAnimationBuilder<double>(
                    tween: Tween(end: _lifter && _scene == Scene.workout ? 1 : 0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubic,
                    builder: (context, t, _) {
                      final s = 1 + (k - 1) * t;
                      final shrink = Matrix4.translationValues(
                        (mini.left - arena.left * k) * t,
                        (mini.top - arena.top * k) * t,
                        0,
                      ).multiplied(Matrix4.diagonal3Values(s, s, 1));
                      final window = Rect.lerp(full, mini, t)!;
                      return Stack(
                        children: [
                          if (t > 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: mini.bottom + 14,
                              bottom: 0,
                              child: Opacity(
                                opacity: t,
                                child: IgnorePointer(
                                  ignoring: !_lifter,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    layoutBuilder: (current, previous) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [...previous, ?current],
                                    ),
                                    child: KeyedSubtree(
                                      key: ValueKey(_focus),
                                      child: _lifterPanel(inset),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // The minimised workout is a card (D75): its hard
                          // shadow, behind the window.
                          if (t > 0)
                            Positioned.fromRect(
                              rect: window.inflate(2).shift(const Offset(5, 5)),
                              child: ColoredBox(color: p.pink.withValues(alpha: t)),
                            ),
                          Positioned.fill(
                            child: ClipRect(
                              clipper: _WindowClip(window),
                              child: _world(shrink, stage, char, classId, _scene == Scene.area ? areaLayout(box.biggest, inset).scale : null),
                            ),
                          ),
                          // Beside the arena (D62): the part that gave up its
                          // space, as a tile. Tap it to give it the space back.
                          if (t > 0 && tiles)
                            Positioned.fromRect(
                              rect: _tileRect(box.biggest, 1),
                              child: Opacity(
                                opacity: t,
                                child: _focus == _Focus.lifter
                                    ? SessionTile(
                                        store: _store,
                                        index: _sessionIndex,
                                        onTap: () => setState(() => _focus = _Focus.sessions),
                                      )
                                    : LifterTile(store: _store, onTap: () => setState(() => _focus = _Focus.lifter)),
                              ),
                            ),
                          // The free tile space right of the last session:
                          // SAVE BACKUP and LOAD BACKUP.
                          if (t > 0 && _focus == _Focus.lifter)
                            Positioned.fromRect(
                              rect: _tileRect(box.biggest, 2),
                              child: Opacity(
                                opacity: t,
                                child: BackupButtons(onSave: _saveBackup, onLoad: _loadBackup),
                              ),
                            ),
                          // The minimised workout window: tap it to go back.
                          if (t > 0)
                            Positioned.fromRect(
                              rect: window.inflate(2),
                              child: MiniWorkoutFrame(t: t, onTap: _lifter ? _closeLifter : null),
                            ),
                          // Freeze-frame intro card: level-ups, over the whole view.
                          if (_intro != null) Positioned.fill(child: _introCard()),
                        ],
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.info, this.level});

  final String info;

  /// Shown in place of [info] (the workout's level and XP bar).
  final Widget? level;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(bottom: BorderSide(color: p.ink, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MegaText('PUMPLEX', size: 30), // no ™ (D75)
                const SizedBox(height: 5),
                // Always one line (shrinks instead of wrapping), cross-fades
                // when the scene changes.
                SizedBox(
                  height: 18,
                  width: double.infinity,
                  child: level ?? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                    child: FittedBox(
                      key: ValueKey(info),
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(info, maxLines: 1, softWrap: false, style: mono(12.5, p.ink)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12, height: 48),
        ],
      ),
    );
  }
}

/// The level and XP bar in the PUMPLEX bar on the workout (D49). Tap it to
/// open the profile.
class _TopLevel extends StatelessWidget {
  const _TopLevel({required this.xp, required this.onTap});

  final int xp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final l = levelFor(xp);
    return GestureDetector(
      key: const ValueKey('top-level'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Text(t('level.short', {'n': l.level}), style: display(16, p.pink)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(color: kNight, border: Border.all(color: p.ink, width: 2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (l.into / l.need).clamp(0.0, 1.0),
                child: Container(color: p.lime),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${l.into}/${l.need} XP', style: mono(11, p.ink)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Clips to the minimised workout window while it shrinks (D61).
class _WindowClip extends CustomClipper<Rect> {
  _WindowClip(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_WindowClip old) => old.rect != rect;
}

/// Which part of the lifter profile has the space (D62).
enum _Focus { none, lifter, sessions }
