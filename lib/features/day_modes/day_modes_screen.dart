import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_pickers.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

class DayModesScreen extends ConsumerStatefulWidget {
  const DayModesScreen({
    required this.targetDate,
    required this.onOpenSettings,
    super.key,
  });

  final DateTime targetDate;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<DayModesScreen> createState() => _DayModesScreenState();
}

class _DayModesScreenState extends ConsumerState<DayModesScreen> {
  int _activeTab = 0; // 0 = Modes, 1 = Calendar Schedule
  String _brush = 'work';
  int _monthOffset = 0;
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  static String _modeTitle(
    String id,
    String customName,
    AppLocalizations l10n,
  ) {
    if (id == 'all') return l10n.dayModeAll;
    if (customName.isNotEmpty) return customName;
    return switch (id) {
      'normal' => l10n.dayModeNormal,
      'work' => l10n.dayModeWork,
      'off' => l10n.dayModeOff,
      'travel' => l10n.dayModeTravel,
      final other => other,
    };
  }

  Future<void> _selectMode(
    String modeId,
    AppSettings s,
    SettingsNotifier notifier,
  ) async {
    final targetKey = AppCalendar.toDateKey(widget.targetDate);
    final hasDateOverride = s.dayModeByDate.containsKey(targetKey);
    final hasWeekdayRule =
        s.weekdayDayModes.containsKey(widget.targetDate.weekday);
    final fallbackNonAll = s.dayModesList.any((d) => d.id == 'normal')
        ? 'normal'
        : (s.dayModesList.isNotEmpty ? s.dayModesList.first.id : 'all');
    if (modeId == 'all') {
      await notifier.updateSettings(s.copyWith(activeDayMode: 'all'));
    } else if (hasDateOverride || hasWeekdayRule) {
      final nextMap = Map<String, String>.from(s.dayModeByDate)
        ..[targetKey] = modeId;
      await notifier.updateSettings(
        s.copyWith(
          dayModeByDate: nextMap,
          activeDayMode:
              s.activeDayMode == 'all' ? fallbackNonAll : s.activeDayMode,
        ),
      );
    } else {
      await notifier.updateSettings(s.copyWith(activeDayMode: modeId));
    }
    await SoundService.instance.play(
      ChimeKind.step,
      enabled: s.isAchievementSoundEnabled,
      profile: s.soundProfile,
    );
  }

  Future<void> _submitCustomMode(
    AppSettings s,
    SettingsNotifier notifier,
  ) async {
    final name = _customCtrl.text.trim();
    if (name.isEmpty) return;
    _customCtrl.clear();
    final id = 'mode_${DateTime.now().millisecondsSinceEpoch}';
    final mode = DayModeConfig(
      id: id,
      name: name,
      colorValue: 0xFFB06CFF,
      iconKey: 'star',
    );
    final targetKey = AppCalendar.toDateKey(widget.targetDate);
    final hasDateRule = s.dayModeByDate.containsKey(targetKey) ||
        s.weekdayDayModes.containsKey(widget.targetDate.weekday);
    final nextModes = [...s.dayModesList, mode];
    if (hasDateRule) {
      final nextMap = Map<String, String>.from(s.dayModeByDate)
        ..[targetKey] = id;
      await notifier.updateSettings(
        s.copyWith(
          dayModesList: nextModes,
          dayModeByDate: nextMap,
          activeDayMode: s.activeDayMode == 'all' ? id : s.activeDayMode,
        ),
      );
    } else {
      await notifier.updateSettings(
        s.copyWith(dayModesList: nextModes, activeDayMode: id),
      );
    }
    if (!mounted) return;
    setState(() => _brush = id);
    await SoundService.instance.play(
      ChimeKind.done,
      enabled: s.isAchievementSoundEnabled,
      profile: s.soundProfile,
    );
  }

  Future<void> _openEditModeModal(
    BuildContext context, {
    required String id,
    required String initialName,
    required Color initialColor,
    required String initialIconKey,
    required AppSettings settings,
    required SettingsNotifier notifier,
  }) async {
    final xc = context.xc;
    final l10n = AppLocalizations.of(context);
    final isAll = id == 'all';
    final nameCtrl = TextEditingController(text: initialName);
    var curColor = initialColor;
    var curIconKey = initialIconKey;
    final isFa = settings.localeCode == 'fa';

    var saving = false;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final habits =
              ref.read(habitStateProvider).value?.habits ?? const <Habit>[];
          final usedColors = <Color>[
            Color(settings.allDayModeColorValue),
            for (final d in settings.dayModesList) Color(d.colorValue),
            for (final h in habits) Color(h.colorValue),
          ];
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.editDayModeTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                    if (!isAll)
                      GestureDetector(
                        onTap: () async {
                          final ok = await showXConfirmSheet(
                            context: ctx,
                            icon: Icons.delete_outline_rounded,
                            title: l10n.deleteDayModeConfirmTitle,
                            message: l10n.deleteDayModeConfirmMsg,
                            cancelLabel: l10n.noCancel,
                            confirmLabel: l10n.yesDelete,
                          );
                          if (!ok || !ctx.mounted) return;
                          await notifier.deleteDayMode(id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isAll) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 15, color: xc.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.dayModeAll,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: xc.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.dayModeFixedNameNote,
                    style: TextStyle(fontSize: 11, color: xc.muted),
                  ),
                ] else
                  XDarkField(
                    controller: nameCtrl,
                    hintText: l10n.dayModeNameHint,
                  ),
                const SizedBox(height: 12),
                XColorIconPickerRow(
                  color: curColor,
                  iconKey: curIconKey,
                  onTapColor: () {},
                  onTapIcon: () async {
                    final picked = await showXIconPickerModal(
                      ctx,
                      currentIconKey: curIconKey,
                      accent: curColor,
                      isFa: isFa,
                    );
                    if (picked != null && ctx.mounted) {
                      setLocal(() => curIconKey = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                XColorStripPicker(
                  selectedColor: curColor,
                  onSelectColor: (c) => setLocal(() => curColor = c),
                  onOpenStudio: () async {
                    final previewTitle = isAll
                        ? l10n.dayModeAll
                        : (nameCtrl.text.trim().isEmpty
                            ? initialName
                            : nameCtrl.text.trim());
                    final picked = await showXColorStudioModal(
                      ctx,
                      currentColor: curColor,
                      previewTitle: previewTitle,
                      iconKey: curIconKey,
                      usedColors: usedColors,
                    );
                    if (picked != null && ctx.mounted) {
                      setLocal(() => curColor = picked);
                    }
                  },
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    if (saving) return;
                    if (!isAll && nameCtrl.text.trim().isEmpty) {
                      showXToast(ctx, l10n.enterValidTitle);
                      return;
                    }
                    saving = true;
                    try {
                      await notifier.updateDayMode(
                        id: id,
                        name: isAll ? null : nameCtrl.text.trim(),
                        colorValue: curColor.toARGB32(),
                        iconKey: curIconKey,
                      );
                    } finally {
                      saving = false;
                    }
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
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), nameCtrl.dispose);
  }

  Future<void> _openModeHabitsPickerSheet(
    BuildContext context,
    String modeId,
    String modeLabel,
    Color accent,
  ) async {
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final st = cRef.watch(habitStateProvider).value;
          final active = st?.habits.where((h) => !h.isArchived).toList() ?? [];
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$modeLabel • ${l10n.dayModeAssignHabits}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: active.length,
                    itemBuilder: (_, i) {
                      final h = active[i];
                      final isAll = h.dayModes.contains('all');
                      final hasExplicit = modeId == 'all'
                          ? isAll
                          : (h.dayModes.contains(modeId) ||
                              (h.dayModes.isEmpty && modeId == 'normal'));
                      return GestureDetector(
                        onTap: () => cRef
                            .read(habitStateProvider.notifier)
                            .toggleHabitDayMode(h, modeId),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: hasExplicit
                                ? accent.withValues(alpha: 0.1)
                                : xc.card2,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: hasExplicit ? accent : xc.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                HabitPalette.iconFor(h.iconKey),
                                size: 17,
                                color: Color(h.colorValue),
                              ),
                              const SizedBox(width: 9),
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
                              if (isAll && modeId != 'all') ...[
                                Container(
                                  margin:
                                      const EdgeInsetsDirectional.only(end: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: xc.card,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: xc.border),
                                  ),
                                  child: Text(
                                    l10n.dayModeAllModesBadge,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: xc.muted,
                                    ),
                                  ),
                                ),
                              ],
                              Container(
                                width: 19,
                                height: 19,
                                decoration: BoxDecoration(
                                  color: hasExplicit
                                      ? accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: hasExplicit
                                        ? Colors.transparent
                                        : xc.borderStrong,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: hasExplicit
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
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    final stateAsync = ref.watch(habitStateProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final targetKey = AppCalendar.toDateKey(widget.targetDate);
    final effectiveMode = HabitEngine.resolveDayMode(s, widget.targetDate);
    final hasDateOverride = s.dayModeByDate.containsKey(targetKey);
    final hasCalRule = HabitEngine.hasCalendarModeRule(s, widget.targetDate);
    final scheduledCount = s.dayModeByDate.length + s.weekdayDayModes.length;

    final assignable = [
      for (final d in s.dayModesList)
        (
          id: d.id,
          title: _modeTitle(d.id, d.name, l10n),
          color: Color(d.colorValue),
          iconKey: d.iconKey,
        ),
    ];
    if (_brush != 'erase' && !assignable.any((m) => m.id == _brush)) {
      _brush = assignable.isNotEmpty ? assignable.first.id : 'erase';
    }
    final orderedModes = [
      (
        id: 'all',
        title: l10n.dayModeAll,
        color: Color(s.allDayModeColorValue),
        iconKey: s.allDayModeIconKey,
        deletable: false,
      ),
      for (final m in assignable)
        (
          id: m.id,
          title: m.title,
          color: m.color,
          iconKey: m.iconKey,
          deletable: true,
        ),
    ];
    Color? colorForMode(String? id) {
      if (id == null) return null;
      if (id == 'all') return Color(s.allDayModeColorValue);
      return assignable.where((e) => e.id == id).firstOrNull?.color;
    }

    return Scaffold(
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (st) {
            final habits = st.habits.where((h) => !h.isArchived).toList();
            final today =
                AppCalendar.logicalToday(DateTime.now(), s.dayResetMinutes);
            final todayKey = AppCalendar.toDateKey(today);
            final anchor =
                AppCalendar.shiftMonth(today, _monthOffset, s.calendarSystem);
            final cells = AppCalendar.monthGridDates(
                anchor, s.calendarSystem, s.weekStartDay);
            final order = AppCalendar.orderedWeekdays(s.weekStartDay);

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      HdrCircleButton(
                        icon: isRtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.dayModeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: xc.text,
                          ),
                        ),
                      ),
                      if (_activeTab == 0 && hasDateOverride)
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              final nextMap =
                                  Map<String, String>.from(s.dayModeByDate)
                                    ..remove(targetKey);
                              notifier.updateSettings(
                                s.copyWith(dayModeByDate: nextMap),
                              );
                            },
                            child: Container(
                              margin:
                                  const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: xc.card2,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: xc.borderStrong),
                              ),
                              child: Text(
                                l10n.dayModeClearDateRule,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: xc.muted,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (_activeTab == 1 && s.dayModeByDate.isNotEmpty)
                        Flexible(
                          child: GestureDetector(
                            onTap: () => notifier.updateSettings(
                              s.copyWith(dayModeByDate: const {}),
                            ),
                            child: Container(
                              margin:
                                  const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: xc.card2,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: xc.borderStrong),
                              ),
                              child: Text(
                                l10n.dayModeClearAllDates,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ),
                      HdrCircleButton(
                        icon: Icons.settings_outlined,
                        onTap: widget.onOpenSettings,
                      ),
                    ],
                  ),
                ),

                // 2-Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        _ModeScreenTab(
                          label: l10n.dayModesTabList,
                          icon: Icons.tune_rounded,
                          count: orderedModes.length,
                          localeCode: s.localeCode,
                          active: _activeTab == 0,
                          onTap: () => setState(() => _activeTab = 0),
                        ),
                        const SizedBox(width: 4),
                        _ModeScreenTab(
                          label: l10n.dayModesTabCalendar,
                          icon: Icons.calendar_month_rounded,
                          count: scheduledCount,
                          localeCode: s.localeCode,
                          active: _activeTab == 1,
                          onTap: () => setState(() => _activeTab = 1),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (_activeTab == 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: xc.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: xc.borderStrong),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCtrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  _submitCustomMode(s, notifier),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: l10n.addCustomModeHint,
                                hintStyle: TextStyle(
                                  color: xc.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _submitCustomMode(s, notifier),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: xc.lime,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_rounded,
                                color: HabitPalette.contrastFg(xc.lime),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding:
                          EdgeInsets.fromLTRB(14, 0, 14, 24 + bottomInset),
                      itemCount: orderedModes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, idx) {
                        final m = orderedModes[idx];
                        final active = effectiveMode == m.id;
                        final count = habits
                            .where((h) => HabitEngine.matchesDayMode(h, m.id))
                            .length;
                        return GestureDetector(
                          onTap: () => _selectMode(m.id, s, notifier),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 12),
                            decoration: BoxDecoration(
                              color: xc.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: active ? m.color : xc.borderStrong,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? m.color
                                        : m.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(7),
                                    border: active
                                        ? null
                                        : Border.all(
                                            color: m.color.withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    active
                                        ? Icons.check_rounded
                                        : HabitPalette.iconFor(m.iconKey),
                                    size: active ? 16 : 14,
                                    color: active
                                        ? HabitPalette.contrastFg(m.color)
                                        : m.color,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              m.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: active ? m.color : xc.text,
                                              ),
                                            ),
                                          ),
                                          if (active && hasCalRule) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: m.color
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                l10n.dayModeCalendarTag,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: m.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppCalendar.localizeDigits(
                                          l10n.dayModeAssignedCount(count),
                                          s.localeCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: xc.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _openModeHabitsPickerSheet(
                                    context,
                                    m.id,
                                    m.title,
                                    m.color,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: xc.card2,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: xc.borderStrong,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.dayModeAssignHabits,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: xc.text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () => _openEditModeModal(
                                    context,
                                    id: m.id,
                                    initialName: m.title,
                                    initialColor: m.color,
                                    initialIconKey: m.iconKey,
                                    settings: s,
                                    notifier: notifier,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: xc.card2,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: xc.border),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: xc.muted,
                                    ),
                                  ),
                                ),
                                if (m.deletable) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      final ok = await showXConfirmSheet(
                                        context: context,
                                        icon: Icons.delete_outline_rounded,
                                        title: l10n.deleteDayModeConfirmTitle,
                                        message: l10n.deleteDayModeConfirmMsg,
                                        cancelLabel: l10n.noCancel,
                                        confirmLabel: l10n.yesDelete,
                                      );
                                      if (ok) {
                                        await notifier.deleteDayMode(m.id);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: xc.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ListView(
                      padding:
                          EdgeInsets.fromLTRB(14, 0, 14, 24 + bottomInset),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: xc.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: xc.borderStrong),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dayModeCalendarTitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l10n.dayModeCalendarHint,
                                style: TextStyle(
                                    fontSize: 11.5, color: xc.muted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final m in assignable)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _brush = m.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _brush == m.id
                                              ? m.color.withValues(alpha: 0.18)
                                              : xc.card2,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: _brush == m.id
                                                ? m.color
                                                : xc.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              HabitPalette.iconFor(m.iconKey),
                                              size: 13,
                                              color: m.color,
                                            ),
                                            const SizedBox(width: 5),
                                            Flexible(
                                              child: Text(
                                                m.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _brush == m.id
                                                      ? xc.text
                                                      : xc.muted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _brush = 'erase'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _brush == 'erase'
                                            ? const Color(0xFFEF4444)
                                                .withValues(alpha: 0.16)
                                            : xc.card2,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: _brush == 'erase'
                                              ? const Color(0xFFEF4444)
                                              : xc.border,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.dayModeBrushClear,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _brush == 'erase'
                                              ? const Color(0xFFEF4444)
                                              : xc.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                decoration: BoxDecoration(
                                  color: xc.card2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: xc.border),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _monthOffset--),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              isRtl
                                                  ? Icons.chevron_right_rounded
                                                  : Icons.chevron_left_rounded,
                                              color: xc.text,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          AppCalendar.formatMonthYear(
                                              anchor,
                                              s.calendarSystem,
                                              s.localeCode),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: xc.text,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              setState(() => _monthOffset++),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              isRtl
                                                  ? Icons.chevron_left_rounded
                                                  : Icons.chevron_right_rounded,
                                              color: xc.text,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: order
                                          .map((w) => Expanded(
                                                child: Center(
                                                  child: Text(
                                                    AppCalendar.weekdayMin(
                                                        w, s.localeCode),
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: xc.muted,
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 6),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        mainAxisSpacing: 5,
                                        crossAxisSpacing: 5,
                                        childAspectRatio: 0.86,
                                      ),
                                      itemCount: cells.length,
                                      itemBuilder: (_, i) {
                                        final d = cells[i];
                                        if (d == null) {
                                          return const SizedBox.shrink();
                                        }
                                        final dk = AppCalendar.toDateKey(d);
                                        final dm = s.dayModeByDate[dk];
                                        final col = colorForMode(dm);
                                        final isToday = dk == todayKey;
                                        return GestureDetector(
                                          onTap: () {
                                            final next =
                                                Map<String, String>.from(
                                                    s.dayModeByDate);
                                            if (_brush == 'erase' ||
                                                dm == _brush) {
                                              next.remove(dk);
                                            } else {
                                              next[dk] = _brush;
                                            }
                                            notifier.updateSettings(
                                              s.copyWith(dayModeByDate: next),
                                            );
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: col != null
                                                  ? col.withValues(alpha: 0.24)
                                                  : xc.card,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: col ??
                                                    (isToday
                                                        ? xc.lime
                                                        : xc.border),
                                                width: isToday ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  AppCalendar.localizeDigits(
                                                    '${AppCalendar.dayNumberInCalendar(d, s.calendarSystem)}',
                                                    s.localeCode,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: col != null
                                                        ? xc.text
                                                        : xc.muted,
                                                  ),
                                                ),
                                                if (col != null)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 2),
                                                    width: 5,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      color: col,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: xc.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: xc.borderStrong),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dayModeWeekdayTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final wd in order)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          final next = Map<int, String>.from(
                                              s.weekdayDayModes);
                                          if (_brush == 'erase' ||
                                              next[wd] == _brush) {
                                            next.remove(wd);
                                          } else {
                                            next[wd] = _brush;
                                          }
                                          notifier.updateSettings(
                                            s.copyWith(weekdayDayModes: next),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            color: colorForMode(
                                                        s.weekdayDayModes[wd]) !=
                                                    null
                                                ? colorForMode(
                                                        s.weekdayDayModes[wd])!
                                                    .withValues(alpha: 0.2)
                                                : xc.card2,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            border: Border.all(
                                              color: colorForMode(
                                                      s.weekdayDayModes[wd]) ??
                                                  xc.border,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                AppCalendar.weekdayMin(
                                                    wd, s.localeCode),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: xc.text,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: colorForMode(s
                                                          .weekdayDayModes[wd]) ??
                                                      xc.borderStrong,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeScreenTab extends StatelessWidget {
  const _ModeScreenTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.localeCode,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final String localeCode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final activeFg = HabitPalette.contrastFg(xc.lime);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? xc.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? activeFg : xc.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: active ? activeFg : xc.muted,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? activeFg.withValues(alpha: 0.14)
                        : xc.card2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppCalendar.localizeDigits('$count', localeCode),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: active ? activeFg : xc.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
