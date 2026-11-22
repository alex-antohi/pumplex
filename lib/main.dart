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
import 'views/play.dart';
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
enum Scene { migrate, create, classSelect, difficulty, area, summary, hub, workout, history, profile, menu }

/// Where the character stands in each scene, inside the content area.
/// The views leave this rect free; the shell draws the one character there,
/// so it glides from place to place when the scene changes.
/// [bottomInset] is the phone's navigation bar, for views that keep it.
Rect stageRect(Scene s, Size a, {double bottomInset = 0}) {
  final w = a.width, h = a.height;
  return switch (s) {
    Scene.create => Rect.fromLTWH(0, 8, w, h * 0.42),
    Scene.classSelect => classLayout(a, bottomInset).stage,
    Scene.difficulty => Rect.fromLTWH(w * 0.76, 2, w * 0.2, 88),
    Scene.area => Rect.fromLTWH(12, 8, w * 0.30, h * 0.22),
    Scene.summary => Rect.fromLTWH(0, 10, w, h * 0.40),
    Scene.hub => hubStage(a),
    Scene.migrate => Rect.fromLTWH(0, 10, w, h * 0.34),
    Scene.workout => workoutStage(a),
    Scene.history => Rect.fromLTWH(w * 0.70, 6, w * 0.26, h * 0.17),
    Scene.profile => Rect.fromLTWH(w * 0.60, 8, w * 0.36, h * 0.24),
    // The menu covers the view; the character steps down out of the frame.
    Scene.menu => Rect.fromLTWH(w * 0.70, h + 20, w * 0.26, h * 0.17),
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

  Scene get _startScene => _store.profile == null ? Scene.create : Scene.hub;

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

  void _go(Scene to, [Motion motion = Motion.zoomIn]) {
    if (to == _scene) return;
    setState(() {
      _head = false;
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
    _go(Scene.hub);
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

  void _editCharacter() => _editStep(0);

  /// The setup steps a summary or profile EDIT opens (0 body, 1 class,
  /// 2 difficulty, 3 area).
  static const _setupSteps = [Scene.create, Scene.classSelect, Scene.difficulty, Scene.area];

  /// Opens one setup step to change it. NEXT leads to the summary, which
  /// saves (D13).
  void _editStep(int step) {
    _resetDraft();
    _editing = true;
    _go(_setupSteps[step], Motion.zoomOut);
  }

  void _pickClass(String id) {
    setState(() {
      _classId = id;
      // The class picks the default area, until the player picks one.
      if (!_areaPicked) _areaId = defaultAreaFor(id).id;
    });
    // No freeze-frame intro card on the class carousel (D46).
  }

  void _pickDifficulty(String id) {
    setState(() => _difficultyId = id);
    final i = difficultyIndex(id);
    _showIntro((title: difficulties[i].name, subtitle: difficulties[i].joke, color: difficultyColor(Pal.of(context), i)));
  }

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

  // ------------------------------------------------------------------- menu

  /// The scene the menu returns to.
  Scene _menuFrom = Scene.hub;

  void _openMenu() {
    if (_scene == Scene.menu) return;
    _menuFrom = _scene;
    _go(Scene.menu, Motion.slideLeft);
  }

  void _closeMenu() => _go(_menuFrom, Motion.slideRight);

  void _openHistory() => _go(Scene.history, Motion.slideRight);

  Future<void> _saveBackup() async {
    try {
      final saved = await saveTextFile(
        name: 'pumplex_backup_${dateKey(DateTime.now())}.json',
        mime: 'application/json',
        content: _store.backupJson(),
      );
      if (saved && mounted) {
        final n = _store.history.length;
        _snack('BACKUP OF $n TRAINING DAYS SAVED. GAINS: INSURED.');
      }
    } on PlatformException catch (e) {
      if (mounted) _snack('COULD NOT SAVE: ${e.message}');
    }
  }

  Future<void> _restoreBackup() async {
    String? text;
    try {
      text = await openTextFile();
    } on PlatformException catch (e) {
      if (mounted) _snack('COULD NOT OPEN: ${e.message}');
      return;
    }
    if (text == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESTORE BACKUP?'),
        content: const Text(
            'This replaces everything in the app with that file. There is no undo. There is only lifting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: display(16, Pal.of(context).ink)),
          ),
          BrutalButton(
            small: true,
            color: Pal.of(context).pink,
            onTap: () => Navigator.pop(context, true),
            child: const Text('REPLACE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _store.importBackup(text.replaceFirst(bom, ''));
    } catch (_) {
      if (mounted) _snack('THAT FILE IS NOT A PUMPLEX BACKUP.');
      return;
    }
    if (!mounted) return;
    _resetDraft();
    _editing = false;
    _go(_openingScene, Motion.zoomOut);
    setState(() {});
    _snack('RESTORED ${_store.history.length} TRAINING DAYS.');
  }

  // ------------------------------------------------------------------ build

  String get _info {
    final l = levelFor(_store.totalXp).level;
    return switch (_scene) {
      Scene.migrate => 'OLD SAVE · ONE-TIME UPGRADE',
      Scene.create => 'CHARACTER · STEP 1 OF 5',
      Scene.classSelect => 'CLASS · STEP 2 OF 5',
      Scene.difficulty => 'DIFFICULTY · STEP 3 OF 5',
      Scene.area => 'STARTING AREA · STEP 4 OF 5',
      Scene.summary => 'READY? · STEP 5 OF 5',
      Scene.hub => 'LVL $l · ${_store.gameClass.name.toUpperCase()} · ${areaById(_store.profile?.areaId).name.toUpperCase()}',
      Scene.workout => 'WORKOUT · ${_store.todaySession?.totalSets ?? 0} SETS · LVL $l',
      Scene.history => 'PAST SESSIONS · LVL $l',
      Scene.profile => 'YOUR LIFTER · LVL $l ${levelTitle(l).toUpperCase()}',
      Scene.menu => 'MENU',
    };
  }

  /// Android back: one step back in the flow, never out of the app mid-flow.
  Scene? get _backTo => switch (_scene) {
        Scene.migrate => null,
        Scene.create => _editing ? Scene.hub : null,
        Scene.classSelect => Scene.create,
        Scene.difficulty => Scene.classSelect,
        Scene.area => Scene.difficulty,
        Scene.summary => Scene.area,
        Scene.workout || Scene.history || Scene.profile => Scene.hub,
        Scene.menu => _menuFrom,
        Scene.hub => null,
      };

  void _back() {
    if (_head) return setState(() => _head = false);
    final to = _backTo;
    if (to == null) return;
    if (_scene == Scene.menu) return _closeMenu();
    if (_scene == Scene.create) _editing = false;
    _go(to, _scene == Scene.history ? Motion.slideLeft : Motion.zoomOut);
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
            editing: _editing,
            onPick: _pickClass,
            onBack: _back,
            onNext: () => _go(_editing ? Scene.summary : Scene.difficulty),
          ),
        Scene.difficulty => DifficultyView(
            stage: stage,
            difficultyId: _difficultyId,
            editing: _editing,
            onPick: _pickDifficulty,
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
        Scene.hub => HubView(
            stage: stage,
            store: _store,
            onTrain: () => _go(Scene.workout),
            onBody: _editCharacter,
            onProfile: () => _go(Scene.profile),
          ),
        Scene.workout => WorkoutView(
            stage: stage,
            store: _store,
            onAdd: _addSet,
            onRemove: _removeSet,
          ),
        Scene.history => HistoryView(stage: stage, store: _store),
        Scene.profile => ProfileView(
            stage: stage,
            store: _store,
            onBody: _editCharacter,
            onHistory: _openHistory,
            onEditStep: _editStep,
          ),
        Scene.menu => MenuView(
            store: _store,
            onClose: _closeMenu,
            onProfile: _hasPlay ? () => _go(Scene.profile) : null,
            onHistory: _hasPlay ? _openHistory : null,
            onEditCharacter: _hasPlay ? _editCharacter : null,
            onSave: _saveBackup,
            onRestore: _restoreBackup,
          ),
      };

  /// The profile exists and the menu was opened from play, not from setup.
  bool get _hasPlay => _store.profile != null && !_isSetupScene(_menuFrom);

  static bool _isSetupScene(Scene s) => s.index <= Scene.summary.index;

  bool get _inSetup => _isSetupScene(_scene == Scene.menu ? _menuFrom : _scene);

  /// The bottom bar's lit tab, or null where there is no bar. The bar shows
  /// on the hub, the workout, past sessions and the profile only.
  NavTab? get _navTab => switch (_scene) {
        Scene.hub || Scene.workout => NavTab.hub,
        Scene.history => NavTab.history,
        Scene.profile => NavTab.profile,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // In setup the character shows the draft; in play, the saved profile.
    final profile = _store.profile;
    final char = _inSetup || profile == null ? _char : profile.character;
    final classId = _inSetup || profile == null ? _classId : profile.classId;
    return PopScope(
      canPop: _backTo == null && !_head,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                  // Opens the full-screen menu (design screen 12). Not on the
                  // first setup: there is nothing to open yet.
                  menu: _store.profile == null && _inSetup
                      ? null
                      : IconButton(
                    key: const ValueKey('menu-open'),
                    tooltip: 'Menu',
                    icon: Icon(_scene == Scene.menu ? Icons.close : Icons.more_vert, color: p.ink, size: 28),
                    onPressed: _scene == Scene.menu ? _closeMenu : _openMenu,
                  ),
                ),
                Container(height: 6, color: p.violet),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final stage = stageRect(_scene, box.biggest, bottomInset: MediaQuery.paddingOf(context).bottom);
                    // The bottom bar takes the system inset, so the views
                    // above it get none.
                    return MediaQuery.removePadding(
                      context: context,
                      removeBottom: _navTab != null,
                      child: Stack(
                      children: [
                        Positioned.fill(
                          child: SceneSwitcher(
                            scene: _scene,
                            motion: _motion,
                            child: _view(_scene, stage),
                          ),
                        ),
                        // The one character, shared by every scene.
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
                                pedestal: _scene != Scene.workout && _scene != Scene.hub,
                                zoomHead: _scene == Scene.create && _head,
                              ),
                            ),
                          ),
                        ),
                        // Freeze-frame intro card: over the preview card on
                        // the difficulty step, over the whole view on level-ups.
                        if (_intro != null)
                          switch (_scene) {
                            Scene.difficulty => Positioned.fromRect(
                                rect: difficultyCardRect(box.biggest),
                                child: _introCard(),
                              ),
                            _ => Positioned.fill(child: _introCard()),
                          },
                      ],
                    ));
                  }),
                ),
                if (_navTab case final tab?)
                  MainNav(
                    current: tab,
                    onHistory: _openHistory,
                    onHub: _back,
                    onProfile: () => _go(Scene.profile),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.info, required this.menu});

  final String info;

  /// The ⋮ button, or null (the space stays, so the bar keeps its height).
  final Widget? menu;

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
                  child: AnimatedSwitcher(
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
          menu ?? const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}
