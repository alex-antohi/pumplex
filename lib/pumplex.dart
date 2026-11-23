// PUMPLEX™ design kit: the look of the "Hydration, But Worse" page,
// rebuilt in Flutter. Thick ink borders, hard offset shadows, rainbow
// type, things that spin for no reason.

import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kDisplay = 'sans-serif-condensed';
const kMono = 'monospace';

/// Deep ink used behind terminal text and the ticker in both themes.
const kNight = Color(0xFF1A0B3B);

TextStyle display(double size, [Color? color]) => TextStyle(
      fontFamily: kDisplay,
      fontWeight: FontWeight.w900,
      fontSize: size,
      height: 1.0,
      letterSpacing: 0.4,
      color: color,
    );

TextStyle mono(double size, Color color) => TextStyle(
      fontFamily: kMono,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.35,
      color: color,
    );

@immutable
class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg,
    required this.ink,
    required this.pink,
    required this.lime,
    required this.orange,
    required this.violet,
    required this.sky,
    required this.panel,
    required this.panel2,
    required this.dot,
  });

  final Color bg, ink, pink, lime, orange, violet, sky, panel, panel2, dot;

  /// Text on the bright colours, in both themes.
  Color get on => kNight;
  List<Color> get rainbow => [pink, orange, lime, sky, violet, pink];
  List<Color> get accents => [pink, sky, orange, lime, violet];

  static const light = Pal(
    bg: Color(0xFFE3FBFF),
    ink: Color(0xFF1A0B3B),
    pink: Color(0xFFFF2E93),
    lime: Color(0xFFB6FF00),
    orange: Color(0xFFFF8A00),
    violet: Color(0xFF7B2CFF),
    sky: Color(0xFF00C2FF),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFFFF0FA),
    dot: Color(0x47FF2E93),
  );

  static const dark = Pal(
    bg: Color(0xFF12061F),
    ink: Color(0xFFF6EEFF),
    pink: Color(0xFFFF5FB0),
    lime: Color(0xFFC6FF3D),
    orange: Color(0xFFFFA033),
    violet: Color(0xFFA77BFF),
    sky: Color(0xFF3FD2FF),
    panel: Color(0xFF1F0D36),
    panel2: Color(0xFF2A1148),
    dot: Color(0x38FF5FB0),
  );

  static Pal of(BuildContext context) => Theme.of(context).extension<Pal>()!;

  @override
  Pal copyWith() => this;

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) =>
      other is Pal && t >= 0.5 ? other : this;
}

ThemeData pumplexTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Pal.dark : Pal.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.pink, brightness: brightness)
      .copyWith(
    primary: p.pink,
    onPrimary: p.on,
    secondary: p.lime,
    onSecondary: p.on,
    surface: p.panel,
    onSurface: p.ink,
  );
  final hard = RoundedRectangleBorder(
    borderRadius: BorderRadius.zero,
    side: BorderSide(color: p.ink, width: 4),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.pink,
      selectionColor: p.lime.withValues(alpha: 0.5),
      selectionHandleColor: p.pink,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.lime,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: display(16, p.on),
      shape: const RoundedRectangleBorder(side: BorderSide(color: kNight, width: 3)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.panel,
      shape: hard,
      textStyle: display(17, p.ink),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      shape: hard,
      titleTextStyle: display(26, p.ink),
      contentTextStyle: mono(14, p.ink),
    ),
  );
}

/// Pink polka dots behind everything.
class DotBackground extends StatelessWidget {
  const DotBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _Dots(Pal.of(context).dot),
        child: child,
      );
}

class _Dots extends CustomPainter {
  _Dots(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 12.0; y < size.height; y += 24) {
      for (var x = 12.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}

/// White panel, ink border, hard coloured shadow, optionally tilted.
class Brutal extends StatelessWidget {
  const Brutal({
    super.key,
    required this.child,
    this.color,
    this.shadow,
    this.offset = 8,
    this.border = 4,
    this.angle = 0,
    this.margin,
  });

  final Widget child;
  final Color? color;
  final Color? shadow;
  final double offset;
  final double border;

  /// Degrees.
  final double angle;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Transform.rotate(
      angle: angle * pi / 180,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? p.panel,
          border: Border.all(color: p.ink, width: border),
          boxShadow: [BoxShadow(color: shadow ?? p.pink, offset: Offset(offset, offset))],
        ),
        child: child,
      ),
    );
  }
}

/// Chunky button that physically squashes into its shadow when pressed.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.small = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final bool small;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final enabled = widget.onTap != null;
    final shadow = widget.small ? 4.0 : 6.0;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            transform: Matrix4.translationValues(
                _down ? shadow - 1 : 0, _down ? shadow - 1 : 0, 0),
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 10 : 16,
              vertical: widget.small ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: widget.color ?? p.lime,
              border: Border.all(color: p.ink, width: widget.small ? 3 : 4),
              boxShadow: [
                BoxShadow(color: p.ink, offset: Offset(_down ? 1 : shadow, _down ? 1 : shadow)),
              ],
            ),
            child: DefaultTextStyle(
              style: display(widget.small ? 15 : 18, p.on).copyWith(letterSpacing: 1),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(-bounds.width * 3 * t, 0, 0);
}

/// Huge rainbow text that never stops sliding, ink outline, hard shadow.
class MegaText extends StatefulWidget {
  const MegaText(this.text, {super.key, this.size = 56});

  final String text;
  final double size;

  @override
  State<MegaText> createState() => _MegaTextState();
}

class _MegaTextState extends State<MegaText> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final text = widget.text.toUpperCase();
    final base = display(widget.size).copyWith(height: 0.92, letterSpacing: 0.8);
    final shift = widget.size * 0.08;
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(shift, shift),
          child: Text(text, style: base.copyWith(color: p.ink)),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: p.rainbow,
              begin: Alignment.centerLeft,
              end: const Alignment(5, 0), // gradient spans 3× the width
              tileMode: TileMode.repeated,
              transform: _SlideGradient(_c.value),
            ).createShader(Offset.zero & bounds.size),
            child: child,
          ),
          child: Text(text, style: base.copyWith(color: Colors.white)),
        ),
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.5, widget.size * 0.045)
              ..strokeJoin = StrokeJoin.round
              ..color = p.ink,
          ),
        ),
      ],
    );
  }
}

/// Little tilted label, ink background, lime text.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.bg, this.fg, this.angle = -2, this.size = 17});

  final String text;
  final Color? bg;
  final Color? fg;
  final double angle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Transform.rotate(
      angle: angle * pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: bg ?? kNight,
        child: Text(
          text.toUpperCase(),
          style: display(size, fg ?? p.lime).copyWith(letterSpacing: 1),
        ),
      ),
    );
  }
}

/// Small uppercase label.
class Shout extends StatelessWidget {
  const Shout(this.text, {super.key, this.color, this.size = 13});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: display(size, color ?? Pal.of(context).ink).copyWith(letterSpacing: 1.6),
      );
}

/// "> TERMINAL READOUT" box.
class Terminal extends StatelessWidget {
  const Terminal(this.lines, {super.key});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: kNight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          lines.map((l) => '> $l').join('\n'),
          style: mono(13.5, Pal.of(context).lime),
        ),
      );
}

/// Spinning 12-point starburst with an upright label on top.
class Starburst extends StatefulWidget {
  const Starburst({super.key, required this.child, this.size = 72, this.color, this.seconds = 9});

  final Widget child;
  final double size;
  final Color? color;
  final int seconds;

  @override
  State<Starburst> createState() => _StarburstState();
}

class _StarburstState extends State<Starburst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(seconds: widget.seconds))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _c,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _StarPainter(widget.color ?? p.orange, p.ink),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.fill, this.ink);

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 2;
    final inner = outer * 0.8;
    final path = Path();
    for (var i = 0; i < 24; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / 12;
      final pt = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.fill != fill || old.ink != ink;
}

/// Grows and shrinks forever.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.amount = 0.08});

  final Widget child;
  final double amount;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.0 + widget.amount)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: widget.child,
      );
}

/// THE PUMP-O-METER™. A gauge for how much of today's sets are done.
class PumpOMeter extends StatefulWidget {
  const PumpOMeter({super.key, required this.value});

  /// 0..1
  final double value;

  @override
  State<PumpOMeter> createState() => _PumpOMeterState();
}

class _PumpOMeterState extends State<PumpOMeter> with SingleTickerProviderStateMixin {
  late final _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _maxed => widget.value >= 1;

  void _sync() {
    if (_maxed && !_wobble.isAnimating) {
      _wobble.repeat(reverse: true);
    } else if (!_maxed) {
      _wobble.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PumpOMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AspectRatio(
      aspectRatio: 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.elasticOut,
        builder: (context, v, _) => AnimatedBuilder(
          animation: _wobble,
          builder: (context, _) {
            final deg = _maxed
                ? lerpDouble(-70, 75, Curves.easeInOut.transform(_wobble.value))!
                : -85 + 170 * v;
            return CustomPaint(painter: _GaugePainter(deg * pi / 180, p));
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.angle, this.p);

  /// Radians from straight up; negative is left.
  final double angle;
  final Pal p;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final c = Offset(size.width / 2, size.height);
    final r = min(size.width / 2, size.height) - 3;
    final outer = Rect.fromCircle(center: c, radius: r);
    final colors = [p.lime, p.orange, p.pink];
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(outer, pi + i * pi / 3, pi / 3, true, Paint()..color = colors[i]);
    }
    final ink = Paint()
      ..color = p.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawArc(outer, pi, pi, true, ink);
    final inner = Rect.fromCircle(center: c, radius: r * 0.6);
    canvas.drawArc(inner, pi, pi, true, Paint()..color = p.panel);
    canvas.drawArc(inner, pi, pi, true, ink);

    final dir = Offset(sin(angle), -cos(angle));
    canvas.drawLine(
      c,
      c + dir * r * 0.93,
      Paint()
        ..color = p.ink
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, r * 0.12, Paint()..color = p.violet);
    canvas.drawCircle(c, r * 0.12, ink);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.angle != angle || old.p != p;
}

String pumpReading(int done, int total) {
  if (total == 0 || done == 0) return 'WAITING FOR YOUR FIRST SET…';
  if (done >= total) return 'PUMP: 100%. NEEDLE HAS OPINIONS. WORKOUT DEMOLISHED.';
  final pct = (done * 100 / total).round();
  if (pct < 25) return 'PUMP: $pct%. POSSIBLY JUST POSTURE.';
  if (pct < 50) return 'PUMP: $pct%. CONSISTENT WITH BEING A PERSON.';
  if (pct < 75) return 'PUMP: $pct%. SLEEVES UNDER PRESSURE.';
  return 'PUMP: $pct%. SUSPICIOUSLY HIGH. DRINK WATER.';
}

const _dayTags = [
  'LIFTING, BUT WORSE.',
  'GAINS, BUT LOUDER.',
  'PAIN, BUT ORGANISED.',
  'SQUATS, BUT MORE.',
  'CARDIO, BUT NO.',
  'SUFFERING, BUT CONJUGATED.',
  'IRON, BUT PERSONAL.',
];

const _restTags = [
  'RECOVERY, BUT HARDER.',
  'NOTHING, BUT ON PURPOSE.',
  'GAINS, BUT HORIZONTAL.',
];

/// Tagline for session [n] (stable per session).
String dayTag(int n) => _dayTags[n % _dayTags.length];
String restTag(int n) => _restTags[n % _restTags.length];

/// PRs already celebrated this run, so each one explodes only once.
final _celebrated = <String>{};

/// Full-screen PR explosion with confetti and a heavy buzz.
/// [big] is the headline number ("120 KG", "14 REPS"), [sub] the brag line.
void celebratePr(
  BuildContext context, {
  required String id,
  required String exercise,
  required String big,
  required String sub,
  String title = 'NEW\nPR!!!',
}) {
  if (!_celebrated.add(id)) return;
  HapticFeedback.heavyImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PrBurst(
      title: title,
      exercise: exercise,
      big: big,
      sub: sub,
      onDone: () => entry.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
}

class _PrBurst extends StatefulWidget {
  const _PrBurst({
    required this.title,
    required this.exercise,
    required this.big,
    required this.sub,
    required this.onDone,
  });

  final String title;
  final String exercise;
  final String big;
  final String sub;
  final VoidCallback onDone;

  @override
  State<_PrBurst> createState() => _PrBurstState();
}

class _PrBurstState extends State<_PrBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final big = Text(
      widget.big,
      style: display(60, Colors.white).copyWith(shadows: [
        Shadow(offset: const Offset(6, 6), color: p.sky),
        Shadow(offset: const Offset(3, 3), color: p.pink),
      ]),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Starburst(
          size: 170,
          color: p.pink,
          seconds: 3,
          child: Text(widget.title, textAlign: TextAlign.center, style: display(36, p.on)),
        ),
        const SizedBox(height: 18),
        Tag(widget.exercise, bg: p.lime, fg: p.on, size: 24),
        const SizedBox(height: 16),
        big,
        const SizedBox(height: 10),
        Text(widget.sub, textAlign: TextAlign.center, style: mono(15, p.lime)),
      ],
    );
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          child: content,
          builder: (context, child) {
            final t = _c.value;
            final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
            final fade = (t < 0.82 ? 1.0 : 1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: Container(
                color: kNight.withValues(alpha: 0.86),
                child: CustomPaint(
                  painter: _Confetti(t, p.accents),
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.08,
                      child: Transform.scale(scale: 0.2 + 0.8 * pop, child: child),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Confetti extends CustomPainter {
  _Confetti(this.t, this.colors);

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(11);
    final c = size.center(Offset.zero);
    final reach = size.longestSide * 0.8;
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final spin = rnd.nextDouble() * 12 - 6;
      final w = 6 + rnd.nextDouble() * 8;
      final delay = rnd.nextDouble() * 0.15;
      final q = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (q <= 0) continue;
      final pos = c +
          Offset(cos(a), sin(a)) * (Curves.easeOutCubic.transform(q) * reach * speed) +
          Offset(0, 260 * q * q);
      paint.color = colors[i % colors.length];
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin * q);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.55), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => old.t != t;
}

/// Chaos mode: the whole app slowly cycles through every hue.
class ChaosFilter extends StatefulWidget {
  const ChaosFilter({super.key, required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<ChaosFilter> createState() => _ChaosFilterState();
}

class _ChaosFilterState extends State<ChaosFilter> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  void _sync() {
    if (widget.on) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ChaosFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static List<double> _hue(double a) {
    final c = cos(a), s = sin(a);
    const r = 0.213, g = 0.715, b = 0.072;
    return [
      r + c * (1 - r) - s * r, g - c * g - s * g, b - c * b + s * (1 - b), 0, 0,
      r - c * r + s * 0.143, g + c * (1 - g) + s * 0.140, b - c * b - s * 0.283, 0, 0,
      r - c * r - s * (1 - r), g - c * g + s * g, b + c * (1 - b) + s * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  // The tree shape never changes (the filter is the identity when off),
  // so toggling chaos does not reset the app underneath it.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => ColorFiltered(
          colorFilter: ColorFilter.matrix(_hue(_c.value * 2 * pi)),
          child: child,
        ),
      );
}
