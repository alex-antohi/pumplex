import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dates.dart';
import 'day_page.dart';
import 'export.dart';
import 'program.dart';
import 'pumplex.dart';
import 'store.dart';

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
      title: ownerLabel == null ? 'PUMPLEX' : 'PUMPLEX $ownerLabel',
      debugShowCheckedModeBanner: false,
      theme: pumplexTheme(Brightness.light),
      darkTheme: pumplexTheme(Brightness.dark),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: store.chaos,
        child: child,
        builder: (context, on, child) => ChaosFilter(on: on, child: child!),
      ),
      home: SessionPager(store: store),
    );
  }
}

/// One page per session: past ones to the right (swipe right to go back),
/// the current one, then previews. The current session stays until
/// I WORKED / I RESTED.
class SessionPager extends StatefulWidget {
  const SessionPager({super.key, required this.store});

  final LogStore store;

  @override
  State<SessionPager> createState() => _SessionPagerState();
}

class _SessionPagerState extends State<SessionPager> with WidgetsBindingObserver {
  LogStore get _store => widget.store;

  /// Upcoming sessions you can swipe ahead to (read-only).
  static const _preview = 6;

  late PageController _controller = PageController(initialPage: _store.currentN - 1);
  late int _page = _store.currentN - 1;
  int _generation = 0; // bumped after a restore to rebuild all pages
  bool _loaded = false;

  int get _n => _page + 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.flush();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _store.flush();
  }

  void _goTo(int page, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      if (animate && (page - _page).abs() <= 3) {
        _controller.animateToPage(page,
            duration: const Duration(milliseconds: 550), curve: Curves.easeOutBack);
      } else {
        _controller.jumpToPage(page);
      }
    });
  }

  void _snack(String text, {SnackBarAction? action}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      action: action,
      duration: Duration(seconds: action == null ? 4 : 6),
    ));

  /// I WORKED / I RESTED on the current session.
  void _complete() {
    final n = _store.currentN;
    final workout = program[_store.dayOf(n)];
    final rested = workout == null;
    _store.flush();
    _store.complete(rested: rested);
    final took = _store.sessions.last.duration;
    final next = program[_store.dayOf(_store.currentN)];
    celebratePr(
      context,
      id: 'done-$n-${DateTime.now().microsecondsSinceEpoch}',
      title: rested ? 'REST\nLOGGED' : 'DAY\nDONE!!!',
      exercise: rested ? 'Rest day' : workout.title,
      big: took == null ? 'SESSION $n' : '⏱ ${fmtDuration(took)}',
      sub: 'NEXT UP: ${(next?.title ?? 'Rest day').toUpperCase()}.\nTHE BAR IS WAITING.',
    );
    setState(() {});
    _goTo(_store.currentN - 1);
    _snack(
      rested ? 'REST DAY LOCKED IN.' : 'WORKOUT LOCKED IN.',
      action: SnackBarAction(label: 'UNDO', textColor: kNight, onPressed: _undo),
    );
  }

  void _undo() {
    if (!_store.undoComplete()) {
      _snack("CAN'T UNDO: THE NEXT SESSION ALREADY HAS SETS IN IT.");
      return;
    }
    setState(() {});
    _goTo(_store.currentN - 1);
  }

  Future<void> _saveBackup() async {
    try {
      final saved = await saveTextFile(
        name: 'pumplex_backup_${dateKey(DateTime.now())}.json',
        mime: 'application/json',
        content: _store.backupJson(),
      );
      if (saved && mounted) {
        _snack('BACKUP OF ${_store.loggedSessions} SESSIONS SAVED. GAINS: INSURED.');
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
    final old = _controller;
    setState(() {
      _generation++;
      _page = _store.currentN - 1;
      _controller = PageController(initialPage: _page);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _snack('RESTORED ${_store.loggedSessions} SESSIONS.');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final current = _store.currentN;
    final n = _n.clamp(1, current + _preview);
    final when = n == current
        ? 'NOW'
        : n > current
            ? 'PREVIEW'
            : shortDate(_store.dateOf(n)).toUpperCase();
    final owner = ownerLabel == null ? '' : '$ownerLabel · ';
    final info = '${owner}SESSION $n · DAY ${_store.dayOf(n)}/7 · $when';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DotBackground(
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    color: kNight,
                    child: const SafeArea(bottom: false, child: Ticker(items: tickerItems)),
                  ),
                  _TopBar(
                    info: info,
                    menu: PopupMenuButton<VoidCallback>(
                      icon: Icon(Icons.more_vert, color: p.ink, size: 28),
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: () => exportCsvFlow(this.context, _store),
                          child: const Text('📊  EXPORT CSV…'),
                        ),
                        PopupMenuItem(value: _saveBackup, child: const Text('💾  SAVE BACKUP FILE')),
                        PopupMenuItem(value: _restoreBackup, child: const Text('♻️  RESTORE BACKUP FILE')),
                        PopupMenuItem(
                          value: () => _store.setChaos(!_store.chaos.value),
                          child: Text(_store.chaos.value ? '🌀  CHAOS MODE: ON!!!' : '🌀  CHAOS MODE: OFF'),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 6, color: p.violet),
                  Expanded(
                    child: PageView.builder(
                      key: ValueKey(_generation),
                      controller: _controller,
                      // Past sessions, the current one, then the rest of the week as previews.
                      itemCount: current + _preview,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (context, page) => DayPage(
                        n: page + 1,
                        store: _store,
                        onComplete: _complete,
                      ),
                    ),
                  ),
                ],
              ),
              // Floating, so the top bar never changes shape while swiping.
              Positioned(
                right: 20,
                bottom: 22 + MediaQuery.paddingOf(context).bottom,
                child: AnimatedScale(
                  scale: n != current ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: BrutalButton(
                    color: p.orange,
                    onTap: n != current ? () => _goTo(current - 1) : null,
                    child: const Text('↩ NOW'),
                  ),
                ),
              ),
              if (!_loaded)
                Positioned.fill(child: Preloader(onDone: () => setState(() => _loaded = true))),
            ],
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
                // when the page changes.
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
