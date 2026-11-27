import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xhabit/core/calendar/app_calendar.dart';
import 'package:xhabit/core/icons/habit_icons.dart';
import 'package:xhabit/core/services/app_update_service.dart';
import 'package:xhabit/core/services/widget_sync_service.dart';
import 'package:xhabit/core/sync/cloud_drive_sync_service.dart';
import 'package:xhabit/data/models/habit_models.dart';
import 'package:xhabit/domain/habit_engine.dart';
import 'package:xhabit/domain/smart_reminder_engine.dart';

void main() {
  group('AppCalendar', () {
    test('converts Gregorian and Jalali day/month accurately', () {
      final nowruz2026 = DateTime(2026, 3, 21);
      expect(
        AppCalendar.yearInCalendar(nowruz2026, CalendarSystem.jalali),
        1405,
      );
      expect(
        AppCalendar.monthInCalendar(nowruz2026, CalendarSystem.jalali),
        1,
      );
      expect(
        AppCalendar.dayNumberInCalendar(nowruz2026, CalendarSystem.jalali),
        1,
      );
    });

    test('produces 7-column month grid for Jalali Saturday start', () {
      final cells = AppCalendar.monthGridDates(
        DateTime(2026, 3, 25),
        CalendarSystem.jalali,
        WeekStartDay.saturday,
      );
      expect(cells.length % 7, 0);
      expect(cells.whereType<DateTime>().length, 31);
    });
  });

  group('HabitEngine', () {
    test('computes build habit streak, score, and opt-in medal tier', () {
      const habit = Habit(
        id: 'h1',
        title: 'Read',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF00C48C,
        iconKey: 'menu_book',
        startDateKey: '2026-11-20',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );

      final comps = {
        '2026-11-20': const HabitCompletion(
          id: 'c1',
          habitId: 'h1',
          dateKey: '2026-11-20',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        '2026-11-21': const HabitCompletion(
          id: 'c2',
          habitId: 'h1',
          dateKey: '2026-11-21',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        '2026-11-22': const HabitCompletion(
          id: 'c3',
          habitId: 'h1',
          dateKey: '2026-11-22',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };

      final stats = HabitEngine.computeStats(
        habit,
        comps,
        const [],
        today: DateTime(2026, 11, 22),
      );
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 3);
      expect(stats.totalCompletions, 3);
      expect(stats.completionRate, 1.0);
      expect(stats.habitScore, 100);
      expect(HabitEngine.highestTierFor(stats.bestStreak)?.days, 1);
      expect(HabitEngine.achievementTiers.last.days, 365);
    });

    test('requires explicit tap on quit habits instead of auto-checking', () {
      const quitHabit = Habit(
        id: 'q1',
        title: 'No Sugar',
        description: '',
        mode: HabitMode.quit,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFFB06CFF,
        iconKey: 'no_drinks',
        startDateKey: '2026-11-18',
        sortOrder: 1,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );

      final comps = {
        '2026-11-18': const HabitCompletion(
          id: 'q0',
          habitId: 'q1',
          dateKey: '2026-11-18',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        '2026-11-19': const HabitCompletion(
          id: 's1',
          habitId: 'q1',
          dateKey: '2026-11-19',
          value: 0,
          completedChecklistIds: [],
          slipped: true,
          updatedAtMs: 0,
        ),
        '2026-11-20': const HabitCompletion(
          id: 'q2',
          habitId: 'q1',
          dateKey: '2026-11-20',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        '2026-11-21': const HabitCompletion(
          id: 'q3',
          habitId: 'q1',
          dateKey: '2026-11-21',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };

      expect(
        HabitEngine.isCompletedOn(
          quitHabit,
          null,
          const [],
          DateTime(2026, 11, 22),
          today: DateTime(2026, 11, 22),
        ),
        isFalse,
      );

      final stats = HabitEngine.computeStats(
        quitHabit,
        comps,
        const [],
        today: DateTime(2026, 11, 22),
      );
      expect(stats.slipCount, 1);
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 2);
    });

    test('evaluates calendar-week period schedule properly', () {
      const periodHabit = Habit(
        id: 'p1',
        title: 'Gym',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.period,
        weekdaysMask: 127,
        targetPerWeek: 2,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF4C8EFF,
        iconKey: 'fitness_center',
        startDateKey: '2026-11-21',
        sortOrder: 2,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );
      final comps = {
        '2026-11-21': const HabitCompletion(
          id: 'k1',
          habitId: 'p1',
          dateKey: '2026-11-21',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        '2026-11-22': const HabitCompletion(
          id: 'k2',
          habitId: 'p1',
          dateKey: '2026-11-22',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };
      // Mon Nov 23 is in the same Saturday-start week and 2/2 already hit -> off schedule
      expect(
        HabitEngine.isScheduledOn(
          periodHabit,
          DateTime(2026, 11, 23),
          weekStart: WeekStartDay.saturday,
          completionsByDate: comps,
          today: DateTime(2026, 11, 23),
        ),
        isFalse,
      );
    });

    test('logicalToday shifts early-morning hours using dayResetMinutes', () {
      // 03:30 reset: 02:15 belongs to previous logical day, 04:00 is current day
      expect(
        AppCalendar.logicalToday(DateTime(2026, 11, 27, 2, 15), 210),
        DateTime(2026, 11, 26),
      );
      expect(
        AppCalendar.logicalToday(DateTime(2026, 11, 27, 4, 0), 210),
        DateTime(2026, 11, 27),
      );
      expect(
        AppCalendar.logicalToday(DateTime(2026, 11, 27, 0, 5), 0),
        DateTime(2026, 11, 27),
      );
    });

    test('protects streaks during HabitPause and monthlyGraceDays', () {
      const dailyHabit = Habit(
        id: 'd1',
        title: 'Read',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'book',
        startDateKey: '2026-11-20',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );
      final comps = {
        '2026-11-20': const HabitCompletion(
          id: 'c1',
          habitId: 'd1',
          dateKey: '2026-11-20',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
        // 2026-11-21 paused, 2026-11-22 missed (covered by 1 grace day), 2026-11-23 done
        '2026-11-23': const HabitCompletion(
          id: 'c2',
          habitId: 'd1',
          dateKey: '2026-11-23',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };
      final pauses = [
        const HabitPause(
          id: 'p_pause',
          habitId: 'd1',
          startDateKey: '2026-11-21',
          endDateKey: '2026-11-21',
          updatedAtMs: 0,
        ),
      ];

      // Without grace day, 2026-11-22 breaks streak -> currentStreak == 1
      final noGrace = HabitEngine.computeStats(
        dailyHabit,
        comps,
        const [],
        calendar: CalendarSystem.gregorian,
        today: DateTime(2026, 11, 23),
        pauses: pauses,
        monthlyGraceDays: 0,
      );
      expect(noGrace.currentStreak, 1);

      // With 1 grace day/mo + pause on Nov 21, streak bridges to 2
      final withGrace = HabitEngine.computeStats(
        dailyHabit,
        comps,
        const [],
        calendar: CalendarSystem.gregorian,
        today: DateTime(2026, 11, 23),
        pauses: pauses,
        monthlyGraceDays: 1,
      );
      expect(withGrace.currentStreak, 2);
      expect(withGrace.bestStreak, 2);
    });

    test('weights partial count progress in score and successRateForWindow', () {
      const countHabit = Habit(
        id: 'w1',
        title: 'Water',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.count,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 4,
        countUnit: 'glasses',
        colorValue: 0xFF3898FF,
        iconKey: 'water_drop',
        startDateKey: '2026-11-23',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );
      final comps = {
        '2026-11-23': const HabitCompletion(
          id: 'cw1',
          habitId: 'w1',
          dateKey: '2026-11-23',
          value: 2,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };
      final stats = HabitEngine.computeStats(
        countHabit,
        comps,
        const [],
        today: DateTime(2026, 11, 23),
      );
      expect(stats.habitScore, 50);

      final wkRate = HabitEngine.successRateForWindow(
        habits: const [countHabit],
        completionsFor: (_) => comps,
        checklistFor: (_) => const [],
        pauses: const [],
        days: 7,
        calendar: CalendarSystem.gregorian,
        weekStart: WeekStartDay.saturday,
        today: DateTime(2026, 11, 23),
      );
      expect(wkRate, closeTo(50.0, 0.1));
    });

    test('computes repeat nudges respecting response window and quiet hours',
        () {
      // Base at 22:00 (1320), repeat 30m, window 120m, quiet hours 23:00 (1380) -> 07:00 (420)
      final nudges = SmartReminderEngine.computeFollowUpMinutes(
        baseMinuteOfDay: 22 * 60,
        repeatIntervalMins: 30,
        maxRepeats: 4,
        responseWindowMins: 120,
        quietEnabled: true,
        quietStartMin: 23 * 60,
        quietEndMin: 7 * 60,
      );
      // Only 22:30 (1350) is outside quiet hours; 23:00+ are skipped
      expect(nudges, [22 * 60 + 30]);
    });

    test('learns densest active window outside quiet hours', () {
      final learned = SmartReminderEngine.learnBestReminderTime(
        recordedMinutesOfDay: [
          1 * 60, // during quiet hours -> ignored
          18 * 60 + 40,
          18 * 60 + 50,
          18 * 60 + 55,
          19 * 60,
          9 * 60,
        ],
        quietEnabled: true,
        quietStartMin: 23 * 60,
        quietEndMin: 7 * 60,
      );
      expect(learned, isNotNull);
      expect(learned!.suggestedHour, 18);
      expect(learned.sampleCount, 5);
      expect(learned.confidence, greaterThan(0.7));
    });

    test('matchesDayMode isolates untagged habits to Normal and handles All/Work/Travel presets',
        () {
      const untaggedHabit = Habit(
        id: 'm0',
        title: 'Default Routine',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'check',
        startDateKey: '2026-11-23',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        dayModes: [],
        updatedAtMs: 0,
      );
      const allModesHabit = Habit(
        id: 'm_all',
        title: 'Drink Water',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF3898FF,
        iconKey: 'water_drop',
        startDateKey: '2026-11-23',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        dayModes: ['all'],
        updatedAtMs: 0,
      );
      const workHabit = Habit(
        id: 'm1',
        title: 'Standup',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'work',
        startDateKey: '2026-11-23',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        dayModes: ['work'],
        updatedAtMs: 0,
      );
      expect(HabitEngine.matchesDayMode(untaggedHabit, 'normal'), isTrue);
      expect(HabitEngine.matchesDayMode(untaggedHabit, 'all'), isTrue);
      expect(HabitEngine.matchesDayMode(untaggedHabit, 'work'), isFalse);
      expect(HabitEngine.matchesDayMode(allModesHabit, 'normal'), isTrue);
      expect(HabitEngine.matchesDayMode(allModesHabit, 'work'), isTrue);
      expect(HabitEngine.matchesDayMode(allModesHabit, 'travel'), isTrue);
      expect(HabitEngine.matchesDayMode(workHabit, 'work'), isTrue);
      expect(HabitEngine.matchesDayMode(workHabit, 'all'), isTrue);
      expect(HabitEngine.matchesDayMode(workHabit, 'normal'), isFalse);
      expect(HabitEngine.matchesDayMode(workHabit, 'travel'), isFalse);

      // Calendar date & weekday mode resolution priority:
      // explicit 'all' > date override > weekday rule > fallback activeDayMode.
      final dec5 = DateTime(2026, 12, 5); // Saturday (weekday == 6)
      const calSettings = AppSettings(
        activeDayMode: 'normal',
        dayModeByDate: {'2026-12-05': 'travel'},
        weekdayDayModes: {DateTime.saturday: 'off'},
      );
      expect(HabitEngine.resolveDayMode(calSettings, dec5), 'travel');
      expect(
        HabitEngine.resolveDayMode(
          calSettings,
          DateTime(2026, 12, 12), // another Saturday without date override
        ),
        'off',
      );
      expect(
        HabitEngine.resolveDayMode(
          calSettings.copyWith(activeDayMode: 'all'),
          dec5,
        ),
        'all',
      );
      // Deleted presets fall back cleanly to 'all'.
      expect(
        HabitEngine.resolveDayMode(
          const AppSettings(activeDayMode: 'work', dayModesList: []),
          dec5,
        ),
        'all',
      );
    });

    test('builds valid RFC-5545 Google Calendar .ics export payload', () {
      const h = Habit(
        id: 'cal1',
        title: 'Meditation',
        description: 'Breathwork',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.weekdays,
        weekdaysMask: 5, // Mon + Wed
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'self_improvement',
        startDateKey: '2026-11-23',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: true,
        reminderHour: 7,
        reminderMinute: 30,
        updatedAtMs: 0,
      );
      final ics = GoogleCalendarSyncService.buildIcsSchedule(
        const [h],
        anchorDate: DateTime(2026, 11, 26),
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:Meditation'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=MO,WE'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('computes UTC calendarDaysBetween cleanly without DST drift', () {
      expect(
        AppCalendar.calendarDaysBetween(
          DateTime(2026, 3, 21),
          DateTime(2026, 3, 28),
        ),
        7,
      );
      expect(
        AppCalendar.calendarDaysBetween(
          DateTime(2026, 10, 30),
          DateTime(2026, 11, 2),
        ),
        3,
      );
      expect(AppCalendar.parseDateKey('invalid-key'), DateTime(2000, 1, 1));
    });

    test('identifies calendar/weekday day mode rules with hasCalendarModeRule',
        () {
      const s = AppSettings(
        dayModeByDate: {'2026-12-01': 'travel'},
        weekdayDayModes: {DateTime.friday: 'off'},
      );
      expect(
        HabitEngine.hasCalendarModeRule(s, DateTime(2026, 12, 1)),
        isTrue,
      );
      expect(
        HabitEngine.hasCalendarModeRule(s, DateTime(2026, 12, 4)), // Friday
        isTrue,
      );
      expect(
        HabitEngine.hasCalendarModeRule(s, DateTime(2026, 12, 2)),
        isFalse,
      );
    });

    test('evaluates FrequencyType.period weekly streaks and successRateForWindow',
        () {
      // Saturday 2026-11-21 to Wednesday 2026-11-25 (5 days into a Saturday-start week)
      const periodHabit = Habit(
        id: 'per1',
        title: 'Gym',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.period,
        weekdaysMask: 127,
        targetPerWeek: 3,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'fitness_center',
        startDateKey: '2026-11-14', // Saturday week 1
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );

      final comps = <String, HabitCompletion>{
        // Week 1 (2026-11-14..2026-11-20): 3 completions => goal met!
        for (final k in const ['2026-11-14', '2026-11-16', '2026-11-18'])
          k: HabitCompletion(
            id: 'c_$k',
            habitId: 'per1',
            dateKey: k,
            value: 1,
            completedChecklistIds: const [],
            slipped: false,
            updatedAtMs: 0,
          ),
        // Week 2 (2026-11-21..): 1 completion so far by Wed 2026-11-25
        '2026-11-21': const HabitCompletion(
          id: 'c_w2',
          habitId: 'per1',
          dateKey: '2026-11-21',
          value: 1,
          completedChecklistIds: [],
          slipped: false,
          updatedAtMs: 0,
        ),
      };

      final stats = HabitEngine.computeStats(
        periodHabit,
        comps,
        const [],
        weekStart: WeekStartDay.saturday,
        today: DateTime(2026, 11, 25),
      );
      // Streak must preserve prior completions without resetting mid-week
      expect(stats.currentStreak, 4);
      expect(stats.bestStreak, 4);
      expect(stats.totalCompletions, 4);

      // 14-day window: Week 1 has 3/3 (100%) and partial Week 2 has 1/1 completed so far => 100%,
      // never diluted by unscheduled gap days.
      final rate = HabitEngine.successRateForWindow(
        habits: const [periodHabit],
        completionsFor: (_) => comps,
        checklistFor: (_) => const [],
        pauses: const [],
        days: 14,
        calendar: CalendarSystem.jalali,
        weekStart: WeekStartDay.saturday,
        today: DateTime(2026, 11, 25),
      );
      expect(rate, 100.0);
    });

    test('schedules FrequencyType.monthDays across Jalali day 29..31 boundaries',
        () {
      const monthHabit = Habit(
        id: 'm31',
        title: 'Monthly Review',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.boolean,
        frequencyType: FrequencyType.monthDays,
        weekdaysMask: 127,
        monthDays: [31],
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'event',
        startDateKey: '2026-01-01',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );

      // 2026-04-20 is 1405-01-31 (Farvardin 31)
      expect(
        HabitEngine.isScheduledOn(
          monthHabit,
          DateTime(2026, 4, 20),
          calendar: CalendarSystem.jalali,
        ),
        isTrue,
      );
      // 2026-04-19 is 1405-01-30 (Farvardin 30)
      expect(
        HabitEngine.isScheduledOn(
          monthHabit,
          DateTime(2026, 4, 19),
          calendar: CalendarSystem.jalali,
        ),
        isFalse,
      );
    });

    test('evaluates TrackingStyle.checklist progress and empty checklist fallback',
        () {
      const checklistHabit = Habit(
        id: 'chk1',
        title: 'Morning Prep',
        description: '',
        mode: HabitMode.build,
        trackingStyle: TrackingStyle.checklist,
        frequencyType: FrequencyType.daily,
        weekdaysMask: 127,
        intervalDays: 1,
        targetCount: 1,
        countUnit: '',
        colorValue: 0xFF8CFF26,
        iconKey: 'checklist',
        startDateKey: '2026-11-01',
        sortOrder: 0,
        isArchived: false,
        reminderEnabled: false,
        updatedAtMs: 0,
      );
      final items = [
        const HabitChecklistItem(
          id: 's1',
          habitId: 'chk1',
          title: 'Step 1',
          sortOrder: 0,
          updatedAtMs: 0,
        ),
        const HabitChecklistItem(
          id: 's2',
          habitId: 'chk1',
          title: 'Step 2',
          sortOrder: 1,
          updatedAtMs: 0,
        ),
      ];
      final d = DateTime(2026, 11, 26);

      const partial = HabitCompletion(
        id: 'p1',
        habitId: 'chk1',
        dateKey: '2026-11-26',
        value: 0,
        completedChecklistIds: ['s1'],
        slipped: false,
        updatedAtMs: 0,
      );
      expect(HabitEngine.progressRatio(checklistHabit, partial, items, d), 0.5);
      expect(HabitEngine.isCompletedOn(checklistHabit, partial, items, d), isFalse);

      const full = HabitCompletion(
        id: 'p2',
        habitId: 'chk1',
        dateKey: '2026-11-26',
        value: 1,
        completedChecklistIds: ['s1', 's2'],
        slipped: false,
        updatedAtMs: 0,
      );
      expect(HabitEngine.progressRatio(checklistHabit, full, items, d), 1.0);
      expect(HabitEngine.isCompletedOn(checklistHabit, full, items, d), isTrue);

      // Empty checklist items still honors boolean completion (`value >= 1`)
      expect(
        HabitEngine.isCompletedOn(checklistHabit, full, const [], d),
        isTrue,
      );
    });

    test('validates SmartReminderEngine.isInQuietHours wrap-around and boundaries',
        () {
      // Disabled returns false
      expect(
        SmartReminderEngine.isInQuietHours(
          60,
          enabled: false,
          startMin: 23 * 60,
          endMin: 7 * 60,
        ),
        isFalse,
      );
      // Equal start/end means zero-length window
      expect(
        SmartReminderEngine.isInQuietHours(
          23 * 60,
          enabled: true,
          startMin: 23 * 60,
          endMin: 23 * 60,
        ),
        isFalse,
      );
      // Overnight 23:00 -> 07:00
      expect(
        SmartReminderEngine.isInQuietHours(
          23 * 60 + 30,
          enabled: true,
          startMin: 23 * 60,
          endMin: 7 * 60,
        ),
        isTrue,
      );
      expect(
        SmartReminderEngine.isInQuietHours(
          2 * 60,
          enabled: true,
          startMin: 23 * 60,
          endMin: 7 * 60,
        ),
        isTrue,
      );
      expect(
        SmartReminderEngine.isInQuietHours(
          7 * 60,
          enabled: true,
          startMin: 23 * 60,
          endMin: 7 * 60,
        ),
        isFalse,
      );
      // Daytime 13:00 -> 15:00
      expect(
        SmartReminderEngine.isInQuietHours(
          14 * 60,
          enabled: true,
          startMin: 13 * 60,
          endMin: 15 * 60,
        ),
        isTrue,
      );
    });

    test('bounds GoogleCalendarSyncService.deterministicEventId to [0-9a-v] 16..512',
        () {
      final shortId = GoogleCalendarSyncService.deterministicEventId('a');
      final longId =
          GoogleCalendarSyncService.deterministicEventId('x' * 400);
      final validRe = RegExp(r'^[0-9a-v]+$');
      expect(validRe.hasMatch(shortId), isTrue);
      expect(shortId.length, inInclusiveRange(16, 512));
      expect(validRe.hasMatch(longId), isTrue);
      expect(longId.length, inInclusiveRange(16, 512));
    });

    test('checks AppUpdateService.compareSemver and HabitPalette contrast/icons', () {
      expect(AppUpdateService.compareSemver('1.0.1', '1.0.0'), greaterThan(0));
      expect(AppUpdateService.compareSemver('v1.0.0+5', '1.0.0'), 0);
      expect(AppUpdateService.compareSemver('1.0.0', '1.2.0'), lessThan(0));

      expect(HabitPalette.contrastFg(const Color(0xFFFFFFFF)), Colors.black);
      expect(HabitPalette.contrastFg(const Color(0xFF000000)), Colors.white);
      expect(HabitPalette.contrastFg(const Color(0xFF4D7C0F)), Colors.white);

      final groupedKeys =
          HabitPalette.categories.expand((g) => g.keys).toSet();
      expect(groupedKeys.contains('emoji_food_beverage'), isTrue);
      expect(groupedKeys.contains('lightbulb'), isTrue);
    });

    test('parses PlacedWidgetInfo instances cleanly with safe defaults', () {
      final ad = PlacedWidgetInfo.fromMap({
        'widgetId': 42,
        'kind': 'adaptive',
        'habitId': 'h_run',
        'themeMode': 'dark',
        'widthDp': 250,
        'heightDp': 170,
      });
      expect(ad.widgetId, 42);
      expect(ad.isAdaptive, isTrue);
      expect(ad.isDailyList, isFalse);
      expect(ad.habitId, 'h_run');
      expect(ad.themeMode, 'dark');
      expect(ad.widthDp, 250);

      final dl = PlacedWidgetInfo.fromMap({
        'widgetId': 55,
        'kind': 'daily_list',
        'listMode': 'custom',
        'habitIds': ['h1', 'h2', ''],
        'customTitle': 'Morning',
      });
      expect(dl.isDailyList, isTrue);
      expect(dl.listMode, 'custom');
      expect(dl.habitIds, ['h1', 'h2']);
      expect(dl.customTitle, 'Morning');
      expect(dl.themeMode, 'follow');

      final td = PlacedWidgetInfo.fromMap({
        'widgetId': 61,
        'kind': 'todo_list',
        'hideCompleted': true,
        'customTitle': 'Errands',
      });
      expect(td.isToDoList, isTrue);
      expect(td.hideCompleted, isTrue);
      expect(td.customTitle, 'Errands');

      final dm = PlacedWidgetInfo.fromMap({
        'widgetId': 77,
        'kind': 'day_mode',
        'includeAll': false,
        'widthDp': 240,
        'heightDp': 78,
      });
      expect(dm.isDayMode, isTrue);
      expect(dm.includeAll, isFalse);
    });

    test('AppSettings.widgetOpacity clamps to 0.0..1.0 and serializes', () {
      const base = AppSettings();
      expect(base.widgetOpacity, 1.0);
      final clampedLow = base.copyWith(widgetOpacity: -0.5);
      expect(clampedLow.widgetOpacity, 0.0);
      final clampedHigh = base.copyWith(widgetOpacity: 1.8);
      expect(clampedHigh.widgetOpacity, 1.0);
      final mid = base.copyWith(widgetOpacity: 0.65);
      expect(mid.toBackupMap()['widgetOpacity'], 0.65);
    });
  });
}
