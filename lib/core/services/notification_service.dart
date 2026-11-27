import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';
import '../calendar/app_calendar.dart';
import '../../domain/habit_engine.dart';
import '../../domain/smart_reminder_engine.dart';
import 'widget_sync_service.dart';

@pragma('vm:entry-point')
Future<void> xhabitNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  final habitId = response.payload;
  if (habitId == null || habitId.isEmpty) return;

  if (response.actionId == 'mark_done') {
    final db = AppDatabase.instance;
    final habits = await db.getHabits(includeArchived: false);
    final habit = habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return;

    final settings = await readWidgetSettingsSnapshot();
    final now = DateTime.now();
    final today = AppCalendar.logicalToday(now, settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final allComps = await db.getAllCompletions();
    final pauses = await db.getAllPauses();
    final checklistAll = await db.getAllChecklistItems();
    final habitItems =
        checklistAll.where((i) => i.habitId == habitId).toList();
    final existing = allComps
        .where((c) => c.habitId == habitId && c.dateKey == todayKey)
        .firstOrNull;
    final nowMs = now.millisecondsSinceEpoch;

    final nextComp = HabitCompletion(
      id: existing?.id ?? const Uuid().v4(),
      habitId: habitId,
      dateKey: todayKey,
      value: habit.trackingStyle == TrackingStyle.count
          ? (habit.targetCount < 1 ? 1 : habit.targetCount)
          : 1,
      completedChecklistIds: habit.trackingStyle == TrackingStyle.checklist
          ? habitItems.map((e) => e.id).toList()
          : (existing?.completedChecklistIds ?? const []),
      slipped: false,
      updatedAtMs: nowMs,
    );
    await db.upsertCompletion(nextComp);
    await db.recordCompletionEvent(habitId, now);
    await NotificationService.instance.syncHabitReminder(
      habit,
      isFa: settings.localeCode == 'fa',
      settings: settings,
      isDoneToday: true,
    );
    final refreshed = await db.getAllCompletions();
    await WidgetSyncService.instance.syncAll(
      habits: habits,
      checklistItems: checklistAll,
      completions: refreshed,
      pauses: pauses,
      settings: settings,
    );
    NotificationService.onActionCompleted?.call();
  } else if (response.actionId == 'snooze_30') {
    final settings = await readWidgetSettingsSnapshot();
    await NotificationService.instance.scheduleSnooze(
      habitId: habitId,
      duration: const Duration(minutes: 30),
      isFa: settings.localeCode == 'fa',
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static void Function()? onActionCompleted;
  static const MethodChannel _tzChannel =
      MethodChannel('app.xhabit.tracker/storage');
  bool _platformTzResolved = false;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _configureLocalTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        await xhabitNotificationBackgroundHandler(resp);
      },
      onDidReceiveBackgroundNotificationResponse:
          xhabitNotificationBackgroundHandler,
    );
    _initialized = true;
  }

  void _configureLocalTimezone() {
    // Immediate synchronous offset fallback so scheduling never blocks; upgraded
    // asynchronously with the real IANA timezone ID via [_ensurePlatformTimezone].
    final targetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    if (targetMs == 12600000) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      } catch (_) {}
    } else {
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        if (entry.value.currentTimeZone.offset == targetMs) {
          tz.setLocalLocation(entry.value);
          break;
        }
      }
    }
    _ensurePlatformTimezone();
  }

  Future<void> _ensurePlatformTimezone() async {
    if (_platformTzResolved || !Platform.isAndroid) return;
    try {
      final tzId = await _tzChannel.invokeMethod<String>('getLocalTimezone');
      if (tzId != null && tzId.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzId));
        _platformTzResolved = true;
      }
    } catch (_) {
      // Background isolate or fallback keeps offset-based tz.local.
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifOk = await androidImpl?.requestNotificationsPermission() ?? true;
    await androidImpl?.requestExactAlarmsPermission();
    return notifOk;
  }

  Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return false;
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidImpl?.canScheduleExactNotifications() ?? false;
  }

  int _habitNotificationId(String habitId) => habitId.hashCode & 0x7fffffff;

  NotificationDetails _details({bool isFa = true}) {
    final markLabel = isFa ? 'انجام شد ✓' : 'Mark Done ✓';
    final snoozeLabel = isFa ? '۳۰ دقیقه بعد' : 'Snooze 30m';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'xhabit_reminders',
        'Habit Reminders',
        channelDescription: 'Daily reminders for scheduled habits',
        importance: Importance.max,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            'mark_done',
            markLabel,
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze_30',
            snoozeLabel,
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  Future<void> syncAllHabitReminders(
    List<Habit> habits, {
    bool isFa = true,
    AppSettings? settings,
    List<HabitCompletion> completions = const [],
    List<HabitChecklistItem> checklistItems = const [],
    List<CompletionEvent> completionEvents = const [],
    List<HabitPause> pauses = const [],
  }) async {
    await init();
    await _ensurePlatformTimezone();
    final s = settings ?? AppSettings(localeCode: isFa ? 'fa' : 'en');
    final today = AppCalendar.logicalToday(DateTime.now(), s.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final allMinutes = completionEvents.map((e) => e.minuteOfDay).toList();

    final todayMode = HabitEngine.resolveDayMode(s, today);
    for (final h in habits) {
      final items = checklistItems.where((i) => i.habitId == h.id).toList();
      final comp = completions
          .where((c) => c.habitId == h.id && c.dateKey == todayKey)
          .firstOrNull;
      final doneToday = HabitEngine.isCompletedOn(
        h,
        comp,
        items,
        today,
        today: today,
      );
      final pausedToday = HabitEngine.isPausedOn(h.id, today, pauses);
      final modeMatch = HabitEngine.matchesDayMode(h, todayMode);

      int? smartHour;
      int? smartMinute;
      if (h.smartLearningEnabled) {
        final habitMins = completionEvents
            .where((e) => e.habitId == h.id)
            .map((e) => e.minuteOfDay)
            .toList();
        final learned = SmartReminderEngine.learnBestReminderTime(
          recordedMinutesOfDay: habitMins.length >= 3 ? habitMins : allMinutes,
          quietEnabled: s.quietHoursEnabled,
          quietStartMin: s.quietStartMinutes,
          quietEndMin: s.quietEndMinutes,
        );
        if (learned != null) {
          smartHour = learned.suggestedHour;
          smartMinute = learned.suggestedMinute;
        }
      }

      await syncHabitReminder(
        h,
        isFa: s.localeCode == 'fa',
        settings: s,
        isDoneToday: doneToday || pausedToday || !modeMatch,
        overrideHour: smartHour,
        overrideMinute: smartMinute,
      );
    }
  }

  Future<void> cancelRepeatNudgesForHabit(String habitId) async {
    await init();
    final base = _habitNotificationId(habitId);
    for (var k = 1; k <= 8; k++) {
      await _plugin.cancel(id: (base ^ (0x400 + k)) & 0x7fffffff);
    }
    await _plugin.cancel(id: (base ^ 0x1357) & 0x7fffffff);
  }

  Future<void> syncHabitReminder(
    Habit habit, {
    bool isFa = true,
    AppSettings? settings,
    bool isDoneToday = false,
    int? overrideHour,
    int? overrideMinute,
  }) async {
    await init();
    await _ensurePlatformTimezone();
    final id = _habitNotificationId(habit.id);
    await _plugin.cancel(id: id);
    await cancelRepeatNudgesForHabit(habit.id);

    if (!habit.reminderEnabled ||
        habit.isArchived ||
        ((overrideHour ?? habit.reminderHour) == null) ||
        ((overrideMinute ?? habit.reminderMinute) == null)) {
      return;
    }

    final effHour = overrideHour ?? habit.reminderHour!;
    final effMinute = overrideMinute ?? habit.reminderMinute!;
    final baseMinOfDay = effHour * 60 + effMinute;
    final quietOn = settings?.quietHoursEnabled ?? false;
    final quietStart = settings?.quietStartMinutes ?? (23 * 60);
    final quietEnd = settings?.quietEndMinutes ?? (7 * 60);
    final exact = await _canScheduleExact();

    // Base daily notification (pushed to tomorrow if already done/paused/excluded today)
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      effHour,
      effMinute,
    );
    if (scheduled.isBefore(now) ||
        (isDoneToday &&
            scheduled.year == now.year &&
            scheduled.month == now.month &&
            scheduled.day == now.day)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (!SmartReminderEngine.isInQuietHours(
      baseMinOfDay,
      enabled: quietOn,
      startMin: quietStart,
      endMin: quietEnd,
    )) {
      await _plugin.zonedSchedule(
        id: id,
        title: habit.title,
        body: habit.description.isEmpty
            ? (isFa ? 'وقت انجام عادتت رسیده' : 'Time for your habit')
            : habit.description,
        scheduledDate: scheduled,
        notificationDetails: _details(isFa: isFa),
        payload: habit.id,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Repeating follow-up reminders anchored to [scheduled]'s date within response window.
    if (!isDoneToday && habit.reminderRepeatMins > 0) {
      final followUps = SmartReminderEngine.computeFollowUpMinutes(
        baseMinuteOfDay: baseMinOfDay,
        repeatIntervalMins: habit.reminderRepeatMins,
        maxRepeats: habit.reminderMaxRepeats.clamp(1, 8),
        responseWindowMins: habit.responseWindowMins,
        quietEnabled: quietOn,
        quietStartMin: quietStart,
        quietEndMin: quietEnd,
      );
      for (var i = 0; i < followUps.length; i++) {
        final m = followUps[i];
        var nudgeAt = tz.TZDateTime(
          tz.local,
          scheduled.year,
          scheduled.month,
          scheduled.day,
          m ~/ 60,
          m % 60,
        );
        if (m < baseMinOfDay) {
          nudgeAt = nudgeAt.add(const Duration(days: 1));
        }
        if (!nudgeAt.isAfter(now)) continue;
        final nudgeId = (id ^ (0x400 + i + 1)) & 0x7fffffff;
        await _plugin.zonedSchedule(
          id: nudgeId,
          title: habit.title,
          body: isFa
              ? 'یادآوری مجدد — هنوز تیک نخورده'
              : 'Follow-up reminder — still pending',
          scheduledDate: nudgeAt,
          notificationDetails: _details(isFa: isFa),
          payload: habit.id,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> scheduleSnooze({
    required String habitId,
    required Duration duration,
    bool isFa = true,
  }) async {
    await init();
    await _ensurePlatformTimezone();
    final habits = await AppDatabase.instance.getHabits(includeArchived: false);
    final habit = habits.where((h) => h.id == habitId).firstOrNull;
    if (habit == null) return;
    final id = (_habitNotificationId(habitId) ^ 0x1357) & 0x7fffffff;
    final target = tz.TZDateTime.now(tz.local).add(duration);
    final exact = await _canScheduleExact();
    await _plugin.zonedSchedule(
      id: id,
      title: habit.title,
      body: isFa ? 'یادآوری مجدد عادت' : 'Snoozed habit reminder',
      scheduledDate: target,
      notificationDetails: _details(isFa: isFa),
      payload: habit.id,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<bool> showTestNotification({bool isFa = true}) async {
    final granted = await requestPermissions();
    if (!granted) return false;
    await _plugin.show(
      id: 99001,
      title: isFa ? 'تست اعلان XHabit' : 'XHabit Test Reminder',
      body: isFa
          ? 'اعلان‌ها به‌درستی فعال هستند ✓'
          : 'Notifications are configured and working ✓',
      notificationDetails: _details(isFa: isFa),
    );
    return true;
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await init();
    final base = _habitNotificationId(habitId);
    await _plugin.cancel(id: base);
    for (var k = 1; k <= 8; k++) {
      await _plugin.cancel(id: (base ^ (0x400 + k)) & 0x7fffffff);
    }
    await _plugin.cancel(id: (base ^ 0x1357) & 0x7fffffff);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
