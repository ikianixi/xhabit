import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../icons/habit_icons.dart';
import '../theme/app_tokens.dart';
import 'xhabit_ui.dart';

String xColorHex(Color c) {
  final rgb = (c.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
  return '#${rgb.toUpperCase()}';
}

/// Shared Color + Icon selector tiles matching the Add Habit composer.
class XColorIconPickerRow extends StatelessWidget {
  const XColorIconPickerRow({
    required this.color,
    required this.iconKey,
    required this.onTapColor,
    required this.onTapIcon,
    super.key,
  });

  final Color color;
  final String iconKey;
  final VoidCallback onTapColor;
  final VoidCallback onTapIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapColor,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: xc.border),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  l10n.colorLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: xc.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
          GestureDetector(
            onTap: onTapIcon,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: xc.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    HabitPalette.iconFor(iconKey),
                    size: 21,
                    color: xc.text,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  l10n.iconLabel,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: xc.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared 2-row horizontal 64-color palette strip + "+" Color Studio trigger.
class XColorStripPicker extends StatelessWidget {
  const XColorStripPicker({
    required this.selectedColor,
    required this.onSelectColor,
    required this.onOpenStudio,
    super.key,
  });

  final Color selectedColor;
  final ValueChanged<Color> onSelectColor;
  final VoidCallback onOpenStudio;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: xc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: xc.border),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...HabitPalette.paletteColumns.map((pair) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      XColorStripDot(
                        color: pair[0],
                        selected: (selectedColor.toARGB32() & 0x00FFFFFF) ==
                            (pair[0].toARGB32() & 0x00FFFFFF),
                        onTap: () => onSelectColor(pair[0]),
                      ),
                      const SizedBox(height: 10),
                      XColorStripDot(
                        color: pair[1],
                        selected: (selectedColor.toARGB32() & 0x00FFFFFF) ==
                            (pair[1].toARGB32() & 0x00FFFFFF),
                        onTap: () => onSelectColor(pair[1]),
                      ),
                    ],
                  ),
                );
              }),
              GestureDetector(
                onTap: onOpenStudio,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: xc.card2,
                    shape: BoxShape.circle,
                    border: Border.all(color: xc.borderStrong),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, size: 16, color: xc.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class XColorStripDot extends StatelessWidget {
  const XColorStripDot({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? xc.text : xc.border,
            width: selected ? 2.2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: xc.card, spreadRadius: 1)]
              : null,
        ),
      ),
    );
  }
}

Future<String?> showXIconPickerModal(
  BuildContext context, {
  required String currentIconKey,
  required Color accent,
  required bool isFa,
}) async {
  final l10n = AppLocalizations.of(context);
  final xc = context.xc;
  final searchCtrl = TextEditingController();
  String? picked;

  await showXModalSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final q = searchCtrl.text.trim().toLowerCase();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.iconLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 10),
            XDarkField(
              controller: searchCtrl,
              hintText: l10n.searchIconsHint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              onChanged: (_) => setLocal(() {}),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.52,
              ),
              child: Builder(
                builder: (_) {
                  final matchingGroups = HabitPalette.categories
                      .map((group) => (
                            group: group,
                            keys: group.keys
                                .where((k) => q.isEmpty || k.contains(q))
                                .toList(),
                          ))
                      .where((e) => e.keys.isNotEmpty)
                      .toList();
                  if (matchingGroups.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          isFa ? 'آیکونی پیدا نشد' : 'No matching icons',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: xc.muted,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: matchingGroups.map((entry) {
                      final group = entry.group;
                      final list = entry.keys;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFa ? group.nameFa : group.nameEn,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: xc.muted,
                              ),
                            ),
                            const SizedBox(height: 7),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 7,
                                mainAxisSpacing: 7,
                              ),
                              itemCount: list.length,
                              itemBuilder: (_, idx) {
                                final k = list[idx];
                                final active = currentIconKey == k;
                                return GestureDetector(
                                  onTap: () {
                                    picked = k;
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: active
                                          ? accent.withValues(alpha: 0.22)
                                          : xc.card2,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: active ? accent : xc.border,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      HabitPalette.iconFor(k),
                                      size: 21,
                                      color: active ? accent : xc.text,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
  Future.delayed(const Duration(milliseconds: 350), searchCtrl.dispose);
  return picked;
}

Future<Color?> showXColorStudioModal(
  BuildContext context, {
  required Color currentColor,
  required String previewTitle,
  required String iconKey,
  required List<Color> usedColors,
}) async {
  final l10n = AppLocalizations.of(context);
  final xc = context.xc;
  var tab = 'palettes';
  var curColor = currentColor;
  var hsl = HSLColor.fromColor(curColor);
  final hexCtrl = TextEditingController(text: xColorHex(curColor));
  Color? picked;

  await showXModalSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final fg = HabitPalette.contrastFg(curColor);
        const cellPattern = [1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1];

        String toneLabel(String id) {
          switch (id) {
            case 'bright':
              return l10n.toneBright;
            case 'pastel':
              return l10n.tonePastel;
            case 'vivid':
              return l10n.toneVivid;
            default:
              return l10n.toneDeep;
          }
        }

        void pickAndClose(Color c) {
          picked = c;
          Navigator.pop(ctx);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.colorLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.previewLabel,
              style: TextStyle(fontSize: 11, color: xc.muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: xc.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: xc.borderStrong),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            HabitRingIcon(
                              iconKey: iconKey,
                              accent: curColor,
                              outerSize: 34,
                              innerSize: 24,
                              iconSize: 14,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    previewTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: xc.text,
                                    ),
                                  ),
                                  Text(
                                    xColorHex(curColor),
                                    style: TextStyle(
                                        fontSize: 10.5, color: xc.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: curColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.check_rounded, size: 15, color: fg),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: cellPattern
                          .map((on) => Expanded(
                                child: Container(
                                  height: 14,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: on == 1
                                        ? curColor
                                        : curColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(3.5),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setLocal(() => tab = 'palettes'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: tab == 'palettes' ? xc.card3 : xc.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.tabPalettes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tab == 'palettes' ? xc.text : xc.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setLocal(() => tab = 'custom'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: tab == 'custom' ? xc.card3 : xc.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.tabCustom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tab == 'custom' ? xc.text : xc.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (tab == 'palettes') ...[
              if (usedColors.isNotEmpty) ...[
                Text(
                  l10n.usedColors,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: xc.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: usedColors.map((c) {
                    final sel = (c.toARGB32() & 0x00FFFFFF) ==
                        (curColor.toARGB32() & 0x00FFFFFF);
                    return GestureDetector(
                      onTap: () => pickAndClose(c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? xc.text : xc.borderStrong,
                            width: sel ? 2.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: sel
                            ? Icon(Icons.check_rounded,
                                size: 14, color: HabitPalette.contrastFg(c))
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              ...HabitPalette.colorTones.map(
                (grp) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toneLabel(grp.id),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: xc.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                        ),
                        itemCount: grp.colors.length,
                        itemBuilder: (_, idx) {
                          final c = grp.colors[idx];
                          final sel = (c.toARGB32() & 0x00FFFFFF) ==
                              (curColor.toARGB32() & 0x00FFFFFF);
                          return GestureDetector(
                            onTap: () => pickAndClose(c),
                            child: Container(
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel ? xc.text : xc.border,
                                  width: sel ? 2.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: sel
                                  ? Icon(Icons.check_rounded,
                                      size: 13,
                                      color: HabitPalette.contrastFg(c))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _XHslGradientSlider(
                label: l10n.hueLabel,
                value: hsl.hue,
                min: 0,
                max: 360,
                gradientColors: const [
                  Color(0xFFFF4D5A),
                  Color(0xFFFFB830),
                  Color(0xFFFFD426),
                  Color(0xFF4ADE80),
                  Color(0xFF20C9C9),
                  Color(0xFF3898FF),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                  Color(0xFFFF4D5A),
                ],
                onChanged: (v) {
                  setLocal(() {
                    hsl = hsl.withHue(v);
                    curColor = hsl.toColor();
                    hexCtrl.text = xColorHex(curColor);
                  });
                },
              ),
              const SizedBox(height: 10),
              _XHslGradientSlider(
                label: l10n.satLabel,
                value: (hsl.saturation * 100).clamp(10, 100),
                min: 10,
                max: 100,
                gradientColors: [
                  hsl.withSaturation(0.1).toColor(),
                  hsl.withSaturation(1.0).toColor(),
                ],
                onChanged: (v) {
                  setLocal(() {
                    hsl = hsl.withSaturation(v / 100);
                    curColor = hsl.toColor();
                    hexCtrl.text = xColorHex(curColor);
                  });
                },
              ),
              const SizedBox(height: 10),
              _XHslGradientSlider(
                label: l10n.litLabel,
                value: (hsl.lightness * 100).clamp(26, 82),
                min: 26,
                max: 82,
                gradientColors: [
                  hsl.withLightness(0.26).toColor(),
                  hsl.withLightness(0.52).toColor(),
                  hsl.withLightness(0.82).toColor(),
                ],
                onChanged: (v) {
                  setLocal(() {
                    hsl = hsl.withLightness(v / 100);
                    curColor = hsl.toColor();
                    hexCtrl.text = xColorHex(curColor);
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.hexLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: xc.muted,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: XDarkField(
                      controller: hexCtrl,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      onChanged: (val) {
                        final clean = val.trim().replaceAll('#', '');
                        if (clean.length == 6) {
                          final parsed = int.tryParse('FF$clean', radix: 16);
                          if (parsed != null) {
                            setLocal(() {
                              curColor = Color(parsed);
                              hsl = HSLColor.fromColor(curColor);
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => pickAndClose(curColor),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: xc.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.applyColor,
                    style: TextStyle(
                      color: HabitPalette.contrastFg(xc.lime),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
  Future.delayed(const Duration(milliseconds: 350), hexCtrl.dispose);
  return picked;
}

class _XHslGradientSlider extends StatelessWidget {
  const _XHslGradientSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.gradientColors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final List<Color> gradientColors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: xc.muted,
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(colors: gradientColors),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 12,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                min: min,
                max: max,
                value: value.clamp(min, max),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
