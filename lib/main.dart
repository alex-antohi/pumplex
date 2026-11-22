import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'files.dart';
import 'game/content.dart';
import 'game/model.dart';
import 'game/rules.dart';
import 'pumplex.dart';
import 'store.dart';
import 'views/intro.dart';
import 'views/profile.dart';
import 'views/scene.dart';
import 'views/setup.dart';
import 'views/sprite.dart';
import 'views/workout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
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
    Scene.create => Rect.fromLTWH(0, 8, w, h * 0.42),
    Scene.classSelect => classLayout(a, bottomInset, buttons: buttons).stage,
    Scene.area => areaLayout(a, bottomInset, buttons: buttons).stage,
    Scene.summary => Rect.fromLTWH(0, 10, w, h * 0.40),
    Scene.migrate => Rect.fromLTWH(0, 10, w, h * 0.34),
    Scene.workout => workoutStage(a, bottomInset),
  };
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
    _life = AppLifecycleListener(onResume: _checkSession);
    _store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
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

  /// One session per calendar day: on open, a new day shows a new workout.
  void _checkSession() {
    if (mounted) setState(() {});
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
      if (mounted) _snack('COULD NOT SAVE: ${e.message}. YOUR OLD DATA IS SAFE.');
      return;
    }
    if (!mounted) return;
    if (!saved) {
      _snack('NO BACKUP, NO UPGRADE. YOUR OLD DATA IS SAFE.');
      return;
    }
    await _store.migrateOld();
    if (mounted) _go(_startScene);
  }

  /// The creator's head looks are open (the camera is on the head).
  bool _head = false;

  /// The lifter profile is open: the workout is minimised (D50).
  bool _lifter = false;

  /// Which part of the lifter profile has the space (D53): lifter = the
  /// editor (the last session is a tile beside the arena); sessions = the
  /// sessions card (the lifter is a tile). none = the profile is closed.
  _Focus _focus = _Focus.none;

  /// The property the lifter editor shows: 0 body, 1 class and difficulty,
  /// 2 area (the setup screens, D51). Swipe up / down to change it (D53).
  int _prop = 0;

  /// The session the sessions card shows (0 = the newest).
  int _sessionIndex = 0;

  /// Opens the lifter profile: the workout shrinks (D50).
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

  /// 1: the next property comes in from below (swipe up), -1: from above.
  int _propDir = 1;

  /// Where and when a finger went down on the lifter editor.
  Offset? _swipeFrom;
  Duration _swipeAt = Duration.zero;

  /// Swipe up (next) or down (before) on the lifter editor: the next
  /// property, round and round (D53). Read from the raw pointer, so it works
  /// over the screens' own lists and sliders: a quick, mostly vertical move.
  void _swipeEnd(PointerUpEvent e) {
    final from = _swipeFrom;
    _swipeFrom = null;
    if (from == null) return;
    final d = e.position - from;
    final quick = e.timeStamp - _swipeAt < const Duration(milliseconds: 700);
    if (!quick || d.dy.abs() < 80 || d.dy.abs() < d.dx.abs() * 2) return;
    setState(() {
      _focus = _Focus.lifter;
      _head = false;
      _propDir = d.dy < 0 ? 1 : -1;
      _prop = (_prop + _propDir) % 3; // round and round: AREA -> BODY, BODY -> AREA
    });
  }

  /// Saves the draft as the profile (the lifter editor saves every change).
  void _saveDraft() => _store.setProfile(Profile(
        character: _char,
        classId: _classId,
        difficultyId: _difficultyId,
        areaId: _areaId,
      ));

  /// The minimised workout at the top left, in a view of [size]: a square,
  /// the arena only (D52). Tile [i] of the top row: 0 the arena, 1 the
  /// lifter card, 2 the last session.
  static Rect _tileRect(Size size, int i) {
    final side = (size.width - 16 - 22 - 2 * 10) / 3;
    return Rect.fromLTWH(16 + i * (side + 10), 10, side, side);
  }

  /// The lifter editor (D51): the setup screen of [_prop] in a box of
  /// [size], without BACK / NEXT. Every change saves at once (a slider
  /// when it is let go).
  Widget _editor(Size size, double inset) {
    final scene = _setupSteps[_prop];
    final stage = stageRect(scene, size, bottomInset: inset, buttons: false);
    final view = switch (scene) {
      Scene.create => CreateView(
          stage: stage,
          character: _char,
          buttons: false,
          onCharacter: (c) {
            final tapped = c.sex != _char.sex || c.skin != _char.skin || c.hair != _char.hair || c.facialHair != _char.facialHair;
            setState(() => _char = c);
            if (tapped) _saveDraft();
          },
          onSlideEnd: _saveDraft,
          onNext: () {},
          headOpen: _head,
          onHead: (open) => setState(() => _head = open),
        ),
      Scene.classSelect => ClassView(
          stage: stage,
          classId: _classId,
          difficultyId: _difficultyId,
          editing: true,
          buttons: false,
          onPick: (id) {
            setState(() => _classId = id);
            _saveDraft();
          },
          onDifficulty: (id) {
            setState(() => _difficultyId = id);
            _saveDraft();
          },
          onBack: () {},
          onNext: () {},
        ),
      _ => AreaView(
          stage: stage,
          areaId: _areaId,
          classId: _classId,
          editing: true,
          buttons: false,
          onPick: (id) {
            setState(() => _areaId = id);
            _saveDraft();
          },
          onBack: () {},
          onNext: () {},
        ),
    };
    return Stack(
      key: ValueKey('lifter-edit-$_prop'),
      children: [
        Positioned.fill(child: view),
        // Which property: body, class, area (swipe up / down).
        Positioned(
          right: 4,
          top: 4,
          child: IgnorePointer(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    key: ValueKey('prop-dot-$i'),
                    width: 10,
                    height: i == _prop ? 22 : 10,
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: i == _prop ? Pal.of(context).lime : Pal.of(context).panel2,
                      border: Border.all(color: Pal.of(context).ink, width: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The screen's own lifter (the small workout window has its own).
        Positioned.fromRect(
          rect: stage,
          child: IgnorePointer(
            child: CharacterSprite(
              key: const ValueKey('edit-lifter'),
              character: _char,
              classId: _classId,
              pedestal: scene != Scene.area,
              zoomHead: scene == Scene.create && _head,
            ),
          ),
        ),
      ],
    );
  }
  /// Under the minimised workout (D53).
  Widget _lifterRegion(Size size, double inset) {
    Widget sessions() => SessionsCard(
          store: _store,
          index: _sessionIndex,
          onIndex: (i) => setState(() => _sessionIndex = i),
        );
    switch (_focus) {
      case _Focus.sessions:
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 22, 14 + inset),
          child: SingleChildScrollView(child: sessions()),
        );
      case _Focus.lifter:
      case _Focus.none:
        return Listener(
          key: const ValueKey('lifter-editor'),
          onPointerDown: (e) {
            _swipeFrom = e.position;
            _swipeAt = e.timeStamp;
          },
          onPointerUp: _swipeEnd,
          // A vertical carousel: the next property slides in from the swipe side.
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(children: [...previous, ?current]),
              transitionBuilder: (child, anim) {
                final incoming = child.key == ValueKey('prop-$_prop');
                return SlideTransition(
                  position: Tween(
                    begin: Offset(0, incoming ? _propDir.toDouble() : -_propDir.toDouble()),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey('prop-$_prop'),
                child: LayoutBuilder(builder: (context, box) => _editor(box.biggest, inset)),
              ),
            ),
          ),
        );
    }
  }



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
    _store.setProfile(Profile(
      character: _char,
      classId: _classId,
      difficultyId: _difficultyId,
      areaId: _areaId,
    ));
    final first = !_editing;
    _editing = false;
    _go(Scene.workout);
    if (first) {
      celebratePr(
        context,
        id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
        title: "LET'S\nGO!!!",
        exercise: classById(_classId).name,
        big: 'LVL ${levelFor(_store.totalXp).level}',
        sub: _legacyXp > 0 ? 'OLD SAVES: +$_legacyXp XP (BETA).' : 'THE BAR IS WAITING.',
      );
    }
  }

  int get _legacyXp =>
      _store.xpEvents.where((e) => e.source == 'legacy').fold(0, (a, e) => a + e.amount);

  /// The setup steps a summary or profile EDIT opens (0 body, 1 class,
  /// 2 difficulty, 3 area).
  static const _setupSteps = [Scene.create, Scene.classSelect, Scene.area];

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

  void _addSet(int i) {
    final before = levelFor(_store.totalXp).level;
    _store.addSet(i);
    final crit = _store.lastSetCritical(i);
    if (crit) {
      HapticFeedback.heavyImpact();
      _snack('CRITICAL SET!!! ×$critMultiplier XP');
    }
    final after = levelFor(_store.totalXp).level;
    if (after > before) {
      HapticFeedback.heavyImpact();
      _showIntro((
        title: 'LEVEL $after',
        subtitle: levelUpLines[after % levelUpLines.length],
        color: Pal.of(context).pink,
      ));
    }
    setState(() {});
  }

  void _removeSet(int i) => _store.removeSet(i);

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
      Scene.migrate => 'OLD SAVE · ONE-TIME UPGRADE',
      Scene.create => 'CHARACTER · STEP 1 OF 4',
      Scene.classSelect => 'CLASS · STEP 2 OF 4',
      Scene.area => 'STARTING AREA · STEP 3 OF 4',
      Scene.summary => 'READY? · STEP 4 OF 4',
      Scene.workout => 'WORKOUT · ${_store.todaySession?.totalSets ?? 0} SETS · LVL $l',
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
        // lifter profile first, D50).
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
            onEdit: (step) => _go(_setupSteps[step], Motion.zoomOut),
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

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // In setup the character shows the draft; in play, the saved profile.
    final profile = _store.profile;
    final char = _inSetup || profile == null ? _char : profile.character;
    final classId = _inSetup || profile == null ? _classId : profile.classId;
    // The phone's back button leaves the app, everywhere (D51).
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
                  // Tap it for the lifter profile (D50).
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
                    // The lifter profile (D50): the workout and the lifter shrink
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
                                    child: LayoutBuilder(
                                      builder: (context, region) => AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        layoutBuilder: (current, previous) => Stack(
                                          alignment: Alignment.topCenter,
                                          children: [...previous, ?current],
                                        ),
                                        child: KeyedSubtree(
                                          key: ValueKey(_focus),
                                          child: _lifterRegion(region.biggest, inset),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: ClipRect(
                                clipper: _WindowClip(window),
                                child: Stack(
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
                            // The one character, shared by every scene.
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
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                                  ],
                                ),
                              ),
                            ),
                            // Beside the arena (D53): the part that gave up its
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
                            // The minimised workout window: tap it to go back.
                            if (t > 0)
                              Positioned.fromRect(
                                rect: window.inflate(2),
                                child: GestureDetector(
                                  key: const ValueKey('mini-workout'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _lifter ? _closeLifter : null,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: p.ink.withValues(alpha: t), width: 3),
                                    ),
                                  ),
                                ),
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
                const MegaText('PUMPLEX™', size: 30),
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
          Text('LVL ${l.level}', style: display(16, p.pink)),
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

/// Clips to the minimised workout window while it shrinks (D52).
class _WindowClip extends CustomClipper<Rect> {
  _WindowClip(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_WindowClip old) => old.rect != rect;
}

/// Which part of the lifter profile has the space (D53).
enum _Focus { none, lifter, sessions }
