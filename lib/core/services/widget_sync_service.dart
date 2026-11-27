import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../calendar/app_calendar.dart';
import '../icons/habit_icons.dart';
import '../sync/cloud_drive_sync_service.dart';
import '../sync/obsidian_sync_service.dart';
import 'notification_service.dart';

/// Snapshot describing a single widget instance placed on the Android Home Screen.
class PlacedWidgetInfo {
  const PlacedWidgetInfo({
    required this.widgetId,
    required this.kind,
    this.habitId,
    this.listMode = 'default',
    this.habitIds = const [],
    this.customTitle = '',
    this.hideCompleted = false,
    this.includeAll = true,
    this.themeMode = 'follow',
    this.widthDp = 0,
    this.heightDp = 0,
  });

  final int widgetId;
  final String kind; // 'adaptive' | 'daily_list' | 'todo_list' | 'day_mode'
  final String? habitId;
  final String listMode; // 'default' | 'all' | 'custom'
  final List<String> habitIds;
  final String customTitle;
  final bool hideCompleted;
  final bool includeAll;
  final String themeMode; // 'follow' | 'dark' | 'light'
  final int widthDp;
  final int heightDp;

  bool get isAdaptive => kind == 'adaptive';
  bool get isDailyList => kind == 'daily_list';
  bool get isToDoList => kind == 'todo_list';
  bool get isDayMode => kind == 'day_mode';

  factory PlacedWidgetInfo.fromMap(Map<dynamic, dynamic> map) {
    final rawIds = map['habitIds'];
    final ids = rawIds is List
        ? rawIds.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return PlacedWidgetInfo(
      widgetId: (map['widgetId'] as num?)?.toInt() ?? 0,
      kind: map['kind']?.toString() ?? 'adaptive',
      habitId: map['habitId']?.toString(),
      listMode: map['listMode']?.toString() ?? 'default',
      habitIds: ids,
      customTitle: map['customTitle']?.toString() ?? '',
      hideCompleted: map['hideCompleted'] == true,
      includeAll: map['includeAll'] != false,
      themeMode: map['themeMode']?.toString() ?? 'follow',
      widthDp: (map['widthDp'] as num?)?.toInt() ?? 0,
      heightDp: (map['heightDp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Synchronizes habit, To-Do, and Day Mode state to the 4 responsive Android Home Screen widgets:
/// 1) Adaptive Single-Habit Widget (per-instance configurable, 2x1 .. 4x4)
/// 2) Daily Tasks List Widget (per-instance configurable, 2x2 .. 4x6 scrollable + sub-steps)
/// 3) To-Do List Widget (matching Daily List aesthetic, 2x2 .. 4x6 scrollable)
/// 4) Quick Day Mode Switcher Widget (matching Adaptive Widget 2x1 .. 4x1)
class WidgetSyncService {
  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._();

  static const String adaptiveProvider = 'AdaptiveHabitWidgetProvider';
  static const String dailyListProvider = 'DailyListWidgetProvider';
  static const String todoListProvider = 'ToDoListWidgetProvider';
  static const String dayModeProvider = 'DayModeWidgetProvider';
  static const MethodChannel _channel =
      MethodChannel('app.xhabit.tracker/widgets');

  Future<bool> requestPinAdaptiveWidget({String? habitId}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'pinAdaptiveWidget',
            habitId == null ? null : {'habitId': habitId},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPinDailyListWidget({
    bool useAll = true,
    List<String> habitIds = const [],
    String? customTitle,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'pinDailyListWidget',
            {
              'useAll': useAll,
              'habitIds': habitIds,
              'customTitle': customTitle ?? '',
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPinToDoWidget({
    bool hideCompleted = false,
    String? customTitle,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'pinToDoWidget',
            {
              'hideCompleted': hideCompleted,
              'customTitle': customTitle ?? '',
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPinDayModeWidget({bool includeAll = true}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'pinDayModeWidget',
            {'includeAll': includeAll},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<List<PlacedWidgetInfo>> listPlacedWidgets() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<dynamic>('listPlacedWidgets');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(PlacedWidgetInfo.fromMap)
          .where((w) => w.widgetId > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> updatePlacedWidgetConfig({
    required int widgetId,
    required String kind,
    String? habitId,
    bool useAll = true,
    List<String> habitIds = const [],
    String customTitle = '',
    bool hideCompleted = false,
    bool includeAll = true,
    String themeMode = 'follow',
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'updateWidgetConfig',
            {
              'widgetId': widgetId,
              'kind': kind,
              'habitId': habitId,
              'useAll': useAll,
              'habitIds': habitIds,
              'customTitle': customTitle,
              'hideCompleted': hideCompleted,
              'includeAll': includeAll,
              'themeMode': themeMode,
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openNativeWidgetConfigure(int widgetId) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openWidgetConfigure',
            {'widgetId': widgetId},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _buildAdaptiveHabitPayload({
    required Habit habit,
    required List<HabitChecklistItem> items,
    required Map<String, HabitCompletion> byDate,
    required List<HabitPause> pauses,
    required AppSettings settings,
    required DateTime today,
    required String todayKey,
    required List<int> order,
    required List<String> monthWeekdays,
    required String monthLabel,
  }) {
    final stats = HabitEngine.computeStats(
      habit,
      byDate,
      items,
      calendar: settings.calendarSystem,
      weekStart: settings.weekStartDay,
      today: today,
      pauses: pauses,
      monthlyGraceDays: settings.streakGraceDaysPerMonth,
    );
    final todayComp = byDate[todayKey];
    final doneToday = HabitEngine.isCompletedOn(
      habit,
      todayComp,
      items,
      today,
      today: today,
    );

    final week7 = List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day - (6 - i));
      final dk = AppCalendar.toDateKey(d);
      final r = HabitEngine.progressRatio(
        habit,
        byDate[dk],
        items,
        d,
        today: today,
      );
      return {
        'label': AppCalendar.weekdayMin(d.weekday, settings.localeCode),
        'ratio': r,
        'isToday': dk == todayKey,
      };
    });

    final monthCells = AppCalendar.monthGridDates(
      today,
      settings.calendarSystem,
      settings.weekStartDay,
    ).map((d) {
      if (d == null) {
        return {'pad': true, 'ratio': 0.0, 'fut': false, 'isToday': false};
      }
      final dk = AppCalendar.toDateKey(d);
      final fut = d.isAfter(today);
      final r = fut
          ? 0.0
          : HabitEngine.progressRatio(habit, byDate[dk], items, d, today: today);
      return {
        'pad': false,
        'ratio': r,
        'fut': fut,
        'isToday': dk == todayKey,
      };
    }).toList();

    const hmWeeks = 18;
    final endOffset = order.indexOf(today.weekday);
    final hmStart = DateTime(
      today.year,
      today.month,
      today.day - ((hmWeeks - 1) * 7 + endOffset),
    );
    final heatmapRows = List.generate(7, (r) {
      final cells = List.generate(hmWeeks, (w) {
        final d = DateTime(
          hmStart.year,
          hmStart.month,
          hmStart.day + w * 7 + r,
        );
        final dk = AppCalendar.toDateKey(d);
        final fut = d.isAfter(today);
        final ratioVal = fut
            ? 0.0
            : HabitEngine.progressRatio(habit, byDate[dk], items, d,
                today: today);
        return {
          'ratio': ratioVal,
          'fut': fut,
          'isToday': dk == todayKey,
        };
      });
      return {
        'label': AppCalendar.weekdayMin(order[r], settings.localeCode),
        'cells': cells,
      };
    });

    final checklistPayload = items.take(5).map((c) {
      final cDone = todayComp?.completedChecklistIds.contains(c.id) ??
          (habit.trackingStyle == TrackingStyle.checklist &&
              (todayComp?.value ?? 0) >= 1);
      return {'id': c.id, 'title': c.title, 'done': cDone};
    }).toList();

    return {
      'empty': false,
      'id': habit.id,
      'title': habit.title,
      'iconKey': habit.iconKey,
      'iconCodePoint': HabitPalette.iconFor(habit.iconKey).codePoint,
      'color': habit.colorValue,
      'style': habit.trackingStyle.name,
      'isQuit': habit.isQuit,
      'doneToday': doneToday,
      'slippedToday': todayComp?.slipped ?? false,
      'countVal': todayComp?.value ?? 0,
      'countTarget': habit.targetCount,
      'streak': stats.currentStreak,
      'best': stats.bestStreak,
      'score': stats.habitScore,
      'monthLabel': monthLabel,
      'sub3x2': settings.localeCode == 'fa'
          ? '۳ ماه اخیر (۱۲ هفته)'
          : 'Last 3 months (12w)',
      'sub4x2': settings.localeCode == 'fa'
          ? '۴ ماه اخیر (۱۸ هفته)'
          : 'Last 4 months (18w)',
      'lblStreak': settings.localeCode == 'fa' ? 'استریک فعلی' : 'Streak',
      'lblBest': settings.localeCode == 'fa' ? 'بهترین' : 'Best',
      'lblScore': settings.localeCode == 'fa' ? 'امتیاز' : 'Score',
      'week7': week7,
      'monthWeekdays': monthWeekdays,
      'monthCells': monthCells,
      'heatmapRows': heatmapRows,
      'checklist': checklistPayload,
    };
  }

  String _localizedDayModeName(DayModeConfig mode, bool isFa) {
    if (mode.name.trim().isNotEmpty) return mode.name.trim();
    return switch (mode.id) {
      'normal' => isFa ? 'عادی' : 'Normal',
      'work' => isFa ? 'روز کاری' : 'Work Day',
      'off' => isFa ? 'روز تعطیل' : 'Day Off',
      'travel' => isFa ? 'مسافرت' : 'Travel',
      _ => mode.id,
    };
  }

  Future<void> syncAll({
    required List<Habit> habits,
    required List<HabitChecklistItem> checklistItems,
    required List<HabitCompletion> completions,
    List<HabitPause> pauses = const [],
    List<OneOffTask> oneOffTasks = const [],
    required AppSettings settings,
  }) async {
    if (!Platform.isAndroid) return;

    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final activeHabits = habits.where((h) => !h.isArchived).toList();
    final compMap = <String, Map<String, HabitCompletion>>{};
    for (final c in completions) {
      compMap.putIfAbsent(c.habitId, () => {})[c.dateKey] = c;
    }
    final checklistMap = <String, List<HabitChecklistItem>>{};
    for (final item in checklistItems) {
      checklistMap.putIfAbsent(item.habitId, () => []).add(item);
    }

    final order = AppCalendar.orderedWeekdays(settings.weekStartDay);
    final monthWeekdays =
        order.map((w) => AppCalendar.weekdayMin(w, settings.localeCode)).toList();
    final monthLabel = AppCalendar.formatMonthYear(
      today,
      settings.calendarSystem,
      settings.localeCode,
    );

    // 1. Multi-instance Adaptive Habits Catalog + Legacy Primary Fallback
    final primary = activeHabits
            .where((h) => h.id == settings.widgetHabitId)
            .firstOrNull ??
        activeHabits.firstOrNull;

    final adaptiveHabitsMap = <String, Map<String, dynamic>>{};
    for (final h in activeHabits) {
      adaptiveHabitsMap[h.id] = _buildAdaptiveHabitPayload(
        habit: h,
        items: checklistMap[h.id] ?? const [],
        byDate: compMap[h.id] ?? const {},
        pauses: pauses,
        settings: settings,
        today: today,
        todayKey: todayKey,
        order: order,
        monthWeekdays: monthWeekdays,
        monthLabel: monthLabel,
      );
    }

    final emptyMsg = settings.localeCode == 'fa'
        ? 'حداقل یک عادت بسازید'
        : 'Create a habit first';

    final adaptiveAllPayload = {
      'empty': activeHabits.isEmpty,
      'emptyMsg': emptyMsg,
      'defaultId': primary?.id ?? '',
      'order': activeHabits.map((h) => h.id).toList(),
      'habits': adaptiveHabitsMap,
    };

    final legacyAdaptivePayload = primary != null
        ? adaptiveHabitsMap[primary.id]!
        : {
            'empty': true,
            'emptyMsg': emptyMsg,
          };

    // 2. Multi-instance Daily List Catalog + Legacy Default Payload
    final selectedIds = settings.widgetListHabitIds;
    final todayMode = HabitEngine.resolveDayMode(settings, today);
    final todayLabel = settings.localeCode == 'fa' ? 'امروز' : 'Today';

    final allHabitsForList = <Map<String, dynamic>>[];
    final defaultListDueItems = <Map<String, dynamic>>[];
    var defaultListDone = 0;

    for (final h in activeHabits) {
      final items = checklistMap[h.id] ?? const [];
      final byDate = compMap[h.id] ?? const {};
      final todayComp = byDate[todayKey];
      final done = HabitEngine.isCompletedOn(
        h,
        todayComp,
        items,
        today,
        today: today,
      );
      final isDueToday = !HabitEngine.isPausedOn(h.id, today, pauses) &&
          HabitEngine.matchesDayMode(h, todayMode) &&
          HabitEngine.isScheduledOn(
            h,
            today,
            calendar: settings.calendarSystem,
            weekStart: settings.weekStartDay,
            completionsByDate: byDate,
            checklistItems: items,
            today: today,
          );
      final stats = adaptiveHabitsMap[h.id]?['streak'] as int? ?? 0;
      final subItems = items.map((c) {
        final cDone = todayComp?.completedChecklistIds.contains(c.id) ?? false;
        return {'id': c.id, 'title': c.title, 'done': cDone};
      }).toList();

      final rowPayload = {
        'id': h.id,
        'title': h.title,
        'iconCodePoint': HabitPalette.iconFor(h.iconKey).codePoint,
        'color': h.colorValue,
        'style': h.trackingStyle.name,
        'isQuit': h.isQuit,
        'streak': stats,
        'done': done,
        'slipped': todayComp?.slipped ?? false,
        'countVal': todayComp?.value ?? 0,
        'countTarget': h.targetCount,
        'isDueToday': isDueToday,
        'checklist': subItems,
      };
      allHabitsForList.add(rowPayload);

      final inDefaultList =
          selectedIds.isEmpty || selectedIds.contains(h.id);
      if (inDefaultList && isDueToday) {
        if (done) defaultListDone++;
        defaultListDueItems.add(rowPayload);
      }
    }

    final emptyDueMsg = settings.localeCode == 'fa'
        ? 'برای امروز عادت برنامه‌ریزی‌شده‌ای نیست'
        : 'No scheduled tasks due today';
    final emptyUnconfiguredMsg = settings.localeCode == 'fa'
        ? 'روی ویجت نگه دارید و عادت‌ها را انتخاب کنید'
        : 'Hold widget to choose habits';

    final dailyListAllPayload = {
      'todayLabel': todayLabel,
      'locale': settings.localeCode,
      'useDefaultAll': selectedIds.isEmpty,
      'defaultIds': selectedIds,
      'emptyUnconfiguredMsg': emptyUnconfiguredMsg,
      'emptyDueMsg': emptyDueMsg,
      'allHabits': allHabitsForList,
    };

    final legacyListPayload = {
      'todayLabel': todayLabel,
      'doneCount': defaultListDone,
      'totalCount': defaultListDueItems.length,
      'emptyMsg': (selectedIds.isNotEmpty &&
              activeHabits.every((h) => !selectedIds.contains(h.id)))
          ? emptyUnconfiguredMsg
          : emptyDueMsg,
      'items': defaultListDueItems,
    };

    // 3. To-Do List Widget Payload
    final isFa = settings.localeCode == 'fa';
    final todoTitle = isFa ? 'لیست کارها' : 'To Do List';
    final todoTasksPayload = oneOffTasks
        .map((t) => {
              'id': t.id,
              'title': t.title,
              'quantity': t.quantity,
              'kind': t.kind.name,
              'isDone': t.isDone,
            })
        .toList();
    final todoAllPayload = {
      'title': todoTitle,
      'emptyMsg': isFa ? 'لیست کارها خالی است' : 'To Do List is empty',
      'allDoneMsg': isFa ? 'همه کارها انجام شدند!' : 'All tasks completed!',
      'tasks': todoTasksPayload,
    };

    // 4. Quick Day Mode Switcher Payload
    final activeColorVal = todayMode == 'all'
        ? settings.allDayModeColorValue
        : (settings.dayModesList
                .where((m) => m.id == todayMode)
                .firstOrNull
                ?.colorValue ??
            0xFF84CC16);
    final activeIconKey = todayMode == 'all'
        ? settings.allDayModeIconKey
        : (settings.dayModesList
                .where((m) => m.id == todayMode)
                .firstOrNull
                ?.iconKey ??
            'tune');
    final activeModeCfg =
        settings.dayModesList.where((m) => m.id == todayMode).firstOrNull;
    final activeModeName = todayMode == 'all'
        ? (isFa ? 'همه مودها' : 'All Modes')
        : (activeModeCfg != null
            ? _localizedDayModeName(activeModeCfg, isFa)
            : (isFa ? 'عادی' : 'Normal'));
    final activeModeHabitCount =
        activeHabits.where((h) => HabitEngine.matchesDayMode(h, todayMode)).length;

    final selectableModes = [
      {'id': 'all', 'name': isFa ? 'همه مودها' : 'All Modes'},
      for (final m in settings.dayModesList)
        {'id': m.id, 'name': _localizedDayModeName(m, isFa)},
    ];
    final posIdx = selectableModes.indexWhere((m) => m['id'] == todayMode);
    final posDisplay = posIdx >= 0 ? posIdx + 1 : 1;

    final modeCountStr = AppCalendar.localizeDigits(
      isFa ? '$activeModeHabitCount عادت' : '$activeModeHabitCount habits',
      settings.localeCode,
    );
    final modePosStr = AppCalendar.localizeDigits(
      '$posDisplay/${selectableModes.length}',
      settings.localeCode,
    );
    final dayModePayload = {
      'activeModeId': todayMode,
      'activeModeName': activeModeName,
      'activeModeColor': activeColorVal,
      'activeModeIconCodePoint': HabitPalette.iconFor(activeIconKey).codePoint,
      'activeHabitCount': activeModeHabitCount,
      'subtitleShort': modeCountStr,
      'subtitleWide': '$modeCountStr • $modePosStr',
    };

    await Future.wait([
      HomeWidget.saveWidgetData('widget_theme', settings.widgetTheme.name),
      HomeWidget.saveWidgetData('widget_locale', settings.localeCode),
      HomeWidget.saveWidgetData(
          'widget_celebration', settings.widgetCelebrationOverlay),
      HomeWidget.saveWidgetData(
          'adaptive_all_habits_json', jsonEncode(adaptiveAllPayload)),
      HomeWidget.saveWidgetData(
          'adaptive_payload_json', jsonEncode(legacyAdaptivePayload)),
      HomeWidget.saveWidgetData(
          'daily_list_all_json', jsonEncode(dailyListAllPayload)),
      HomeWidget.saveWidgetData(
          'daily_list_payload_json', jsonEncode(legacyListPayload)),
      HomeWidget.saveWidgetData(
          'todo_list_all_json', jsonEncode(todoAllPayload)),
      HomeWidget.saveWidgetData(
          'day_mode_payload_json', jsonEncode(dayModePayload)),
    ]);

    await Future.wait([
      HomeWidget.updateWidget(androidName: adaptiveProvider),
      HomeWidget.updateWidget(androidName: dailyListProvider),
      HomeWidget.updateWidget(androidName: todoListProvider),
      HomeWidget.updateWidget(androidName: dayModeProvider),
    ]);
  }
}

Future<AppSettings> readWidgetSettingsSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final calStr = prefs.getString('calendarSystem') ?? CalendarSystem.jalali.name;
  final weekStr = prefs.getString('weekStartDay') ?? WeekStartDay.saturday.name;
  final hwThemeStr = await HomeWidget.getWidgetData<String>('widget_theme');
  final wThemeStr = hwThemeStr ??
      prefs.getString('widgetTheme') ??
      WidgetThemeMode.dark.name;
  final hwLocale = await HomeWidget.getWidgetData<String>('widget_locale');
  final hwCeleb = await HomeWidget.getWidgetData<bool>('widget_celebration');
  return AppSettings(
    localeCode: hwLocale ?? prefs.getString('localeCode') ?? 'fa',
    calendarSystem: CalendarSystem.values.asNameMap()[calStr] ?? CalendarSystem.jalali,
    weekStartDay: WeekStartDay.values.asNameMap()[weekStr] ?? WeekStartDay.saturday,
    widgetTheme: WidgetThemeMode.values.asNameMap()[wThemeStr] ?? WidgetThemeMode.dark,
    widgetCelebrationOverlay:
        hwCeleb ?? prefs.getBool('widgetCelebrationOverlay') ?? true,
    customStoragePath: prefs.getString('customStoragePath'),
    dayResetMinutes: prefs.getInt('dayResetMinutes') ?? 0,
    streakGraceDaysPerMonth: prefs.getInt('streakGraceDaysPerMonth') ?? 0,
    autoBackupEnabled: prefs.getBool('autoBackupEnabled') ?? false,
    autoBackupIntervalDays: prefs.getInt('autoBackupIntervalDays') ?? 1,
    autoBackupHour: prefs.getInt('autoBackupHour') ?? 23,
    autoBackupMinute: prefs.getInt('autoBackupMinute') ?? 0,
    autoBackupKeepCount: prefs.getInt('autoBackupKeepCount') ?? 5,
    lastAutoBackupMs: prefs.getInt('lastAutoBackupMs'),
    quietHoursEnabled: prefs.getBool('quietHoursEnabled') ?? false,
    quietStartMinutes: prefs.getInt('quietStartMinutes') ?? (23 * 60),
    quietEndMinutes: prefs.getInt('quietEndMinutes') ?? (7 * 60),
    activeDayMode: prefs.getString('activeDayMode') ?? 'normal',
    customDayModes: prefs.getStringList('customDayModes') ?? const [],
    dayModesList: _decodeWidgetDayModes(
      prefs.getString('dayModesList'),
      prefs.getStringList('customDayModes') ?? const [],
    ),
    allDayModeColorValue:
        prefs.getInt('allDayModeColorValue') ?? 0xFF84CC16,
    allDayModeIconKey:
        prefs.getString('allDayModeIconKey') ?? 'all_inclusive',
    dayModeByDate: _decodeStrMap(prefs.getString('dayModeByDate')),
    weekdayDayModes: _decodeIntStrMap(prefs.getString('weekdayDayModes')),
    obsidianVaultUri: prefs.getString('obsidianVaultUri'),
    obsidianSyncEnabled: prefs.getBool('obsidianSyncEnabled') ?? false,
    lastObsidianSyncMs: prefs.getInt('lastObsidianSyncMs'),
    googleDriveUri: prefs.getString('googleDriveUri'),
    googleAccountEmail: prefs.getString('googleAccountEmail'),
    googleAccountName: prefs.getString('googleAccountName'),
    googleAutoSyncEnabled: prefs.getBool('googleAutoSyncEnabled') ?? true,
    googleCalendarSyncEnabled:
        prefs.getBool('googleCalendarSyncEnabled') ?? false,
    lastGoogleSyncMs: prefs.getInt('lastGoogleSyncMs'),
    widgetHabitId: prefs.getString('widgetHabitId'),
    widgetListHabitIds: prefs.getStringList('widgetListHabitIds') ?? const [],
  );
}

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;

  final db = AppDatabase.instance;

  if (uri.host == 'todotoggle') {
    final taskId = uri.queryParameters['taskId'];
    if (taskId == null || taskId.isEmpty) return;
    final tasks = await db.getOneOffTasks();
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.upsertOneOffTask(
      task.copyWith(isDone: !task.isDone, updatedAtMs: nowMs),
    );
    final refreshedTasks = await db.getOneOffTasks();
    final habits = await db.getHabits(includeArchived: false);
    final checklistAll = await db.getAllChecklistItems();
    final comps = await db.getAllCompletions();
    final pauses = await db.getAllPauses();
    final settings = await readWidgetSettingsSnapshot();
    await WidgetSyncService.instance.syncAll(
      habits: habits,
      checklistItems: checklistAll,
      completions: comps,
      pauses: pauses,
      oneOffTasks: refreshedTasks,
      settings: settings,
    );
    if (settings.obsidianSyncEnabled &&
        settings.obsidianVaultUri != null &&
        settings.obsidianVaultUri!.isNotEmpty) {
      await ObsidianSyncService.instance.syncFullVaultNow(
        settings: settings,
        forceFullWrite: false,
      );
    }
    if ((settings.googleAccountEmail ?? '').isNotEmpty &&
        settings.googleAutoSyncEnabled) {
      await GoogleDriveSyncService.instance.syncWithGoogleAccount(
        settings: settings,
        pullFirst: false,
      );
    }
    return;
  }

  if (uri.host == 'daymode') {
    final delta = int.tryParse(uri.queryParameters['delta'] ?? '1') ?? 1;
    final includeAll = uri.queryParameters['includeAll'] != 'false';
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final settings = await readWidgetSettingsSnapshot();
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final effective = HabitEngine.resolveDayMode(settings, today);

    final modeIds = <String>[
      if (includeAll) 'all',
      for (final m in settings.dayModesList) m.id,
    ];
    if (modeIds.isEmpty) return;

    var curIdx = modeIds.indexOf(effective);
    if (curIdx < 0) curIdx = 0;
    final nextIdx = ((curIdx + delta) % modeIds.length + modeIds.length) % modeIds.length;
    final targetModeId = modeIds[nextIdx];

    final hasDateOverride = settings.dayModeByDate.containsKey(todayKey);
    final hasWeekdayRule = settings.weekdayDayModes.containsKey(today.weekday);
    final fallbackNonAll = settings.dayModesList.any((d) => d.id == 'normal')
        ? 'normal'
        : (settings.dayModesList.isNotEmpty ? settings.dayModesList.first.id : 'all');

    late final AppSettings nextSettings;
    if (targetModeId == 'all') {
      await prefs.setString('activeDayMode', 'all');
      nextSettings = settings.copyWith(activeDayMode: 'all');
    } else if (hasDateOverride || hasWeekdayRule) {
      final nextDateMap = Map<String, String>.from(settings.dayModeByDate)
        ..[todayKey] = targetModeId;
      final nextActive =
          settings.activeDayMode == 'all' ? fallbackNonAll : settings.activeDayMode;
      await prefs.setString('dayModeByDate', jsonEncode(nextDateMap));
      await prefs.setString('activeDayMode', nextActive);
      nextSettings = settings.copyWith(
        dayModeByDate: nextDateMap,
        activeDayMode: nextActive,
      );
    } else {
      await prefs.setString('activeDayMode', targetModeId);
      nextSettings = settings.copyWith(activeDayMode: targetModeId);
    }

    final habits = await db.getHabits(includeArchived: false);
    final checklistAll = await db.getAllChecklistItems();
    final comps = await db.getAllCompletions();
    final pauses = await db.getAllPauses();
    final oneOffTasks = await db.getOneOffTasks();
    await WidgetSyncService.instance.syncAll(
      habits: habits,
      checklistItems: checklistAll,
      completions: comps,
      pauses: pauses,
      oneOffTasks: oneOffTasks,
      settings: nextSettings,
    );
    if (nextSettings.obsidianSyncEnabled &&
        nextSettings.obsidianVaultUri != null &&
        nextSettings.obsidianVaultUri!.isNotEmpty) {
      await ObsidianSyncService.instance.syncFullVaultNow(
        settings: nextSettings,
        forceFullWrite: false,
      );
    }
    if ((nextSettings.googleAccountEmail ?? '').isNotEmpty &&
        nextSettings.googleAutoSyncEnabled) {
      await GoogleDriveSyncService.instance.syncWithGoogleAccount(
        settings: nextSettings,
        pullFirst: false,
      );
    }
    return;
  }

  final habitId = uri.queryParameters['habitId'];
  if (habitId == null || habitId.isEmpty) return;

  final habits = await db.getHabits(includeArchived: false);
  final habit = habits.where((h) => h.id == habitId).firstOrNull;
  if (habit == null) return;

  final settings = await readWidgetSettingsSnapshot();
  final today =
      AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
  final todayKey = AppCalendar.toDateKey(today);
  final allComps = await db.getAllCompletions();
  final checklistAll = await db.getAllChecklistItems();
  final habitItems = checklistAll.where((i) => i.habitId == habitId).toList();
  final existing = allComps
      .where((c) => c.habitId == habitId && c.dateKey == todayKey)
      .firstOrNull;
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  late final HabitCompletion updated;
  if (uri.host == 'sub') {
    final subId = uri.queryParameters['subId'];
    if (subId == null || subId.isEmpty) return;
    final ids = List<String>.from(existing?.completedChecklistIds ?? const []);
    if (ids.contains(subId)) {
      ids.remove(subId);
    } else {
      ids.add(subId);
    }
    final allOk =
        habitItems.isNotEmpty && habitItems.every((i) => ids.contains(i.id));
    updated = HabitCompletion(
      id: existing?.id ?? const Uuid().v4(),
      habitId: habitId,
      dateKey: todayKey,
      value: allOk ? 1 : 0,
      completedChecklistIds: ids,
      slipped: existing?.slipped ?? false,
      updatedAtMs: nowMs,
    );
  } else if (uri.host == 'step') {
    final delta = int.tryParse(uri.queryParameters['delta'] ?? '1') ?? 1;
    final maxTarget = habit.targetCount < 1 ? 1 : habit.targetCount;
    final nextVal = ((existing?.value ?? 0) + delta).clamp(0, maxTarget);
    updated = HabitCompletion(
      id: existing?.id ?? const Uuid().v4(),
      habitId: habitId,
      dateKey: todayKey,
      value: nextVal,
      completedChecklistIds: existing?.completedChecklistIds ?? const [],
      slipped: false,
      updatedAtMs: nowMs,
    );
  } else if (uri.host == 'toggle') {
    if (habit.isQuit) {
      final nextVal = (existing?.value ?? 0) >= 1 ? 0 : 1;
      updated = HabitCompletion(
        id: existing?.id ?? const Uuid().v4(),
        habitId: habitId,
        dateKey: todayKey,
        value: nextVal,
        completedChecklistIds: existing?.completedChecklistIds ?? const [],
        slipped: false,
        updatedAtMs: nowMs,
      );
    } else if (habit.trackingStyle == TrackingStyle.count) {
      final curVal = existing?.value ?? 0;
      final target = habit.targetCount < 1 ? 1 : habit.targetCount;
      final nextVal = curVal >= target ? 0 : curVal + 1;
      updated = HabitCompletion(
        id: existing?.id ?? const Uuid().v4(),
        habitId: habitId,
        dateKey: todayKey,
        value: nextVal,
        completedChecklistIds: existing?.completedChecklistIds ?? const [],
        slipped: false,
        updatedAtMs: nowMs,
      );
    } else if (habit.trackingStyle == TrackingStyle.checklist) {
      final allIds = habitItems.map((e) => e.id).toList();
      final wasAll = allIds.isEmpty
          ? (existing?.value ?? 0) >= 1
          : allIds.every(
              (id) => existing?.completedChecklistIds.contains(id) ?? false,
            );
      updated = HabitCompletion(
        id: existing?.id ?? const Uuid().v4(),
        habitId: habitId,
        dateKey: todayKey,
        value: wasAll ? 0 : 1,
        completedChecklistIds: wasAll ? const [] : allIds,
        slipped: false,
        updatedAtMs: nowMs,
      );
    } else {
      final nextVal = (existing?.value ?? 0) >= 1 ? 0 : 1;
      updated = HabitCompletion(
        id: existing?.id ?? const Uuid().v4(),
        habitId: habitId,
        dateKey: todayKey,
        value: nextVal,
        completedChecklistIds: existing?.completedChecklistIds ?? const [],
        slipped: false,
        updatedAtMs: nowMs,
      );
    }
  } else {
    return;
  }

  await db.upsertCompletion(updated);
  if (HabitEngine.isCompletedOn(habit, updated, habitItems, today,
      today: today)) {
    await db.recordCompletionEvent(habitId, DateTime.now());
    await NotificationService.instance.syncHabitReminder(
      habit,
      isFa: settings.localeCode == 'fa',
      settings: settings,
      isDoneToday: true,
    );
  }
  final refreshedComps = await db.getAllCompletions();
  final pauses = await db.getAllPauses();
  final oneOffTasks = await db.getOneOffTasks();
  await WidgetSyncService.instance.syncAll(
    habits: habits,
    checklistItems: checklistAll,
    completions: refreshedComps,
    pauses: pauses,
    oneOffTasks: oneOffTasks,
    settings: settings,
  );
  if (settings.obsidianSyncEnabled &&
      settings.obsidianVaultUri != null &&
      settings.obsidianVaultUri!.isNotEmpty) {
    await ObsidianSyncService.instance.syncFullVaultNow(
      settings: settings,
      forceFullWrite: false,
    );
  }
  if ((settings.googleAccountEmail ?? '').isNotEmpty &&
      (settings.googleAutoSyncEnabled || settings.googleCalendarSyncEnabled)) {
    await GoogleDriveSyncService.instance.syncWithGoogleAccount(
      settings: settings,
      pullFirst: false,
    );
  }
}

List<DayModeConfig> _decodeWidgetDayModes(
  String? raw,
  List<String> legacyCustom,
) {
  if (raw != null) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => DayModeConfig.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }
  return [
    ...DayModeConfig.starterDefaults,
    for (final c in legacyCustom)
      DayModeConfig(
        id: c,
        name: c,
        colorValue: 0xFFB06CFF,
        iconKey: 'star',
      ),
  ];
}

Map<String, String> _decodeStrMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final d = jsonDecode(raw);
    if (d is Map) {
      return {for (final e in d.entries) e.key.toString(): e.value.toString()};
    }
  } catch (_) {}
  return const {};
}

Map<int, String> _decodeIntStrMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final d = jsonDecode(raw);
    if (d is Map) {
      return {
        for (final e in d.entries)
          if (int.tryParse(e.key.toString()) case final k?)
            k: e.value.toString(),
      };
    }
  } catch (_) {}
  return const {};
}
