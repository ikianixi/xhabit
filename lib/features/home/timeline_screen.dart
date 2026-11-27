import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../habits/habit_details_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingNoteId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(HabitNote note) async {
    if (_playingNoteId == note.id) {
      await _player.stop();
      if (mounted) setState(() => _playingNoteId = null);
      return;
    }
    try {
      await _player.stop();
      await _player.setFilePath(note.content);
      if (!mounted) return;
      setState(() => _playingNoteId = note.id);
      await _player.play();
      if (mounted && _playingNoteId == note.id) {
        setState(() => _playingNoteId = null);
      }
    } catch (_) {
      if (mounted && _playingNoteId == note.id) {
        setState(() => _playingNoteId = null);
      }
    }
  }

  Future<void> _confirmDeleteNote(HabitNote note) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showXConfirmSheet(
      context: context,
      icon: Icons.delete_rounded,
      title: l10n.deleteAttachmentTitle,
      message: l10n.deleteAttachmentMsg,
      cancelLabel: l10n.noCancel,
      confirmLabel: l10n.yesDelete,
    );
    if (!ok || !mounted) return;
    if (_playingNoteId == note.id) {
      await _player.stop();
      _playingNoteId = null;
    }
    await ref.read(habitStateProvider.notifier).deleteNote(note.id);
    if (mounted) showXToast(context, l10n.noteDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final stateAsync = ref.watch(habitStateProvider);
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final dateSub = AppCalendar.monthDayLabel(
        today, settings.calendarSystem, settings.localeCode);

    return Scaffold(
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (st) {
            final active = st.habits.where((h) => !h.isArchived).toList();
            var wkSched = 0;
            var wkDoneSum = 0.0;
            final dayScores = <({int weekday, int pct})>[];
            for (var i = 6; i >= 0; i--) {
              final d = DateTime(today.year, today.month, today.day - i);
              final dk = AppCalendar.toDateKey(d);
              var sCnt = 0;
              var dRatioSum = 0.0;
              for (final h in active) {
                if (HabitEngine.isPausedOn(h.id, d, st.pauses)) continue;
                final items = st.checklistFor(h.id);
                final byDate = st.completionsByDateFor(h.id);
                if (HabitEngine.isScheduledOn(
                  h,
                  d,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  completionsByDate: byDate,
                  checklistItems: items,
                  today: today,
                )) {
                  sCnt++;
                  dRatioSum += HabitEngine.progressRatio(
                    h,
                    byDate[dk],
                    items,
                    d,
                    today: today,
                  );
                }
              }
              wkSched += sCnt;
              wkDoneSum += dRatioSum;
              dayScores.add((
                weekday: d.weekday,
                pct: sCnt > 0 ? ((dRatioSum / sCnt) * 100).round() : 0,
              ));
            }
            final wkPct =
                wkSched > 0 ? ((wkDoneSum / wkSched) * 100).round() : 0;
            final wkDone = wkDoneSum.round();
            final bestD = dayScores.reduce((a, b) => b.pct > a.pct ? b : a);
            final bestDayName =
                AppCalendar.weekdayFull(bestD.weekday, settings.localeCode);

            final streakItems = active.take(3).map((h) {
              final stats = HabitEngine.computeStats(
                h,
                st.completionsByDateFor(h.id),
                st.checklistFor(h.id),
                calendar: settings.calendarSystem,
                weekStart: settings.weekStartDay,
                today: today,
                pauses: st.pauses,
                monthlyGraceDays: settings.streakGraceDaysPerMonth,
              );
              return (habit: h, streak: stats.currentStreak);
            }).toList();

            return ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                // 1. Header Row (`.hdr-row`)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: settings.localeCode == 'fa'
                                  ? 'Vazirmatn'
                                  : 'FiraSans',
                              fontFamilyFallback: const ['Vazirmatn', 'FiraSans'],
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: xc.text,
                            ),
                            children: [
                              TextSpan(text: '${l10n.today} '),
                              TextSpan(
                                text: dateSub,
                                style: TextStyle(
                                  color: xc.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          HdrCircleButton(
                            size: 39,
                            iconSize: 19.5,
                            icon: Icons.note_add_outlined,
                            onTap: () {
                              if (active.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => NoteEditorPage(
                                    habit: active.first,
                                    settings: settings,
                                    showHabitPicker: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          HdrCircleButton(
                            size: 39,
                            iconSize: 19.5,
                            icon: Icons.settings_rounded,
                            onTap: widget.onOpenSettings,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Weekly Summary Card
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: xc.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: xc.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.weeklySummaryTitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: xc.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  AppCalendar.localizeDigits(
                                      '$wkPct%', settings.localeCode),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: xc.lime,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppCalendar.localizeDigits(
                                      '($wkDone/$wkSched)',
                                      settings.localeCode),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: xc.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: settings.localeCode == 'fa'
                                      ? 'Vazirmatn'
                                      : 'FiraSans',
                                  fontFamilyFallback: const [
                                    'Vazirmatn',
                                    'FiraSans',
                                  ],
                                  fontSize: 11,
                                  color: xc.muted,
                                ),
                                children: [
                                  TextSpan(text: '${l10n.bestDayPrefix} '),
                                  TextSpan(
                                    text:
                                        '$bestDayName (${AppCalendar.localizeDigits('${bestD.pct}%', settings.localeCode)})',
                                    style: TextStyle(
                                      color: xc.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 38,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: dayScores.map((ds) {
                            final hPct = (ds.pct / 100.0).clamp(0.16, 1.0);
                            return Container(
                              width: 8,
                              height: 38 * hPct,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: ds.pct >= 100
                                    ? xc.lime
                                    : ds.pct > 0
                                        ? xc.lime.withValues(alpha: 0.55)
                                        : xc.card3,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Centered Month Title (`.tl-month`)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    AppCalendar.formatMonthYear(
                        today, settings.calendarSystem, settings.localeCode),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: xc.text,
                    ),
                  ),
                ),

                // 4. Vertical Timeline Rail (`.tl-rail`)
                if (st.notes.isEmpty && streakItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Center(
                      child: Text(
                        l10n.noHabitsYet,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: xc.muted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Stack(
                      children: [
                        Positioned.directional(
                          textDirection: Directionality.of(context),
                          start: 16,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: xc.card3),
                        ),
                        Column(
                          children: [
                            ...st.notes.map((n) {
                              final h = st.habits
                                  .where((x) => x.id == n.habitId)
                                  .firstOrNull;
                              if (h == null) return const SizedBox.shrink();
                              return TimelineRailNoteRow(
                                habit: h,
                                note: n,
                                playing: _playingNoteId == n.id,
                                settings: settings,
                                onTogglePlay: () => _toggleAudio(n),
                                onDelete: () => _confirmDeleteNote(n),
                                onEditText: n.kind == NoteKind.text
                                    ? () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => NoteEditorPage(
                                              habit: h,
                                              settings: settings,
                                              existingNote: n,
                                            ),
                                          ),
                                        )
                                    : null,
                                onOpenPhoto: n.kind == NoteKind.image
                                    ? () => showTimelinePhotoPreview(
                                        context, h, n, () => _confirmDeleteNote(n))
                                    : null,
                              );
                            }),
                            ...streakItems.map((entry) {
                              final h = entry.habit;
                              final accent = Color(h.colorValue);
                              return TimelineRailBadgeRow(
                                habit: h,
                                backgroundColor: accent.withValues(alpha: 0.10),
                                textColor: accent,
                                icon: Icons.local_fire_department_rounded,
                                label: AppCalendar.localizeDigits(
                                  '${h.title} - ${l10n.daysUnit(entry.streak)}',
                                  settings.localeCode,
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        HabitDetailsScreen(habitId: h.id),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shared timeline note row matching `.tl-note-card` + `.tl-dot`.
class TimelineRailNoteRow extends StatelessWidget {
  const TimelineRailNoteRow({
    required this.habit,
    required this.note,
    required this.playing,
    required this.settings,
    required this.onTogglePlay,
    required this.onDelete,
    this.onEditText,
    this.onOpenPhoto,
    super.key,
  });

  final Habit habit;
  final HabitNote note;
  final bool playing;
  final AppSettings settings;
  final VoidCallback onTogglePlay;
  final VoidCallback onDelete;
  final VoidCallback? onEditText;
  final VoidCallback? onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final accent = Color(habit.colorValue);
    final dateStr = AppCalendar.monthDayLabel(
      AppCalendar.parseDateKey(note.dateKey),
      settings.calendarSystem,
      settings.localeCode,
    );
    const waveHeights = [
      0.40, 0.80, 0.35, 0.95, 0.60, 0.75, 0.45, 0.90, 0.55, 0.70, 0.40, 0.85,
      0.50, 0.65
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: xc.bg,
                  spreadRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              HabitPalette.iconFor(habit.iconKey),
              size: 16,
              color: HabitPalette.contrastFg(accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onEditText,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: xc.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: xc.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            habit.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: xc.muted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: onDelete,
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 15,
                                  color: xc.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (note.title.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: xc.text,
                        ),
                      ),
                    ],
                    if (note.kind == NoteKind.text && note.content.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        note.content,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: xc.muted,
                          height: 1.55,
                        ),
                      ),
                    ],
                    if (note.kind == NoteKind.image &&
                        File(note.content).existsSync()) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onOpenPhoto,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(note.content),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    if (note.kind == NoteKind.audio) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: onTogglePlay,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 16,
                                  color: HabitPalette.contrastFg(accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 20,
                                child: Row(
                                  children: waveHeights
                                      .map((p) => Expanded(
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 1.5),
                                              height: 20 * p,
                                              decoration: BoxDecoration(
                                                color: playing ? accent : xc.dim,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppCalendar.localizeDigits(
                                _formatSec(note.durationMs),
                                settings.localeCode,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: xc.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSec(int ms) {
    final s = (ms / 1000).ceil();
    final m = s ~/ 60;
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$m:$rem';
  }
}

/// Shared timeline badge row (`.tl-item` + `.tl-dot`).
class TimelineRailBadgeRow extends StatelessWidget {
  const TimelineRailBadgeRow({
    required this.habit,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Habit habit;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final accent = Color(habit.colorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: xc.bg, spreadRadius: 4)],
            ),
            alignment: Alignment.center,
            child: Icon(
              HabitPalette.iconFor(habit.iconKey),
              size: 16,
              color: HabitPalette.contrastFg(accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 15, color: textColor),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        trailing!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: xc.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTimelinePhotoPreview(
  BuildContext context,
  Habit habit,
  HabitNote note,
  VoidCallback onDelete,
) async {
  final xc = context.xc;
  await showXModalSheet<void>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                note.title.isEmpty ? habit.title : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: xc.text,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
              child: const Icon(Icons.delete_rounded,
                  size: 18, color: Color(0xFFEF4444)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (File(note.content).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(note.content),
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
      ],
    ),
  );
}
