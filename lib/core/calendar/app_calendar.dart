import 'package:shamsi_date/shamsi_date.dart';
import '../../data/models/habit_models.dart';

/// Unified date and calendar helper supporting both Gregorian and Jalali (Shamsi)
/// presentations while persisting canonical ISO `yyyy-MM-dd` keys.
class AppCalendar {
  AppCalendar._();

  static const List<String> _jalaliMonthsFa = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  static const List<String> _jalaliMonthsEn = [
    'Farvardin',
    'Ordibehesht',
    'Khordad',
    'Tir',
    'Mordad',
    'Shahrivar',
    'Mehr',
    'Aban',
    'Azar',
    'Dey',
    'Bahman',
    'Esfand',
  ];

  static const List<String> _gregorianMonthsFa = [
    'ژانویه',
    'فوریه',
    'مارس',
    'آوریل',
    'مه',
    'ژوئن',
    'ژوئیه',
    'اوت',
    'سپتامبر',
    'اکتبر',
    'نوامبر',
    'دسامبر',
  ];

  static const List<String> _gregorianMonthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const Map<int, String> _weekdaysMinFa = {
    DateTime.saturday: 'ش',
    DateTime.sunday: 'ی',
    DateTime.monday: 'د',
    DateTime.tuesday: 'س',
    DateTime.wednesday: 'چ',
    DateTime.thursday: 'پ',
    DateTime.friday: 'ج',
  };

  static const Map<int, String> _weekdaysMinEn = {
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
  };

  static const Map<int, String> _weekdaysShortFa = {
    DateTime.saturday: 'شن',
    DateTime.sunday: 'یک',
    DateTime.monday: 'دو',
    DateTime.tuesday: 'سه',
    DateTime.wednesday: 'چه',
    DateTime.thursday: 'پن',
    DateTime.friday: 'جم',
  };

  static const Map<int, String> _weekdaysShortEn = {
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
  };

  static const Map<int, String> _weekdaysFullFa = {
    DateTime.saturday: 'شنبه',
    DateTime.sunday: 'یکشنبه',
    DateTime.monday: 'دوشنبه',
    DateTime.tuesday: 'سه‌شنبه',
    DateTime.wednesday: 'چهارشنبه',
    DateTime.thursday: 'پنج‌شنبه',
    DateTime.friday: 'جمعه',
  };

  static const Map<int, String> _weekdaysFullEn = {
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
  };

  static String toDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime(2000, 1, 1);
  }

  static DateTime fromDateKey(String key) => parseDateKey(key);

  static DateTime normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Calendar-day delta immune to DST 23h/25h transitions.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Logical "today" shifted back by [dayResetMinutes] (e.g. 03:30 AM -> 210 min).
  static DateTime logicalToday(DateTime now, int dayResetMinutes) {
    final cutoff = dayResetMinutes.clamp(0, 720);
    final curMin = now.hour * 60 + now.minute;
    if (curMin < cutoff) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  static String yearMonthKey(DateTime dt, CalendarSystem system) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(dt);
      return '${j.year}-${j.month.toString().padLeft(2, '0')}';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  static String localizeDigits(String input, String localeCode) {
    if (localeCode != 'fa') return input;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(en[i], fa[i]);
    }
    return out;
  }

  static int dayNumberInCalendar(DateTime dt, CalendarSystem system) {
    if (system == CalendarSystem.jalali) {
      return Jalali.fromDateTime(dt).day;
    }
    return dt.day;
  }

  static int yearInCalendar(DateTime dt, CalendarSystem system) {
    if (system == CalendarSystem.jalali) {
      return Jalali.fromDateTime(dt).year;
    }
    return dt.year;
  }

  static int monthInCalendar(DateTime dt, CalendarSystem system) {
    if (system == CalendarSystem.jalali) {
      return Jalali.fromDateTime(dt).month;
    }
    return dt.month;
  }

  static String monthDayLabel(
    DateTime dt,
    CalendarSystem system,
    String localeCode,
  ) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(dt);
      final m = localeCode == 'fa'
          ? _jalaliMonthsFa[j.month - 1]
          : _jalaliMonthsEn[j.month - 1];
      return localizeDigits('${j.day} $m', localeCode);
    }
    final m = localeCode == 'fa'
        ? _gregorianMonthsFa[dt.month - 1]
        : _gregorianMonthsEn[dt.month - 1].substring(0, 3);
    return localizeDigits('${dt.day} $m', localeCode);
  }

  static String formatMonthYear(
    DateTime dt,
    CalendarSystem system,
    String localeCode,
  ) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(dt);
      final monthName = localeCode == 'fa'
          ? _jalaliMonthsFa[j.month - 1]
          : _jalaliMonthsEn[j.month - 1];
      return localizeDigits('$monthName ${j.year}', localeCode);
    }
    final monthName = localeCode == 'fa'
        ? _gregorianMonthsFa[dt.month - 1]
        : _gregorianMonthsEn[dt.month - 1];
    return localizeDigits('$monthName ${dt.year}', localeCode);
  }

  static String formatFullDate(
    DateTime dt,
    CalendarSystem system,
    String localeCode,
  ) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(dt);
      final monthName = localeCode == 'fa'
          ? _jalaliMonthsFa[j.month - 1]
          : _jalaliMonthsEn[j.month - 1];
      return localizeDigits('${j.day} $monthName ${j.year}', localeCode);
    }
    final monthName = localeCode == 'fa'
        ? _gregorianMonthsFa[dt.month - 1]
        : _gregorianMonthsEn[dt.month - 1];
    return localizeDigits('${dt.day} $monthName ${dt.year}', localeCode);
  }

  static String weekdayMin(int dartWeekday, String localeCode) {
    final map = localeCode == 'fa' ? _weekdaysMinFa : _weekdaysMinEn;
    return map[dartWeekday] ?? '';
  }

  static String weekdayShort(int dartWeekday, String localeCode) {
    final map = localeCode == 'fa' ? _weekdaysShortFa : _weekdaysShortEn;
    return map[dartWeekday] ?? '';
  }

  static String weekdayFull(int dartWeekday, String localeCode) {
    final map = localeCode == 'fa' ? _weekdaysFullFa : _weekdaysFullEn;
    return map[dartWeekday] ?? '';
  }

  static List<int> orderedWeekdays(WeekStartDay start) {
    switch (start) {
      case WeekStartDay.saturday:
        return const [
          DateTime.saturday,
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ];
      case WeekStartDay.sunday:
        return const [
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
        ];
      case WeekStartDay.monday:
        return const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        ];
    }
  }

  static int _startWeekdayValue(WeekStartDay start) {
    switch (start) {
      case WeekStartDay.saturday:
        return DateTime.saturday;
      case WeekStartDay.sunday:
        return DateTime.sunday;
      case WeekStartDay.monday:
        return DateTime.monday;
    }
  }

  /// Returns leading-padded list of dates for [anchor]'s month (exact calendar cells).
  static List<DateTime?> monthGridDates(
    DateTime anchor,
    CalendarSystem system,
    WeekStartDay weekStart,
  ) {
    late final DateTime firstDay;
    late final int daysCount;
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(anchor);
      final startJ = Jalali(j.year, j.month, 1);
      firstDay = startJ.toDateTime();
      daysCount = startJ.monthLength;
    } else {
      firstDay = DateTime(anchor.year, anchor.month, 1);
      daysCount = DateTime(anchor.year, anchor.month + 1, 0).day;
    }

    final order = orderedWeekdays(weekStart);
    final leadingNulls = order.indexOf(firstDay.weekday);
    final cells = <DateTime?>[
      for (var i = 0; i < leadingNulls; i++) null,
      for (var d = 0; d < daysCount; d++)
        DateTime(firstDay.year, firstDay.month, firstDay.day + d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  static DateTime shiftMonth(
    DateTime anchor,
    int deltaMonths,
    CalendarSystem system,
  ) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(anchor);
      final totalMonths = (j.year * 12 + (j.month - 1)) + deltaMonths;
      final newYear = totalMonths ~/ 12;
      final newMonth = (totalMonths % 12) + 1;
      final target = Jalali(newYear, newMonth, 1);
      return target.toDateTime();
    }
    return DateTime(anchor.year, anchor.month + deltaMonths, 1);
  }

  static List<DateTime> yearDates(DateTime anchor, CalendarSystem system) {
    if (system == CalendarSystem.jalali) {
      final j = Jalali.fromDateTime(anchor);
      final start = Jalali(j.year, 1, 1);
      final nextStart = Jalali(j.year + 1, 1, 1);
      final base = start.toDateTime();
      final totalDays = calendarDaysBetween(base, nextStart.toDateTime());
      return List.generate(
        totalDays,
        (i) => DateTime(base.year, base.month, base.day + i),
      );
    }
    final start = DateTime(anchor.year, 1, 1);
    final nextStart = DateTime(anchor.year + 1, 1, 1);
    final totalDays = calendarDaysBetween(start, nextStart);
    return List.generate(
      totalDays,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  static DateTime startOfWeek(DateTime dt, WeekStartDay startDay) {
    final norm = normalizeDate(dt);
    final target = _startWeekdayValue(startDay);
    final diff = (norm.weekday - target + 7) % 7;
    return DateTime(norm.year, norm.month, norm.day - diff);
  }
}
