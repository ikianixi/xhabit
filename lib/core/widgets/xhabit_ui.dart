import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../calendar/app_calendar.dart';
import '../icons/habit_icons.dart';
import '../theme/app_tokens.dart';

/// Circular 34x34 header icon button matching `.hdr-circ` in prototype.
class HdrCircleButton extends StatelessWidget {
  const HdrCircleButton({
    required this.icon,
    required this.onTap,
    this.mutedAlert = false,
    this.backgroundColor,
    this.iconColor,
    this.iconSize = 19,
    this.size = 38,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool mutedAlert;
  final Color? backgroundColor;
  final Color? iconColor;
  final double iconSize;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final bg = backgroundColor ?? xc.card2;
    final fg =
        iconColor ?? (mutedAlert ? xc.muted.withValues(alpha: 0.45) : xc.text);
    final child = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

/// Nested concentric circle habit icon (`38x38` card2 outer + `28x28` accented inner).
class HabitRingIcon extends StatelessWidget {
  const HabitRingIcon({
    required this.iconKey,
    required this.accent,
    this.outerSize = 38,
    this.innerSize = 28,
    this.iconSize = 16,
    super.key,
  });

  final String iconKey;
  final Color accent;
  final double outerSize;
  final double innerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        color: xc.card2,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.8),
        ),
        alignment: Alignment.center,
        child: Icon(
          HabitPalette.iconFor(iconKey),
          size: iconSize,
          color: accent,
        ),
      ),
    );
  }
}

/// Exact custom canvas port of `medalSvg(days, unlocked, size)` from `index.html`.
class MedalBadge extends StatelessWidget {
  const MedalBadge({
    required this.days,
    required this.unlocked,
    this.size = 62,
    super.key,
  });

  final int days;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MedalBadgePainter(days: days, unlocked: unlocked),
    );
  }
}

class _MedalSpec {
  const _MedalSpec({
    required this.days,
    required this.tier,
    required this.bg,
    required this.ring,
    required this.core,
    required this.rib,
  });

  final int days;
  final int tier;
  final Color bg;
  final Color ring;
  final Color core;
  final Color rib;

  static const specs = [
    _MedalSpec(
      days: 1,
      tier: 1,
      bg: Color(0xFFCD7F32),
      ring: Color(0xFFFDBA74),
      core: Color(0xFF9A3412),
      rib: Color(0xFFB45309),
    ),
    _MedalSpec(
      days: 7,
      tier: 2,
      bg: Color(0xFFCBD5E1),
      ring: Color(0xFFF8FAFC),
      core: Color(0xFF475569),
      rib: Color(0xFF64748B),
    ),
    _MedalSpec(
      days: 14,
      tier: 3,
      bg: Color(0xFF10B981),
      ring: Color(0xFFA7F3D0),
      core: Color(0xFF065F46),
      rib: Color(0xFF047857),
    ),
    _MedalSpec(
      days: 30,
      tier: 4,
      bg: Color(0xFF0EA5E9),
      ring: Color(0xFFBAE6FD),
      core: Color(0xFF075985),
      rib: Color(0xFF0369A1),
    ),
    _MedalSpec(
      days: 50,
      tier: 5,
      bg: Color(0xFFA855F7),
      ring: Color(0xFFE9D5FF),
      core: Color(0xFF6B21A8),
      rib: Color(0xFF7E22CE),
    ),
    _MedalSpec(
      days: 100,
      tier: 6,
      bg: Color(0xFFF59E0B),
      ring: Color(0xFFFEF08A),
      core: Color(0xFFB45309),
      rib: Color(0xFFEF4444),
    ),
    _MedalSpec(
      days: 200,
      tier: 7,
      bg: Color(0xFFF43F5E),
      ring: Color(0xFFFECDD3),
      core: Color(0xFF9F1239),
      rib: Color(0xFFFB7185),
    ),
    _MedalSpec(
      days: 365,
      tier: 8,
      bg: Color(0xFFFFD426),
      ring: Color(0xFF22D3EE),
      core: Color(0xFF1E1B4B),
      rib: Color(0xFFEC4899),
    ),
  ];

  static _MedalSpec forDays(int d) =>
      specs.firstWhere((e) => e.days == d, orElse: () => specs.first);
}

class _MedalBadgePainter extends CustomPainter {
  const _MedalBadgePainter({required this.days, required this.unlocked});

  final int days;
  final bool unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64.0;
    canvas.save();
    canvas.scale(s, s);

    if (!unlocked) {
      // Locked scalloped silhouette + white padlock
      final seal = _scallopedCircle(const Offset(32, 31), 25, 10, 2.8);
      canvas.drawPath(
        seal,
        Paint()..color = const Color(0xFF132226).withValues(alpha: 0.72),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(23, 29, 18, 15),
          const Radius.circular(3.5),
        ),
        Paint()..color = Colors.white,
      );
      final shackle = Path()
        ..moveTo(27, 29)
        ..lineTo(27, 25)
        ..arcToPoint(
          const Offset(37, 25),
          radius: const Radius.circular(5),
        )
        ..lineTo(37, 29);
      canvas.drawPath(
        shackle,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        const Offset(32, 36.5),
        1.8,
        Paint()..color = const Color(0xFF0B0B0D),
      );
      canvas.restore();
      return;
    }

    final t = _MedalSpec.forDays(days);

    // 1. Splash halo behind badge
    final splashPath = t.tier >= 6
        ? _starburst(const Offset(32, 29.5), 30, 23, 12)
        : _scallopedCircle(const Offset(32, 30), 25, 10, 2.5);
    canvas.drawPath(
      splashPath,
      Paint()..color = t.bg.withValues(alpha: t.tier >= 6 ? 0.28 : 0.22),
    );

    // 2. Tier 8 dashed magenta aura
    if (t.tier == 8) {
      final auraPaint = Paint()
        ..color = const Color(0xFFEC4899).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      for (var i = 0; i < 20; i++) {
        final a0 = (i * 18) * math.pi / 180;
        final a1 = (i * 18 + 9) * math.pi / 180;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(32, 29.5), radius: 20),
          a0,
          a1 - a0,
          false,
          auraPaint,
        );
      }
    }

    // 3. Tier >= 4 wings
    if (t.tier >= 4) {
      final wingPaint = Paint()
        ..color = t.ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final leftW = Path()
        ..moveTo(12, 28)
        ..quadraticBezierTo(6, 28, 4, 20)
        ..quadraticBezierTo(9, 21, 13, 25);
      final rightW = Path()
        ..moveTo(52, 28)
        ..quadraticBezierTo(58, 28, 60, 20)
        ..quadraticBezierTo(55, 21, 51, 25);
      canvas.drawPath(leftW, wingPaint);
      canvas.drawPath(rightW, wingPaint);
    }

    // 4. Tier >= 3 laurel arcs
    if (t.tier >= 3) {
      final laurelPaint = Paint()
        ..color = t.ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final leftL = Path()
        ..moveTo(17, 41)
        ..quadraticBezierTo(11, 35, 14, 25);
      final rightL = Path()
        ..moveTo(47, 41)
        ..quadraticBezierTo(53, 35, 50, 25);
      canvas.drawPath(leftL, laurelPaint);
      canvas.drawPath(rightL, laurelPaint);
    }

    // 5. Tier >= 6 crown
    if (t.tier >= 6) {
      final crown = Path()
        ..moveTo(23, 14)
        ..lineTo(27, 9)
        ..lineTo(32, 13)
        ..lineTo(37, 9)
        ..lineTo(41, 14)
        ..close();
      canvas.drawPath(
        crown,
        Paint()..color = t.tier == 8 ? const Color(0xFF22D3EE) : t.ring,
      );
    }

    // 6. Twin ribbons below coin
    final leftRib = Path()
      ..moveTo(25, 40)
      ..lineTo(21, 55)
      ..lineTo(28, 52)
      ..lineTo(32, 56)
      ..lineTo(32, 40)
      ..close();
    final rightRib = Path()
      ..moveTo(39, 40)
      ..lineTo(43, 55)
      ..lineTo(36, 52)
      ..lineTo(32, 56)
      ..lineTo(32, 40)
      ..close();
    canvas.drawPath(leftRib, Paint()..color = t.rib);
    canvas.drawPath(
        rightRib, Paint()..color = t.rib.withValues(alpha: 0.88));

    // 7. Outer disk + rim + inner core
    canvas.drawCircle(const Offset(32, 29.5), 15, Paint()..color = t.bg);
    canvas.drawCircle(
      const Offset(32, 29.5),
      15,
      Paint()
        ..color = t.ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = t.tier >= 6 ? 2.6 : 2.0,
    );
    canvas.drawCircle(
      const Offset(32, 29.5),
      11,
      Paint()..color = t.core.withValues(alpha: 0.55),
    );

    // 8. Center emblem
    if (t.tier == 8) {
      final d = Path()
        ..moveTo(32, 20)
        ..lineTo(40, 28)
        ..lineTo(32, 39)
        ..lineTo(24, 28)
        ..close();
      canvas.drawPath(d, Paint()..color = const Color(0xFF22D3EE));
      canvas.drawPath(
        d,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else if (t.tier >= 5) {
      canvas.drawPath(
        _fivePointStar(const Offset(32, 30), 10, 4.4),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    } else if (t.tier >= 2) {
      final d = Path()
        ..moveTo(32, 22)
        ..lineTo(39, 29)
        ..lineTo(32, 37)
        ..lineTo(25, 29)
        ..close();
      canvas.drawPath(d, Paint()..color = Colors.white.withValues(alpha: 0.92));
    } else {
      canvas.drawCircle(
        const Offset(32, 29.5),
        4.5,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
    }

    canvas.restore();
  }

  Path _scallopedCircle(Offset c, double r, int lobes, double amp) {
    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final a = (i / steps) * 2 * math.pi;
      final rr = r + math.sin(a * lobes) * amp;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  Path _starburst(Offset c, double outerR, double innerR, int points) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final pt = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  Path _fivePointStar(Offset c, double outerR, double innerR) {
    return _starburst(c, outerR, innerR, 5);
  }

  @override
  bool shouldRepaint(covariant _MedalBadgePainter old) =>
      old.days != days || old.unlocked != unlocked;
}

/// Optional 20x20 rounded-6 medal button beside habit title (opt-in per habit).
class HabitTitleBadgeButton extends StatelessWidget {
  const HabitTitleBadgeButton({
    required this.habit,
    required this.bestStreak,
    required this.onTap,
    super.key,
  });

  final Habit habit;
  final int bestStreak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!habit.showTitleBadge) return const SizedBox.shrink();
    final tier = HabitEngine.highestTierFor(bestStreak);
    if (tier == null) return const SizedBox.shrink();
    final spec = _MedalSpec.forDays(tier.days);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 5),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: spec.bg.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: MedalBadge(days: tier.days, unlocked: true, size: 16),
      ),
    );
  }
}

/// Prototype `.action-btn` circular habit action button with rounded SVG-style arc & ripple.
class HabitActionCircle extends StatefulWidget {
  const HabitActionCircle({
    required this.habit,
    required this.done,
    required this.ratio,
    required this.slipped,
    required this.onTap,
    this.onLongPress,
    this.size = 35,
    super.key,
  });

  final Habit habit;
  final bool done;
  final double ratio;
  final bool slipped;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  State<HabitActionCircle> createState() => _HabitActionCircleState();
}

class _HabitActionCircleState extends State<HabitActionCircle>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _burstCtrl;
  bool _fullBurst = false;

  @override
  void initState() {
    super.initState();
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
  }

  @override
  void didUpdateWidget(covariant HabitActionCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habit.id == widget.habit.id) {
      if (!oldWidget.done && widget.done) {
        _fullBurst = true;
        _burstCtrl.forward(from: 0);
      } else if (widget.ratio > oldWidget.ratio) {
        _fullBurst = false;
        _burstCtrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final accent = Color(widget.habit.colorValue);
    final fg = HabitPalette.contrastFg(accent);
    final size = widget.size;

    Widget inner;
    if (widget.habit.trackingStyle == TrackingStyle.count &&
        !widget.habit.isQuit) {
      if (widget.done) {
        inner = AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.check_rounded, size: size * 0.5, color: fg),
        );
      } else {
        inner = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: widget.ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (_, animRatio, child) => CustomPaint(
              painter: _CircleArcPainter(
                progress: animRatio,
                trackColor: accent.withValues(alpha: 0.22),
                fillColor: accent,
                strokeWidth: 2.6,
              ),
              child: child,
            ),
            child: Center(
              child: Icon(Icons.add_rounded, size: size * 0.48, color: xc.text),
            ),
          ),
        );
      }
    } else if (widget.habit.isQuit) {
      if (widget.slipped) {
        inner = AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x33EF4444),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close_rounded,
            size: size * 0.48,
            color: const Color(0xFFEF4444),
          ),
        );
      } else {
        inner = AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.done
                ? accent
                : (xc.isDark
                    ? const Color(0x0FFFFFFF)
                    : const Color(0x0F0F172A)),
            border: widget.done ? null : Border.all(color: xc.borderStrong),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.check_rounded,
            size: size * 0.48,
            color: widget.done ? fg : xc.muted,
          ),
        );
      }
    } else {
      inner = AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.done
              ? accent
              : (xc.isDark
                  ? const Color(0x0FFFFFFF)
                  : const Color(0x0F0F172A)),
          border: widget.done ? null : Border.all(color: xc.borderStrong),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.check_rounded,
          size: size * 0.48,
          color: widget.done ? fg : xc.muted,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: OverflowBox(
              maxWidth: size * 3.1,
              maxHeight: size * 3.1,
              child: AnimatedBuilder(
                animation: _burstCtrl,
                builder: (_, _) {
                  if (_burstCtrl.value == 0 ||
                      _burstCtrl.status == AnimationStatus.dismissed ||
                      _burstCtrl.status == AnimationStatus.completed) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    size: Size(size * 3.1, size * 3.1),
                    painter: _CheckBurstPainter(
                      t: Curves.easeOutCubic.transform(_burstCtrl.value),
                      color: accent,
                      buttonSize: size,
                      fullBurst: _fullBurst,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: _burstCtrl,
            builder: (_, child) {
              var bounce = 1.0;
              if (_burstCtrl.isAnimating && _burstCtrl.value < 0.42) {
                final bt = _burstCtrl.value / 0.42;
                bounce = 1.0 + 0.14 * math.sin(bt * math.pi);
              }
              return Transform.scale(
                scale: (_pressed ? 0.84 : 1.0) * bounce,
                child: child,
              );
            },
            child: inner,
          ),
        ),
      ],
    );
  }
}

class _CheckBurstPainter extends CustomPainter {
  const _CheckBurstPainter({
    required this.t,
    required this.color,
    required this.buttonSize,
    required this.fullBurst,
  });

  final double t;
  final Color color;
  final double buttonSize;
  final bool fullBurst;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    if (opacity <= 0.01) return;

    // 1. Expanding `.tap-ripple` shockwave ring + radial glow
    final ringRadius = (buttonSize * 0.35) + (buttonSize * 1.15) * t;
    final glowRect = Rect.fromCircle(center: center, radius: ringRadius);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.34 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.78],
      ).createShader(glowRect);
    canvas.drawCircle(center, ringRadius, glowPaint);

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.88 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1.0 - t * 0.45);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 2. Radial sparkle particles around check button when completing
    if (fullBurst) {
      const particleCount = 10;
      const palette = [
        Color(0xFF84CC16),
        Color(0xFFFFD426),
        Color(0xFF38BDF8),
        Color(0xFFFF4D8D),
      ];
      for (var i = 0; i < particleCount; i++) {
        final angle = (i / particleCount) * 2 * math.pi + (i.isOdd ? 0.14 : -0.1);
        final dist = buttonSize * (0.45 + 0.98 * t);
        final px = center.dx + math.cos(angle) * dist;
        final py = center.dy + math.sin(angle) * dist;
        final pColor = i % 3 == 0 ? color : palette[i % palette.length];
        final dotR = (2.7 - t * 1.6).clamp(0.8, 3.0);
        canvas.drawCircle(
          Offset(px, py),
          dotR,
          Paint()..color = pColor.withValues(alpha: 0.92 * opacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckBurstPainter old) =>
      old.t != t || old.color != color || old.fullBurst != fullBurst;
}

class _CircleArcPainter extends CustomPainter {
  const _CircleArcPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth * 0.8;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircleArcPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

/// Circular progress ring painter with rounded caps matching prototype `.day-ring-box`.
class DayProgressRing extends StatelessWidget {
  const DayProgressRing({
    required this.progress,
    required this.label,
    required this.active,
    this.size = 42,
    this.strokeWidth = 4.2,
    this.ringColor,
    this.labelStyle,
    super.key,
  });

  final double progress;
  final String label;
  final bool active;
  final double size;
  final double strokeWidth;
  final Color? ringColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final col = ringColor ??
        (active ? xc.lime : xc.lime.withValues(alpha: 0.68));
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        builder: (_, animProgress, child) => CustomPaint(
          painter: _CircleArcPainter(
            progress: animProgress,
            trackColor: xc.card3,
            fillColor: col,
            strokeWidth: strokeWidth,
          ),
          child: child,
        ),
        child: Center(
          child: Text(
            label,
            style: labelStyle ??
                TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                  color: active ? xc.text : xc.muted,
                ),
          ),
        ),
      ),
    );
  }
}

/// Dark `#0F0F12` rounded-16 box matching `.section-box`.
class XSectionBox extends StatelessWidget {
  const XSectionBox({
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(13),
    this.margin,
    super.key,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: xc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: xc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Sleek dark input matching `.dark-field`.
class XDarkField extends StatelessWidget {
  const XDarkField({
    required this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.style,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textAlign: textAlign,
      textDirection: textDirection,
      style: style ??
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: xc.text),
      decoration: InputDecoration(
        filled: true,
        fillColor: xc.fieldBg,
        hintText: hintText,
        hintStyle: TextStyle(color: xc.muted, fontSize: 13.5),
        contentPadding: contentPadding,
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: xc.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: xc.lime, width: 1.3),
        ),
      ),
    );
  }
}

/// Custom modal sheet matching `.modal-sheet` (24px top corners, card bg, 38x4 drag handle).
Future<T?> showXModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.74),
    builder: (ctx) {
      final xc = ctx.xc;
      final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: xc.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: xc.borderStrong)),
        ),
        child: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 22 + viewInsets),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: xc.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                SizedBox(width: double.infinity, child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Centered confirmation bottom sheet matching prototype confirm modals.
Future<bool> showXConfirmSheet({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  Color? iconColor,
  Color? confirmBgColor,
  Color? confirmFgColor,
}) async {
  final xc = context.xc;
  final ic = iconColor ?? const Color(0xFFDC2626);
  final cBg = confirmBgColor ?? const Color(0xFFDC2626);
  final cFg = confirmFgColor ?? Colors.white;
  final res = await showXModalSheet<bool>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: ic.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 21, color: ic),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: xc.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: xc.muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: xc.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cancelLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: xc.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: cBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    confirmLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: cFg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return res == true;
}

/// Floating pill toast matching `.toast` (`#1B1B22` border-999 with optional lime Undo pill).
void showXToast(
  BuildContext context,
  String message, {
  String? undoLabel,
  VoidCallback? onUndo,
  Duration duration = const Duration(milliseconds: 2200),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      duration: onUndo != null ? const Duration(milliseconds: 3400) : duration,
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (undoLabel != null && onUndo != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onUndo();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x2484CC16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      undoLabel,
                      style: const TextStyle(
                        color: Color(0xFF84CC16),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Directional back / forward chevron matching prototype RTL/LTR arrows.
class XNavBackButton extends StatelessWidget {
  const XNavBackButton({
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    super.key,
  });

  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return HdrCircleButton(
      icon: isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      iconSize: 22,
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      onTap: onTap,
    );
  }
}

IconData xForwardChevron(BuildContext context) {
  return Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;
}

/// Custom XHabit modal sheet picker replacing plain Material DropdownButton menus.
Future<String?> showXHabitPickerSheet({
  required BuildContext context,
  required String title,
  required List<Habit> habits,
  required String? selectedId,
}) {
  final xc = context.xc;
  return showXModalSheet<String>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: xc.text,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.46,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final h = habits[i];
              final accent = Color(h.colorValue);
              final selected = h.id == selectedId;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, h.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.12)
                        : xc.card2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected ? accent : xc.border,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          HabitPalette.iconFor(h.iconKey),
                          size: 16,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          h.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: xc.text,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: accent),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Custom XHabit styled 24-hour time selector sheet replacing default Material TimePicker.
Future<TimeOfDay?> showXTimePickerSheet({
  required BuildContext context,
  required String title,
  required TimeOfDay initialTime,
  required String confirmLabel,
  required String localeCode,
}) {
  final xc = context.xc;
  var hour = initialTime.hour;
  var minute = initialTime.minute;

  return showXModalSheet<TimeOfDay>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Widget stepCol(String val, VoidCallback onUp, VoidCallback onDown) {
          return Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: xc.card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: xc.borderStrong),
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onUp,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.keyboard_arrow_up_rounded,
                        size: 24, color: xc.lime),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    AppCalendar.localizeDigits(val, localeCode),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: xc.text,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDown,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 24, color: xc.lime),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  stepCol(
                    hour.toString().padLeft(2, '0'),
                    () => setLocal(() => hour = (hour + 1) % 24),
                    () => setLocal(() => hour = (hour + 23) % 24),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: xc.muted,
                      ),
                    ),
                  ),
                  stepCol(
                    minute.toString().padLeft(2, '0'),
                    () => setLocal(() => minute = (minute + 5) % 60),
                    () => setLocal(() => minute = (minute + 55) % 60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pop(
                  ctx, TimeOfDay(hour: hour, minute: minute)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: xc.lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    color: HabitPalette.contrastFg(xc.lime),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
