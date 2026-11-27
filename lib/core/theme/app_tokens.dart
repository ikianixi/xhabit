import 'package:flutter/material.dart';

/// Exact color tokens matching the finalized XHabit OLED Dark & Light themes.
class XColors {
  const XColors({
    required this.isDark,
    required this.bg,
    required this.fieldBg,
    required this.card,
    required this.card2,
    required this.card3,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.dim,
    required this.lime,
    required this.cellFuture,
    required this.detailBox,
  });

  final bool isDark;
  final Color bg;
  final Color fieldBg;
  final Color card;
  final Color card2;
  final Color card3;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color muted;
  final Color dim;
  final Color lime;
  final Color cellFuture;
  final Color detailBox;

  static const oled = XColors(
    isDark: true,
    bg: Color(0xFF000000),
    fieldBg: Color(0xFF070709),
    card: Color(0xFF0F0F12),
    card2: Color(0xFF17171C),
    card3: Color(0xFF222229),
    border: Color(0x11FFFFFF),
    borderStrong: Color(0x24FFFFFF),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF9393A0),
    dim: Color(0xFF5B5B67),
    lime: Color(0xFF84CC16),
    cellFuture: Color(0x08FFFFFF),
    detailBox: Color(0x4D000000),
  );

  static const light = XColors(
    isDark: false,
    bg: Color(0xFFF4F5F9),
    fieldBg: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFEEF0F6),
    card3: Color(0xFFE2E5EF),
    border: Color(0x140F172A),
    borderStrong: Color(0x290F172A),
    text: Color(0xFF0F172A),
    muted: Color(0xFF475569),
    dim: Color(0xFF64748B),
    lime: Color(0xFF4D7C0F),
    cellFuture: Color(0x0C0F172A),
    detailBox: Color(0xB8FFFFFF),
  );

  static XColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? oled : light;
  }
}

extension XColorsBuildContext on BuildContext {
  XColors get xc => XColors.of(this);
}
