import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/widget_sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

class WidgetsSettingsScreen extends ConsumerStatefulWidget {
  const WidgetsSettingsScreen({super.key});

  @override
  ConsumerState<WidgetsSettingsScreen> createState() =>
      _WidgetsSettingsScreenState();
}

class _WidgetsSettingsScreenState extends ConsumerState<WidgetsSettingsScreen>
    with WidgetsBindingObserver {
  int _studioTab = 0; // 0 = adaptive, 1 = daily list, 2 = todo list, 3 = day mode
  String _morphSize = '4x2';
  String _listSize = '4x3';
  String _todoSize = '4x3';
  String _dayModeSize = '4x1';
  String? _previewAdaptiveHabitId;
  bool _previewListUseAll = true;
  List<String> _previewListIds = const [];
  bool _previewTodoHideDone = false;
  bool _previewDayModeIncludeAll = true;

  List<PlacedWidgetInfo> _placedWidgets = const [];
  bool _loadingPlaced = true;
  bool _pinning = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
    final cur = ref.read(settingsProvider).value;
    if (cur != null) {
      _previewAdaptiveHabitId = cur.widgetHabitId;
      _previewListUseAll = cur.widgetListHabitIds.isEmpty;
      _previewListIds = List<String>.from(cur.widgetListHabitIds);
    }
    _refreshPlacedWidgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPlacedWidgets();
    }
  }

  Future<void> _refreshPlacedWidgets() async {
    final list = await WidgetSyncService.instance.listPlacedWidgets();
    if (!mounted) return;
    setState(() {
      _placedWidgets = list;
      _loadingPlaced = false;
    });
  }

  Future<void> _togglePreviewHabit(
    Habit habit,
    DateTime day,
    AppSettings settings,
  ) async {
    final compMap =
        ref.read(habitStateProvider).value?.completionsByDateFor(habit.id);
    final key = AppCalendar.toDateKey(day);
    final prevVal = compMap?[key]?.value ?? 0;
    final fb =
        await ref.read(habitStateProvider.notifier).toggleOrStepHabit(habit, day);
    if (!mounted) return;
    final curSettings = ref.read(settingsProvider).value ?? settings;
    final prof = curSettings.soundProfile;
    final enabled = curSettings.isAchievementSoundEnabled;
    if (fb.unlockedMedalTier != null || fb.allDailyCompleted) {
      if (curSettings.isConfettiEnabled) _confetti.play();
      await SoundService.instance.play(
        ChimeKind.grand,
        enabled: enabled,
        profile: prof,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showXToast(
          context,
          fb.unlockedMedalTier != null
              ? '${l10n.medalUnlockedTitle}: ${habit.title}'
              : '${l10n.allDailyDoneTitle} — ${l10n.allDailyDoneSub}',
        );
      }
    } else if (fb.completedNow) {
      if (curSettings.isConfettiEnabled) _confetti.play();
      await SoundService.instance.play(
        ChimeKind.done,
        enabled: enabled,
        profile: prof,
      );
    } else if (habit.trackingStyle == TrackingStyle.count &&
        !habit.isQuit &&
        prevVal < habit.targetCount) {
      await SoundService.instance.play(
        ChimeKind.step,
        enabled: enabled,
        profile: prof,
      );
    } else {
      await SoundService.instance.play(
        ChimeKind.undo,
        enabled: enabled,
        profile: prof,
      );
    }
  }

  Future<void> _openEditPlacedWidgetSheet(
    PlacedWidgetInfo placed,
    List<Habit> activeHabits,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;

    if (placed.isToDoList) {
      final titleCtrl = TextEditingController(text: placed.customTitle);
      var hideDone = placed.hideCompleted;
      var themeMode = placed.themeMode;
      var saving = false;

      try {
        await showXModalSheet<void>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.todoWidgetLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: xc.card2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: xc.border),
                      ),
                      child: Text(
                        AppCalendar.localizeDigits(
                          l10n.widgetIdBadge(placed.widgetId),
                          settings.localeCode,
                        ),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: xc.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.widgetCustomTitleLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: xc.muted,
                  ),
                ),
                const SizedBox(height: 5),
                XDarkField(
                  controller: titleCtrl,
                  hintText: l10n.widgetCustomTitleHint,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                ),
                const SizedBox(height: 10),
                _ThemeModeRow(
                  themeMode: themeMode,
                  onChanged: (v) => setLocal(() => themeMode = v),
                  l10n: l10n,
                  xc: xc,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.todoFilterLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: xc.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChoicePill(
                        label: l10n.todoShowAllTasks,
                        active: !hideDone,
                        xc: xc,
                        onTap: () => setLocal(() => hideDone = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChoicePill(
                        label: l10n.todoPendingOnly,
                        active: hideDone,
                        xc: xc,
                        onTap: () => setLocal(() => hideDone = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    if (saving) return;
                    setLocal(() => saving = true);
                    try {
                      await WidgetSyncService.instance.updatePlacedWidgetConfig(
                        widgetId: placed.widgetId,
                        kind: 'todo_list',
                        hideCompleted: hideDone,
                        customTitle: titleCtrl.text.trim(),
                        themeMode: themeMode,
                      );
                      await _refreshPlacedWidgets();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showXToast(context, l10n.widgetUpdatedToast);
                      }
                    } finally {
                      if (ctx.mounted) setLocal(() => saving = false);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: xc.lime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.save,
                      style: TextStyle(
                        color: HabitPalette.contrastFg(xc.lime),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } finally {
        titleCtrl.dispose();
      }
      return;
    }

    if (placed.isDayMode) {
      var includeAll = placed.includeAll;
      var themeMode = placed.themeMode;
      var saving = false;

      await showXModalSheet<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.dayModeWidgetLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: xc.border),
                    ),
                    child: Text(
                      AppCalendar.localizeDigits(
                        l10n.widgetIdBadge(placed.widgetId),
                        settings.localeCode,
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: xc.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ThemeModeRow(
                themeMode: themeMode,
                onChanged: (v) => setLocal(() => themeMode = v),
                l10n: l10n,
                xc: xc,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ModeChoicePill(
                      label: l10n.dayModeCycleAllToggle,
                      active: includeAll,
                      xc: xc,
                      onTap: () => setLocal(() => includeAll = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeChoicePill(
                      label: l10n.dayModeCycleActiveOnly,
                      active: !includeAll,
                      xc: xc,
                      onTap: () => setLocal(() => includeAll = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.dayModeWidgetHint,
                style: TextStyle(fontSize: 11.5, color: xc.muted),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  if (saving) return;
                  setLocal(() => saving = true);
                  try {
                    await WidgetSyncService.instance.updatePlacedWidgetConfig(
                      widgetId: placed.widgetId,
                      kind: 'day_mode',
                      includeAll: includeAll,
                      themeMode: themeMode,
                    );
                    await _refreshPlacedWidgets();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) showXToast(context, l10n.widgetUpdatedToast);
                  } finally {
                    if (ctx.mounted) setLocal(() => saving = false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: xc.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.save,
                    style: TextStyle(
                      color: HabitPalette.contrastFg(xc.lime),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (placed.isAdaptive) {
      var selectedHabitId = placed.habitId ?? activeHabits.firstOrNull?.id;
      var themeMode = placed.themeMode;
      var saving = false;

      await showXModalSheet<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adaptiveWidgetLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: xc.border),
                    ),
                    child: Text(
                      AppCalendar.localizeDigits(
                        l10n.widgetIdBadge(placed.widgetId),
                        settings.localeCode,
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: xc.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ThemeModeRow(
                themeMode: themeMode,
                onChanged: (v) => setLocal(() => themeMode = v),
                l10n: l10n,
                xc: xc,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.42,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: activeHabits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final h = activeHabits[idx];
                    final on = selectedHabitId == h.id;
                    final accent = Color(h.colorValue);
                    return GestureDetector(
                      onTap: () => setLocal(() => selectedHabitId = h.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? accent.withValues(alpha: 0.14) : xc.card2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: on ? accent : xc.border,
                            width: on ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Icon(HabitPalette.iconFor(h.iconKey),
                                  size: 16, color: accent),
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
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: on ? accent : Colors.transparent,
                                shape: BoxShape.circle,
                                border: on
                                    ? null
                                    : Border.all(
                                        color: xc.borderStrong, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: on
                                  ? Icon(Icons.check_rounded,
                                      size: 13,
                                      color: HabitPalette.contrastFg(accent))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  if (saving || selectedHabitId == null) return;
                  setLocal(() => saving = true);
                  try {
                    await WidgetSyncService.instance.updatePlacedWidgetConfig(
                      widgetId: placed.widgetId,
                      kind: 'adaptive',
                      habitId: selectedHabitId,
                      themeMode: themeMode,
                    );
                    await _refreshPlacedWidgets();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      showXToast(context, l10n.widgetUpdatedToast);
                    }
                  } finally {
                    if (ctx.mounted) setLocal(() => saving = false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: xc.lime,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.save,
                    style: TextStyle(
                      color: HabitPalette.contrastFg(xc.lime),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Daily List Widget per-instance editor
    final titleCtrl = TextEditingController(text: placed.customTitle);
    var useAll = placed.listMode == 'all' ||
        (placed.listMode == 'default' && settings.widgetListHabitIds.isEmpty);
    final selected = placed.listMode == 'custom'
        ? List<String>.from(placed.habitIds)
        : (settings.widgetListHabitIds.isEmpty
            ? activeHabits.map((h) => h.id).toList()
            : List<String>.from(settings.widgetListHabitIds));
    var themeMode = placed.themeMode;
    var saving = false;

    try {
      await showXModalSheet<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.dailyListWidgetLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: xc.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: xc.border),
                  ),
                  child: Text(
                    AppCalendar.localizeDigits(
                      l10n.widgetIdBadge(placed.widgetId),
                      settings.localeCode,
                    ),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: xc.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.widgetCustomTitleLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: xc.muted,
              ),
            ),
            const SizedBox(height: 5),
            XDarkField(
              controller: titleCtrl,
              hintText: l10n.widgetCustomTitleHint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            ),
            const SizedBox(height: 10),
            _ThemeModeRow(
              themeMode: themeMode,
              onChanged: (v) => setLocal(() => themeMode = v),
              l10n: l10n,
              xc: xc,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeChoicePill(
                    label: l10n.widgetAllDueToday,
                    active: useAll,
                    xc: xc,
                    onTap: () => setLocal(() => useAll = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChoicePill(
                    label: l10n.widgetCustomHabitsMode,
                    active: !useAll,
                    xc: xc,
                    onTap: () => setLocal(() => useAll = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.34,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeHabits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (_, idx) {
                  final h = activeHabits[idx];
                  final on = useAll || selected.contains(h.id);
                  final accent = Color(h.colorValue);
                  return GestureDetector(
                    onTap: () {
                      setLocal(() {
                        useAll = false;
                        if (selected.contains(h.id)) {
                          selected.remove(h.id);
                        } else {
                          selected.add(h.id);
                        }
                      });
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: useAll ? 0.65 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: (!useAll && on) ? accent : xc.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(HabitPalette.iconFor(h.iconKey),
                                size: 17, color: accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: on
                                    ? (useAll ? xc.muted : accent)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: on
                                    ? null
                                    : Border.all(
                                        color: xc.borderStrong, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: on
                                  ? Icon(Icons.check_rounded,
                                      size: 12,
                                      color: useAll
                                          ? xc.card
                                          : HabitPalette.contrastFg(accent))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                if (saving) return;
                if (!useAll && selected.isEmpty) {
                  showXToast(ctx, l10n.widgetSelectAtLeastOne);
                  return;
                }
                setLocal(() => saving = true);
                try {
                  await WidgetSyncService.instance.updatePlacedWidgetConfig(
                    widgetId: placed.widgetId,
                    kind: 'daily_list',
                    useAll: useAll,
                    habitIds: selected,
                    customTitle: titleCtrl.text.trim(),
                    themeMode: themeMode,
                  );
                  await _refreshPlacedWidgets();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    showXToast(context, l10n.widgetUpdatedToast);
                  }
                } finally {
                  if (ctx.mounted) setLocal(() => saving = false);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: xc.lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.save,
                  style: TextStyle(
                    color: HabitPalette.contrastFg(xc.lime),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    } finally {
      titleCtrl.dispose();
    }
  }

  Future<void> _openStudioListFilterModal(
    BuildContext context,
    List<Habit> activeHabits,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    var localUseAll = _previewListUseAll;
    final localSelected = _previewListIds.isEmpty
        ? activeHabits.map((h) => h.id).toList()
        : List<String>.from(_previewListIds);

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.configureListHabits,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeChoicePill(
                    label: l10n.widgetAllDueToday,
                    active: localUseAll,
                    xc: xc,
                    onTap: () => setLocal(() => localUseAll = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeChoicePill(
                    label: l10n.widgetCustomHabitsMode,
                    active: !localUseAll,
                    xc: xc,
                    onTap: () => setLocal(() => localUseAll = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeHabits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (_, idx) {
                  final h = activeHabits[idx];
                  final on = localUseAll || localSelected.contains(h.id);
                  final accent = Color(h.colorValue);
                  return GestureDetector(
                    onTap: () {
                      setLocal(() {
                        localUseAll = false;
                        if (localSelected.contains(h.id)) {
                          localSelected.remove(h.id);
                        } else {
                          localSelected.add(h.id);
                        }
                      });
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: localUseAll ? 0.65 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: (!localUseAll && on) ? accent : xc.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(HabitPalette.iconFor(h.iconKey),
                                size: 17, color: accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: on
                                    ? (localUseAll ? xc.muted : accent)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: on
                                    ? null
                                    : Border.all(
                                        color: xc.borderStrong, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: on
                                  ? Icon(Icons.check_rounded,
                                      size: 12,
                                      color: localUseAll
                                          ? xc.card
                                          : HabitPalette.contrastFg(accent))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                if (!localUseAll && localSelected.isEmpty) {
                  showXToast(ctx, l10n.widgetSelectAtLeastOne);
                  return;
                }
                final normalized = localUseAll ? const <String>[] : localSelected;
                setState(() {
                  _previewListUseAll = localUseAll;
                  _previewListIds = List<String>.from(normalized);
                });
                final cur = ref.read(settingsProvider).value ?? settings;
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(cur.copyWith(widgetListHabitIds: normalized));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: xc.lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.save,
                  style: TextStyle(
                    color: HabitPalette.contrastFg(xc.lime),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _approxGridLabel(PlacedWidgetInfo w) {
    if (w.widthDp <= 0 || w.heightDp <= 0) {
      return w.isAdaptive ? '2×1+' : '4×2+';
    }
    final cols = w.widthDp >= 235 ? 4 : (w.widthDp >= 175 ? 3 : 2);
    final rows = w.heightDp >= 315
        ? 4
        : (w.heightDp >= 230 ? 3 : (w.heightDp >= 120 ? 2 : 1));
    return '$cols×$rows';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final state = ref.watch(habitStateProvider).value;
    final active =
        state?.habits.where((h) => !h.isArchived).toList() ?? const <Habit>[];
    final habitById = {for (final h in active) h.id: h};

    final hAd = active.where((h) => h.id == _previewAdaptiveHabitId).firstOrNull ??
        active.where((h) => h.id == settings.widgetHabitId).firstOrNull ??
        active.firstOrNull;

    final isLightWidget = settings.widgetTheme == WidgetThemeMode.light;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);

    final wCardBg = (isLightWidget ? Colors.white : const Color(0xFF0B0B0E))
        .withValues(alpha: settings.widgetOpacity);
    final wText = isLightWidget ? const Color(0xFF0F172A) : Colors.white;
    final wMuted =
        isLightWidget ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final wBorder =
        isLightWidget ? const Color(0x140F172A) : const Color(0x14FFFFFF);
    final wSep =
        isLightWidget ? const Color(0x1C0F172A) : const Color(0x17FFFFFF);
    final wIdleBg =
        isLightWidget ? const Color(0x0F0F172A) : const Color(0x12FFFFFF);
    final wPillBorder =
        isLightWidget ? const Color(0x3D0F172A) : const Color(0x2EFFFFFF);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Clean Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  XNavBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.homeWidgetsTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HdrCircleButton(
                    icon: Icons.sync_rounded,
                    onTap: () async {
                      if (state != null) {
                        await WidgetSyncService.instance.syncAll(
                          habits: state.habits,
                          checklistItems: state.checklistItems,
                          completions: state.completions,
                          pauses: state.pauses,
                          oneOffTasks: state.oneOffTasks,
                          settings: settings,
                        );
                      }
                      await _refreshPlacedWidgets();
                      if (context.mounted) {
                        showXToast(context, l10n.refreshWidgets);
                      }
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 28 + bottomInset),
                children: [
                  // 1. Global Appearance & Behavior Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 13),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.widgetThemeLabel,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: xc.text,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    l10n.widgetThemeSectionHint,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: xc.muted,
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final opt in [
                                    (WidgetThemeMode.dark, l10n.oledBlack),
                                    (WidgetThemeMode.light, l10n.lightMode),
                                  ])
                                    GestureDetector(
                                      onTap: () async {
                                        final cur =
                                            ref.read(settingsProvider).value ??
                                                settings;
                                        await ref
                                            .read(settingsProvider.notifier)
                                            .updateSettings(cur.copyWith(
                                                widgetTheme: opt.$1));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 11, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: settings.widgetTheme == opt.$1
                                              ? xc.lime
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          opt.$2,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: settings.widgetTheme == opt.$1
                                                ? HabitPalette.contrastFg(xc.lime)
                                                : xc.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: xc.border),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.localeCode == 'fa'
                                  ? 'شفافیت پس‌زمینه ویجت'
                                  : 'Widget Background Opacity',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: xc.card2,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: xc.border),
                              ),
                              child: Text(
                                AppCalendar.localizeDigits(
                                  '${(settings.widgetOpacity * 100).round()}%',
                                  settings.localeCode,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: xc.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                          ),
                          child: Slider(
                            value: settings.widgetOpacity.clamp(0.0, 1.0),
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            activeColor: xc.lime,
                            inactiveColor: xc.card2,
                            onChanged: (val) async {
                              final cur =
                                  ref.read(settingsProvider).value ?? settings;
                              await ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                      cur.copyWith(widgetOpacity: val));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Active Placed Home Screen Widgets (Per-Widget Independent Management)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.activeHomeWidgetsTitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: xc.card2,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: xc.border),
                              ),
                              child: Text(
                                AppCalendar.localizeDigits(
                                  '${_placedWidgets.length}',
                                  settings.localeCode,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _placedWidgets.isEmpty
                                      ? xc.muted
                                      : xc.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_loadingPlaced)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_placedWidgets.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: xc.card2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: xc.border),
                            ),
                            child: Text(
                              l10n.noPlacedWidgetsMsg,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.5,
                                color: xc.muted,
                              ),
                            ),
                          )
                        else ...[
                          for (var i = 0; i < _placedWidgets.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _buildPlacedWidgetTile(
                              _placedWidgets[i],
                              habitById,
                              active,
                              settings,
                              xc,
                              l10n,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  size: 14, color: xc.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.holdToReconfigureTip,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: xc.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 3. Interactive Preview & Add New Widget Studio
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.widgetPreviewStudioTitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: xc.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Studio Type Tabs (2x2 clean grid supporting all 4 widgets)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: xc.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: xc.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StudioTabPill(
                                      icon: Icons.auto_awesome_mosaic_outlined,
                                      label: l10n.adaptiveWidgetLabel,
                                      active: _studioTab == 0,
                                      xc: xc,
                                      onTap: () =>
                                          setState(() => _studioTab = 0),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _StudioTabPill(
                                      icon: Icons.checklist_rtl_rounded,
                                      label: l10n.dailyListWidgetLabel,
                                      active: _studioTab == 1,
                                      xc: xc,
                                      onTap: () =>
                                          setState(() => _studioTab = 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StudioTabPill(
                                      icon: Icons.fact_check_outlined,
                                      label: l10n.todoWidgetLabel,
                                      active: _studioTab == 2,
                                      xc: xc,
                                      onTap: () =>
                                          setState(() => _studioTab = 2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _StudioTabPill(
                                      icon: Icons.tune_rounded,
                                      label: l10n.dayModeWidgetLabel,
                                      active: _studioTab == 3,
                                      xc: xc,
                                      onTap: () =>
                                          setState(() => _studioTab = 3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (active.isNotEmpty && _studioTab == 0 && hAd != null)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showXHabitPickerSheet(
                                      context: context,
                                      title: l10n.selectHabitTitle,
                                      habits: active,
                                      selectedId: hAd.id,
                                    );
                                    if (picked == null || !mounted) return;
                                    setState(
                                        () => _previewAdaptiveHabitId = picked);
                                    final cur =
                                        ref.read(settingsProvider).value ??
                                            settings;
                                    await ref
                                        .read(settingsProvider.notifier)
                                        .updateSettings(
                                            cur.copyWith(widgetHabitId: picked));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: xc.card2,
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(color: xc.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(HabitPalette.iconFor(hAd.iconKey),
                                            size: 16,
                                            color: Color(hAd.colorValue)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            hAd.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: xc.text,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            size: 16, color: xc.muted),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        if (active.isNotEmpty && _studioTab == 1)
                          GestureDetector(
                            onTap: () => _openStudioListFilterModal(
                                context, active, settings),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 9),
                              decoration: BoxDecoration(
                                color: xc.card2,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: xc.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.checklist_rounded,
                                      size: 16, color: xc.lime),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _previewListUseAll
                                          ? l10n.widgetAllDueToday
                                          : AppCalendar.localizeDigits(
                                              l10n.widgetCountSelected(
                                                  _previewListIds.length),
                                              settings.localeCode,
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: xc.text,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.tune_rounded,
                                      size: 15, color: xc.muted),
                                ],
                              ),
                            ),
                          ),

                        if (_studioTab == 2)
                          Row(
                            children: [
                              Expanded(
                                child: _ModeChoicePill(
                                  label: l10n.todoShowAllTasks,
                                  active: !_previewTodoHideDone,
                                  xc: xc,
                                  onTap: () =>
                                      setState(() => _previewTodoHideDone = false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ModeChoicePill(
                                  label: l10n.todoPendingOnly,
                                  active: _previewTodoHideDone,
                                  xc: xc,
                                  onTap: () =>
                                      setState(() => _previewTodoHideDone = true),
                                ),
                              ),
                            ],
                          ),

                        if (_studioTab == 3)
                          Row(
                            children: [
                              Expanded(
                                child: _ModeChoicePill(
                                  label: l10n.dayModeCycleAllToggle,
                                  active: _previewDayModeIncludeAll,
                                  xc: xc,
                                  onTap: () => setState(
                                      () => _previewDayModeIncludeAll = true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ModeChoicePill(
                                  label: l10n.dayModeCycleActiveOnly,
                                  active: !_previewDayModeIncludeAll,
                                  xc: xc,
                                  onTap: () => setState(
                                      () => _previewDayModeIncludeAll = false),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 10),

                        // Interactive Live Preview Board with Confetti
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isLightWidget
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF050507),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: xc.border),
                                ),
                                child: ((_studioTab == 0 || _studioTab == 1) &&
                                        active.isEmpty)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 22),
                                        child: Center(
                                          child: Text(
                                            l10n.noHabitsYet,
                                            style: TextStyle(
                                                fontSize: 12, color: wMuted),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_studioTab == 0) ...[
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                '2x1',
                                                '3x1',
                                                '4x1',
                                                '2x2',
                                                '3x2',
                                                '4x2',
                                                '4x3',
                                                '4x4',
                                              ].map((s) {
                                                final on = _morphSize == s;
                                                return GestureDetector(
                                                  onTap: () => setState(
                                                      () => _morphSize = s),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: on
                                                          ? xc.lime
                                                          : wBorder,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      AppCalendar
                                                          .localizeDigits(
                                                              s,
                                                              settings
                                                                  .localeCode),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: on
                                                            ? HabitPalette
                                                                .contrastFg(
                                                                    xc.lime)
                                                            : wMuted,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 10),
                                            if (hAd != null)
                                              Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child:
                                                    _buildAdaptivePreviewCard(
                                                  hAd,
                                                  state!,
                                                  settings,
                                                  today,
                                                  todayKey,
                                                  wCardBg,
                                                  wText,
                                                  wMuted,
                                                  wBorder,
                                                  wSep,
                                                  wIdleBg,
                                                  wPillBorder,
                                                  l10n,
                                                ),
                                              ),
                                          ] else if (_studioTab == 1) ...[
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                '2x2',
                                                '3x2',
                                                '3x3',
                                                '4x2',
                                                '4x3',
                                                '4x6',
                                              ].map((s) {
                                                final on = _listSize == s;
                                                return GestureDetector(
                                                  onTap: () => setState(
                                                      () => _listSize = s),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: on
                                                          ? xc.lime
                                                          : wBorder,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      AppCalendar
                                                          .localizeDigits(
                                                              s,
                                                              settings
                                                                  .localeCode),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: on
                                                            ? HabitPalette
                                                                .contrastFg(
                                                                    xc.lime)
                                                            : wMuted,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 10),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: _buildListPreviewCard(
                                                active,
                                                state!,
                                                settings,
                                                today,
                                                todayKey,
                                                wCardBg,
                                                wText,
                                                wMuted,
                                                wBorder,
                                                xc,
                                              ),
                                            ),
                                          ] else if (_studioTab == 2) ...[
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                '2x2',
                                                '3x2',
                                                '4x2',
                                                '4x3',
                                                '4x6',
                                              ].map((s) {
                                                final on = _todoSize == s;
                                                return GestureDetector(
                                                  onTap: () => setState(
                                                      () => _todoSize = s),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: on
                                                          ? xc.lime
                                                          : wBorder,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      AppCalendar
                                                          .localizeDigits(
                                                              s,
                                                              settings
                                                                  .localeCode),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: on
                                                            ? HabitPalette
                                                                .contrastFg(
                                                                    xc.lime)
                                                            : wMuted,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 10),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: _buildToDoPreviewCard(
                                                state?.oneOffTasks ??
                                                    const <OneOffTask>[],
                                                settings,
                                                wCardBg,
                                                wText,
                                                wMuted,
                                                wBorder,
                                                wIdleBg,
                                                wPillBorder,
                                                xc,
                                                l10n,
                                              ),
                                            ),
                                          ] else ...[
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                '2x1',
                                                '3x1',
                                                '4x1',
                                              ].map((s) {
                                                final on = _dayModeSize == s;
                                                return GestureDetector(
                                                  onTap: () => setState(
                                                      () => _dayModeSize = s),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: on
                                                          ? xc.lime
                                                          : wBorder,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      AppCalendar
                                                          .localizeDigits(
                                                              s,
                                                              settings
                                                                  .localeCode),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: on
                                                            ? HabitPalette
                                                                .contrastFg(
                                                                    xc.lime)
                                                            : wMuted,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 10),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: _buildDayModePreviewCard(
                                                active,
                                                settings,
                                                today,
                                                wCardBg,
                                                wText,
                                                wMuted,
                                                wBorder,
                                                wIdleBg,
                                                wPillBorder,
                                                l10n,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                              ConfettiWidget(
                                confettiController: _confetti,
                                blastDirectionality:
                                    BlastDirectionality.explosive,
                                emissionFrequency: 0.08,
                                numberOfParticles: 24,
                                gravity: 0.25,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Unified contextual Add to Home Screen CTA for selected studio widget
                        GestureDetector(
                          onTap: () async {
                            if (_pinning) return;
                            setState(() => _pinning = true);
                            try {
                              final launched = switch (_studioTab) {
                                0 => await WidgetSyncService.instance
                                    .requestPinAdaptiveWidget(habitId: hAd?.id),
                                1 => await WidgetSyncService.instance
                                    .requestPinDailyListWidget(
                                    useAll: _previewListUseAll,
                                    habitIds: _previewListIds,
                                  ),
                                2 => await WidgetSyncService.instance
                                    .requestPinToDoWidget(
                                    hideCompleted: _previewTodoHideDone,
                                  ),
                                _ => await WidgetSyncService.instance
                                    .requestPinDayModeWidget(
                                    includeAll: _previewDayModeIncludeAll,
                                  ),
                              };
                              if (context.mounted) {
                                showXToast(
                                  context,
                                  launched
                                      ? l10n.pinWidgetTriggered
                                      : l10n.holdToReconfigureTip,
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _pinning = false);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12.5),
                            decoration: BoxDecoration(
                              color: xc.lime,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_to_home_screen_rounded,
                                    size: 16,
                                    color: HabitPalette.contrastFg(xc.lime)),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    switch (_studioTab) {
                                      0 => l10n.pinAdaptiveWidget,
                                      1 => l10n.pinListWidget,
                                      2 => l10n.pinToDoWidget,
                                      _ => l10n.pinDayModeWidget,
                                    },
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: HabitPalette.contrastFg(xc.lime),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacedWidgetTile(
    PlacedWidgetInfo w,
    Map<String, Habit> habitById,
    List<Habit> active,
    AppSettings settings,
    XColors xc,
    AppLocalizations l10n,
  ) {
    final adaptiveHabit = w.habitId != null ? habitById[w.habitId!] : null;
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final activeModeId = HabitEngine.resolveDayMode(settings, today);
    final activeModeCfg =
        settings.dayModesList.where((m) => m.id == activeModeId).firstOrNull;

    final accent = switch (w.kind) {
      'adaptive' =>
        adaptiveHabit != null ? Color(adaptiveHabit.colorValue) : xc.lime,
      'day_mode' => Color(
          activeModeId == 'all'
              ? settings.allDayModeColorValue
              : (activeModeCfg?.colorValue ?? 0xFF84CC16),
        ),
      _ => xc.lime,
    };

    final kindLabel = switch (w.kind) {
      'adaptive' => l10n.adaptiveWidgetLabel,
      'daily_list' =>
        w.customTitle.isNotEmpty ? w.customTitle : l10n.dailyListWidgetLabel,
      'todo_list' =>
        w.customTitle.isNotEmpty ? w.customTitle : l10n.todoWidgetLabel,
      'day_mode' => l10n.dayModeWidgetLabel,
      _ => l10n.adaptiveWidgetLabel,
    };

    String summary;
    if (w.isAdaptive) {
      summary = adaptiveHabit?.title ?? l10n.noHabitsYet;
    } else if (w.isToDoList) {
      summary =
          w.hideCompleted ? l10n.todoPendingOnly : l10n.todoShowAllTasks;
    } else if (w.isDayMode) {
      summary =
          w.includeAll ? l10n.dayModeCycleAllToggle : l10n.dayModeCycleActiveOnly;
    } else if (w.listMode == 'all' ||
        (w.listMode == 'default' && settings.widgetListHabitIds.isEmpty)) {
      summary = l10n.widgetAllDueToday;
    } else {
      final ids =
          w.listMode == 'custom' ? w.habitIds : settings.widgetListHabitIds;
      final titles = ids
          .map((id) => habitById[id]?.title)
          .whereType<String>()
          .toList();
      if (titles.isEmpty) {
        summary = AppCalendar.localizeDigits(
            l10n.widgetCountSelected(0), settings.localeCode);
      } else {
        final preview = titles.take(2).join('، ');
        summary = titles.length > 2
            ? '$preview +${AppCalendar.localizeDigits('${titles.length - 2}', settings.localeCode)}'
            : preview;
      }
    }

    final iconData = switch (w.kind) {
      'adaptive' => adaptiveHabit != null
          ? HabitPalette.iconFor(adaptiveHabit.iconKey)
          : Icons.widgets_outlined,
      'todo_list' => Icons.fact_check_outlined,
      'day_mode' => HabitPalette.iconFor(
          activeModeId == 'all'
              ? settings.allDayModeIconKey
              : (activeModeCfg?.iconKey ?? 'tune'),
        ),
      _ => Icons.format_list_bulleted_rounded,
    };

    final canEdit = (w.isToDoList || w.isDayMode) || active.isNotEmpty;

    final themeTag = w.themeMode == 'light'
        ? ' • ${l10n.lightMode}'
        : (w.themeMode == 'dark' ? ' • ${l10n.oledBlack}' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: xc.card2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: xc.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              iconData,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        kindLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppCalendar.localizeDigits(
                        '${_approxGridLabel(w)} • #${w.widgetId}$themeTag',
                        settings.localeCode,
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: xc.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: xc.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: !canEdit
                ? null
                : () => _openEditPlacedWidgetSheet(w, active, settings),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: xc.card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: xc.borderStrong),
              ),
              child: Text(
                l10n.editWidgetAction,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: !canEdit ? xc.muted : xc.lime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptivePreviewCard(
    Habit hAd,
    XHabitState state,
    AppSettings settings,
    DateTime today,
    String todayKey,
    Color wCardBg,
    Color wText,
    Color wMuted,
    Color wBorder,
    Color wSep,
    Color wIdleBg,
    Color wPillBorder,
    AppLocalizations l10n,
  ) {
    final accent = Color(hAd.colorValue);
    final items = state.checklistFor(hAd.id);
    final byDate = state.completionsByDateFor(hAd.id);
    final comp = byDate[todayKey];
    final done =
        HabitEngine.isCompletedOn(hAd, comp, items, today, today: today);
    final ratio =
        HabitEngine.progressRatio(hAd, comp, items, today, today: today);
    final stats = HabitEngine.computeStats(
      hAd,
      byDate,
      items,
      calendar: settings.calendarSystem,
      weekStart: settings.weekStartDay,
      today: today,
      pauses: state.pauses,
      monthlyGraceDays: settings.streakGraceDaysPerMonth,
    );
    final curVal = comp?.value ?? 0;

    if (_morphSize == '2x1' || _morphSize == '3x1') {
      final is3 = _morphSize == '3x1';
      final cardW = is3 ? 244.0 : 168.0;
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: cardW,
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: wBorder),
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.35,
              colors: [accent.withValues(alpha: 0.18), wCardBg],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: is3 ? 32 : 28,
                height: is3 ? 32 : 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(is3 ? 10 : 9),
                ),
                alignment: Alignment.center,
                child: Icon(HabitPalette.iconFor(hAd.iconKey),
                    size: is3 ? 18 : 16, color: accent),
              ),
              SizedBox(width: is3 ? 9 : 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hAd.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: is3 ? 12 : 11,
                        fontWeight: FontWeight.w800,
                        color: wText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    hAd.trackingStyle == TrackingStyle.count
                        ? Text(
                            AppCalendar.localizeDigits(
                                '$curVal/${hAd.targetCount}',
                                settings.localeCode),
                            style: TextStyle(fontSize: 9.5, color: wMuted),
                          )
                        : Row(
                            children: [
                              Text(
                                AppCalendar.localizeDigits(
                                    '${stats.currentStreak}',
                                    settings.localeCode),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.local_fire_department_rounded,
                                  size: 11, color: accent),
                            ],
                          ),
                  ],
                ),
              ),
              HabitActionCircle(
                habit: hAd,
                done: done,
                ratio: ratio,
                slipped: hAd.isQuit && (comp?.slipped == true),
                size: is3 ? 34 : 32,
                onTap: () => _togglePreviewHabit(hAd, today, settings),
              ),
            ],
          ),
        ),
      );
    }

    if (_morphSize == '4x1') {
      return Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: wBorder),
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [accent.withValues(alpha: 0.16 * settings.widgetOpacity), wCardBg],
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hAd.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: wText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    hAd.trackingStyle == TrackingStyle.count
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppCalendar.localizeDigits(
                                    '$curVal/${hAd.targetCount}',
                                    settings.localeCode),
                                style: TextStyle(fontSize: 9.5, color: wMuted),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: SizedBox(
                                  width: 92,
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 4,
                                    backgroundColor: wBorder,
                                    valueColor: AlwaysStoppedAnimation(accent),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Text(
                                AppCalendar.localizeDigits(
                                    '${stats.currentStreak}',
                                    settings.localeCode),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.local_fire_department_rounded,
                                  size: 12, color: accent),
                            ],
                          ),
                  ],
                ),
              ),
              Row(
                children: List.generate(7, (i) {
                  final d = DateTime(today.year, today.month, today.day - (6 - i));
                  final dk = AppCalendar.toDateKey(d);
                  final r = HabitEngine.progressRatio(
                      hAd, byDate[dk], items, d,
                      today: today);
                  final isT = dk == todayKey;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppCalendar.weekdayMin(
                              d.weekday, settings.localeCode),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: wMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: r >= 1.0
                                ? accent
                                : r > 0
                                    ? accent.withValues(alpha: 0.45)
                                    : accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                            border: isT
                                ? Border.all(color: wText, width: 1.4)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              HabitActionCircle(
                habit: hAd,
                done: done,
                ratio: ratio,
                slipped: hAd.isQuit && (comp?.slipped == true),
                size: 36,
                onTap: () => _togglePreviewHabit(hAd, today, settings),
              ),
            ],
          ),
        ),
      );
    }

    if (_morphSize == '2x2') {
      final order = AppCalendar.orderedWeekdays(settings.weekStartDay);
      final cells = AppCalendar.monthGridDates(
          today, settings.calendarSystem, settings.weekStartDay);
      final calRows = (cells.length / 7).ceil();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: wBorder),
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.25,
              colors: [accent.withValues(alpha: 0.16 * settings.widgetOpacity), wCardBg],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hAd.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: wText,
                            ),
                          ),
                          Text(
                            AppCalendar.formatMonthYear(today,
                                    settings.calendarSystem, settings.localeCode) +
                                (hAd.trackingStyle == TrackingStyle.count
                                    ? AppCalendar.localizeDigits(
                                        ' - $curVal/${hAd.targetCount}',
                                        settings.localeCode)
                                    : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 8.5, color: wMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    HabitActionCircle(
                      habit: hAd,
                      done: done,
                      ratio: ratio,
                      slipped: hAd.isQuit && (comp?.slipped == true),
                      size: 32,
                      onTap: () => _togglePreviewHabit(hAd, today, settings),
                    ),
                  ],
                ),
              ),
              SizedBox(height: calRows >= 6 ? 5 : 7),
              Row(
                children: order
                    .map((w) => Expanded(
                          child: Center(
                            child: Text(
                              AppCalendar.weekdayMin(w, settings.localeCode),
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                                color: wMuted,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 3),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: calRows >= 6 ? 2 : 2.5,
                  crossAxisSpacing: calRows >= 6 ? 2 : 2.5,
                  childAspectRatio: calRows >= 6 ? 1.2 : 1.0,
                ),
                itemCount: cells.length,
                itemBuilder: (_, idx) {
                  final d = cells[idx];
                  if (d == null) return const SizedBox.shrink();
                  final fut = d.isAfter(today);
                  final dk = AppCalendar.toDateKey(d);
                  final r = fut
                      ? 0.0
                      : HabitEngine.progressRatio(
                          hAd, byDate[dk], items, d,
                          today: today);
                  final isT = dk == todayKey;
                  return Container(
                    decoration: BoxDecoration(
                      color: fut
                          ? Colors.transparent
                          : r >= 1.0
                              ? accent
                              : r > 0
                                  ? accent.withValues(alpha: 0.45)
                                  : accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(2.5),
                      border: isT
                          ? Border.all(color: wText, width: 1.3)
                          : fut
                              ? Border.all(
                                  color: accent.withValues(alpha: 0.25),
                                  width: 1)
                              : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    final isTall = _morphSize == '4x3' || _morphSize == '4x4';
    final hmWeeks = _morphSize == '3x2' ? 12 : 18;
    final subLabel = _morphSize == '3x2'
        ? (settings.localeCode == 'fa'
            ? '۳ ماه اخیر (۱۲ هفته)'
            : 'Last 3 months (12w)')
        : (settings.localeCode == 'fa'
            ? '۴ ماه اخیر (۱۸ هفته)'
            : 'Last 4 months (18w)');
    final order = AppCalendar.orderedWeekdays(settings.weekStartDay);
    final endOffset = order.indexOf(today.weekday);
    final hmStart = DateTime(
      today.year,
      today.month,
      today.day - ((hmWeeks - 1) * 7 + endOffset),
    );
    final cardWidth = _morphSize == '3x2' ? 248.0 : double.infinity;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: wBorder),
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [accent.withValues(alpha: 0.16 * settings.widgetOpacity), wCardBg],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      HabitPalette.iconFor(hAd.iconKey),
                      size: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hAd.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: wText,
                          ),
                        ),
                        Text(
                          subLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, color: wMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                if (isTall && hAd.trackingStyle == TrackingStyle.count && !hAd.isQuit)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: wIdleBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: wPillBorder),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: curVal <= 0
                              ? null
                              : () async {
                                  await ref
                                      .read(habitStateProvider.notifier)
                                      .stepHabitCount(hAd, today, -1);
                                  await SoundService.instance.play(
                                    ChimeKind.undo,
                                    enabled: settings.isAchievementSoundEnabled,
                                    profile: settings.soundProfile,
                                  );
                                },
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: Text('−',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: curVal <= 0 ? wMuted : wText)),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 32),
                          child: Text(
                            AppCalendar.localizeDigits(
                                '$curVal/${hAd.targetCount}',
                                settings.localeCode),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: wText,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: curVal >= hAd.targetCount
                              ? null
                              : () async {
                                  final fb = await ref
                                      .read(habitStateProvider.notifier)
                                      .stepHabitCount(hAd, today, 1);
                                  await SoundService.instance.play(
                                    fb.completedNow
                                        ? ChimeKind.done
                                        : ChimeKind.step,
                                    enabled: settings.isAchievementSoundEnabled,
                                    profile: settings.soundProfile,
                                  );
                                },
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: Text('+',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: curVal >= hAd.targetCount
                                          ? accent.withValues(alpha: 0.4)
                                          : accent)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        AppCalendar.localizeDigits(
                            '${stats.currentStreak}', settings.localeCode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.local_fire_department_rounded,
                          size: 14, color: accent),
                    ],
                  ),
                const SizedBox(width: 8),
                HabitActionCircle(
                  habit: hAd,
                  done: done,
                  ratio: ratio,
                  slipped: hAd.isQuit && (comp?.slipped == true),
                  size: 34,
                  onTap: () => _togglePreviewHabit(hAd, today, settings),
                ),
              ],
            ),
          ),
            if (isTall && hAd.trackingStyle == TrackingStyle.count && !hAd.isQuit) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: wBorder,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: List.generate(7, (r) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: r < 6 ? 2.5 : 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text(
                            AppCalendar.weekdayMin(
                                order[r], settings.localeCode),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              color: wMuted,
                            ),
                          ),
                        ),
                        ...List.generate(hmWeeks, (w) {
                          final d = DateTime(
                            hmStart.year,
                            hmStart.month,
                            hmStart.day + w * 7 + r,
                          );
                          final dk = AppCalendar.toDateKey(d);
                          final fut = d.isAfter(today);
                          final cellRatio = fut
                              ? 0.0
                              : HabitEngine.progressRatio(
                                  hAd, byDate[dk], items, d,
                                  today: today);
                          final isT = dk == todayKey;
                          return Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.only(left: w == 0 ? 2 : 2.5),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: fut
                                        ? const Color(0x1E808080)
                                        : cellRatio >= 1.0
                                            ? accent
                                            : cellRatio > 0
                                                ? accent.withValues(alpha: 0.45)
                                                : accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(3),
                                    border: isT
                                        ? Border.all(color: wText, width: 1)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ),
            ),
            if (isTall) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: wSep),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        AppCalendar.localizeDigits(
                            '${stats.currentStreak}', settings.localeCode),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: accent),
                      ),
                      Text(
                        l10n.currentStreak,
                        style: TextStyle(fontSize: 9, color: wMuted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        AppCalendar.localizeDigits(
                            '${stats.bestStreak}', settings.localeCode),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: wText),
                      ),
                      Text(
                        l10n.bestStreak,
                        style: TextStyle(fontSize: 9, color: wMuted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        AppCalendar.localizeDigits(
                            '${stats.habitScore}%', settings.localeCode),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: wText),
                      ),
                      Text(
                        l10n.completionRate,
                        style: TextStyle(fontSize: 9, color: wMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (_morphSize == '4x4' &&
                  hAd.trackingStyle == TrackingStyle.checklist &&
                  items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...items.take(5).map((sub) {
                  final subDone =
                      comp?.completedChecklistIds.contains(sub.id) ?? false;
                  return InkWell(
                    borderRadius: BorderRadius.circular(7),
                    onTap: () async {
                      final fb = await ref
                          .read(habitStateProvider.notifier)
                          .toggleChecklistItem(hAd, today, sub.id);
                      if (!mounted) return;
                      final curSettings =
                          ref.read(settingsProvider).value ?? settings;
                      if (fb.completedNow && curSettings.isConfettiEnabled) {
                        _confetti.play();
                      }
                      await SoundService.instance.play(
                        fb.completedNow ? ChimeKind.done : ChimeKind.step,
                        enabled: curSettings.isAchievementSoundEnabled,
                        profile: curSettings.soundProfile,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: subDone ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: subDone
                                  ? null
                                  : Border.all(
                                      color: accent.withValues(alpha: 0.55),
                                      width: 1.5,
                                    ),
                            ),
                            alignment: Alignment.center,
                            child: subDone
                                ? Icon(Icons.check_rounded,
                                    size: 11,
                                    color: HabitPalette.contrastFg(accent))
                                : null,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              sub.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: subDone
                                    ? wMuted.withValues(alpha: 0.55)
                                    : wText,
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
          ],
        ),
      ),
    );
  }

  Widget _buildListPreviewCard(
    List<Habit> active,
    XHabitState state,
    AppSettings settings,
    DateTime today,
    String todayKey,
    Color wCardBg,
    Color wText,
    Color wMuted,
    Color wBorder,
    XColors xc,
  ) {
    final todayMode = HabitEngine.resolveDayMode(settings, today);
    final pool = _previewListUseAll
        ? active
        : active.where((h) => _previewListIds.contains(h.id)).toList();
    final items = pool
        .where((h) =>
            HabitEngine.matchesDayMode(h, todayMode) &&
            !HabitEngine.isPausedOn(h.id, today, state.pauses) &&
            HabitEngine.isScheduledOn(
              h,
              today,
              calendar: settings.calendarSystem,
              weekStart: settings.weekStartDay,
              completionsByDate: state.completionsByDateFor(h.id),
              checklistItems: state.checklistFor(h.id),
              today: today,
            ))
        .toList();
    final doneCnt = items
        .where((h) => HabitEngine.isCompletedOn(
              h,
              state.completionsByDateFor(h.id)[todayKey],
              state.checklistFor(h.id),
              today,
              today: today,
            ))
        .length;
    final pct = items.isEmpty ? 0.0 : doneCnt / items.length;
    final showSubSteps =
        _listSize == '3x3' || _listSize == '4x3' || _listSize == '4x6';
    final cardWidth = _listSize == '2x2'
        ? 168.0
        : (_listSize == '3x2' || _listSize == '3x3')
            ? 248.0
            : double.infinity;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: wCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: wBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  settings.localeCode == 'fa' ? 'امروز' : 'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: wText,
                  ),
                ),
                Text(
                  AppCalendar.localizeDigits(
                      '$doneCnt/${items.length}', settings.localeCode),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: wMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: wBorder,
                valueColor: AlwaysStoppedAnimation(xc.lime),
              ),
            ),
            const SizedBox(height: 8),
            ...items.take(_listSize == '4x6' ? 10 : 5).map((h) {
              final cItems = state.checklistFor(h.id);
              final comp = state.completionsByDateFor(h.id)[todayKey];
              final done = HabitEngine.isCompletedOn(
                  h, comp, cItems, today,
                  today: today);
              final ratio = HabitEngine.progressRatio(
                  h, comp, cItems, today,
                  today: today);
              final accent = Color(h.colorValue);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 3.5,
                          height: 14,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            h.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? wMuted.withValues(alpha: 0.45)
                                  : wText,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (h.trackingStyle == TrackingStyle.count && !done) ...[
                          Text(
                            AppCalendar.localizeDigits(
                              '${comp?.value ?? 0}/${h.targetCount}',
                              settings.localeCode,
                            ),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: wMuted),
                          ),
                          const SizedBox(width: 6),
                        ],
                        HabitActionCircle(
                          habit: h,
                          done: done,
                          ratio: ratio,
                          slipped: h.isQuit && (comp?.slipped == true),
                          size: _listSize == '2x2' ? 26 : 28,
                          onTap: () => _togglePreviewHabit(h, today, settings),
                        ),
                      ],
                    ),
                  ),
                  if (showSubSteps &&
                      !done &&
                      h.trackingStyle == TrackingStyle.checklist &&
                      cItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: 14, bottom: 4),
                      child: Column(
                        children: cItems.map((sub) {
                          final subDone =
                              comp?.completedChecklistIds.contains(sub.id) ??
                                  false;
                          return InkWell(
                            borderRadius: BorderRadius.circular(7),
                            onTap: () async {
                              final fb = await ref
                                  .read(habitStateProvider.notifier)
                                  .toggleChecklistItem(h, today, sub.id);
                              if (!mounted) return;
                              final curSettings =
                                  ref.read(settingsProvider).value ?? settings;
                              await SoundService.instance.play(
                                fb.completedNow ? ChimeKind.done : ChimeKind.step,
                                enabled: curSettings.isAchievementSoundEnabled,
                                profile: curSettings.soundProfile,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: subDone
                                          ? accent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: subDone
                                          ? null
                                          : Border.all(
                                              color: accent.withValues(
                                                  alpha: 0.55),
                                              width: 1.4,
                                            ),
                                    ),
                                    alignment: Alignment.center,
                                    child: subDone
                                        ? Icon(Icons.check_rounded,
                                            size: 10,
                                            color:
                                                HabitPalette.contrastFg(accent))
                                        : null,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: subDone
                                            ? wMuted.withValues(alpha: 0.55)
                                            : wText,
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
                        }).toList(),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _localizedDayModeName(DayModeConfig mode, String localeCode) {
    if (mode.name.trim().isNotEmpty) return mode.name.trim();
    final isFa = localeCode == 'fa';
    return switch (mode.id) {
      'normal' => isFa ? 'عادی' : 'Normal',
      'work' => isFa ? 'روز کاری' : 'Work Day',
      'off' => isFa ? 'روز تعطیل' : 'Day Off',
      'travel' => isFa ? 'مسافرت' : 'Travel',
      _ => mode.id,
    };
  }

  Future<void> _stepPreviewDayMode(
    AppSettings settings,
    DateTime today,
    int delta,
  ) async {
    final modeIds = <String>[
      if (_previewDayModeIncludeAll) 'all',
      for (final m in settings.dayModesList) m.id,
    ];
    if (modeIds.isEmpty) return;

    final effective = HabitEngine.resolveDayMode(settings, today);
    var idx = modeIds.indexOf(effective);
    if (idx < 0) idx = 0;
    final nextIdx =
        ((idx + delta) % modeIds.length + modeIds.length) % modeIds.length;
    final targetId = modeIds[nextIdx];

    final todayKey = AppCalendar.toDateKey(today);
    final hasDateRule = settings.dayModeByDate.containsKey(todayKey);
    final hasWeekdayRule = settings.weekdayDayModes.containsKey(today.weekday);
    final fallbackNonAll = settings.dayModesList.any((d) => d.id == 'normal')
        ? 'normal'
        : (settings.dayModesList.isNotEmpty
            ? settings.dayModesList.first.id
            : 'all');

    final notifier = ref.read(settingsProvider.notifier);
    if (targetId == 'all') {
      await notifier.updateSettings(settings.copyWith(activeDayMode: 'all'));
    } else if (hasDateRule || hasWeekdayRule) {
      final nextMap = Map<String, String>.from(settings.dayModeByDate)
        ..[todayKey] = targetId;
      await notifier.updateSettings(
        settings.copyWith(
          dayModeByDate: nextMap,
          activeDayMode: settings.activeDayMode == 'all'
              ? fallbackNonAll
              : settings.activeDayMode,
        ),
      );
    } else {
      await notifier.updateSettings(settings.copyWith(activeDayMode: targetId));
    }
    await SoundService.instance.play(
      ChimeKind.step,
      enabled: settings.isAchievementSoundEnabled,
      profile: settings.soundProfile,
    );
  }

  Widget _buildToDoPreviewCard(
    List<OneOffTask> allTasks,
    AppSettings settings,
    Color wCardBg,
    Color wText,
    Color wMuted,
    Color wBorder,
    Color wIdleBg,
    Color wPillBorder,
    XColors xc,
    AppLocalizations l10n,
  ) {
    final visible = _previewTodoHideDone
        ? allTasks.where((t) => !t.isDone).toList()
        : allTasks;
    final doneCnt = allTasks.where((t) => t.isDone).length;
    final totalCnt = allTasks.length;
    final pct = totalCnt == 0 ? 0.0 : doneCnt / totalCnt;
    final cardWidth = _todoSize == '2x2'
        ? 168.0
        : _todoSize == '3x2'
            ? 248.0
            : double.infinity;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: wCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: wBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.tasksTabTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: wText,
                  ),
                ),
                Text(
                  AppCalendar.localizeDigits(
                      '$doneCnt/$totalCnt', settings.localeCode),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: wMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: wBorder,
                valueColor: AlwaysStoppedAnimation(xc.lime),
              ),
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    l10n.noOneOffTasks,
                    style: TextStyle(fontSize: 11, color: wMuted),
                  ),
                ),
              )
            else
              ...visible.take(_todoSize == '4x6' ? 10 : 5).map((t) {
                final accent = t.isDone
                    ? wMuted
                    : (t.kind == OneOffKind.shopping
                        ? const Color(0xFF38BDF8)
                        : xc.lime);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 14,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                t.isDone ? wMuted.withValues(alpha: 0.45) : wText,
                            decoration:
                                t.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (t.quantity.isNotEmpty) ...[
                        Text(
                          t.quantity,
                          style: TextStyle(fontSize: 10, color: wMuted),
                        ),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(
                        onTap: () async {
                          final wasDone = t.isDone;
                          await ref
                              .read(habitStateProvider.notifier)
                              .toggleOneOffTask(t);
                          if (!mounted) return;
                          final curSettings =
                              ref.read(settingsProvider).value ?? settings;
                          if (!wasDone && curSettings.isConfettiEnabled) {
                            _confetti.play();
                          }
                          await SoundService.instance.play(
                            wasDone ? ChimeKind.undo : ChimeKind.done,
                            enabled: curSettings.isAchievementSoundEnabled,
                            profile: curSettings.soundProfile,
                          );
                        },
                        child: Container(
                          width: _todoSize == '2x2' ? 24 : 26,
                          height: _todoSize == '2x2' ? 24 : 26,
                          decoration: BoxDecoration(
                            color: t.isDone ? accent : wIdleBg,
                            shape: BoxShape.circle,
                            border: t.isDone
                                ? null
                                : Border.all(color: wPillBorder, width: 1.2),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: t.isDone
                                ? HabitPalette.contrastFg(accent)
                                : wMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayModePreviewCard(
    List<Habit> active,
    AppSettings settings,
    DateTime today,
    Color wCardBg,
    Color wText,
    Color wMuted,
    Color wBorder,
    Color wIdleBg,
    Color wPillBorder,
    AppLocalizations l10n,
  ) {
    final todayMode = HabitEngine.resolveDayMode(settings, today);
    final cfg = settings.dayModesList.where((m) => m.id == todayMode).firstOrNull;
    final accent = Color(
      todayMode == 'all'
          ? settings.allDayModeColorValue
          : (cfg?.colorValue ?? 0xFF84CC16),
    );
    final iconKey = todayMode == 'all'
        ? settings.allDayModeIconKey
        : (cfg?.iconKey ?? 'tune');
    final modeTitle = todayMode == 'all'
        ? l10n.dayModeAll
        : (cfg != null
            ? _localizedDayModeName(cfg, settings.localeCode)
            : l10n.dayModeNormal);
    final count =
        active.where((h) => HabitEngine.matchesDayMode(h, todayMode)).length;

    final selectableModes = <String>[
      if (_previewDayModeIncludeAll) 'all',
      for (final m in settings.dayModesList) m.id,
    ];
    final posIdx = selectableModes.indexOf(todayMode);
    final posDisp = posIdx >= 0 ? posIdx + 1 : 1;

    final isWide = _dayModeSize == '4x1';
    final is3 = _dayModeSize == '3x1';
    final cardW = isWide ? double.infinity : (is3 ? 248.0 : 176.0);
    final countText = AppCalendar.localizeDigits(
      settings.localeCode == 'fa' ? '$count عادت' : '$count habits',
      settings.localeCode,
    );
    final wideSub = isWide && selectableModes.isNotEmpty
        ? '$countText • ${AppCalendar.localizeDigits('$posDisp/${selectableModes.length}', settings.localeCode)}'
        : countText;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: cardW,
        height: 78,
        padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: wBorder),
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [accent.withValues(alpha: 0.18), wCardBg],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: isWide ? 34 : (is3 ? 32 : 28),
              height: isWide ? 34 : (is3 ? 32 : 28),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(isWide ? 10 : 9),
              ),
              alignment: Alignment.center,
              child: Icon(
                HabitPalette.iconFor(iconKey),
                size: isWide ? 18 : 16,
                color: accent,
              ),
            ),
            SizedBox(width: isWide ? 9 : 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: is3 || isWide ? 12 : 11,
                      fontWeight: FontWeight.w800,
                      color: wText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wideSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, color: wMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _stepPreviewDayMode(settings, today, -1),
              child: Container(
                width: isWide ? 36 : (is3 ? 34 : 32),
                height: isWide ? 36 : (is3 ? 34 : 32),
                decoration: BoxDecoration(
                  color: wIdleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: isWide ? 20 : 18,
                  color: wText,
                ),
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: () => _stepPreviewDayMode(settings, today, 1),
              child: Container(
                width: isWide ? 36 : (is3 ? 34 : 32),
                height: isWide ? 36 : (is3 ? 34 : 32),
                decoration: BoxDecoration(
                  color: wIdleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: isWide ? 20 : 18,
                  color: wText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioTabPill extends StatelessWidget {
  const _StudioTabPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.xc,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final XColors xc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? HabitPalette.contrastFg(xc.lime) : xc.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active ? xc.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChoicePill extends StatelessWidget {
  const _ModeChoicePill({
    required this.label,
    required this.active,
    required this.xc,
    required this.onTap,
  });

  final String label;
  final bool active;
  final XColors xc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active ? xc.lime.withValues(alpha: 0.14) : xc.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? xc.lime : xc.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: active ? xc.lime : xc.text,
          ),
        ),
      ),
    );
  }
}

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.themeMode,
    required this.onChanged,
    required this.l10n,
    required this.xc,
  });

  final String themeMode;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;
  final XColors xc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opt in [
          ('follow', l10n.widgetThemeFollowApp),
          ('dark', l10n.oledBlack),
          ('light', l10n.lightMode),
        ]) ...[
          if (opt.$1 != 'follow') const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: themeMode == opt.$1
                      ? xc.lime.withValues(alpha: 0.14)
                      : xc.card2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: themeMode == opt.$1 ? xc.lime : xc.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: themeMode == opt.$1 ? xc.lime : xc.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
