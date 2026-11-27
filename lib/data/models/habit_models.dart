enum HabitMode { build, quit }

enum TrackingStyle { boolean, count, checklist }

enum FrequencyType { daily, weekdays, monthDays, period, interval }

enum NoteKind { text, image, audio }

enum CalendarSystem { gregorian, jalali }

enum WeekStartDay { saturday, sunday, monday }

enum HomeLayout { grid, list }

enum SoundProfile { pop, drop, wood, minimal }

enum WidgetThemeMode { dark, light }

enum FontScaleMode { small, medium, large }

enum SuccessRatePeriod { weekly, monthly, yearly }

enum OneOffKind { shopping, todo }

class OneOffTask {
  const OneOffTask({
    required this.id,
    required this.title,
    this.kind = OneOffKind.todo,
    this.quantity = '',
    this.isDone = false,
    this.dueDateKey,
    this.sortOrder = 0,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String title;
  final OneOffKind kind;
  final String quantity;
  final bool isDone;
  final String? dueDateKey;
  final int sortOrder;
  final int createdAtMs;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  OneOffTask copyWith({
    String? title,
    OneOffKind? kind,
    String? quantity,
    bool? isDone,
    String? dueDateKey,
    bool clearDueDate = false,
    int? sortOrder,
    int? updatedAtMs,
    int? deletedAtMs,
    int? syncRevision,
    bool? syncDirty,
  }) {
    return OneOffTask(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      quantity: quantity ?? this.quantity,
      isDone: isDone ?? this.isDone,
      dueDateKey: clearDueDate ? null : (dueDateKey ?? this.dueDateKey),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      syncRevision: syncRevision ?? this.syncRevision,
      syncDirty: syncDirty ?? this.syncDirty,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'quantity': quantity,
        'is_done': isDone ? 1 : 0,
        'due_date_key': dueDateKey,
        'sort_order': sortOrder,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory OneOffTask.fromDbMap(Map<String, dynamic> m) => OneOffTask(
        id: m['id'] as String,
        title: m['title'] as String,
        kind: OneOffKind.values.asNameMap()[m['kind']] ?? OneOffKind.todo,
        quantity: (m['quantity'] as String?) ?? '',
        isDone: ((m['is_done'] as int?) ?? 0) == 1,
        dueDateKey: m['due_date_key'] as String?,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        createdAtMs: (m['created_at_ms'] as int?) ?? 0,
        updatedAtMs: (m['updated_at_ms'] as int?) ?? 0,
        deletedAtMs: m['deleted_at_ms'] as int?,
        syncRevision: (m['sync_revision'] as int?) ?? 0,
        syncDirty: ((m['sync_dirty'] as int?) ?? 0) == 1,
      );
}

class CompletionEvent {
  const CompletionEvent({
    required this.id,
    required this.habitId,
    required this.minuteOfDay,
    required this.weekday,
    required this.recordedAtMs,
  });

  final String id;
  final String habitId;
  final int minuteOfDay;
  final int weekday;
  final int recordedAtMs;

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'habit_id': habitId,
        'minute_of_day': minuteOfDay,
        'weekday': weekday,
        'recorded_at_ms': recordedAtMs,
      };

  factory CompletionEvent.fromDbMap(Map<String, dynamic> m) => CompletionEvent(
        id: m['id'] as String,
        habitId: m['habit_id'] as String,
        minuteOfDay: m['minute_of_day'] as int,
        weekday: m['weekday'] as int,
        recordedAtMs: m['recorded_at_ms'] as int,
      );
}

class HabitPause {
  const HabitPause({
    required this.id,
    required this.habitId,
    required this.startDateKey,
    this.endDateKey,
    this.reason = '',
    required this.updatedAtMs,
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String habitId;
  final String startDateKey;
  final String? endDateKey;
  final String reason;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  bool coversDateKey(String dateKey) =>
      dateKey.compareTo(startDateKey) >= 0 &&
      (endDateKey == null || dateKey.compareTo(endDateKey!) <= 0);

  HabitPause copyWith({
    String? startDateKey,
    String? endDateKey,
    bool clearEndDate = false,
    String? reason,
    int? updatedAtMs,
    int? deletedAtMs,
    int? syncRevision,
    bool? syncDirty,
  }) {
    return HabitPause(
      id: id,
      habitId: habitId,
      startDateKey: startDateKey ?? this.startDateKey,
      endDateKey: clearEndDate ? null : (endDateKey ?? this.endDateKey),
      reason: reason ?? this.reason,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      syncRevision: syncRevision ?? this.syncRevision,
      syncDirty: syncDirty ?? this.syncDirty,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'habit_id': habitId,
        'start_date_key': startDateKey,
        'end_date_key': endDateKey,
        'reason': reason,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory HabitPause.fromDbMap(Map<String, dynamic> m) => HabitPause(
        id: m['id'] as String,
        habitId: m['habit_id'] as String,
        startDateKey: m['start_date_key'] as String,
        endDateKey: m['end_date_key'] as String?,
        reason: (m['reason'] as String?) ?? '',
        updatedAtMs: m['updated_at_ms'] as int,
        deletedAtMs: m['deleted_at_ms'] as int?,
        syncRevision: (m['sync_revision'] as int?) ?? 0,
        syncDirty: ((m['sync_dirty'] as int?) ?? 0) == 1,
      );
}

class HabitCategory {
  const HabitCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.sortOrder,
    required this.updatedAtMs,
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String name;
  final int colorValue;
  final int sortOrder;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  HabitCategory copyWith({
    String? name,
    int? colorValue,
    int? sortOrder,
    int? updatedAtMs,
    int? deletedAtMs,
    int? syncRevision,
    bool? syncDirty,
  }) {
    return HabitCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      syncRevision: syncRevision ?? this.syncRevision,
      syncDirty: syncDirty ?? this.syncDirty,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'name': name,
        'color_value': colorValue,
        'sort_order': sortOrder,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory HabitCategory.fromDbMap(Map<String, dynamic> m) => HabitCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        colorValue: m['color_value'] as int,
        sortOrder: m['sort_order'] as int,
        updatedAtMs: m['updated_at_ms'] as int,
        deletedAtMs: m['deleted_at_ms'] as int?,
        syncRevision: (m['sync_revision'] as int?) ?? 0,
        syncDirty: ((m['sync_dirty'] as int?) ?? 0) == 1,
      );
}

class HabitChecklistItem {
  const HabitChecklistItem({
    required this.id,
    required this.habitId,
    required this.title,
    required this.sortOrder,
    required this.updatedAtMs,
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String habitId;
  final String title;
  final int sortOrder;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'habit_id': habitId,
        'title': title,
        'sort_order': sortOrder,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory HabitChecklistItem.fromDbMap(Map<String, dynamic> m) =>
      HabitChecklistItem(
        id: m['id'] as String,
        habitId: m['habit_id'] as String,
        title: m['title'] as String,
        sortOrder: m['sort_order'] as int,
        updatedAtMs: m['updated_at_ms'] as int,
        deletedAtMs: m['deleted_at_ms'] as int?,
        syncRevision: (m['sync_revision'] as int?) ?? 0,
        syncDirty: ((m['sync_dirty'] as int?) ?? 0) == 1,
      );
}

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.description,
    required this.mode,
    required this.trackingStyle,
    required this.frequencyType,
    required this.weekdaysMask,
    required this.intervalDays,
    required this.targetCount,
    required this.countUnit,
    required this.colorValue,
    required this.iconKey,
    required this.startDateKey,
    required this.sortOrder,
    required this.isArchived,
    required this.reminderEnabled,
    required this.updatedAtMs,
    this.monthDays = const [1, 15],
    this.targetPerWeek = 5,
    this.showTitleBadge = false,
    this.categoryId,
    this.reminderHour,
    this.reminderMinute,
    this.reminderRepeatMins = 0,
    this.reminderMaxRepeats = 3,
    this.responseWindowMins = 120,
    this.smartLearningEnabled = false,
    this.dayModes = const [],
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String title;
  final String description;
  final HabitMode mode;
  final TrackingStyle trackingStyle;
  final FrequencyType frequencyType;

  /// Bitmask of DateTime.weekday (bit 1..7 for Mon..Sun; 127 = all days).
  final int weekdaysMask;
  final List<int> monthDays;
  final int targetPerWeek;
  final int intervalDays;
  final int targetCount;
  final String countUnit;
  final int colorValue;
  final String iconKey;
  final String? categoryId;
  final String startDateKey;
  final int sortOrder;
  final bool isArchived;
  final bool showTitleBadge;
  final bool reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;
  final int reminderRepeatMins;
  final int reminderMaxRepeats;
  final int responseWindowMins;
  final bool smartLearningEnabled;
  final List<String> dayModes;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  bool get isQuit => mode == HabitMode.quit;

  Habit copyWith({
    String? title,
    String? description,
    HabitMode? mode,
    TrackingStyle? trackingStyle,
    FrequencyType? frequencyType,
    int? weekdaysMask,
    List<int>? monthDays,
    int? targetPerWeek,
    int? intervalDays,
    int? targetCount,
    String? countUnit,
    int? colorValue,
    String? iconKey,
    String? categoryId,
    bool clearCategory = false,
    String? startDateKey,
    int? sortOrder,
    bool? isArchived,
    bool? showTitleBadge,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? reminderRepeatMins,
    int? reminderMaxRepeats,
    int? responseWindowMins,
    bool? smartLearningEnabled,
    List<String>? dayModes,
    int? updatedAtMs,
    int? deletedAtMs,
    int? syncRevision,
    bool? syncDirty,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      trackingStyle: trackingStyle ?? this.trackingStyle,
      frequencyType: frequencyType ?? this.frequencyType,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      monthDays: monthDays ?? this.monthDays,
      targetPerWeek: targetPerWeek ?? this.targetPerWeek,
      intervalDays: intervalDays ?? this.intervalDays,
      targetCount: targetCount ?? this.targetCount,
      countUnit: countUnit ?? this.countUnit,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startDateKey: startDateKey ?? this.startDateKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      showTitleBadge: showTitleBadge ?? this.showTitleBadge,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reminderRepeatMins: reminderRepeatMins ?? this.reminderRepeatMins,
      reminderMaxRepeats: reminderMaxRepeats ?? this.reminderMaxRepeats,
      responseWindowMins: responseWindowMins ?? this.responseWindowMins,
      smartLearningEnabled: smartLearningEnabled ?? this.smartLearningEnabled,
      dayModes: dayModes ?? this.dayModes,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      syncRevision: syncRevision ?? this.syncRevision,
      syncDirty: syncDirty ?? this.syncDirty,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'description': description,
        'mode': mode.name,
        'tracking_style': trackingStyle.name,
        'frequency_type': frequencyType.name,
        'weekdays_mask': weekdaysMask,
        'month_days': monthDays.join(','),
        'target_per_week': targetPerWeek,
        'interval_days': intervalDays,
        'target_count': targetCount,
        'count_unit': countUnit,
        'color_value': colorValue,
        'icon_key': iconKey,
        'category_id': categoryId,
        'start_date_key': startDateKey,
        'sort_order': sortOrder,
        'is_archived': isArchived ? 1 : 0,
        'show_title_badge': showTitleBadge ? 1 : 0,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'reminder_repeat_mins': reminderRepeatMins,
        'reminder_max_repeats': reminderMaxRepeats,
        'response_window_mins': responseWindowMins,
        'smart_learning_enabled': smartLearningEnabled ? 1 : 0,
        'day_modes': dayModes.join(','),
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory Habit.fromDbMap(Map<String, dynamic> m) {
    final rawMonthDays = (m['month_days'] as String?) ?? '1,15';
    final parsedMonthDays = rawMonthDays
        .split(',')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => int.tryParse(e.trim()) ?? 1)
        .toList();
    return Habit(
      id: (m['id'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] as String?) ?? '',
      mode: HabitMode.values.asNameMap()[m['mode']] ?? HabitMode.build,
      trackingStyle: TrackingStyle.values.asNameMap()[m['tracking_style']] ??
          TrackingStyle.boolean,
      frequencyType: FrequencyType.values.asNameMap()[m['frequency_type']] ??
          FrequencyType.daily,
      weekdaysMask: (m['weekdays_mask'] as num?)?.toInt() ?? 127,
      monthDays: parsedMonthDays.isEmpty ? const [1, 15] : parsedMonthDays,
      targetPerWeek: (m['target_per_week'] as num?)?.toInt() ?? 5,
      intervalDays: (m['interval_days'] as num?)?.toInt() ?? 1,
      targetCount: (m['target_count'] as num?)?.toInt() ?? 1,
      countUnit: (m['count_unit'] as String?) ?? '',
      colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF84CC16,
      iconKey: (m['icon_key'] as String?) ?? 'check_circle',
      categoryId: m['category_id'] as String?,
      startDateKey: (m['start_date_key'] as String?) ?? '2025-01-01',
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      isArchived: ((m['is_archived'] as num?)?.toInt() ?? 0) == 1,
      showTitleBadge: ((m['show_title_badge'] as num?)?.toInt() ?? 0) == 1,
      reminderEnabled: ((m['reminder_enabled'] as num?)?.toInt() ?? 0) == 1,
      reminderHour: (m['reminder_hour'] as num?)?.toInt(),
      reminderMinute: (m['reminder_minute'] as num?)?.toInt(),
      reminderRepeatMins: (m['reminder_repeat_mins'] as num?)?.toInt() ?? 0,
      reminderMaxRepeats: (m['reminder_max_repeats'] as num?)?.toInt() ?? 3,
      responseWindowMins: (m['response_window_mins'] as num?)?.toInt() ?? 120,
      smartLearningEnabled:
          ((m['smart_learning_enabled'] as num?)?.toInt() ?? 0) == 1,
      dayModes: ((m['day_modes'] as String?) ?? '')
          .split(',')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      updatedAtMs: (m['updated_at_ms'] as num?)?.toInt() ?? 0,
      deletedAtMs: (m['deleted_at_ms'] as num?)?.toInt(),
      syncRevision: (m['sync_revision'] as num?)?.toInt() ?? 0,
      syncDirty: ((m['sync_dirty'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}

class HabitCompletion {
  const HabitCompletion({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.value,
    required this.completedChecklistIds,
    required this.slipped,
    required this.updatedAtMs,
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String habitId;
  final String dateKey;
  final int value;
  final List<String> completedChecklistIds;
  final bool slipped;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'habit_id': habitId,
        'date_key': dateKey,
        'value': value,
        'completed_checklist_ids': completedChecklistIds.join(','),
        'slipped': slipped ? 1 : 0,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory HabitCompletion.fromDbMap(Map<String, dynamic> m) {
    final rawIds = (m['completed_checklist_ids'] as String?) ?? '';
    return HabitCompletion(
      id: m['id'] as String,
      habitId: m['habit_id'] as String,
      dateKey: m['date_key'] as String,
      value: m['value'] as int,
      completedChecklistIds: rawIds.isEmpty
          ? const []
          : rawIds.split(',').where((e) => e.isNotEmpty).toList(),
      slipped: ((m['slipped'] as int?) ?? 0) == 1,
      updatedAtMs: m['updated_at_ms'] as int,
      deletedAtMs: m['deleted_at_ms'] as int?,
      syncRevision: (m['sync_revision'] as int?) ?? 0,
      syncDirty: ((m['sync_dirty'] as int?) ?? 0) == 1,
    );
  }
}

class HabitNote {
  const HabitNote({
    required this.id,
    required this.habitId,
    required this.dateKey,
    required this.kind,
    required this.content,
    required this.durationMs,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.title = '',
    this.deletedAtMs,
    this.syncRevision = 0,
    this.syncDirty = true,
  });

  final String id;
  final String habitId;
  final String dateKey;
  final NoteKind kind;
  final String title;
  final String content;
  final int durationMs;
  final int createdAtMs;
  final int updatedAtMs;
  final int? deletedAtMs;
  final int syncRevision;
  final bool syncDirty;

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'habit_id': habitId,
        'date_key': dateKey,
        'kind': kind.name,
        'title': title,
        'content': content,
        'duration_ms': durationMs,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'deleted_at_ms': deletedAtMs,
        'sync_revision': syncRevision,
        'sync_dirty': syncDirty ? 1 : 0,
      };

  factory HabitNote.fromDbMap(Map<String, dynamic> m) => HabitNote(
        id: (m['id'] ?? '').toString(),
        habitId: (m['habit_id'] ?? '').toString(),
        dateKey: (m['date_key'] as String?) ?? '2025-01-01',
        kind: NoteKind.values.asNameMap()[m['kind']] ?? NoteKind.text,
        title: (m['title'] as String?) ?? '',
        content: (m['content'] as String?) ?? '',
        durationMs: (m['duration_ms'] as num?)?.toInt() ?? 0,
        createdAtMs: (m['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (m['updated_at_ms'] as num?)?.toInt() ?? 0,
        deletedAtMs: (m['deleted_at_ms'] as num?)?.toInt(),
        syncRevision: (m['sync_revision'] as num?)?.toInt() ?? 0,
        syncDirty: ((m['sync_dirty'] as num?)?.toInt() ?? 0) == 1,
      );
}

class DayModeConfig {
  const DayModeConfig({
    required this.id,
    this.name = '',
    this.colorValue = 0xFFB06CFF,
    this.iconKey = 'tune',
  });

  final String id;
  final String name;
  final int colorValue;
  final String iconKey;

  static const List<DayModeConfig> starterDefaults = [
    DayModeConfig(
        id: 'normal', name: '', colorValue: 0xFF94A3B8, iconKey: 'tune'),
    DayModeConfig(
        id: 'work', name: '', colorValue: 0xFF3898FF, iconKey: 'work'),
    DayModeConfig(
        id: 'off', name: '', colorValue: 0xFF00C48C, iconKey: 'weekend'),
    DayModeConfig(
        id: 'travel', name: '', colorValue: 0xFFFFB020, iconKey: 'flight'),
  ];

  DayModeConfig copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconKey,
  }) =>
      DayModeConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconKey: iconKey ?? this.iconKey,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconKey': iconKey,
      };

  factory DayModeConfig.fromMap(Map<String, dynamic> m) => DayModeConfig(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        colorValue: (m['colorValue'] as int?) ?? 0xFFB06CFF,
        iconKey: (m['iconKey'] ?? 'tune').toString(),
      );
}

class AppSettings {
  const AppSettings({
    this.localeCode = 'fa',
    this.calendarSystem = CalendarSystem.jalali,
    this.weekStartDay = WeekStartDay.saturday,
    this.isDarkMode = true,
    this.homeLayout = HomeLayout.grid,
    this.widgetTheme = WidgetThemeMode.dark,
    this.soundProfile = SoundProfile.pop,
    this.fontScaleMode = FontScaleMode.medium,
    this.widgetCelebrationOverlay = true,
    this.customStoragePath,
    this.dayResetMinutes = 0,
    this.streakGraceDaysPerMonth = 0,
    this.homeRatePeriod = SuccessRatePeriod.weekly,
    this.autoBackupEnabled = false,
    this.autoBackupIntervalDays = 1,
    this.autoBackupHour = 23,
    this.autoBackupMinute = 0,
    this.autoBackupKeepCount = 5,
    this.lastAutoBackupMs,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 23 * 60,
    this.quietEndMinutes = 7 * 60,
    this.activeDayMode = 'normal',
    this.customDayModes = const [],
    this.dayModesList = DayModeConfig.starterDefaults,
    this.allDayModeColorValue = 0xFF84CC16,
    this.allDayModeIconKey = 'all_inclusive',
    this.dayModeByDate = const {},
    this.weekdayDayModes = const {},
    this.obsidianVaultUri,
    this.obsidianSyncEnabled = false,
    this.lastObsidianSyncMs,
    this.googleDriveUri,
    this.googleAccountEmail,
    this.googleAccountName,
    this.googleAutoSyncEnabled = true,
    this.googleCalendarSyncEnabled = false,
    this.lastGoogleSyncMs,
    this.isShowOnlyDueHabit = false,
    this.isShowAddNoteInHome = true,
    this.isConfettiEnabled = true,
    this.isAchievementSoundEnabled = true,
    this.isAppLockEnabled = false,
    this.isOnboardingCompleted = true,
    this.widgetHabitId,
    this.widgetListHabitIds = const [],
  });

  final String localeCode;
  final CalendarSystem calendarSystem;
  final WeekStartDay weekStartDay;
  final bool isDarkMode;
  final HomeLayout homeLayout;
  final WidgetThemeMode widgetTheme;
  final SoundProfile soundProfile;
  final FontScaleMode fontScaleMode;
  final bool widgetCelebrationOverlay;
  final String? customStoragePath;
  final int dayResetMinutes;
  final int streakGraceDaysPerMonth;
  final SuccessRatePeriod homeRatePeriod;
  final bool autoBackupEnabled;
  final int autoBackupIntervalDays;
  final int autoBackupHour;
  final int autoBackupMinute;
  final int autoBackupKeepCount;
  final int? lastAutoBackupMs;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final String activeDayMode;
  final List<String> customDayModes;
  final List<DayModeConfig> dayModesList;
  final int allDayModeColorValue;
  final String allDayModeIconKey;
  final Map<String, String> dayModeByDate;
  final Map<int, String> weekdayDayModes;
  final String? obsidianVaultUri;
  final bool obsidianSyncEnabled;
  final int? lastObsidianSyncMs;
  final String? googleDriveUri;
  final String? googleAccountEmail;
  final String? googleAccountName;
  final bool googleAutoSyncEnabled;
  final bool googleCalendarSyncEnabled;
  final int? lastGoogleSyncMs;
  final bool isShowOnlyDueHabit;
  final bool isShowAddNoteInHome;
  final bool isConfettiEnabled;
  final bool isAchievementSoundEnabled;
  final bool isAppLockEnabled;
  final bool isOnboardingCompleted;
  final String? widgetHabitId;
  final List<String> widgetListHabitIds;

  AppSettings copyWith({
    String? localeCode,
    CalendarSystem? calendarSystem,
    WeekStartDay? weekStartDay,
    bool? isDarkMode,
    HomeLayout? homeLayout,
    WidgetThemeMode? widgetTheme,
    SoundProfile? soundProfile,
    FontScaleMode? fontScaleMode,
    bool? widgetCelebrationOverlay,
    String? customStoragePath,
    bool clearCustomStoragePath = false,
    int? dayResetMinutes,
    int? streakGraceDaysPerMonth,
    SuccessRatePeriod? homeRatePeriod,
    bool? autoBackupEnabled,
    int? autoBackupIntervalDays,
    int? autoBackupHour,
    int? autoBackupMinute,
    int? autoBackupKeepCount,
    int? lastAutoBackupMs,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    String? activeDayMode,
    List<String>? customDayModes,
    List<DayModeConfig>? dayModesList,
    int? allDayModeColorValue,
    String? allDayModeIconKey,
    Map<String, String>? dayModeByDate,
    Map<int, String>? weekdayDayModes,
    String? obsidianVaultUri,
    bool clearObsidianVaultUri = false,
    bool? obsidianSyncEnabled,
    int? lastObsidianSyncMs,
    String? googleDriveUri,
    bool clearGoogleDriveUri = false,
    String? googleAccountEmail,
    String? googleAccountName,
    bool clearGoogleAccount = false,
    bool? googleAutoSyncEnabled,
    bool? googleCalendarSyncEnabled,
    int? lastGoogleSyncMs,
    bool? isShowOnlyDueHabit,
    bool? isShowAddNoteInHome,
    bool? isConfettiEnabled,
    bool? isAchievementSoundEnabled,
    bool? isAppLockEnabled,
    bool? isOnboardingCompleted,
    String? widgetHabitId,
    bool clearWidgetHabitId = false,
    List<String>? widgetListHabitIds,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      calendarSystem: calendarSystem ?? this.calendarSystem,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      homeLayout: homeLayout ?? this.homeLayout,
      widgetTheme: widgetTheme ?? this.widgetTheme,
      soundProfile: soundProfile ?? this.soundProfile,
      fontScaleMode: fontScaleMode ?? this.fontScaleMode,
      widgetCelebrationOverlay:
          widgetCelebrationOverlay ?? this.widgetCelebrationOverlay,
      customStoragePath: clearCustomStoragePath
          ? null
          : (customStoragePath ?? this.customStoragePath),
      dayResetMinutes: dayResetMinutes ?? this.dayResetMinutes,
      streakGraceDaysPerMonth:
          streakGraceDaysPerMonth ?? this.streakGraceDaysPerMonth,
      homeRatePeriod: homeRatePeriod ?? this.homeRatePeriod,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupIntervalDays:
          autoBackupIntervalDays ?? this.autoBackupIntervalDays,
      autoBackupHour: autoBackupHour ?? this.autoBackupHour,
      autoBackupMinute: autoBackupMinute ?? this.autoBackupMinute,
      autoBackupKeepCount: autoBackupKeepCount ?? this.autoBackupKeepCount,
      lastAutoBackupMs: lastAutoBackupMs ?? this.lastAutoBackupMs,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      activeDayMode: activeDayMode ?? this.activeDayMode,
      customDayModes: customDayModes ?? this.customDayModes,
      dayModesList: dayModesList ?? this.dayModesList,
      allDayModeColorValue:
          allDayModeColorValue ?? this.allDayModeColorValue,
      allDayModeIconKey: allDayModeIconKey ?? this.allDayModeIconKey,
      dayModeByDate: dayModeByDate ?? this.dayModeByDate,
      weekdayDayModes: weekdayDayModes ?? this.weekdayDayModes,
      obsidianVaultUri: clearObsidianVaultUri
          ? null
          : (obsidianVaultUri ?? this.obsidianVaultUri),
      obsidianSyncEnabled: obsidianSyncEnabled ?? this.obsidianSyncEnabled,
      lastObsidianSyncMs: lastObsidianSyncMs ?? this.lastObsidianSyncMs,
      googleDriveUri:
          clearGoogleDriveUri ? null : (googleDriveUri ?? this.googleDriveUri),
      googleAccountEmail: clearGoogleAccount
          ? null
          : (googleAccountEmail ?? this.googleAccountEmail),
      googleAccountName: clearGoogleAccount
          ? null
          : (googleAccountName ?? this.googleAccountName),
      googleAutoSyncEnabled:
          googleAutoSyncEnabled ?? this.googleAutoSyncEnabled,
      googleCalendarSyncEnabled:
          googleCalendarSyncEnabled ?? this.googleCalendarSyncEnabled,
      lastGoogleSyncMs: lastGoogleSyncMs ?? this.lastGoogleSyncMs,
      isShowOnlyDueHabit: isShowOnlyDueHabit ?? this.isShowOnlyDueHabit,
      isShowAddNoteInHome: isShowAddNoteInHome ?? this.isShowAddNoteInHome,
      isConfettiEnabled: isConfettiEnabled ?? this.isConfettiEnabled,
      isAchievementSoundEnabled:
          isAchievementSoundEnabled ?? this.isAchievementSoundEnabled,
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      widgetHabitId:
          clearWidgetHabitId ? null : (widgetHabitId ?? this.widgetHabitId),
      widgetListHabitIds: widgetListHabitIds ?? this.widgetListHabitIds,
    );
  }

  Map<String, dynamic> toBackupMap() => {
        'localeCode': localeCode,
        'calendarSystem': calendarSystem.name,
        'weekStartDay': weekStartDay.name,
        'isDarkMode': isDarkMode,
        'homeLayout': homeLayout.name,
        'widgetTheme': widgetTheme.name,
        'soundProfile': soundProfile.name,
        'fontScaleMode': fontScaleMode.name,
        'widgetCelebrationOverlay': widgetCelebrationOverlay,
        'customStoragePath': customStoragePath,
        'dayResetMinutes': dayResetMinutes,
        'streakGraceDaysPerMonth': streakGraceDaysPerMonth,
        'homeRatePeriod': homeRatePeriod.name,
        'autoBackupEnabled': autoBackupEnabled,
        'autoBackupIntervalDays': autoBackupIntervalDays,
        'autoBackupHour': autoBackupHour,
        'autoBackupMinute': autoBackupMinute,
        'autoBackupKeepCount': autoBackupKeepCount,
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartMinutes': quietStartMinutes,
        'quietEndMinutes': quietEndMinutes,
        'activeDayMode': activeDayMode,
        'customDayModes': customDayModes,
        'dayModesList': [for (final d in dayModesList) d.toMap()],
        'allDayModeColorValue': allDayModeColorValue,
        'allDayModeIconKey': allDayModeIconKey,
        'dayModeByDate': dayModeByDate,
        'weekdayDayModes': {
          for (final e in weekdayDayModes.entries) '${e.key}': e.value,
        },
        'obsidianVaultUri': obsidianVaultUri,
        'obsidianSyncEnabled': obsidianSyncEnabled,
        'lastObsidianSyncMs': lastObsidianSyncMs,
        'googleDriveUri': googleDriveUri,
        'googleAccountEmail': googleAccountEmail,
        'googleAccountName': googleAccountName,
        'googleAutoSyncEnabled': googleAutoSyncEnabled,
        'googleCalendarSyncEnabled': googleCalendarSyncEnabled,
        'lastGoogleSyncMs': lastGoogleSyncMs,
        'isShowOnlyDueHabit': isShowOnlyDueHabit,
        'isShowAddNoteInHome': isShowAddNoteInHome,
        'isConfettiEnabled': isConfettiEnabled,
        'isAchievementSoundEnabled': isAchievementSoundEnabled,
        'widgetHabitId': widgetHabitId,
        'widgetListHabitIds': widgetListHabitIds,
      };
}
