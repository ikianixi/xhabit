import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../home/timeline_screen.dart';
import 'add_edit_habit_screen.dart';

class HabitDetailsScreen extends ConsumerStatefulWidget {
  const HabitDetailsScreen({
    required this.habitId,
    this.openAchievementsOnStart = false,
    this.initialDate,
    super.key,
  });

  final String habitId;
  final bool openAchievementsOnStart;
  final DateTime? initialDate;

  @override
  ConsumerState<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends ConsumerState<HabitDetailsScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _playingNoteId;
  bool _openedInitialAch = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAchievementsOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openedInitialAch) return;
        final st = ref.read(habitStateProvider).value;
        final h = st?.habits.where((x) => x.id == widget.habitId).firstOrNull;
        if (st != null && h != null) {
          _openedInitialAch = true;
          final settings =
              ref.read(settingsProvider).value ?? const AppSettings();
          final today = AppCalendar.logicalToday(
              DateTime.now(), settings.dayResetMinutes);
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
          _openAchievements(stats, settings);
        }
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _openNoteEditor(
    Habit habit,
    AppSettings settings, {
    HabitNote? existingNote,
    DateTime? initialDate,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(
          habit: habit,
          settings: settings,
          existingNote: existingNote,
          initialDate: initialDate,
        ),
      ),
    );
  }

  Future<void> _openPhotoOptions(Habit habit, DateTime activeDate) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final notifier = ref.read(habitStateProvider.notifier);
    final source = await showXModalSheet<ImageSource>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.optionsTitle,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 16),
          _OptionCardButton(
            icon: Icons.photo_camera_outlined,
            label: l10n.takePhoto,
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _OptionCardButton(
            icon: Icons.photo_library_outlined,
            label: l10n.fromGallery,
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final mediaDir = Directory(p.join(dir.path, 'xhabit_media'));
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    final dest = p.join(
      mediaDir.path,
      'img_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}',
    );
    await File(picked.path).copy(dest);
    if (!mounted) return;
    await notifier.saveNote(
      habitId: habit.id,
      date: activeDate,
      kind: NoteKind.image,
      title: p.basename(picked.path),
      content: dest,
    );
  }

  Future<void> _openVoiceSheet(
    Habit habit,
    AppSettings settings,
    DateTime activeDate,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final notifier = ref.read(habitStateProvider.notifier);
    final accent = Color(habit.colorValue);
    final fg = HabitPalette.contrastFg(accent);
    var recording = false;
    var starting = false;
    var stopping = false;
    var sec = 0;
    Timer? timer;

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final timeTxt = AppCalendar.localizeDigits(
            '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}',
            settings.localeCode,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.voiceNoteTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                ),
                const SizedBox(height: 14),
                if (recording)
                  Text(
                    timeTxt,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  )
                else
                  const SizedBox(height: 10),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    if (stopping || starting) return;
                    if (!recording) {
                      starting = true;
                      try {
                        if (!await _recorder.hasPermission() || !ctx.mounted) {
                          return;
                        }
                        final dir = await getApplicationDocumentsDirectory();
                        if (!ctx.mounted) return;
                        final mediaDir =
                            Directory(p.join(dir.path, 'xhabit_media'));
                        if (!await mediaDir.exists()) {
                          await mediaDir.create(recursive: true);
                        }
                        if (!ctx.mounted) return;
                        final outPath = p.join(
                          mediaDir.path,
                          'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
                        );
                        await _recorder.start(const RecordConfig(),
                            path: outPath);
                        if (!ctx.mounted) {
                          try {
                            await _recorder.stop();
                          } catch (_) {}
                          return;
                        }
                        setLocal(() {
                          recording = true;
                          sec = 0;
                        });
                        timer =
                            Timer.periodic(const Duration(seconds: 1), (_) {
                          if (ctx.mounted) setLocal(() => sec++);
                        });
                      } finally {
                        starting = false;
                      }
                    } else {
                      stopping = true;
                      recording = false;
                      timer?.cancel();
                      try {
                        final path = await _recorder.stop();
                        final dur = (sec <= 0 ? 1 : sec) * 1000;
                        if (path != null && path.isNotEmpty) {
                          await notifier.saveNote(
                            habitId: habit.id,
                            date: activeDate,
                            kind: NoteKind.audio,
                            title: l10n.voiceNoteTitle,
                            content: path,
                            durationMs: dur,
                          );
                        }
                      } finally {
                        stopping = false;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: recording ? 92 : 84,
                        height: recording ? 92 : 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accent.withValues(
                                alpha: recording ? 0.55 : 0.25),
                            width: recording ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: recording ? 26 : 28,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  recording ? l10n.tapToStop : l10n.tapToRecord,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: xc.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    timer?.cancel();
    if (recording && mounted) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
  }

  Future<void> _openAchievements(HabitStats st, AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.achievementsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            childAspectRatio: 0.56,
            physics: const NeverScrollableScrollPhysics(),
            children: HabitEngine.achievementTiers.map((t) {
              final ok = st.bestStreak >= t.days;
              final name = settings.localeCode == 'fa' ? t.nameFa : t.nameEn;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MedalBadge(days: t.days, unlocked: ok, size: 62),
                  const SizedBox(height: 5),
                  Text(
                    AppCalendar.localizeDigits(
                      l10n.daysUnit(t.days),
                      settings.localeCode,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: xc.text,
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ok ? t.badgeColor : xc.dim,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _openBackdateCalendar(
    Habit habit,
    List<HabitChecklistItem> items,
    AppSettings settings,
  ) async {
    var offset = 0;
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) => StatefulBuilder(
          builder: (ctx, setLocal) {
            final st = cRef.watch(habitStateProvider).value;
          final byDate = st?.completionsByDateFor(habit.id) ?? const {};
          final anchor =
              AppCalendar.shiftMonth(today, offset, settings.calendarSystem);
          final cells = AppCalendar.monthGridDates(
              anchor, settings.calendarSystem, settings.weekStartDay);
          final order = AppCalendar.orderedWeekdays(settings.weekStartDay);
          final accent = Color(habit.colorValue);
          final isRtl = Directionality.of(ctx) == TextDirection.rtl;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setLocal(() => offset--),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          isRtl
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                    ),
                    Text(
                      AppCalendar.formatMonthYear(
                          anchor, settings.calendarSystem, settings.localeCode),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setLocal(() => offset++),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          isRtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: order
                    .map((w) => Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                AppCalendar.weekdayShort(
                                    w, settings.localeCode),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: xc.muted,
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 6,
                ),
                itemCount: cells.length,
                itemBuilder: (_, i) {
                  final d = cells[i];
                  if (d == null) return const SizedBox.shrink();
                  final fut = d.isAfter(today);
                  final dk = AppCalendar.toDateKey(d);
                  final ok = !fut &&
                      HabitEngine.isCompletedOn(habit, byDate[dk], items, d,
                          today: today);
                  return GestureDetector(
                    onTap: fut
                        ? null
                        : () async {
                            await ref
                                .read(habitStateProvider.notifier)
                                .toggleOrStepHabit(habit, d);
                            await SoundService.instance.play(
                              ok ? ChimeKind.undo : ChimeKind.done,
                              enabled: settings.isAchievementSoundEnabled,
                              profile: settings.soundProfile,
                            );
                            if (ctx.mounted) setLocal(() {});
                          },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ok
                            ? accent.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: ok ? accent : Colors.transparent,
                          width: 1.8,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        AppCalendar.localizeDigits(
                          '${AppCalendar.dayNumberInCalendar(d, settings.calendarSystem)}',
                          settings.localeCode,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: ok ? FontWeight.w800 : FontWeight.w700,
                          color: fut
                              ? xc.dim.withValues(alpha: 0.38)
                              : xc.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  Future<void> _openAnalytics(
    Habit habit,
    HabitStats st,
    Map<String, HabitCompletion> byDate,
    List<HabitChecklistItem> items,
    List<HabitPause> pauses,
    AppSettings settings,
    int attachCount,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    var win = 30;
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final startDate = AppCalendar.parseDateKey(habit.startDateKey);
    final accent = Color(habit.colorValue);
    final fg = HabitPalette.contrastFg(accent);

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          var schedCur = 0;
          var doneCur = 0;
          var sumValCur = 0;
          var schedPrev = 0;
          var donePrev = 0;
          for (var i = 0; i < win; i++) {
            final dC = DateTime(today.year, today.month, today.day - i);
            if (!dC.isBefore(startDate) &&
                !HabitEngine.isPausedOn(habit.id, dC, pauses)) {
              final kC = AppCalendar.toDateKey(dC);
              if (HabitEngine.isScheduledOn(habit, dC,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  completionsByDate: byDate,
                  checklistItems: items,
                  today: today)) {
                schedCur++;
                if (HabitEngine.isCompletedOn(habit, byDate[kC], items, dC,
                    today: today)) {
                  doneCur++;
                }
              }
              if (habit.trackingStyle == TrackingStyle.count) {
                sumValCur += byDate[kC]?.value ?? 0;
              } else {
                sumValCur += HabitEngine.isCompletedOn(
                        habit, byDate[kC], items, dC,
                        today: today)
                    ? 1
                    : 0;
              }
            }

            final dP = DateTime(today.year, today.month, today.day - (i + win));
            if (!dP.isBefore(startDate) &&
                !HabitEngine.isPausedOn(habit.id, dP, pauses)) {
              final kP = AppCalendar.toDateKey(dP);
              if (HabitEngine.isScheduledOn(habit, dP,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  completionsByDate: byDate,
                  checklistItems: items,
                  today: today)) {
                schedPrev++;
                if (HabitEngine.isCompletedOn(habit, byDate[kP], items, dP,
                    today: today)) {
                  donePrev++;
                }
              }
            }
          }
          final rateCur =
              schedCur == 0 ? 0 : ((doneCur / schedCur) * 100).round();
          final ratePrev =
              schedPrev == 0 ? rateCur : ((donePrev / schedPrev) * 100).round();
          final delta = rateCur - ratePrev;

          // 1-day recovery rate over 90 days
          var misses = 0;
          var bounce = 0;
          for (var i = 89; i >= 1; i--) {
            final d0 = DateTime(today.year, today.month, today.day - i);
            final d1 = DateTime(today.year, today.month, today.day - (i - 1));
            if (d0.isBefore(startDate) ||
                HabitEngine.isPausedOn(habit.id, d0, pauses) ||
                HabitEngine.isPausedOn(habit.id, d1, pauses)) {
              continue;
            }
            if (HabitEngine.isScheduledOn(habit, d0,
                    calendar: settings.calendarSystem,
                    weekStart: settings.weekStartDay,
                    completionsByDate: byDate,
                    checklistItems: items,
                    today: today) &&
                !HabitEngine.isCompletedOn(
                    habit, byDate[AppCalendar.toDateKey(d0)], items, d0,
                    today: today)) {
              misses++;
              if (HabitEngine.isCompletedOn(
                  habit, byDate[AppCalendar.toDateKey(d1)], items, d1,
                  today: today)) {
                bounce++;
              }
            }
          }
          final recoveryRate =
              misses == 0 ? 100 : ((bounce / misses) * 100).round();

          // 90D Weekday consistency aligned to weekStartDay
          final order = AppCalendar.orderedWeekdays(settings.weekStartDay);
          final wdStats = order.map((w) {
            var tot = 0;
            var ok = 0;
            for (var i = 0; i < 90; i++) {
              final d = DateTime(today.year, today.month, today.day - i);
              if (d.weekday == w) {
                tot++;
                if (HabitEngine.isCompletedOn(
                    habit, byDate[AppCalendar.toDateKey(d)], items, d,
                    today: today)) {
                  ok++;
                }
              }
            }
            return (weekday: w, pct: tot == 0 ? 0 : ((ok / tot) * 100).round());
          }).toList();
          final bestWd = wdStats.reduce((a, b) => b.pct > a.pct ? b : a);
          final weakWd = wdStats.reduce((a, b) => b.pct < a.pct ? b : a);
          final bestWdName =
              AppCalendar.weekdayFull(bestWd.weekday, settings.localeCode);
          final weakWdName =
              AppCalendar.weekdayFull(weakWd.weekday, settings.localeCode);

          // Trend bars
          final trendPcts = <int>[];
          if (win == 90) {
            for (var b = 14; b >= 0; b--) {
              var s = 0.0;
              for (var j = 0; j < 6; j++) {
                final d =
                    DateTime(today.year, today.month, today.day - (b * 6 + j));
                s += HabitEngine.progressRatio(
                    habit, byDate[AppCalendar.toDateKey(d)], items, d,
                    today: today);
              }
              trendPcts.add(((s / 6) * 100).round());
            }
          } else {
            for (var i = win - 1; i >= 0; i--) {
              final d = DateTime(today.year, today.month, today.day - i);
              final r = HabitEngine.progressRatio(
                  habit, byDate[AppCalendar.toDateKey(d)], items, d,
                  today: today);
              trendPcts.add((r * 100).round());
            }
          }

          final insight = weakWd.pct < 55
              ? l10n.analyticsInsightSlip(
                  weakWdName, weakWd.pct, bestWdName, bestWd.pct)
              : (delta > 0
                  ? l10n.analyticsInsightClimb(delta, recoveryRate)
                  : l10n.analyticsInsightSteady(
                      rateCur, bestWdName, recoveryRate));

          final midVal = habit.trackingStyle == TrackingStyle.count
              ? AppCalendar.localizeDigits(
                  (sumValCur / win).toStringAsFixed(1), settings.localeCode)
              : AppCalendar.localizeDigits('$recoveryRate%', settings.localeCode);
          final midLbl = habit.trackingStyle == TrackingStyle.count
              ? l10n.dailyAverage
              : l10n.bounceBack;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(HabitPalette.iconFor(habit.iconKey),
                              size: 16, color: fg),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.analyticsTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: xc.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        (14, l10n.range14D),
                        (30, l10n.range30D),
                        (90, l10n.range90D),
                      ].map((pair) {
                        final on = win == pair.$1;
                        return GestureDetector(
                          onTap: () => setLocal(() => win = pair.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: on ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              pair.$2,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: on ? fg : xc.muted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hero card (`.an-card` + `.an-hero`)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: xc.border),
                ),
                child: Row(
                  children: [
                    DayProgressRing(
                      progress: rateCur / 100.0,
                      active: true,
                      size: 66,
                      strokeWidth: 6,
                      ringColor: accent,
                      label: AppCalendar.localizeDigits(
                          '$rateCur%', settings.localeCode),
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: xc.text,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.scheduledRate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: xc.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppCalendar.localizeDigits(
                              '$doneCur / $schedCur (${l10n.daysUnit(schedCur)})',
                              settings.localeCode,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: xc.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: delta >= 0
                                  ? const Color(0x2984CC16)
                                  : const Color(0x29EF4444),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppCalendar.localizeDigits(
                                '${delta >= 0 ? '▲' : '▼'} ${delta.abs()}% ${l10n.vsPrevPeriod}',
                                settings.localeCode,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: delta >= 0
                                    ? const Color(0xFF84CC16)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4 KPI mini-boxes (`.an-kpis`)
              Row(
                children: [
                  _AnKpiBox(
                    value: AppCalendar.localizeDigits(
                        '${st.currentStreak}', settings.localeCode),
                    label: l10n.currentStreak,
                    valueColor: accent,
                  ),
                  const SizedBox(width: 7),
                  _AnKpiBox(
                    value: AppCalendar.localizeDigits(
                        '${st.bestStreak}', settings.localeCode),
                    label: l10n.bestStreak,
                  ),
                  const SizedBox(width: 7),
                  _AnKpiBox(value: midVal, label: midLbl),
                  const SizedBox(width: 7),
                  _AnKpiBox(
                    value: AppCalendar.localizeDigits(
                        '$attachCount', settings.localeCode),
                    label: l10n.logsCountLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Trend Bars Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: xc.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.trendTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: xc.text,
                          ),
                        ),
                        Text(
                          AppCalendar.localizeDigits(
                            '${l10n.avgScoreShort} ${st.habitScore}%',
                            settings.localeCode,
                          ),
                          style: TextStyle(fontSize: 11, color: xc.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 68,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: trendPcts.map((pct) {
                          final col = pct >= 80
                              ? accent
                              : pct > 0
                                  ? accent.withValues(alpha: 0.55)
                                  : accent.withValues(alpha: 0.14);
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: win > 20 ? 1.2 : 2.2),
                              height: (68 * (pct.clamp(8, 100) / 100.0)),
                              decoration: BoxDecoration(
                                color: col,
                                borderRadius:
                                    BorderRadius.circular(win > 20 ? 2 : 4),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Weekday Consistency Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: xc.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.weekdayConsistency,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: xc.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: wdStats.map((w) {
                        final isBest = w.weekday == bestWd.weekday;
                        final isWeak =
                            w.weekday == weakWd.weekday && w.pct < bestWd.pct;
                        final col = isBest
                            ? accent
                            : isWeak
                                ? const Color(0xFFF59E0B)
                                : accent.withValues(alpha: 0.45);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              children: [
                                Text(
                                  AppCalendar.localizeDigits(
                                      '${w.pct}%', settings.localeCode),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isBest
                                        ? accent
                                        : isWeak
                                            ? const Color(0xFFF59E0B)
                                            : xc.muted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 64,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: xc.card,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        (w.pct.clamp(10, 100) / 100.0),
                                    widthFactor: 1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: col,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  AppCalendar.weekdayMin(
                                      w.weekday, settings.localeCode),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isBest ? xc.text : xc.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: xc.border),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            AppCalendar.localizeDigits(
                              '${l10n.strongestDay} $bestWdName (${bestWd.pct}%)',
                              settings.localeCode,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            AppCalendar.localizeDigits(
                              '${l10n.weakestDay} $weakWdName (${weakWd.pct}%)',
                              settings.localeCode,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Smart Insight Tinted Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.smartInsight,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppCalendar.localizeDigits(insight, settings.localeCode),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: xc.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openHabitMenu(Habit habit) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final items = ref.read(habitStateProvider).value?.checklistFor(habit.id) ??
        const <HabitChecklistItem>[];
    final accent = Color(habit.colorValue);

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetMenuRow(
            label: l10n.showMedalBadgeTitle,
            trailing: Icon(
              habit.showTitleBadge
                  ? Icons.workspace_premium_rounded
                  : Icons.workspace_premium_outlined,
              size: 18,
              color: habit.showTitleBadge ? accent : xc.muted,
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(habitStateProvider.notifier).saveHabit(
                  habit.copyWith(showTitleBadge: !habit.showTitleBadge), items);
            },
          ),
          const SizedBox(height: 8),
          _SheetMenuRow(
            label: l10n.editHabit,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AddEditHabitScreen(habit: habit),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _SheetMenuRow(
            label: l10n.archive,
            onTap: () async {
              final notifier = ref.read(habitStateProvider.notifier);
              Navigator.pop(ctx);
              await notifier.toggleArchiveHabit(habit);
              if (mounted) {
                showXToast(
                  context,
                  '${habit.title} • ${l10n.movedToArchive}',
                  undoLabel: l10n.undo,
                  onUndo: () => notifier
                      .toggleArchiveHabit(habit.copyWith(isArchived: true)),
                );
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 8),
          _SheetMenuRow(
            label: l10n.delete,
            textColor: const Color(0xFFEF4444),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showXConfirmSheet(
                context: context,
                icon: Icons.delete_rounded,
                title: l10n.delete,
                message: l10n.deleteHabitConfirm,
                cancelLabel: l10n.noCancel,
                confirmLabel: l10n.yesDelete,
              );
              if (ok && mounted) {
                await ref
                    .read(habitStateProvider.notifier)
                    .deleteHabit(habit.id);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNoteConfirm(HabitNote note) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showXConfirmSheet(
      context: context,
      icon: Icons.delete_rounded,
      title: l10n.deleteAttachmentTitle,
      message: l10n.deleteAttachmentMsg,
      cancelLabel: l10n.noCancel,
      confirmLabel: l10n.yesDelete,
    );
    if (ok && mounted) {
      if (_playingNoteId == note.id) {
        try {
          await _player.stop();
        } catch (_) {}
        _playingNoteId = null;
      }
      if (!mounted) return;
      await ref.read(habitStateProvider.notifier).deleteNote(note.id);
      if (mounted) showXToast(context, l10n.noteDeleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final stateAsync = ref.watch(habitStateProvider);
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final activeDate = AppCalendar.normalizeDate(widget.initialDate ?? today);
    final activeKey = AppCalendar.toDateKey(activeDate);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (st) {
          final h = st.habits.where((x) => x.id == widget.habitId).firstOrNull;
          if (h == null) {
            return Center(child: Text(l10n.noHabitsYet));
          }
          final accent = Color(h.colorValue);
          final items = st.checklistFor(h.id);
          final byDate = st.completionsByDateFor(h.id);
          final stats = HabitEngine.computeStats(
            h,
            byDate,
            items,
            calendar: settings.calendarSystem,
            weekStart: settings.weekStartDay,
            today: today,
            pauses: st.pauses,
            monthlyGraceDays: settings.streakGraceDaysPerMonth,
          );
          final isPaused = HabitEngine.isPausedOn(h.id, activeDate, st.pauses);
          final comp = byDate[activeKey];
          final done = HabitEngine.isCompletedOn(
              h, comp, items, activeDate,
              today: today);
          final notes = st.notesFor(h.id);
          final fg = HabitPalette.contrastFg(accent);
          final curVal = comp?.value ?? 0;

          final ctaText = h.isQuit
              ? (done ? l10n.slipFreeDay : l10n.slippedToday)
              : h.trackingStyle == TrackingStyle.count && !done
                  ? '${l10n.addOneAction} (${AppCalendar.localizeDigits('$curVal/${h.targetCount}', settings.localeCode)})'
                  : l10n.doneAction;

          return ListView(
            padding: EdgeInsets.only(bottom: 28 + bottomInset),
            children: [
              // Top Gradient Wash (`.detail-wash`)
              Container(
                padding: EdgeInsets.fromLTRB(
                    14, MediaQuery.paddingOf(context).top + 14, 14, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.75, 1.0],
                    colors: [
                      accent.withValues(alpha: 0.25),
                      accent.withValues(alpha: 0.11),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        XNavBackButton(
                          backgroundColor: xc.detailBox,
                          iconColor: xc.text,
                          onTap: () => Navigator.pop(context),
                        ),
                        HdrCircleButton(
                          icon: Icons.more_vert_rounded,
                          backgroundColor: xc.detailBox,
                          iconColor: xc.text,
                          onTap: () => _openHabitMenu(h),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(HabitPalette.iconFor(h.iconKey),
                          size: 28, color: fg),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            h.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: xc.text,
                            ),
                          ),
                        ),
                        HabitTitleBadgeButton(
                          habit: h,
                          bestStreak: stats.bestStreak,
                          onTap: () => _openAchievements(stats, settings),
                        ),
                      ],
                    ),
                    if (h.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        h.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: xc.muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaused && !done
                            ? const Color(0xFFFFB020).withValues(alpha: 0.2)
                            : accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        done
                            ? l10n.completed
                            : isPaused
                                ? l10n.pausedBadge
                                : l10n.inProgress,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPaused && !done
                              ? const Color(0xFFFFB020)
                              : xc.text,
                        ),
                      ),
                    ),

                    // Mid Row (`.detail-mid-row`)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          AddEditHabitScreen(habit: h),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: xc.detailBox,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: xc.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            size: 14, color: xc.text),
                                        const SizedBox(width: 6),
                                        Text(
                                          h.frequencyType == FrequencyType.daily
                                              ? l10n.freqDaily
                                              : l10n.customDaysLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: xc.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final nowPaused = await ref
                                        .read(habitStateProvider.notifier)
                                        .togglePauseHabit(h, activeDate);
                                    if (context.mounted) {
                                      showXToast(
                                        context,
                                        nowPaused
                                            ? l10n.pauseSavedToast
                                            : l10n.resumedToast,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isPaused
                                          ? const Color(0xFFFFB020)
                                              .withValues(alpha: 0.16)
                                          : xc.detailBox,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isPaused
                                            ? const Color(0xFFFFB020)
                                            : xc.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isPaused
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          size: 14,
                                          color: isPaused
                                              ? const Color(0xFFFFB020)
                                              : xc.text,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isPaused
                                              ? l10n.resumeHabit
                                              : l10n.pauseHabit,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isPaused
                                                ? const Color(0xFFFFB020)
                                                : xc.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (h.reminderEnabled)
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AddEditHabitScreen(habit: h),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: xc.detailBox,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: xc.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.notifications_none_rounded,
                                            size: 14,
                                            color: accent,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            AppCalendar.localizeDigits(
                                              '${(h.reminderHour ?? 8).toString().padLeft(2, '0')}:${(h.reminderMinute ?? 30).toString().padLeft(2, '0')}',
                                              settings.localeCode,
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _DetailSqBtn(
                                icon: Icons.emoji_events_outlined,
                                onTap: () => _openAchievements(stats, settings),
                              ),
                              const SizedBox(width: 7),
                              _DetailSqBtn(
                                icon: Icons.bar_chart_rounded,
                                onTap: () => _openAnalytics(h, stats, byDate,
                                    items, st.pauses, settings, notes.length),
                              ),
                              const SizedBox(width: 7),
                              _DetailSqBtn(
                                icon: Icons.calendar_today_outlined,
                                onTap: () =>
                                    _openBackdateCalendar(h, items, settings),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // KPI 3-Boxes (`.kpi-3-boxes`)
                    Row(
                      children: [
                        _DetailKpiBox(
                          val: AppCalendar.localizeDigits(
                              '${stats.currentStreak}', settings.localeCode),
                          lbl: l10n.currentStreak,
                        ),
                        const SizedBox(width: 8),
                        _DetailKpiBox(
                          val: AppCalendar.localizeDigits(
                              '${stats.bestStreak}', settings.localeCode),
                          lbl: l10n.bestStreak,
                        ),
                        const SizedBox(width: 8),
                        _DetailKpiBox(
                          val: AppCalendar.localizeDigits(
                              '${stats.habitScore}%', settings.localeCode),
                          lbl: l10n.completionRate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),

                    // Checklist card if checklist habit
                    if (h.trackingStyle == TrackingStyle.checklist &&
                        items.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 11),
                        decoration: BoxDecoration(
                          color: xc.detailBox,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: xc.border),
                        ),
                        child: Column(
                          children: items.map((c) {
                            final cDone =
                                comp?.completedChecklistIds.contains(c.id) ??
                                    false;
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final fb = await ref
                                    .read(habitStateProvider.notifier)
                                    .toggleChecklistItem(h, activeDate, c.id);
                                await SoundService.instance.play(
                                  fb.completedNow
                                      ? ChimeKind.done
                                      : ChimeKind.step,
                                  enabled: settings.isAchievementSoundEnabled,
                                  profile: settings.soundProfile,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 5),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 17,
                                      height: 17,
                                      decoration: BoxDecoration(
                                        color: cDone
                                            ? accent
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(5),
                                        border: cDone
                                            ? null
                                            : Border.all(
                                                color: accent.withValues(
                                                    alpha: 0.5),
                                                width: 1.5,
                                              ),
                                      ),
                                      alignment: Alignment.center,
                                      child: cDone
                                          ? Icon(Icons.check_rounded,
                                              size: 11, color: fg)
                                          : null,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        c.title,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: cDone
                                              ? xc.text.withValues(alpha: 0.55)
                                              : xc.text,
                                          decoration: cDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Media 3-Buttons (`.media-3-btns`)
                    Row(
                      children: [
                        Expanded(
                          child: _MediaPillBtn(
                            icon: Icons.note_add_outlined,
                            label: l10n.addTextNote,
                            onTap: () => _openNoteEditor(
                              h,
                              settings,
                              initialDate: activeDate,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MediaPillBtn(
                            icon: Icons.image_outlined,
                            label: l10n.addImageNote,
                            onTap: () => _openPhotoOptions(h, activeDate),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MediaPillBtn(
                            icon: Icons.mic_none_rounded,
                            label: l10n.addVoiceNote,
                            onTap: () => _openVoiceSheet(h, settings, activeDate),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),

                    // Done / Count CTA (`.done-full-btn`)
                    if (h.trackingStyle == TrackingStyle.count && !h.isQuit)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: curVal <= 0
                                ? null
                                : () async {
                                    await ref
                                        .read(habitStateProvider.notifier)
                                        .stepHabitCount(h, activeDate, -1);
                                    await SoundService.instance.play(
                                      ChimeKind.undo,
                                      enabled:
                                          settings.isAchievementSoundEnabled,
                                      profile: settings.soundProfile,
                                    );
                                  },
                            child: Container(
                              width: 52,
                              height: 44,
                              decoration: BoxDecoration(
                                color: xc.detailBox,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: xc.border),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '−',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: curVal <= 0 ? xc.dim : xc.text,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: curVal >= h.targetCount
                                  ? null
                                  : () async {
                                      final fb = await ref
                                          .read(habitStateProvider.notifier)
                                          .stepHabitCount(h, activeDate, 1);
                                      await SoundService.instance.play(
                                        fb.completedNow
                                            ? ChimeKind.done
                                            : ChimeKind.step,
                                        enabled:
                                            settings.isAchievementSoundEnabled,
                                        profile: settings.soundProfile,
                                      );
                                    },
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: done
                                      ? accent
                                      : accent.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      done
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      size: 17,
                                      color: done ? fg : accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        ctaText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: done ? fg : accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          final fb = await ref
                              .read(habitStateProvider.notifier)
                              .toggleOrStepHabit(h, activeDate);
                          await SoundService.instance.play(
                            fb.completedNow ? ChimeKind.done : ChimeKind.undo,
                            enabled: settings.isAchievementSoundEnabled,
                            profile: settings.soundProfile,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                done ? accent : accent.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (done) ...[
                                Icon(Icons.check_rounded, size: 17, color: fg),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  ctaText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: done ? fg : accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Centered Month Label (`.tl-month`)
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

              // Timeline Rail (`.tl-rail` matching prototype lines 2454-2471)
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
                        ...notes.map(
                          (n) => TimelineRailNoteRow(
                            habit: h,
                            note: n,
                            playing: _playingNoteId == n.id,
                            settings: settings,
                            onTogglePlay: () async {
                              if (_playingNoteId == n.id) {
                                try {
                                  await _player.stop();
                                } catch (_) {}
                                if (mounted) {
                                  setState(() => _playingNoteId = null);
                                }
                              } else {
                                try {
                                  await _player.stop();
                                  await _player.setFilePath(n.content);
                                  if (!mounted) return;
                                  setState(() => _playingNoteId = n.id);
                                  await _player.play();
                                } catch (_) {
                                } finally {
                                  if (mounted && _playingNoteId == n.id) {
                                    setState(() => _playingNoteId = null);
                                  }
                                }
                              }
                            },
                            onDelete: () => _deleteNoteConfirm(n),
                            onEditText: n.kind == NoteKind.text
                                ? () => _openNoteEditor(h, settings,
                                    existingNote: n)
                                : null,
                            onOpenPhoto: n.kind == NoteKind.image
                                ? () => showTimelinePhotoPreview(context, h, n,
                                    () => _deleteNoteConfirm(n))
                                : null,
                          ),
                        ),
                        TimelineRailBadgeRow(
                          habit: h,
                          backgroundColor: accent.withValues(alpha: 0.12),
                          textColor: accent,
                          icon: Icons.workspace_premium_outlined,
                          label:
                              '${AppCalendar.localizeDigits('${stats.bestStreak}', settings.localeCode)} ${l10n.unlockedStreakLabel}',
                          trailing: AppCalendar.localizeDigits(
                            '${AppCalendar.dayNumberInCalendar(today, settings.calendarSystem)}',
                            settings.localeCode,
                          ),
                        ),
                        TimelineRailBadgeRow(
                          habit: h,
                          backgroundColor: accent.withValues(alpha: 0.09),
                          textColor: accent,
                          icon: Icons.local_fire_department_rounded,
                          label:
                              '${AppCalendar.localizeDigits('${stats.currentStreak}', settings.localeCode)} ${l10n.ongoingStreakLabel}',
                          trailing: AppCalendar.localizeDigits(
                            '${AppCalendar.dayNumberInCalendar(today, settings.calendarSystem)}',
                            settings.localeCode,
                          ),
                        ),
                        TimelineRailBadgeRow(
                          habit: h,
                          backgroundColor: xc.card,
                          textColor: xc.text,
                          icon: Icons.flag_rounded,
                          label: l10n.taskStartedLabel,
                          trailing: '-',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailSqBtn extends StatelessWidget {
  const _DetailSqBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 32,
        decoration: BoxDecoration(
          color: xc.detailBox,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: xc.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: xc.text),
      ),
    );
  }
}

class _DetailKpiBox extends StatelessWidget {
  const _DetailKpiBox({required this.val, required this.lbl});

  final String val;
  final String lbl;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: xc.detailBox,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: xc.border),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              lbl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: xc.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPillBtn extends StatelessWidget {
  const _MediaPillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: xc.detailBox,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: xc.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: xc.text),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: xc.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnKpiBox extends StatelessWidget {
  const _AnKpiBox({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: xc.card2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: xc.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valueColor ?? xc.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: xc.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCardButton extends StatelessWidget {
  const _OptionCardButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: xc.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: xc.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: xc.muted),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: xc.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetMenuRow extends StatelessWidget {
  const _SheetMenuRow({
    required this.label,
    required this.onTap,
    this.trailing,
    this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: xc.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: xc.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? xc.text,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-Screen Tinted Note Editor matching `.note-fs` in prototype.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({
    required this.habit,
    required this.settings,
    this.existingNote,
    this.initialDate,
    this.showHabitPicker = false,
    super.key,
  });

  final Habit habit;
  final AppSettings settings;
  final HabitNote? existingNote;
  final DateTime? initialDate;
  final bool showHabitPicker;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String _habitId;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _habitId = widget.existingNote?.habitId ?? widget.habit.id;
    _titleCtrl =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _bodyCtrl =
        TextEditingController(text: widget.existingNote?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndExit() async {
    if (_closing) return;
    _closing = true;
    final l10n = AppLocalizations.of(context);
    final t = _titleCtrl.text.trim();
    final b = _bodyCtrl.text.trim();
    final noteDate = widget.existingNote != null
        ? AppCalendar.parseDateKey(widget.existingNote!.dateKey)
        : (widget.initialDate ?? DateTime.now());
    if (t.isNotEmpty || b.isNotEmpty) {
      await ref.read(habitStateProvider.notifier).saveNote(
            id: widget.existingNote?.id,
            habitId: _habitId,
            date: noteDate,
            kind: NoteKind.text,
            title: t,
            content: b,
          );
      if (mounted) showXToast(context, l10n.noteSaved);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteAndExit() async {
    if (_closing) return;
    final l10n = AppLocalizations.of(context);
    final t = _titleCtrl.text.trim();
    final b = _bodyCtrl.text.trim();
    if (widget.existingNote == null && t.isEmpty && b.isEmpty) {
      _closing = true;
      if (mounted) Navigator.pop(context);
      return;
    }
    final ok = await showXConfirmSheet(
      context: context,
      icon: Icons.delete_rounded,
      title: l10n.deleteAttachmentTitle,
      message: l10n.deleteAttachmentMsg,
      cancelLabel: l10n.noCancel,
      confirmLabel: l10n.yesDelete,
    );
    if (!ok || !mounted) return;
    _closing = true;
    if (widget.existingNote != null) {
      await ref
          .read(habitStateProvider.notifier)
          .deleteNote(widget.existingNote!.id);
    }
    if (mounted) {
      showXToast(context, l10n.noteDeleted);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final habits =
        ref.watch(habitStateProvider).value?.habits.where((h) => !h.isArchived).toList() ??
            const <Habit>[];
    final currentHabit =
        habits.where((h) => h.id == _habitId).firstOrNull ?? widget.habit;
    final accent = Color(currentHabit.colorValue);
    final noteDate = widget.existingNote != null
        ? AppCalendar.parseDateKey(widget.existingNote!.dateKey)
        : (widget.initialDate ?? DateTime.now());
    final dateStr = AppCalendar.formatFullDate(
      noteDate,
      widget.settings.calendarSystem,
      widget.settings.localeCode,
    );
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndExit();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: xc.isDark ? 0.22 : 0.16),
                accent.withValues(alpha: xc.isDark ? 0.14 : 0.08),
              ],
            ),
          ),
          child: SafeArea(
            maintainBottomViewPadding: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _saveAndExit,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            isRtl
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_back_rounded,
                            size: 22,
                            color: xc.text,
                          ),
                        ),
                      ),
                      if (widget.showHabitPicker && habits.isNotEmpty)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showXHabitPickerSheet(
                                  context: context,
                                  title: l10n.selectHabitTitle,
                                  habits: habits,
                                  selectedId: currentHabit.id,
                                );
                                if (picked != null && mounted) {
                                  setState(() => _habitId = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(
                                  color: xc.card2.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: xc.borderStrong),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        HabitPalette.iconFor(
                                            currentHabit.iconKey),
                                        size: 14,
                                        color: accent),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        currentHabit.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: xc.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 16, color: xc.muted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _saveAndExit,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.check_rounded,
                                size: 19,
                                color: HabitPalette.contrastFg(accent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _deleteAndExit,
                            child: const SizedBox(
                              width: 34,
                              height: 34,
                              child: Icon(
                                Icons.delete_rounded,
                                size: 20,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: xc.muted,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.noteTitleHint,
                    hintStyle: TextStyle(
                      color: xc.muted.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _bodyCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: xc.text,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.notePlaceholder,
                      hintStyle: TextStyle(
                        color: xc.muted.withValues(alpha: 0.68),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
