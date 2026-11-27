import 'package:flutter/material.dart';
import '../core/calendar/app_calendar.dart';
import '../data/models/habit_models.dart';

class AchievementTier {
  const AchievementTier({
    required this.days,
    required this.nameFa,
    required this.nameEn,
    required this.badgeColor,
    required this.rimColor,
  });

  final int days;
  final String nameFa;
  final String nameEn;
  final Color badgeColor;
  final Color rimColor;
}

class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.slipCount,
    required this.completionRate,
    required this.habitScore,
  });

  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final int slipCount;
  final double completionRate;

  /// Weighted 90-day consistency percentage (0..100).
  final int habitScore;
}

class HabitEngine {
  HabitEngine._();

  static const List<AchievementTier> achievementTiers = [
    AchievementTier(
      days: 1,
      nameFa: 'برنزی',
      nameEn: 'Bronze',
      badgeColor: Color(0xFFCD7F32),
      rimColor: Color(0xFFFDBA74),
    ),
    AchievementTier(
      days: 7,
      nameFa: 'نقره‌ای',
      nameEn: 'Silver',
      badgeColor: Color(0xFFCBD5E1),
      rimColor: Color(0xFFF8FAFC),
    ),
    AchievementTier(
      days: 14,
      nameFa: 'زمردین',
      nameEn: 'Emerald',
      badgeColor: Color(0xFF10B981),
      rimColor: Color(0xFFA7F3D0),
    ),
    AchievementTier(
      days: 30,
      nameFa: 'یاقوت کبود',
      nameEn: 'Sapphire',
      badgeColor: Color(0xFF0EA5E9),
      rimColor: Color(0xFFBAE6FD),
    ),
    AchievementTier(
      days: 50,
      nameFa: 'آمیتیست',
      nameEn: 'Amethyst',
      badgeColor: Color(0xFFA855F7),
      rimColor: Color(0xFFE9D5FF),
    ),
    AchievementTier(
      days: 100,
      nameFa: 'طلایی',
      nameEn: 'Gold',
      badgeColor: Color(0xFFF59E0B),
      rimColor: Color(0xFFFEF08A),
    ),
    AchievementTier(
      days: 200,
      nameFa: 'یاقوت سرخ',
      nameEn: 'Ruby',
      badgeColor: Color(0xFFF43F5E),
      rimColor: Color(0xFFFECDD3),
    ),
    AchievementTier(
      days: 365,
      nameFa: 'الماس افسانه',
      nameEn: 'Legend',
      badgeColor: Color(0xFFFFD426),
      rimColor: Color(0xFF22D3EE),
    ),
  ];

  static AchievementTier? highestTierFor(int bestStreak) {
    AchievementTier? top;
    for (final t in achievementTiers) {
      if (bestStreak >= t.days) top = t;
    }
    return top;
  }

  /// Resolves the effective Day Mode for [date]:
  /// - Explicit 'all' ("All Modes") overrides filters to show everything.
  /// - Calendar date overrides (`dayModeByDate`) take priority over weekly rules.
  /// - Weekly rules (`weekdayDayModes`) take priority over manual fallback.
  /// - Any deleted/unknown mode falls back cleanly to existing modes or 'all'.
  static String resolveDayMode(AppSettings settings, DateTime date) {
    final validIds = {for (final m in settings.dayModesList) m.id};
    String validOrAll(String id) =>
        id == 'all' || validIds.contains(id) ? id : 'all';

    if (settings.activeDayMode == 'all') return 'all';
    final dateKey = AppCalendar.toDateKey(date);
    final byDate = settings.dayModeByDate[dateKey];
    if (byDate != null && byDate.isNotEmpty && validIds.contains(byDate)) {
      return byDate;
    }
    final byWeekday = settings.weekdayDayModes[date.weekday];
    if (byWeekday != null &&
        byWeekday.isNotEmpty &&
        validIds.contains(byWeekday)) {
      return byWeekday;
    }
    return validOrAll(settings.activeDayMode);
  }

  static bool hasCalendarModeRule(AppSettings settings, DateTime date) {
    if (settings.activeDayMode == 'all') return false;
    final validIds = {for (final m in settings.dayModesList) m.id};
    final dateKey = AppCalendar.toDateKey(date);
    final bd = settings.dayModeByDate[dateKey];
    final bw = settings.weekdayDayModes[date.weekday];
    return (bd != null && validIds.contains(bd)) ||
        (bw != null && validIds.contains(bw));
  }

  /// Evaluates strict day-mode membership:
  /// - Viewing 'all' ("All Modes") shows every habit.
  /// - Habits marked 'all' appear in every mode.
  /// - Legacy/untagged habits (empty list) belong strictly to 'normal'.
  static bool matchesDayMode(Habit habit, String activeDayMode) {
    if (activeDayMode == 'all') return true;
    if (habit.dayModes.contains('all')) return true;
    if (habit.dayModes.isEmpty) return activeDayMode == 'normal';
    return habit.dayModes.contains(activeDayMode);
  }

  static bool isScheduledOn(
    Habit habit,
    DateTime date, {
    CalendarSystem calendar = CalendarSystem.jalali,
    WeekStartDay weekStart = WeekStartDay.saturday,
    Map<String, HabitCompletion>? completionsByDate,
    List<HabitChecklistItem> checklistItems = const [],
    DateTime? today,
  }) {
    final norm = AppCalendar.normalizeDate(date);
    final start = AppCalendar.parseDateKey(habit.startDateKey);

    switch (habit.frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.weekdays:
        final bit = 1 << (norm.weekday - 1);
        return (habit.weekdaysMask & bit) != 0;
      case FrequencyType.monthDays:
        final dNum = AppCalendar.dayNumberInCalendar(norm, calendar);
        return habit.monthDays.contains(dNum);
      case FrequencyType.period:
        final refToday = AppCalendar.normalizeDate(today ?? DateTime.now());
        final targetPerWeek = habit.targetPerWeek.clamp(1, 7);
        if (completionsByDate == null) return true;
        final wStart = AppCalendar.startOfWeek(norm, weekStart);
        var doneInWeek = 0;
        for (var i = 0; i < 7; i++) {
          final d = DateTime(wStart.year, wStart.month, wStart.day + i);
          if (d.isAfter(refToday)) continue;
          final dk = AppCalendar.toDateKey(d);
          if (isCompletedOn(
            habit,
            completionsByDate[dk],
            checklistItems,
            d,
            today: refToday,
          )) {
            doneInWeek++;
          }
        }
        final selfKey = AppCalendar.toDateKey(norm);
        final doneSelf = isCompletedOn(
          habit,
          completionsByDate[selfKey],
          checklistItems,
          norm,
          today: refToday,
        );
        return doneInWeek < targetPerWeek || doneSelf;
      case FrequencyType.interval:
        final step = habit.intervalDays < 1 ? 1 : habit.intervalDays;
        final diff = AppCalendar.calendarDaysBetween(start, norm);
        return ((diff % step) + step) % step == 0;
    }
  }

  /// Quit tasks start unchecked (`false`) until the user explicitly marks them clean (`value >= 1 && !slipped`).
  static bool isCompletedOn(
    Habit habit,
    HabitCompletion? completion,
    List<HabitChecklistItem> checklistItems,
    DateTime date, {
    DateTime? today,
  }) {
    final norm = AppCalendar.normalizeDate(date);
    final refToday = AppCalendar.normalizeDate(today ?? DateTime.now());
    if (norm.isAfter(refToday)) return false;

    if (completion == null) return false;
    if (habit.isQuit) {
      if (completion.slipped) return false;
      return completion.value >= 1;
    }

    switch (habit.trackingStyle) {
      case TrackingStyle.boolean:
        return completion.value >= 1;
      case TrackingStyle.count:
        final target = habit.targetCount < 1 ? 1 : habit.targetCount;
        return completion.value >= target;
      case TrackingStyle.checklist:
        if (checklistItems.isEmpty) return completion.value >= 1;
        return checklistItems
            .every((item) => completion.completedChecklistIds.contains(item.id));
    }
  }

  static double progressRatio(
    Habit habit,
    HabitCompletion? completion,
    List<HabitChecklistItem> checklistItems,
    DateTime date, {
    DateTime? today,
  }) {
    final norm = AppCalendar.normalizeDate(date);
    final refToday = AppCalendar.normalizeDate(today ?? DateTime.now());
    if (norm.isAfter(refToday)) return 0.0;

    if (habit.isQuit) {
      return isCompletedOn(habit, completion, checklistItems, norm,
              today: refToday)
          ? 1.0
          : 0.0;
    }

    if (completion == null) return 0.0;
    switch (habit.trackingStyle) {
      case TrackingStyle.boolean:
        return completion.value >= 1 ? 1.0 : 0.0;
      case TrackingStyle.count:
        final target = habit.targetCount < 1 ? 1 : habit.targetCount;
        return (completion.value / target).clamp(0.0, 1.0);
      case TrackingStyle.checklist:
        if (checklistItems.isEmpty) return completion.value >= 1 ? 1.0 : 0.0;
        final done = checklistItems
            .where((i) => completion.completedChecklistIds.contains(i.id))
            .length;
        return (done / checklistItems.length).clamp(0.0, 1.0);
    }
  }

  static bool isPausedOn(
    String habitId,
    DateTime date,
    List<HabitPause> pauses,
  ) {
    final key = AppCalendar.toDateKey(AppCalendar.normalizeDate(date));
    for (final p in pauses) {
      if (p.habitId == habitId &&
          p.deletedAtMs == null &&
          p.coversDateKey(key)) {
        return true;
      }
    }
    return false;
  }

  static HabitStats computeStats(
    Habit habit,
    Map<String, HabitCompletion> completionsByDate,
    List<HabitChecklistItem> checklistItems, {
    CalendarSystem calendar = CalendarSystem.jalali,
    WeekStartDay weekStart = WeekStartDay.saturday,
    DateTime? today,
    List<HabitPause> pauses = const [],
    int monthlyGraceDays = 0,
  }) {
    final refToday = AppCalendar.normalizeDate(today ?? DateTime.now());
    var start = AppCalendar.parseDateKey(habit.startDateKey);
    // Include active backdated completion history prior to habit creation date.
    for (final entry in completionsByDate.entries) {
      final c = entry.value;
      if (c.value == 0 && !c.slipped && c.completedChecklistIds.isEmpty) {
        continue;
      }
      final d = AppCalendar.parseDateKey(entry.key);
      if (d.isBefore(start)) start = d;
    }
    if (refToday.isBefore(start)) {
      return const HabitStats(
        currentStreak: 0,
        bestStreak: 0,
        totalCompletions: 0,
        slipCount: 0,
        completionRate: 0,
        habitScore: 0,
      );
    }

    final totalDays = AppCalendar.calendarDaysBetween(start, refToday) + 1;
    var scheduledCount = 0;
    var completedCount = 0;
    var slips = 0;
    var runningStreak = 0;
    var bestStreak = 0;
    final usedGraceByMonth = <String, int>{};

    if (habit.frequencyType == FrequencyType.period) {
      final targetPerWeek = habit.targetPerWeek.clamp(1, 7);
      var wStart = AppCalendar.startOfWeek(start, weekStart);
      while (!wStart.isAfter(refToday)) {
        var unpausedDays = 0;
        var doneInWeek = 0;
        var lastActiveDay = wStart;
        for (var j = 0; j < 7; j++) {
          final d = DateTime(wStart.year, wStart.month, wStart.day + j);
          if (d.isBefore(start) || d.isAfter(refToday)) continue;
          final key = AppCalendar.toDateKey(d);
          final comp = completionsByDate[key];
          if (comp?.slipped == true) slips++;
          final paused = isPausedOn(habit.id, d, pauses);
          final done =
              isCompletedOn(habit, comp, checklistItems, d, today: refToday);
          if (!paused) {
            unpausedDays++;
            lastActiveDay = d;
          }
          if (!paused || done) {
            if (done) doneInWeek++;
          }
        }
        final wEnd = DateTime(wStart.year, wStart.month, wStart.day + 6);
        final isCurrentWeek = !wEnd.isBefore(refToday);
        final expected = unpausedDays < targetPerWeek ? unpausedDays : targetPerWeek;

        if (expected > 0) {
          if (!isCurrentWeek || doneInWeek >= targetPerWeek || unpausedDays >= 7) {
            scheduledCount += doneInWeek > expected ? doneInWeek : expected;
            completedCount += doneInWeek;
          } else {
            scheduledCount += doneInWeek;
            completedCount += doneInWeek;
          }

          if (doneInWeek >= expected) {
            runningStreak += doneInWeek;
            if (runningStreak > bestStreak) bestStreak = runningStreak;
          } else if (isCurrentWeek) {
            runningStreak += doneInWeek;
            if (runningStreak > bestStreak) bestStreak = runningStreak;
          } else {
            var graced = false;
            if (runningStreak > 0 && monthlyGraceDays > 0) {
              final ym = AppCalendar.yearMonthKey(lastActiveDay, calendar);
              final used = usedGraceByMonth[ym] ?? 0;
              if (used < monthlyGraceDays) {
                usedGraceByMonth[ym] = used + 1;
                graced = true;
              }
            }
            if (!graced) runningStreak = 0;
          }
        }
        wStart = DateTime(wStart.year, wStart.month, wStart.day + 7);
      }

      // Weighted 90-day consistency score by week for period habits.
      var wSum = 0.0;
      var wVal = 0.0;
      final winStart = DateTime(refToday.year, refToday.month, refToday.day - 89);
      final effWinStart = winStart.isBefore(start) ? start : winStart;
      var scoreWStart = AppCalendar.startOfWeek(effWinStart, weekStart);
      while (!scoreWStart.isAfter(refToday)) {
        var unpausedDays = 0;
        var doneInWeek = 0;
        DateTime? lastDay;
        for (var j = 0; j < 7; j++) {
          final d = DateTime(scoreWStart.year, scoreWStart.month, scoreWStart.day + j);
          if (d.isBefore(effWinStart) || d.isAfter(refToday)) continue;
          lastDay = d;
          final key = AppCalendar.toDateKey(d);
          final paused = isPausedOn(habit.id, d, pauses);
          final done = isCompletedOn(
            habit,
            completionsByDate[key],
            checklistItems,
            d,
            today: refToday,
          );
          if (!paused) unpausedDays++;
          if (done) doneInWeek++;
        }
        if (lastDay != null) {
          final daysAgo = AppCalendar.calendarDaysBetween(lastDay, refToday);
          final w = 1.0 + (90 - daysAgo.clamp(0, 89)) * 0.025;
          final expected =
              unpausedDays < targetPerWeek ? unpausedDays : targetPerWeek;
          final wEnd =
              DateTime(scoreWStart.year, scoreWStart.month, scoreWStart.day + 6);
          final isCur = !wEnd.isBefore(refToday);
          if (expected > 0 && (!isCur || doneInWeek >= expected || unpausedDays >= 7)) {
            wSum += w;
            wVal += w * (doneInWeek / expected).clamp(0.0, 1.0);
          } else if (doneInWeek > 0) {
            wSum += w;
            wVal += w;
          }
        }
        scoreWStart =
            DateTime(scoreWStart.year, scoreWStart.month, scoreWStart.day + 7);
      }
      final score =
          wSum > 0 ? ((wVal / wSum) * 100).round().clamp(0, 100) : 0;
      final rate = scheduledCount == 0 ? 0.0 : completedCount / scheduledCount;
      return HabitStats(
        currentStreak: runningStreak,
        bestStreak: bestStreak,
        totalCompletions: completedCount,
        slipCount: slips,
        completionRate: rate.clamp(0.0, 1.0),
        habitScore: score,
      );
    }

    for (var i = 0; i < totalDays; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final key = AppCalendar.toDateKey(d);
      final comp = completionsByDate[key];
      if (comp?.slipped == true) slips++;

      final paused = isPausedOn(habit.id, d, pauses);
      final sched = isScheduledOn(
        habit,
        d,
        calendar: calendar,
        weekStart: weekStart,
        completionsByDate: completionsByDate,
        checklistItems: checklistItems,
        today: refToday,
      );
      if (!sched) continue;

      final done =
          isCompletedOn(habit, comp, checklistItems, d, today: refToday);

      if (paused) {
        if (done) {
          scheduledCount++;
          completedCount++;
          runningStreak++;
          if (runningStreak > bestStreak) bestStreak = runningStreak;
        }
        continue;
      }

      scheduledCount++;
      if (done) {
        completedCount++;
        runningStreak++;
        if (runningStreak > bestStreak) bestStreak = runningStreak;
      } else {
        final isToday = d == refToday;
        if (!isToday) {
          if (runningStreak > 0 && monthlyGraceDays > 0) {
            final ym = AppCalendar.yearMonthKey(d, calendar);
            final used = usedGraceByMonth[ym] ?? 0;
            if (used < monthlyGraceDays) {
              usedGraceByMonth[ym] = used + 1;
              continue;
            }
          }
          runningStreak = 0;
        }
      }
    }

    // Weighted 90-day consistency score with partial ratio & pause awareness.
    var wSum = 0.0;
    var wVal = 0.0;
    for (var i = 89; i >= 0; i--) {
      final d = DateTime(refToday.year, refToday.month, refToday.day - i);
      if (d.isBefore(start)) continue;
      final key = AppCalendar.toDateKey(d);
      final comp = completionsByDate[key];
      final paused = isPausedOn(habit.id, d, pauses);
      final r = progressRatio(habit, comp, checklistItems, d, today: refToday);
      final sched = isScheduledOn(
        habit,
        d,
        calendar: calendar,
        weekStart: weekStart,
        completionsByDate: completionsByDate,
        checklistItems: checklistItems,
        today: refToday,
      );
      if (paused && r <= 0) continue;
      final w = 1.0 + (90 - i) * 0.025;
      if (sched || r > 0) {
        wSum += w;
        wVal += w * r;
      }
    }

    final score =
        wSum > 0 ? ((wVal / wSum) * 100).round().clamp(0, 100) : 0;
    final rate = scheduledCount == 0 ? 0.0 : completedCount / scheduledCount;
    return HabitStats(
      currentStreak: runningStreak,
      bestStreak: bestStreak,
      totalCompletions: completedCount,
      slipCount: slips,
      completionRate: rate,
      habitScore: score,
    );
  }

  /// Partial-progress weighted success percentage (`0..100`) over the trailing [days].
  static double successRateForWindow({
    required List<Habit> habits,
    required Map<String, HabitCompletion> Function(String habitId) completionsFor,
    required List<HabitChecklistItem> Function(String habitId) checklistFor,
    required List<HabitPause> pauses,
    required int days,
    required CalendarSystem calendar,
    required WeekStartDay weekStart,
    required DateTime today,
  }) {
    if (habits.isEmpty || days <= 0) return 0.0;
    final refToday = AppCalendar.normalizeDate(today);
    var sumRatio = 0.0;
    var countSlots = 0;

    for (final h in habits) {
      if (h.isArchived) continue;
      final byDate = completionsFor(h.id);
      final items = checklistFor(h.id);
      var start = AppCalendar.parseDateKey(h.startDateKey);
      for (final entry in byDate.entries) {
        final c = entry.value;
        if (c.value == 0 && !c.slipped && c.completedChecklistIds.isEmpty) {
          continue;
        }
        final d = AppCalendar.parseDateKey(entry.key);
        if (d.isBefore(start)) start = d;
      }

      if (h.frequencyType == FrequencyType.period) {
        final targetPerWeek = h.targetPerWeek.clamp(1, 7);
        final winStart =
            DateTime(refToday.year, refToday.month, refToday.day - (days - 1));
        final effStart = winStart.isBefore(start) ? start : winStart;
        var wStart = AppCalendar.startOfWeek(effStart, weekStart);
        while (!wStart.isAfter(refToday)) {
          var unpaused = 0;
          var doneInWeek = 0;
          for (var j = 0; j < 7; j++) {
            final d = DateTime(wStart.year, wStart.month, wStart.day + j);
            if (d.isBefore(effStart) || d.isAfter(refToday)) continue;
            final key = AppCalendar.toDateKey(d);
            final paused = isPausedOn(h.id, d, pauses);
            final done = isCompletedOn(h, byDate[key], items, d, today: refToday);
            if (!paused) unpaused++;
            if (done) doneInWeek++;
          }
          final expected = unpaused < targetPerWeek ? unpaused : targetPerWeek;
          final wEnd = DateTime(wStart.year, wStart.month, wStart.day + 6);
          final isCur = !wEnd.isBefore(refToday);
          if (expected > 0 && (!isCur || doneInWeek >= expected || unpaused >= 7)) {
            final denom = doneInWeek > expected ? doneInWeek : expected;
            countSlots += denom;
            sumRatio += doneInWeek;
          } else if (doneInWeek > 0) {
            countSlots += doneInWeek;
            sumRatio += doneInWeek;
          }
          wStart = DateTime(wStart.year, wStart.month, wStart.day + 7);
        }
        continue;
      }

      for (var i = 0; i < days; i++) {
        final d = DateTime(refToday.year, refToday.month, refToday.day - i);
        if (d.isBefore(start)) break;
        if (isPausedOn(h.id, d, pauses)) continue;
        final sched = isScheduledOn(
          h,
          d,
          calendar: calendar,
          weekStart: weekStart,
          completionsByDate: byDate,
          checklistItems: items,
          today: refToday,
        );
        final key = AppCalendar.toDateKey(d);
        final r = progressRatio(h, byDate[key], items, d, today: refToday);
        if (sched || r > 0) {
          countSlots++;
          sumRatio += r;
        }
      }
    }

    if (countSlots == 0) return 0.0;
    return ((sumRatio / countSlots) * 100.0).clamp(0.0, 100.0);
  }
}
