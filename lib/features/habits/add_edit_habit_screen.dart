import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_pickers.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../../domain/smart_reminder_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  const AddEditHabitScreen({this.habit, super.key});

  final Habit? habit;

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  static const _uuid = Uuid();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _unitCtrl;
  final TextEditingController _checkItemCtrl = TextEditingController();
  final TextEditingController _inlineCatCtrl = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  late HabitMode _mode;
  late TrackingStyle _style;
  late FrequencyType _freq;
  late int _weekdaysMask;
  late List<int> _monthDays;
  late int _targetPerWeek;
  late int _intervalDays;
  late Color _color;
  late String _iconKey;
  String? _categoryId;
  late bool _showTitleBadge;
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;
  late int _repeatMins;
  late int _responseWindowMins;
  late bool _smartLearningEnabled;
  late List<String> _dayModes;
  late List<HabitChecklistItem> _checklistItems;

  bool _showColorStrip = true;
  bool _showInlineNewCat = false;
  bool _saving = false;
  bool _creatingCategory = false;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _titleCtrl = TextEditingController(text: h?.title ?? '');
    _descCtrl = TextEditingController(text: h?.description ?? '');
    _targetCtrl = TextEditingController(text: '${h?.targetCount ?? 5}');
    _unitCtrl = TextEditingController(text: h?.countUnit ?? '');
    _mode = h?.mode ?? HabitMode.build;
    _style = h?.trackingStyle ?? TrackingStyle.boolean;
    _freq = h?.frequencyType ?? FrequencyType.daily;
    _weekdaysMask = h?.weekdaysMask ?? 127;
    _monthDays = List<int>.from(h?.monthDays ?? const [1, 15]);
    _targetPerWeek = h?.targetPerWeek ?? 5;
    _intervalDays = h?.intervalDays ?? 2;
    _color = h != null ? Color(h.colorValue) : const Color(0xFF607D8B);
    _iconKey = h?.iconKey ?? 'directions_bike';
    _categoryId = h?.categoryId;
    _showTitleBadge = h?.showTitleBadge ?? false;
    _reminderEnabled = h?.reminderEnabled ?? false;
    _reminderTime = TimeOfDay(
      hour: h?.reminderHour ?? 8,
      minute: h?.reminderMinute ?? 30,
    );
    _repeatMins = h?.reminderRepeatMins ?? 0;
    _responseWindowMins = h?.responseWindowMins ?? 120;
    _smartLearningEnabled = h?.smartLearningEnabled ?? false;
    final settingsSnapshot = ref.read(settingsProvider).value ?? const AppSettings();
    final logicalToday =
        AppCalendar.logicalToday(DateTime.now(), settingsSnapshot.dayResetMinutes);
    final curMode = HabitEngine.resolveDayMode(settingsSnapshot, logicalToday);
    final fallbackMode =
        settingsSnapshot.dayModesList.any((d) => d.id == 'normal')
            ? 'normal'
            : 'all';
    _dayModes = h == null
        ? [curMode == 'all' ? fallbackMode : curMode]
        : (h.dayModes.isEmpty
            ? [fallbackMode]
            : List<String>.from(h.dayModes));
    _checklistItems = h != null
        ? List<HabitChecklistItem>.from(
            ref.read(habitStateProvider).value?.checklistFor(h.id) ?? const [],
          )
        : [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    _checkItemCtrl.dispose();
    _inlineCatCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _addChecklistRow() {
    final txt = _checkItemCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _checklistItems.add(
        HabitChecklistItem(
          id: _uuid.v4(),
          habitId: widget.habit?.id ?? '',
          title: txt,
          sortOrder: _checklistItems.length,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _checkItemCtrl.clear();
    });
  }

  Future<void> _createInlineCategory() async {
    if (_creatingCategory) return;
    final txt = _inlineCatCtrl.text.trim();
    if (txt.isEmpty) return;
    _creatingCategory = true;
    try {
      await ref
          .read(habitStateProvider.notifier)
          .saveCategory(txt, _color.toARGB32());
      if (!mounted) return;
      final cats = ref.read(habitStateProvider).value?.categories ?? const [];
      setState(() {
        if (cats.isNotEmpty) _categoryId = cats.last.id;
        _inlineCatCtrl.clear();
        _showInlineNewCat = false;
      });
    } finally {
      if (mounted) _creatingCategory = false;
    }
  }

  Future<void> _openIconPicker() async {
    final isFa =
        (ref.read(settingsProvider).value?.localeCode ?? 'fa') == 'fa';
    final picked = await showXIconPickerModal(
      context,
      currentIconKey: _iconKey,
      accent: _color,
      isFa: isFa,
    );
    if (picked != null && mounted) setState(() => _iconKey = picked);
  }

  Future<void> _openColorStudio() async {
    final l10n = AppLocalizations.of(context);
    final habits = ref.read(habitStateProvider).value?.habits ?? const <Habit>[];
    final usedColors = habits
        .map((h) => h.colorValue & 0x00FFFFFF)
        .toSet()
        .map((rgb) => Color(0xFF000000 | rgb))
        .toList();
    final previewTitle = _titleCtrl.text.trim().isEmpty
        ? l10n.sampleHabitPreview
        : _titleCtrl.text.trim();
    final picked = await showXColorStudioModal(
      context,
      currentColor: _color,
      previewTitle: previewTitle,
      iconKey: _iconKey,
      usedColors: usedColors,
    );
    if (picked != null && mounted) setState(() => _color = picked);
  }

  String _normalizeAsciiDigits(String raw) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final fi = fa.indexOf(ch);
      if (fi >= 0) {
        buf.writeCharCode(48 + fi);
      } else {
        final ai = ar.indexOf(ch);
        buf.write(ai >= 0 ? String.fromCharCode(48 + ai) : ch);
      }
    }
    return buf.toString();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showXToast(context, l10n.enterValidTitleToast);
      _titleFocus.requestFocus();
      return;
    }
    _saving = true;
    try {
      if (_style == TrackingStyle.checklist &&
          _checkItemCtrl.text.trim().isNotEmpty) {
        _addChecklistRow();
      }

      final existing = widget.habit;
      final id = existing?.id ?? _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeCount =
          ref.read(habitStateProvider).value?.habits.length ?? 0;
      final target =
          (int.tryParse(_normalizeAsciiDigits(_targetCtrl.text.trim())) ?? 5)
              .clamp(1, 9999);
      final effectiveStyle =
          _mode == HabitMode.quit ? TrackingStyle.boolean : _style;

      final habit = Habit(
        id: id,
        title: title,
        description: _descCtrl.text.trim(),
        mode: _mode,
        trackingStyle: effectiveStyle,
        frequencyType: _freq,
        weekdaysMask: _weekdaysMask == 0 ? 127 : _weekdaysMask,
        monthDays: _monthDays.isEmpty ? const [1, 15] : _monthDays,
        targetPerWeek: _targetPerWeek,
        intervalDays: _intervalDays,
        targetCount: target,
        countUnit: _unitCtrl.text.trim(),
        colorValue: _color.toARGB32(),
        iconKey: _iconKey,
        categoryId: _categoryId ??
            ref.read(habitStateProvider).value?.categories.firstOrNull?.id,
        startDateKey:
            existing?.startDateKey ?? AppCalendar.toDateKey(DateTime.now()),
        sortOrder: existing?.sortOrder ?? activeCount,
        isArchived: existing?.isArchived ?? false,
        showTitleBadge: _showTitleBadge,
        reminderEnabled: _reminderEnabled,
        reminderHour: _reminderTime.hour,
        reminderMinute: _reminderTime.minute,
        reminderRepeatMins: _repeatMins,
        responseWindowMins: _responseWindowMins,
        smartLearningEnabled: _smartLearningEnabled,
        dayModes: _dayModes,
        updatedAtMs: now,
      );

      final items = effectiveStyle == TrackingStyle.checklist
          ? _checklistItems
              .asMap()
              .entries
              .map(
                (e) => HabitChecklistItem(
                  id: e.value.id,
                  habitId: id,
                  title: e.value.title,
                  sortOrder: e.key,
                  updatedAtMs: now,
                ),
              )
              .toList()
          : const <HabitChecklistItem>[];

      await ref.read(habitStateProvider.notifier).saveHabit(habit, items);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final cats = ref.watch(habitStateProvider).value?.categories ?? const [];
    final selectedCatId = _categoryId ?? cats.firstOrNull?.id;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final activeSegBg = _color.withValues(alpha: 0.24);
    final fg = HabitPalette.contrastFg(_color);

    final freqs = [
      (FrequencyType.daily, l10n.freqDaily),
      (FrequencyType.weekdays, l10n.freqWeekdays),
      (FrequencyType.monthDays, l10n.freqMonthDays),
      (FrequencyType.period, l10n.freqPeriod),
      (FrequencyType.interval, l10n.freqInterval),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Topbar matching `.add-topbar`
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      XNavBackButton(onTap: () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      Text(
                        widget.habit == null ? l10n.addHabit : l10n.editHabit,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            l10n.save,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: xc.text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.check_rounded, size: 17, color: xc.text),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body (`.add-body`)
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 28 + bottomInset),
                children: [
                  XDarkField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    hintText: l10n.habitTitle,
                  ),
                  const SizedBox(height: 12),
                  XDarkField(
                    controller: _descCtrl,
                    hintText: l10n.habitDescription,
                  ),
                  const SizedBox(height: 12),

                  XColorIconPickerRow(
                    color: _color,
                    iconKey: _iconKey,
                    onTapColor: () =>
                        setState(() => _showColorStrip = !_showColorStrip),
                    onTapIcon: _openIconPicker,
                  ),
                  const SizedBox(height: 12),

                  if (_showColorStrip) ...[
                    XColorStripPicker(
                      selectedColor: _color,
                      onSelectColor: (c) => setState(() => _color = c),
                      onOpenStudio: _openColorStudio,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Categories Box
                  XSectionBox(
                    title: l10n.categoryLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            ...cats.map((c) {
                              final sel = selectedCatId == c.id;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _categoryId = c.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: sel ? xc.text : xc.card2,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          sel ? Colors.transparent : xc.border,
                                    ),
                                  ),
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: sel ? xc.bg : xc.muted,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _showInlineNewCat = !_showInlineNewCat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: xc.card2,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: xc.lime.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  l10n.newCategoryShort,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: xc.lime,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_showInlineNewCat) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: XDarkField(
                                  controller: _inlineCatCtrl,
                                  hintText: l10n.categoryName,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 9),
                                  onSubmitted: (_) => _createInlineCategory(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _createInlineCategory,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: xc.lime,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    l10n.addBtnLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: HabitPalette.contrastFg(xc.lime),
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
                  const SizedBox(height: 12),

                  // Mode Box (`.seg-2`)
                  XSectionBox(
                    title: l10n.habitType,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SegButton(
                                label: l10n.habitModeBuild,
                                selected: _mode == HabitMode.build,
                                selectedBg: activeSegBg,
                                onTap: () =>
                                    setState(() => _mode = HabitMode.build),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SegButton(
                                label: l10n.habitModeQuit,
                                selected: _mode == HabitMode.quit,
                                selectedBg: activeSegBg,
                                onTap: () => setState(() {
                                  _mode = HabitMode.quit;
                                  _style = TrackingStyle.boolean;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          _mode == HabitMode.build
                              ? l10n.buildModeHint
                              : l10n.quitModeHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: xc.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Frequency Box (`.radio-row` + `.mini-day-chips`)
                  XSectionBox(
                    title: l10n.scheduleLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...freqs.map((pair) {
                          final on = _freq == pair.$1;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _freq = pair.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: on ? _color : xc.text,
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: on
                                        ? Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _color,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      pair.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: xc.text,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (_freq == FrequencyType.weekdays) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                AppCalendar.orderedWeekdays(settings.weekStartDay)
                                    .map((w) {
                              final bit = 1 << (w - 1);
                              final on = (_weekdaysMask & bit) != 0;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _weekdaysMask ^= bit),
                                child: Container(
                                  width: 34,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: on ? _color : xc.card2,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          on ? Colors.transparent : xc.border,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    AppCalendar.weekdayMin(
                                        w, settings.localeCode),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: on ? fg : xc.muted,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_freq == FrequencyType.monthDays) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(31, (i) => i + 1).map((d) {
                              final on = _monthDays.contains(d);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (on) {
                                      _monthDays.remove(d);
                                    } else {
                                      _monthDays.add(d);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: on ? _color : xc.card2,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          on ? Colors.transparent : xc.border,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    AppCalendar.localizeDigits(
                                        '$d', settings.localeCode),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: on ? fg : xc.muted,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_freq == FrequencyType.period) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  min: 1,
                                  max: 7,
                                  divisions: 6,
                                  activeColor: _color,
                                  value: _targetPerWeek.toDouble(),
                                  onChanged: (v) =>
                                      setState(() => _targetPerWeek = v.round()),
                                ),
                              ),
                              Text(
                                AppCalendar.localizeDigits(
                                    '$_targetPerWeek / 7', settings.localeCode),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_freq == FrequencyType.interval) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  min: 2,
                                  max: 14,
                                  divisions: 12,
                                  activeColor: _color,
                                  value: _intervalDays.clamp(2, 14).toDouble(),
                                  onChanged: (v) =>
                                      setState(() => _intervalDays = v.round()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppCalendar.localizeDigits(
                                    l10n.intervalDaysCount(_intervalDays),
                                    settings.localeCode,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: xc.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tracking Style Box (`.seg-3`, build habits only)
                  if (_mode == HabitMode.build) ...[
                  XSectionBox(
                    title: l10n.trackingStyle,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SegButton(
                                label: l10n.styleBoolean,
                                selected: _style == TrackingStyle.boolean,
                                selectedBg: activeSegBg,
                                onTap: () => setState(
                                    () => _style = TrackingStyle.boolean),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SegButton(
                                label: l10n.styleCount,
                                selected: _style == TrackingStyle.count,
                                selectedBg: activeSegBg,
                                onTap: () => setState(
                                    () => _style = TrackingStyle.count),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SegButton(
                                label: l10n.styleChecklist,
                                selected: _style == TrackingStyle.checklist,
                                selectedBg: activeSegBg,
                                onTap: () => setState(
                                    () => _style = TrackingStyle.checklist),
                              ),
                            ),
                          ],
                        ),
                        if (_style == TrackingStyle.count) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: XDarkField(
                                  controller: _targetCtrl,
                                  keyboardType: TextInputType.number,
                                  hintText: _mode == HabitMode.quit
                                      ? l10n.dailyLimit
                                      : l10n.dailyGoal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: XDarkField(
                                  controller: _unitCtrl,
                                  hintText: l10n.unitLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_style == TrackingStyle.checklist) ...[
                          const SizedBox(height: 10),
                          ..._checklistItems.asMap().entries.map(
                                (e) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: xc.card2,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.value.title,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: xc.text,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _checklistItems.removeAt(e.key)),
                                        child: const Icon(Icons.close_rounded,
                                            size: 16,
                                            color: Color(0xFFEF4444)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          Row(
                            children: [
                              Expanded(
                                child: XDarkField(
                                  controller: _checkItemCtrl,
                                  hintText: l10n.addChecklistItem,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  onSubmitted: (_) => _addChecklistRow(),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _addChecklistRow,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: xc.card2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: xc.border),
                                  ),
                                  child: Text(
                                    l10n.addBtnLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: xc.text,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 9),
                        Text(
                          _style == TrackingStyle.count
                              ? l10n.countModeHint
                              : _style == TrackingStyle.checklist
                                  ? l10n.checklistModeHint
                                  : l10n.tickModeHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: xc.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ],

                  // Medal Badge Toggle Box
                  XSectionBox(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _showTitleBadge = !_showTitleBadge),
                      child: Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,
                            size: 18,
                            color: _showTitleBadge ? _color : xc.muted,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.showMedalBadgeTitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: xc.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.showMedalBadgeHint,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: xc.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _XPillSwitch(
                              value: _showTitleBadge, activeColor: _color),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Daily Reminder Box
                  XSectionBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final enabling = !_reminderEnabled;
                            setState(() => _reminderEnabled = enabling);
                            if (enabling) {
                              await NotificationService.instance
                                  .requestPermissions();
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: _reminderEnabled ? _color : xc.muted,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.enableReminder,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: xc.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.reminderHint,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: xc.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _XPillSwitch(
                                  value: _reminderEnabled, activeColor: _color),
                            ],
                          ),
                        ),
                        if (_reminderEnabled) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showXTimePickerSheet(
                                  context: context,
                                  title: l10n.reminderTime,
                                  initialTime: _reminderTime,
                                  confirmLabel: l10n.doneAction,
                                  localeCode: settings.localeCode,
                                );
                                if (picked != null && mounted) {
                                  setState(() => _reminderTime = picked);
                                }
                              },
                              child: Container(
                                width: 130,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: xc.fieldBg,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: xc.borderStrong),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  AppCalendar.localizeDigits(
                                    '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                                    settings.localeCode,
                                  ),
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: xc.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.repeatReminderLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: xc.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [0, 15, 30, 60].map((m) {
                              final active = _repeatMins == m;
                              final lbl = m == 0
                                  ? l10n.repeatOff
                                  : AppCalendar.localizeDigits(
                                      l10n.repeatMinutesUnit(m),
                                      settings.localeCode,
                                    );
                              return GestureDetector(
                                onTap: () => setState(() => _repeatMins = m),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? _color.withValues(alpha: 0.2)
                                        : xc.fieldBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: active ? _color : xc.border,
                                    ),
                                  ),
                                  child: Text(
                                    lbl,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: active ? xc.text : xc.muted,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_repeatMins > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              l10n.responseWindowLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: xc.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [30, 60, 120, 240].map((w) {
                                final active = _responseWindowMins == w;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _responseWindowMins = w),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? _color.withValues(alpha: 0.2)
                                          : xc.fieldBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: active ? _color : xc.border,
                                      ),
                                    ),
                                    child: Text(
                                      AppCalendar.localizeDigits(
                                        l10n.responseWindowMinsUnit(w),
                                        settings.localeCode,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: active ? xc.text : xc.muted,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() =>
                                _smartLearningEnabled = !_smartLearningEnabled),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: _smartLearningEnabled
                                      ? _color
                                      : xc.muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.smartLearningLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: xc.text,
                                        ),
                                      ),
                                      Text(
                                        l10n.smartLearningHint,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: xc.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _XPillSwitch(
                                  value: _smartLearningEnabled,
                                  activeColor: _color,
                                ),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (_) {
                              final st = ref.watch(habitStateProvider).value;
                              final mins = st?.completionMinutesFor(
                                      widget.habit?.id ?? '') ??
                                  const [];
                              final learned =
                                  SmartReminderEngine.learnBestReminderTime(
                                recordedMinutesOfDay: mins,
                                quietEnabled: settings.quietHoursEnabled,
                                quietStartMin: settings.quietStartMinutes,
                                quietEndMin: settings.quietEndMinutes,
                              );
                              if (learned == null) {
                                return const SizedBox.shrink();
                              }
                              final timeStr = AppCalendar.localizeDigits(
                                '${learned.suggestedHour.toString().padLeft(2, '0')}:${learned.suggestedMinute.toString().padLeft(2, '0')}',
                                settings.localeCode,
                              );
                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _color.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        AppCalendar.localizeDigits(
                                          l10n.smartSuggestionBadge(
                                            timeStr,
                                            (learned.confidence * 100).round(),
                                          ),
                                          settings.localeCode,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: xc.text,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _reminderTime = TimeOfDay(
                                          hour: learned.suggestedHour,
                                          minute: learned.suggestedMinute,
                                        );
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _color,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          l10n.applySmartTime,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: HabitPalette.contrastFg(
                                                _color),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.habitDayModesLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: xc.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.habitDayModesHint,
                          style: TextStyle(fontSize: 11, color: xc.muted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final entry in [
                              ('all', l10n.dayModeAll),
                              for (final d in settings.dayModesList)
                                (
                                  d.id,
                                  d.name.isNotEmpty
                                      ? d.name
                                      : switch (d.id) {
                                          'normal' => l10n.dayModeNormal,
                                          'work' => l10n.dayModeWork,
                                          'off' => l10n.dayModeOff,
                                          'travel' => l10n.dayModeTravel,
                                          final other => other,
                                        },
                                ),
                            ])
                              GestureDetector(
                                onTap: () => setState(() {
                                  final id = entry.$1;
                                  final fallback =
                                      settings.dayModesList.any((d) =>
                                              d.id == 'normal')
                                          ? 'normal'
                                          : 'all';
                                  if (id == 'all') {
                                    _dayModes =
                                        (_dayModes.length == 1 &&
                                                _dayModes.contains('all'))
                                            ? [fallback]
                                            : ['all'];
                                  } else {
                                    _dayModes.remove('all');
                                    if (_dayModes.contains(id)) {
                                      if (_dayModes.length > 1) {
                                        _dayModes.remove(id);
                                      } else if (id != fallback) {
                                        _dayModes = [fallback];
                                      }
                                    } else {
                                      _dayModes.add(id);
                                    }
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _dayModes.contains(entry.$1)
                                        ? _color.withValues(alpha: 0.2)
                                        : xc.fieldBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _dayModes.contains(entry.$1)
                                          ? _color
                                          : xc.border,
                                    ),
                                  ),
                                  child: Text(
                                    entry.$2,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _dayModes.contains(entry.$1)
                                          ? xc.text
                                          : xc.muted,
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
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedBg : xc.card2,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? xc.text : xc.muted,
          ),
        ),
      ),
    );
  }
}

class _XPillSwitch extends StatelessWidget {
  const _XPillSwitch({required this.value, required this.activeColor});

  final bool value;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? activeColor : xc.card3,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: value
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value
              ? HabitPalette.contrastFg(activeColor)
              : const Color(0xFF9393A0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
