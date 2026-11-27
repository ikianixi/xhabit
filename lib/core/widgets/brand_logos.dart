import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Official 4-color Google "G" logo rendered with crisp vector geometry.
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final outerR = math.min(w, h) * 0.46;
    final strokeW = outerR * 0.42;
    final arcRect = Rect.fromCircle(center: center, radius: outerR - strokeW / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Red top arc (-145 deg to -38 deg)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      arcRect,
      -148 * math.pi / 180,
      112 * math.pi / 180,
      false,
      paint,
    );

    // Yellow left arc (145 deg to 215 deg)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      arcRect,
      142 * math.pi / 180,
      72 * math.pi / 180,
      false,
      paint,
    );

    // Green bottom arc (35 deg to 145 deg)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      arcRect,
      36 * math.pi / 180,
      108 * math.pi / 180,
      false,
      paint,
    );

    // Blue right-bottom arc (-4 deg to 40 deg)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      arcRect,
      -4 * math.pi / 180,
      44 * math.pi / 180,
      false,
      paint,
    );

    // Blue horizontal crossbar of "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final barTop = center.dy - strokeW * 0.46;
    final barBottom = center.dy + strokeW * 0.46;
    final barLeft = center.dx - strokeW * 0.08;
    final barRight = center.dx + outerR;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
        topRight: Radius.circular(strokeW * 0.12),
        bottomRight: Radius.circular(strokeW * 0.12),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Obsidian faceted crystal logo rendered with crisp vector facets.
class ObsidianLogoIcon extends StatelessWidget {
  const ObsidianLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ObsidianLogoPainter()),
    );
  }
}

class _ObsidianLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Offset p(double x, double y) => Offset(x * w, y * h);

    // Key vertices of the faceted Obsidian crystal
    final top = p(0.64, 0.04);
    final topLeft = p(0.28, 0.18);
    final midLeft = p(0.16, 0.56);
    final bottom = p(0.46, 0.96);
    final bottomRight = p(0.84, 0.72);
    final midRight = p(0.82, 0.34);
    final innerCenter = p(0.54, 0.48);
    final innerLower = p(0.49, 0.72);

    void drawFacet(List<Offset> pts, Color color) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    // Facet 1: Top-left bright highlight
    drawFacet([topLeft, top, innerCenter], const Color(0xFFA88BFA));
    // Facet 2: Upper-right medium violet
    drawFacet([top, midRight, innerCenter], const Color(0xFF7C3AED));
    // Facet 3: Mid-left deep violet
    drawFacet([topLeft, innerCenter, innerLower, midLeft], const Color(0xFF5B21B6));
    // Facet 4: Bottom-left dark shadow
    drawFacet([midLeft, innerLower, bottom], const Color(0xFF4C1D95));
    // Facet 5: Right bright highlight
    drawFacet([innerCenter, midRight, bottomRight, innerLower], const Color(0xFF8B5CF6));
    // Facet 6: Bottom-right royal purple
    drawFacet([innerLower, bottomRight, bottom], const Color(0xFF6D28D9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google Sign-In button following Google Identity Branding Guidelines.
class OfficialGoogleSignInButton extends StatelessWidget {
  const OfficialGoogleSignInButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF131314) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF8E918F) : const Color(0xFF747775);
    final textColor =
        isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF4285F4),
                  ),
                )
              else
                const GoogleLogoIcon(size: 19),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
