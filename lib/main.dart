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
import 'views/scene.dart';
import 'views/setup.dart';
import 'views/sprite.dart';

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
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: store.cel,
        child: ValueListenableBuilder<bool>(
          valueListenable: store.chaos,
          child: child,
          builder: (context, on, child) => ChaosFilter(on: on, child: child!),
        ),
        builder: (context, on, child) => CelFilter(on: on, child: child!),
      ),
      home: GameShell(store: store),
    );
  }
}

/// Every view of the app. They are scenes of ONE screen (see GameShell).
enum Scene { migrate, create, classSelect, difficulty, area, summary, hub, workout, history, gear }

/// Where the character stands in each scene, inside the content area.
/// The views leave this rect free; the shell draws the one character there,
/// so it glides from place to place when the scene changes.
Rect stageRect(Scene s, Size a) {
  final w = a.width, h = a.height;
  return switch (s) {
    Scene.create => Rect.fromLTWH(0, 8, w, h * 0.42),
    Scene.classSelect => Rect.fromLTWH(26, 132, w * 0.34, h * 0.25),
    Scene.difficulty || Scene.area => Rect.fromLTWH(12, 8, w * 0.30, h * 0.22),
    Scene.summary => Rect.fromLTWH(0, 10, w, h * 0.40),
    Scene.hub => Rect.fromLTWH(0, 6, w, h * 0.34),
    Scene.migrate => Rect.fromLTWH(0, 10, w, h * 0.34),
    Scene.workout || Scene.history || Scene.gear => Rect.fromLTWH(w * 0.70, 6, w * 0.26, h * 0.17),
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

  late Scene _scene = _store.hasOldData ? Scene.migrate : _startScene;

  Scene get _startScene => _store.profile == null ? Scene.create : Scene.hub;
  Motion _motion = Motion.zoomIn;

  // Setup draft (the profile is only saved on LET'S GO).
  late Character _char;
  late String _classId, _difficultyId, _areaId;
  bool _editing = false;

  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _resetDraft();
    _life = AppLifecycleListener(onResume: _checkSession);
    _store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  bool _precached = false;

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
    if (!mounted) return;
    setState(() {});
    // Achievements and gear: a burst for the first, a message for the rest.
    final news = _store.takeUnlocks();
    if (news.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final u = news.first;
      celebratePr(
        context,
        id: 'unlock-${u.name}-${DateTime.now().microsecondsSinceEpoch}',
        title: u.title,
        exercise: u.name,
        big: 'LVL ${levelFor(_store.totalXp).level}',
        sub: u.sub,
      );
      if (news.length > 1) {
        _snack('ALSO UNLOCKED: ${news.skip(1).map((n) => n.name.toUpperCase()).join(', ')}.');
      }
    });
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
    _areaId = areaById(p?.areaId).id;
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

  void _go(Scene to, [Motion motion = Motion.zoomIn]) {
    if (to == _scene) return;
    setState(() {
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

  void _editCharacter() {
    _resetDraft();
    _editing = true;
    _go(Scene.create, Motion.zoomOut);
  }

  // ---------------------------------------------------------------- workout

  void _addSet(int i) {
    final before = levelFor(_store.totalXp).level;
    _store.addSet(i);
    if (_store.lastSetCritical(i)) {
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

  // ------------------------------------------------------- freeze-frame card

  IntroSpec? _intro;
  int _introRun = 0; // a new pick restarts the card

  void _showIntro(IntroSpec spec) => setState(() {
        _intro = spec;
        _introRun++;
      });

  void _pickClass(String id) {
    setState(() => _classId = id);
    final c = classById(id);
    _showIntro((title: c.name, subtitle: c.subtitle, color: classColor(Pal.of(context), id)));
  }

  void _removeSet(int i) => _store.removeSet(i);

  void _swap(int i, int dir) {
    if (_store.swap(i, dir)) return;
    _snack(_store.todayExercises[i].sets > 0
        ? 'SETS ALREADY DONE HERE. HOLD TO TAKE THEM AWAY, OR ADD AN EXERCISE.'
        : 'NO OTHER EXERCISE LEFT IN THE POOL.');
  }

  // ------------------------------------------------------------------- menu

  void _toggleCel() {
    final on = !_store.cel.value;
    _store.setCel(on);
    if (on && !CelFilter.supported) {
      _snack('CEL SHADER needs the Impeller renderer; this phone draws without it.');
    }
  }

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
    _go(_store.hasOldData ? Scene.migrate : _startScene, Motion.zoomOut);
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
      Scene.gear => 'GEAR · LVL $l',
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
        Scene.workout || Scene.history || Scene.gear => Scene.hub,
        Scene.hub => null,
      };

  void _back() {
    final to = _backTo;
    if (to == null) return;
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
        Scene.gear => GearView(stage: stage, store: _store, onBack: _back),
        Scene.create => CreateView(
            stage: stage,
            character: _char,
            onCharacter: (c) => setState(() => _char = c),
            onNext: () => _go(_editing ? Scene.summary : Scene.classSelect),
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
            onPick: (id) => setState(() => _difficultyId = id),
            onBack: _back,
            onNext: () => _go(_editing ? Scene.summary : Scene.area),
          ),
        Scene.area => AreaView(
            stage: stage,
            areaId: _areaId,
            onPick: (id) => setState(() => _areaId = id),
            onBack: _back,
            onNext: () => _go(Scene.summary),
          ),
        Scene.summary => SummaryView(
            stage: stage,
            classId: _classId,
            difficultyId: _difficultyId,
            areaId: _areaId,
            editing: _editing,
            onEdit: (step) => _go(const [Scene.create, Scene.classSelect, Scene.difficulty, Scene.area][step], Motion.zoomOut),
            onBack: _back,
            onGo: _finishSetup,
          ),
        Scene.hub => HubView(
            stage: stage,
            store: _store,
            onTrain: () => _go(Scene.workout),
            onHistory: () => _go(Scene.history, Motion.slideRight),
            onBody: _editCharacter,
            onGear: () => _go(Scene.gear),
          ),
        Scene.workout => WorkoutView(
            stage: stage,
            store: _store,
            onAdd: _addSet,
            onRemove: _removeSet,
            onSwap: _swap,
            onBack: _back,
          ),
        Scene.history => HistoryView(stage: stage, store: _store, onBack: _back),
      };

  bool get _inSetup => _scene.index <= Scene.summary.index;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // In setup the character shows the draft; in play, the saved profile.
    final profile = _store.profile;
    final char = _inSetup || profile == null ? _char : profile.character;
    final classId = _inSetup || profile == null ? _classId : profile.classId;
    return PopScope(
      canPop: _backTo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: DotBackground(
            child: Column(
              children: [
                Container(
                  color: kNight,
                  child: const SafeArea(bottom: false, child: Ticker(items: tickerItems)),
                ),
                _TopBar(
                  info: _info,
                  menu: PopupMenuButton<VoidCallback>(
                    icon: Icon(Icons.more_vert, color: p.ink, size: 28),
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      if (profile != null && !_inSetup)
                        PopupMenuItem(value: _editCharacter, child: const Text('🧬  EDIT CHARACTER')),
                      PopupMenuItem(value: _saveBackup, child: const Text('💾  SAVE BACKUP FILE')),
                      PopupMenuItem(value: _restoreBackup, child: const Text('♻️  RESTORE BACKUP FILE')),
                      PopupMenuItem(
                        value: () => _store.setChaos(!_store.chaos.value),
                        child: Text(_store.chaos.value ? '🌀  CHAOS MODE: ON!!!' : '🌀  CHAOS MODE: OFF'),
                      ),
                      PopupMenuItem(
                        value: _toggleCel,
                        child: Text(_store.cel.value ? '🖍️  CEL SHADER: ON!!!' : '🖍️  CEL SHADER: OFF'),
                      ),
                    ],
                  ),
                ),
                Container(height: 6, color: p.violet),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final stage = stageRect(_scene, box.biggest);
                    return Stack(
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
                              child: CharacterSprite(character: char, classId: classId),
                            ),
                          ),
                        ),
                        // Freeze-frame intro card: over the preview card on
                        // the class step, over the whole view on level-ups.
                        if (_intro != null)
                          _scene == Scene.classSelect
                              ? Positioned.fromRect(
                                  rect: classCardRect(stage, box.maxWidth),
                                  child: IntroCard(
                                    key: ValueKey(_introRun),
                                    spec: _intro!,
                                    onDone: () => setState(() => _intro = null),
                                  ),
                                )
                              : Positioned.fill(
                                  child: IntroCard(
                                    key: ValueKey(_introRun),
                                    spec: _intro!,
                                    onDone: () => setState(() => _intro = null),
                                  ),
                                ),
                      ],
                    );
                  }),
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
  final Widget menu;

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
          menu,
        ],
      ),
    );
  }
}
