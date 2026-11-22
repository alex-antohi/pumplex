// PUMPLEX™ design kit: the look of the "Hydration, But Worse" page,
// rebuilt in Flutter. Thick ink borders, hard offset shadows, rainbow
// type, things that spin for no reason.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


const kDisplay = 'Anton';
const kMono = 'Space Mono';

/// Deep ink used behind terminal text and the ticker in both themes.
const kNight = Color(0xFF1A0B3B);

TextStyle display(double size, [Color? color]) => TextStyle(
      fontFamily: kDisplay,
      fontWeight: FontWeight.w400, // Anton has one weight
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

/// Burst ids already shown this run, so each one explodes only once.
final _celebrated = <String>{};

/// Full-screen burst with confetti and a heavy buzz (the welcome).
/// [exercise] is the tag line, [big] the headline ("LVL 3"), [sub] the
/// brag line.
void celebratePr(
  BuildContext context, {
  required String id,
  String exercise = '',
  String big = '',
  String sub = '',
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
        // Empty texts are left out (the welcome shows only its title, D56).
        if (widget.exercise.isNotEmpty) ...[
          const SizedBox(height: 18),
          Tag(widget.exercise, bg: p.lime, fg: p.on, size: 24),
        ],
        if (widget.big.isNotEmpty) ...[const SizedBox(height: 16), big],
        if (widget.sub.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(widget.sub, textAlign: TextAlign.center, style: mono(15, p.lime)),
        ],
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

/// A design pixel icon (assets/icons, docs/moodboard/icons). The PNGs are
/// white, so [color] tints them. Keep [size] a multiple of 24 for square
/// pixels where the layout allows.
class PxIcon extends StatelessWidget {
  const PxIcon(this.id, {super.key, this.size = 24, this.color});

  final String id;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icons/$id.png',
        width: size,
        height: size,
        color: color ?? Pal.of(context).ink,
        filterQuality: FilterQuality.none,
        isAntiAlias: false,
        excludeFromSemantics: true,
      );
}

/// A pixel icon and a label in one row, in the current text style and
/// colour (for buttons: the design has no text glyphs such as ◀ or ✎).
class IconText extends StatelessWidget {
  const IconText(this.icon, this.text, {super.key, this.iconAfter = false});

  final String icon, text;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final size = (style.fontSize ?? 16) * 0.9;
    final i = PxIcon(icon, size: size, color: style.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!iconAfter) ...[i, const SizedBox(width: 6)],
        Flexible(child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.fade)),
        if (iconAfter) ...[const SizedBox(width: 6), i],
      ],
    );
  }
}
