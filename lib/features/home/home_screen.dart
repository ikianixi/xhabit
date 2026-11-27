import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../day_modes/day_modes_screen.dart';
import '../habits/add_edit_habit_screen.dart';
import '../habits/habit_details_screen.dart';
import '../tasks/one_off_tasks_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedDate;
  bool _userPickedDate = false;
  String? _selectedCategoryId;
  late final ConfettiController _confetti;
  final ScrollController _ringScroll = ScrollController();
  bool _didInitialRingScroll = false;
  AchievementTier? _bannerTier;
  String? _bannerHabitTitle;
  String? _bannerHabitId;
  bool _seedingDemo = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = AppCalendar.normalizeDate(DateTime.now());
    _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _ringScroll.dispose();
    super.dispose();
  }

  Future<void> _handleFeedback(
    BuildContext context,
    ActionFeedback fb,
    AppSettings settings, {
    required bool isCountPartial,
    Habit? habitForUndo,
    HabitCompletion? prevSnapshot,
  }) async {
    if (fb.unlockedMedalTier != null || fb.allDailyCompleted) {
      if (settings.isConfettiEnabled) _confetti.play();
      await SoundService.instance.play(
        ChimeKind.grand,
        enabled: settings.isAchievementSoundEnabled,
        profile: settings.soundProfile,
      );
    } else if (fb.completedNow) {
      if (settings.isConfettiEnabled) _confetti.play();
      await SoundService.instance.play(
        ChimeKind.done,
        enabled: settings.isAchievementSoundEnabled,
        profile: settings.soundProfile,
      );
    } else if (isCountPartial) {
      await SoundService.instance.play(
        ChimeKind.step,
        enabled: settings.isAchievementSoundEnabled,
        profile: settings.soundProfile,
      );
    } else {
      await SoundService.instance.play(
        ChimeKind.undo,
        enabled: settings.isAchievementSoundEnabled,
        profile: settings.soundProfile,
      );
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (fb.unlockedMedalTier != null) {
      final tier = fb.unlockedMedalTier!;
      setState(() {
        _bannerTier = tier;
        _bannerHabitTitle = habitForUndo?.title ?? '';
        _bannerHabitId = habitForUndo?.id;
      });
      Future.delayed(const Duration(milliseconds: 4200), () {
        if (mounted && _bannerTier == tier) {
          setState(() => _bannerTier = null);
        }
      });
    } else if (fb.allDailyCompleted) {
      showXToast(context, '${l10n.allDailyDoneTitle} — ${l10n.allDailyDoneSub}');
    } else if (fb.completedNow &&
        settings.isShowOnlyDueHabit &&
        habitForUndo != null) {
      showXToast(
        context,
        '${habitForUndo.title} • ${l10n.taskCompleted}',
        undoLabel: l10n.undo,
        onUndo: () {
          ref.read(habitStateProvider.notifier).restoreCompletionSnapshot(
                habitForUndo,
                _selectedDate,
                prevSnapshot,
              );
        },
      );
    }
  }

  Future<void> _openCountEditorModal(
    BuildContext context,
    Habit h,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final accent = Color(h.colorValue);
    final fg = HabitPalette.contrastFg(accent);
    final dateKey = AppCalendar.toDateKey(_selectedDate);

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final st = cRef.watch(habitStateProvider).value;
          final cur = st?.completionsByDateFor(h.id)[dateKey]?.value ?? 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                h.title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: xc.text),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.editCountTitle,
                style: TextStyle(fontSize: 11.5, color: xc.muted),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: cur <= 0
                        ? null
                        : () async {
                            await cRef
                                .read(habitStateProvider.notifier)
                                .stepHabitCount(h, _selectedDate, -1);
                            await SoundService.instance.play(
                              ChimeKind.undo,
                              enabled: settings.isAchievementSoundEnabled,
                              profile: settings.soundProfile,
                            );
                          },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(color: xc.card2, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cur <= 0 ? xc.dim : xc.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    AppCalendar.localizeDigits(
                      '$cur / ${h.targetCount}',
                      settings.localeCode,
                    ),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: cur >= h.targetCount
                        ? null
                        : () async {
                            final prevComp = st?.completionsByDateFor(h.id)[dateKey];
                            final fb = await cRef
                                .read(habitStateProvider.notifier)
                                .stepHabitCount(h, _selectedDate, 1);
                            if (ctx.mounted) {
                              await _handleFeedback(
                                ctx,
                                fb,
                                settings,
                                isCountPartial: !fb.completedNow,
                                habitForUndo: h,
                                prevSnapshot: prevComp,
                              );
                            }
                          },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cur >= h.targetCount
                            ? accent.withValues(alpha: 0.35)
                            : accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: xc.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.doneAction,
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

  Widget _actionCircle(
    BuildContext context,
    Habit h,
    HabitCompletion? comp,
    List<HabitChecklistItem> items,
    AppSettings settings,
    DateTime today,
  ) {
    final done =
        HabitEngine.isCompletedOn(h, comp, items, _selectedDate, today: today);
    final ratio =
        HabitEngine.progressRatio(h, comp, items, _selectedDate, today: today);
    final slipped = h.isQuit && (comp?.slipped == true);

    return HabitActionCircle(
      habit: h,
      done: done,
      ratio: ratio,
      slipped: slipped,
      size: 35,
      onLongPress: h.trackingStyle == TrackingStyle.count && !h.isQuit
          ? () => _openCountEditorModal(context, h, settings)
          : null,
      onTap: () async {
        final prevVal = comp?.value ?? 0;
        final fb = await ref
            .read(habitStateProvider.notifier)
            .toggleOrStepHabit(h, _selectedDate);
        if (!context.mounted) return;
        final isPartial = !fb.completedNow &&
            h.trackingStyle == TrackingStyle.count &&
            prevVal < h.targetCount;
        await _handleFeedback(
          context,
          fb,
          settings,
          isCountPartial: isPartial,
          habitForUndo: h,
          prevSnapshot: comp,
        );
      },
    );
  }

  Widget _buildSubtitle(
    BuildContext context,
    Habit h,
    HabitCompletion? comp,
    HabitStats stats,
    bool scheduled,
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final xc = context.xc;
    final accent = Color(h.colorValue);
    if (h.trackingStyle == TrackingStyle.count) {
      return Text(
        AppCalendar.localizeDigits(
          '${comp?.value ?? 0}/${h.targetCount} ${h.countUnit}',
          settings.localeCode,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: xc.muted),
      );
    }
    final streakCountStr =
        AppCalendar.localizeDigits('${stats.currentStreak}', settings.localeCode);
    final streakLine = settings.localeCode == 'fa'
        ? '${l10n.streakPrefix} $streakCountStr روز'
        : '${l10n.streakPrefix} ${l10n.daysUnit(stats.currentStreak)}';

    return Row(
      children: [
        Icon(Icons.local_fire_department_rounded, size: 14, color: accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            scheduled ? streakLine : '$streakLine • ${l10n.offScheduleToday}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: xc.muted),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final stateAsync = ref.watch(habitStateProvider);
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    if (!_userPickedDate) {
      _selectedDate = today;
    }
    final selectedKey = AppCalendar.toDateKey(_selectedDate);
    final headerDate = AppCalendar.monthDayLabel(
        today, settings.calendarSystem, settings.localeCode);
    final ringItemWidth =
        ((MediaQuery.sizeOf(context).width - 20) / 7).clamp(44.0, 68.0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            stateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (st) {
                if (!_didInitialRingScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        !_didInitialRingScroll &&
                        _ringScroll.hasClients) {
                      _didInitialRingScroll = true;
                      _ringScroll.jumpTo(_ringScroll.position.maxScrollExtent);
                    }
                  });
                }
                final effectiveDayMode =
                    HabitEngine.resolveDayMode(settings, _selectedDate);
                final active = st.habits
                    .where((h) =>
                        !h.isArchived &&
                        HabitEngine.matchesDayMode(h, effectiveDayMode))
                    .toList();
                final effectiveCatId = (_selectedCategoryId == null ||
                        st.categories.any((c) => c.id == _selectedCategoryId))
                    ? _selectedCategoryId
                    : null;
                final catFiltered = effectiveCatId == null
                    ? active
                    : active
                        .where((h) => h.categoryId == effectiveCatId)
                        .toList();

                final dueList = catFiltered.where((h) {
                  if (HabitEngine.isPausedOn(h.id, _selectedDate, st.pauses)) {
                    return false;
                  }
                  final items = st.checklistFor(h.id);
                  final byDate = st.completionsByDateFor(h.id);
                  return HabitEngine.isScheduledOn(
                        h,
                        _selectedDate,
                        calendar: settings.calendarSystem,
                        weekStart: settings.weekStartDay,
                        completionsByDate: byDate,
                        checklistItems: items,
                        today: today,
                      ) &&
                      !HabitEngine.isCompletedOn(
                        h,
                        byDate[selectedKey],
                        items,
                        _selectedDate,
                        today: today,
                      );
                }).toList();

                final shown = settings.isShowOnlyDueHabit ? dueList : catFiltered;
                final weeklyRate = HabitEngine.successRateForWindow(
                  habits: active,
                  completionsFor: st.completionsByDateFor,
                  checklistFor: st.checklistFor,
                  pauses: st.pauses,
                  days: 7,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  today: today,
                );
                final monthlyRate = HabitEngine.successRateForWindow(
                  habits: active,
                  completionsFor: st.completionsByDateFor,
                  checklistFor: st.checklistFor,
                  pauses: st.pauses,
                  days: 30,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  today: today,
                );
                final yearlyRate = HabitEngine.successRateForWindow(
                  habits: active,
                  completionsFor: st.completionsByDateFor,
                  checklistFor: st.checklistFor,
                  pauses: st.pauses,
                  days: 365,
                  calendar: settings.calendarSystem,
                  weekStart: settings.weekStartDay,
                  today: today,
                );
                final displayedRate = switch (settings.homeRatePeriod) {
                  SuccessRatePeriod.weekly => weeklyRate,
                  SuccessRatePeriod.monthly => monthlyRate,
                  SuccessRatePeriod.yearly => yearlyRate,
                };
                final rateLabel = switch (settings.homeRatePeriod) {
                  SuccessRatePeriod.weekly => l10n.weeklyRate,
                  SuccessRatePeriod.monthly => l10n.monthlyRate,
                  SuccessRatePeriod.yearly => l10n.yearlyRate,
                };

                return CustomScrollView(
                  slivers: [
                    // 1. Top Header Row (`.hdr-row`)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _userPickedDate = false;
                                    _selectedDate = today;
                                  });
                                  if (_ringScroll.hasClients) {
                                    _ringScroll.animateTo(
                                      _ringScroll.position.maxScrollExtent,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                },
                                child: RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: settings.localeCode == 'fa'
                                          ? 'Vazirmatn'
                                          : 'FiraSans',
                                      fontFamilyFallback: const [
                                        'Vazirmatn',
                                        'FiraSans'
                                      ],
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: xc.text,
                                    ),
                                    children: [
                                      TextSpan(text: '${l10n.today} '),
                                      TextSpan(
                                        text: headerDate,
                                        style: TextStyle(
                                          color: xc.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                HdrCircleButton(
                                  size: 39,
                                  iconSize: 19.5,
                                  icon: settings.isAchievementSoundEnabled
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_off_rounded,
                                  mutedAlert:
                                      !settings.isAchievementSoundEnabled,
                                  onTap: () async {
                                    final nextVal =
                                        !settings.isAchievementSoundEnabled;
                                    await settingsNotifier.updateSettings(
                                      settings.copyWith(
                                          isAchievementSoundEnabled: nextVal),
                                    );
                                    if (nextVal) {
                                      await SoundService.instance.play(
                                        ChimeKind.step,
                                        enabled: true,
                                        profile: settings.soundProfile,
                                      );
                                    }
                                    if (context.mounted) {
                                      showXToast(
                                        context,
                                        nextVal
                                            ? l10n.soundOnToast
                                            : l10n.soundMutedToast,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                HdrCircleButton(
                                  size: 39,
                                  iconSize: 19.5,
                                  icon: settings.homeLayout == HomeLayout.grid
                                      ? Icons.grid_view_rounded
                                      : Icons.format_list_bulleted_rounded,
                                  onTap: () {
                                    final next =
                                        settings.homeLayout == HomeLayout.grid
                                            ? HomeLayout.list
                                            : HomeLayout.grid;
                                    settingsNotifier.updateSettings(
                                        settings.copyWith(homeLayout: next));
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
                    ),

                    // 2. Sticky Strip: Date Progress Rings + Filter/Score Bar + Categories
                    // Header scrolls off first; then these controls lock at the top while only habit cards scroll.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyDateStripDelegate(
                        height: 202,
                        backgroundColor: xc.bg,
                        borderColor: xc.border,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 88,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: ListView.builder(
                            controller: _ringScroll,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                            itemCount: 31,
                            itemBuilder: (_, idx) {
                              final d = DateTime(today.year, today.month,
                                  today.day - (30 - idx));
                              final k = AppCalendar.toDateKey(d);
                              final sel = k == selectedKey;
                              final sched = active.where((h) {
                                if (HabitEngine.isPausedOn(h.id, d, st.pauses)) {
                                  return false;
                                }
                                return HabitEngine.isScheduledOn(
                                  h,
                                  d,
                                  calendar: settings.calendarSystem,
                                  weekStart: settings.weekStartDay,
                                  completionsByDate:
                                      st.completionsByDateFor(h.id),
                                  checklistItems: st.checklistFor(h.id),
                                  today: today,
                                );
                              }).toList();
                              final fallbackPool = active
                                  .where((h) => !HabitEngine.isPausedOn(
                                      h.id, d, st.pauses))
                                  .toList();
                              final pool =
                                  sched.isNotEmpty ? sched : fallbackPool;
                              var ratioSum = 0.0;
                              for (final h in pool) {
                                ratioSum += HabitEngine.progressRatio(
                                  h,
                                  st.completionsByDateFor(h.id)[k],
                                  st.checklistFor(h.id),
                                  d,
                                  today: today,
                                );
                              }
                              final pct = pool.isEmpty
                                  ? 0.0
                                  : (ratioSum / pool.length).clamp(0.0, 1.0);

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  _userPickedDate = d != today;
                                  _selectedDate = d;
                                }),
                                child: SizedBox(
                                  width: ringItemWidth,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppCalendar.weekdayShort(
                                            d.weekday, settings.localeCode),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: sel
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                          color: sel ? xc.text : xc.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DayProgressRing(
                                        progress: pct,
                                        active: sel,
                                        size: 42,
                                        strokeWidth: 4.2,
                                        label: AppCalendar.localizeDigits(
                                          '${AppCalendar.dayNumberInCalendar(d, settings.calendarSystem)}',
                                          settings.localeCode,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                            // 3. Filter & Habit Score Bar (`.filter-score-bar`)
                            SizedBox(
                              height: 70,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                                child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.filterLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: xc.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: xc.card,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(color: xc.border),
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _FilterPill(
                                            label:
                                                '${l10n.allFilter} (${AppCalendar.localizeDigits('${catFiltered.length}', settings.localeCode)})',
                                            active:
                                                !settings.isShowOnlyDueHabit,
                                            onTap: () => settingsNotifier
                                                .updateSettings(
                                                    settings.copyWith(
                                                        isShowOnlyDueHabit:
                                                            false)),
                                          ),
                                          _FilterPill(
                                            label:
                                                '${l10n.dueFilter} (${AppCalendar.localizeDigits('${dueList.length}', settings.localeCode)})',
                                            active: settings.isShowOnlyDueHabit,
                                            onTap: () => settingsNotifier
                                                .updateSettings(
                                                    settings.copyWith(
                                                        isShowOnlyDueHabit:
                                                            true)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  rateLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: xc.muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _openSuccessRatesSheet(
                                    context,
                                    l10n,
                                    settings,
                                    settingsNotifier,
                                    weeklyRate,
                                    monthlyRate,
                                    yearlyRate,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 13, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: xc.card,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(color: xc.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.speed_rounded,
                                            size: 16, color: xc.text),
                                        const SizedBox(width: 7),
                                        TweenAnimationBuilder<double>(
                                          tween: Tween<double>(end: displayedRate),
                                          duration: const Duration(milliseconds: 420),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, animRate, __) => Text(
                                            AppCalendar.localizeDigits(
                                              '${animRate.toStringAsFixed(1)}%',
                                              settings.localeCode,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: xc.text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 15,
                                          color: xc.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                            // 4. Sleek Pill Category Bar (`.cat-bar`)
                            SizedBox(
                              height: 44,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                children: [
                                  _CategoryPill(
                                    label: l10n.allCategories,
                                    active: effectiveCatId == null,
                                    onTap: () =>
                                        setState(() => _selectedCategoryId = null),
                                  ),
                                  ...st.categories.map(
                                    (cat) => _CategoryPill(
                                      label: cat.name,
                                      active: effectiveCatId == cat.id,
                                      onTap: () => setState(
                                          () => _selectedCategoryId = cat.id),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Habit Cards (`.cards-wrap`)
                    if (shown.isEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 28),
                          decoration: BoxDecoration(
                            color: xc.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: xc.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: xc.lime.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.check_rounded,
                                    size: 20, color: xc.lime),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                settings.isShowOnlyDueHabit
                                    ? l10n.noDueHabits
                                    : l10n.noHabitsYet,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: xc.muted,
                                  height: 1.6,
                                ),
                              ),
                              if (active.isEmpty) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AddEditHabitScreen(),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: xc.lime,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          l10n.addFirstHabit,
                                          style: TextStyle(
                                            color: HabitPalette.contrastFg(
                                                xc.lime),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _seedingDemo
                                          ? null
                                          : () async {
                                              _seedingDemo = true;
                                              try {
                                                await ref
                                                    .read(habitStateProvider
                                                        .notifier)
                                                    .seedDemoStarterPack();
                                              } finally {
                                                if (mounted) {
                                                  _seedingDemo = false;
                                                }
                                              }
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: xc.card2,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(color: xc.border),
                                        ),
                                        child: Text(
                                          l10n.loadDemoHabits,
                                          style: TextStyle(
                                            color: xc.text,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 92),
                        sliver: SliverList.builder(
                          itemCount: shown.length,
                          itemBuilder: (_, idx) {
                            final h = shown[idx];
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
                              monthlyGraceDays:
                                  settings.streakGraceDaysPerMonth,
                            );
                            final isPaused = HabitEngine.isPausedOn(
                              h.id,
                              _selectedDate,
                              st.pauses,
                            );
                            final comp = byDate[selectedKey];
                            final sched = HabitEngine.isScheduledOn(
                              h,
                              _selectedDate,
                              calendar: settings.calendarSystem,
                              weekStart: settings.weekStartDay,
                              completionsByDate: byDate,
                              checklistItems: items,
                              today: today,
                            );

                            if (settings.homeLayout == HomeLayout.grid) {
                              return _buildGridCard(
                                context,
                                h: h,
                                accent: accent,
                                items: items,
                                byDate: byDate,
                                stats: stats,
                                comp: comp,
                                scheduled: sched,
                                isPaused: isPaused,
                                settings: settings,
                                today: today,
                                l10n: l10n,
                              );
                            }
                            return _buildListCard(
                              context,
                              h: h,
                              accent: accent,
                              items: items,
                              stats: stats,
                              comp: comp,
                              scheduled: sched,
                              isPaused: isPaused,
                              settings: settings,
                              today: today,
                              l10n: l10n,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_bannerTier != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    final hid = _bannerHabitId;
                    setState(() => _bannerTier = null);
                    if (hid != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HabitDetailsScreen(habitId: hid),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: xc.isDark
                          ? const Color(0xF0121216)
                          : const Color(0xF5FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x8CFFd426),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        MedalBadge(
                          days: _bannerTier!.days,
                          unlocked: true,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.medalUnlockedTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: xc.isDark
                                      ? const Color(0xFFFFD426)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                              Text(
                                '${_bannerHabitTitle ?? ''} • ${settings.localeCode == 'fa' ? _bannerTier!.nameFa : _bannerTier!.nameEn}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 18,
              gravity: 0.25,
            ),
            // Floating Home Mode + Quick Shopping/Tasks Hub Bar (bottom-left anchored)
            Positioned(
              left: 14,
              right: 14,
              bottom: 10,
              child: Builder(
                builder: (_) {
                  final st = stateAsync.value;
                  final pendingQuickCount = st == null
                      ? 0
                      : st.oneOffTasks.where((t) => !t.isDone).length;
                  final effectiveDayMode =
                      HabitEngine.resolveDayMode(settings, _selectedDate);
                  final hasCalRule =
                      HabitEngine.hasCalendarModeRule(settings, _selectedDate);
                  final activeModeLabel = _dayModeDisplayLabel(
                    effectiveDayMode,
                    settings,
                    l10n,
                  );
                  final activeModeCfg = effectiveDayMode == 'all'
                      ? null
                      : settings.dayModesList
                          .where((d) => d.id == effectiveDayMode)
                          .firstOrNull;
                  final activeModeColor = effectiveDayMode == 'all'
                      ? Color(settings.allDayModeColorValue)
                      : Color(activeModeCfg?.colorValue ?? 0xFF84CC16);
                  final activeModeIconKey = effectiveDayMode == 'all'
                      ? settings.allDayModeIconKey
                      : (activeModeCfg?.iconKey ?? 'tune');
                  final isNormalDefault = effectiveDayMode == 'normal';
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DayModesScreen(
                                targetDate: _selectedDate,
                                onOpenSettings: widget.onOpenSettings,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: xc.isDark
                                  ? const Color(0xEB141418)
                                  : const Color(0xF2FFFFFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isNormalDefault
                                    ? xc.borderStrong
                                    : activeModeColor,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  HabitPalette.iconFor(activeModeIconKey),
                                  size: 15,
                                  color: activeModeColor,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    activeModeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isNormalDefault
                                          ? xc.text
                                          : activeModeColor,
                                    ),
                                  ),
                                ),
                                if (hasCalRule) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 13,
                                    color: isNormalDefault
                                        ? xc.muted
                                        : activeModeColor,
                                  ),
                                ],
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 15,
                                  color: xc.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => OneOffTasksScreen(
                                onOpenSettings: widget.onOpenSettings,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: xc.isDark
                                  ? const Color(0xEB141418)
                                  : const Color(0xF2FFFFFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: xc.borderStrong),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.checklist_rounded,
                                    size: 15, color: xc.text),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    pendingQuickCount > 0
                                        ? '${l10n.quickTasksInHome} (${AppCalendar.localizeDigits('$pendingQuickCount', settings.localeCode)})'
                                        : l10n.quickTasksInHome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: xc.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSuccessRatesSheet(
    BuildContext context,
    AppLocalizations l10n,
    AppSettings settings,
    SettingsNotifier settingsNotifier,
    double weeklyRate,
    double monthlyRate,
    double yearlyRate,
  ) async {
    final xc = context.xc;
    final rows = [
      (SuccessRatePeriod.weekly, l10n.weeklyRate, weeklyRate),
      (SuccessRatePeriod.monthly, l10n.monthlyRate, monthlyRate),
      (SuccessRatePeriod.yearly, l10n.yearlyRate, yearlyRate),
    ];
    var savingRate = false;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.successRatesTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in rows)
            GestureDetector(
              onTap: () async {
                if (savingRate) return;
                savingRate = true;
                try {
                  await settingsNotifier.updateSettings(
                    settings.copyWith(homeRatePeriod: item.$1),
                  );
                } finally {
                  savingRate = false;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: settings.homeRatePeriod == item.$1
                      ? xc.lime.withValues(alpha: 0.12)
                      : xc.card2,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: settings.homeRatePeriod == item.$1
                        ? xc.lime
                        : xc.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: settings.homeRatePeriod == item.$1
                              ? xc.lime
                              : xc.text,
                        ),
                      ),
                    ),
                    Text(
                      AppCalendar.localizeDigits(
                        '${item.$3.toStringAsFixed(1)}%',
                        settings.localeCode,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: settings.homeRatePeriod == item.$1
                            ? xc.lime
                            : xc.text,
                      ),
                    ),
                    if (settings.homeRatePeriod == item.$1) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_rounded, size: 17, color: xc.lime),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required Habit h,
    required Color accent,
    required List<HabitChecklistItem> items,
    required Map<String, HabitCompletion> byDate,
    required HabitStats stats,
    required HabitCompletion? comp,
    required bool scheduled,
    required bool isPaused,
    required AppSettings settings,
    required DateTime today,
    required AppLocalizations l10n,
  }) {
    final xc = context.xc;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailsScreen(
            habitId: h.id,
            initialDate: _selectedDate,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: xc.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: xc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HabitRingIcon(iconKey: h.iconKey, accent: accent),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              h.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                          HabitTitleBadgeButton(
                            habit: h,
                            bestStreak: stats.bestStreak,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => HabitDetailsScreen(
                                  habitId: h.id,
                                  openAchievementsOnStart: true,
                                ),
                              ),
                            ),
                          ),
                          if (isPaused) _PausedMiniBadge(label: l10n.pausedBadge),
                          if (_habitScopedModeLabel(h, settings, l10n)
                              case final modeBadge?)
                            Flexible(child: _ModeMiniBadge(label: modeBadge)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _buildSubtitle(
                          context, h, comp, stats, scheduled, settings, l10n),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (settings.isShowAddNoteInHome) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NoteEditorPage(
                          habit: h,
                          settings: settings,
                          initialDate: _selectedDate,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.note_add_outlined,
                          size: 16, color: accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _actionCircle(context, h, comp, items, settings, today),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                const cols = 21;
                const rows = 7;
                const gap = 3.0;
                final cell = (constraints.maxWidth - (cols - 1) * gap) / cols;
                final totalH = rows * cell + (rows - 1) * gap;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: totalH,
                  child: CustomPaint(
                    painter: _Heatmap21Painter(
                      habit: h,
                      completionsByDate: byDate,
                      checklistItems: items,
                      weekStart: settings.weekStartDay,
                      today: today,
                      futureColor: xc.cellFuture,
                      todayRingColor: xc.text,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context, {
    required Habit h,
    required Color accent,
    required List<HabitChecklistItem> items,
    required HabitStats stats,
    required HabitCompletion? comp,
    required bool scheduled,
    required bool isPaused,
    required AppSettings settings,
    required DateTime today,
    required AppLocalizations l10n,
  }) {
    final xc = context.xc;
    final fg = HabitPalette.contrastFg(accent);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailsScreen(
            habitId: h.id,
            initialDate: _selectedDate,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: xc.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: xc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Center(
                    child: Icon(HabitPalette.iconFor(h.iconKey),
                        size: 20, color: accent),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              h.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                          HabitTitleBadgeButton(
                            habit: h,
                            bestStreak: stats.bestStreak,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => HabitDetailsScreen(
                                  habitId: h.id,
                                  openAchievementsOnStart: true,
                                ),
                              ),
                            ),
                          ),
                          if (isPaused) _PausedMiniBadge(label: l10n.pausedBadge),
                          if (_habitScopedModeLabel(h, settings, l10n)
                              case final modeBadge?)
                            Flexible(child: _ModeMiniBadge(label: modeBadge)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _buildSubtitle(
                          context, h, comp, stats, scheduled, settings, l10n),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _actionCircle(context, h, comp, items, settings, today),
              ],
            ),
            if (h.trackingStyle == TrackingStyle.checklist &&
                items.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: xc.border),
              const SizedBox(height: 8),
              ...items.map((sub) {
                final subDone =
                    comp?.completedChecklistIds.contains(sub.id) ?? false;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final fb = await ref
                        .read(habitStateProvider.notifier)
                        .toggleChecklistItem(h, _selectedDate, sub.id);
                    if (!context.mounted) return;
                    await _handleFeedback(
                      context,
                      fb,
                      settings,
                      isCountPartial: true,
                      habitForUndo: h,
                      prevSnapshot: comp,
                    );
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: subDone ? accent : Colors.transparent,
                            border: subDone
                                ? null
                                : Border.all(
                                    color: accent.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: subDone
                              ? Icon(Icons.check_rounded, size: 11, color: fg)
                              : null,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            sub.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subDone
                                  ? xc.muted.withValues(alpha: 0.55)
                                  : xc.muted,
                              decoration: subDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyDateStripDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDateStripDelegate({
    required this.height,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  final double height;
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: overlapsContent || shrinkOffset > 0
            ? Border(bottom: BorderSide(color: borderColor))
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyDateStripDelegate oldDelegate) => true;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? xc.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w700,
            color: active ? HabitPalette.contrastFg(xc.lime) : xc.muted,
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? xc.text : xc.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.transparent : xc.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? xc.bg : xc.muted,
          ),
        ),
      ),
    );
  }
}

class _Heatmap21Painter extends CustomPainter {
  const _Heatmap21Painter({
    required this.habit,
    required this.completionsByDate,
    required this.checklistItems,
    required this.weekStart,
    required this.today,
    required this.futureColor,
    required this.todayRingColor,
  });

  final Habit habit;
  final Map<String, HabitCompletion> completionsByDate;
  final List<HabitChecklistItem> checklistItems;
  final WeekStartDay weekStart;
  final DateTime today;
  final Color futureColor;
  final Color todayRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 21;
    const rows = 7;
    const gap = 3.0;
    final cell = (size.width - (cols - 1) * gap) / cols;

    final order = AppCalendar.orderedWeekdays(weekStart);
    final endOffset = order.indexOf(today.weekday);
    final start = DateTime(
      today.year,
      today.month,
      today.day - ((cols - 1) * 7 + endOffset),
    );
    final accent = Color(habit.colorValue);
    final paint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = todayRingColor;

    for (var w = 0; w < cols; w++) {
      for (var r = 0; r < rows; r++) {
        final d = DateTime(start.year, start.month, start.day + w * 7 + r);
        final key = AppCalendar.toDateKey(d);
        final fut = d.isAfter(today);
        final ratio = fut
            ? 0.0
            : HabitEngine.progressRatio(
                habit, completionsByDate[key], checklistItems, d,
                today: today);
        paint.color = fut
            ? futureColor
            : ratio >= 1.0
                ? accent
                : ratio > 0.0
                    ? accent.withValues(alpha: 0.45)
                    : accent.withValues(alpha: 0.14);

        final left = w * (cell + gap);
        final top = r * (cell + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cell, cell),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, paint);
        if (d == today) {
          canvas.drawRRect(rect.deflate(0.5), ringPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Heatmap21Painter old) => true;
}

String _dayModeDisplayLabel(
  String modeId,
  AppSettings settings,
  AppLocalizations l10n,
) {
  if (modeId == 'all') return l10n.dayModeAll;
  final found =
      settings.dayModesList.where((d) => d.id == modeId).firstOrNull;
  if (found != null && found.name.isNotEmpty) return found.name;
  return switch (modeId) {
    'normal' => l10n.dayModeNormal,
    'work' => l10n.dayModeWork,
    'off' => l10n.dayModeOff,
    'travel' => l10n.dayModeTravel,
    final other => other,
  };
}

String? _habitScopedModeLabel(
  Habit h,
  AppSettings settings,
  AppLocalizations l10n,
) {
  if (h.dayModes.isEmpty || h.dayModes.contains('all')) return null;
  final validIds = {for (final m in settings.dayModesList) m.id};
  final specific =
      h.dayModes.where((m) => m != 'normal' && validIds.contains(m)).toList();
  if (specific.isEmpty) return null;
  final first = _dayModeDisplayLabel(specific.first, settings, l10n);
  return specific.length > 1
      ? AppCalendar.localizeDigits(
          '$first +${specific.length - 1}', settings.localeCode)
      : first;
}

class _ModeMiniBadge extends StatelessWidget {
  const _ModeMiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: xc.card2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: xc.borderStrong),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: xc.muted,
        ),
      ),
    );
  }
}

class _PausedMiniBadge extends StatelessWidget {
  const _PausedMiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB020).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFB020).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFFB020),
        ),
      ),
    );
  }
}
