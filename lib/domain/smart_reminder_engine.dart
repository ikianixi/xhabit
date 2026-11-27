/// Pure scheduling and behavioral pattern helper for repeat reminders,
/// quiet hours filtering, and completion-time habit learning.
class SmartReminderEngine {
  SmartReminderEngine._();

  /// Returns true when [minuteOfDay] (`0..1439`) falls inside [startMin]..[endMin].
  /// Supports overnight wrap-around ranges (e.g. 23:00 -> 07:00).
  static bool isInQuietHours(
    int minuteOfDay, {
    required bool enabled,
    required int startMin,
    required int endMin,
  }) {
    if (!enabled) return false;
    final m = ((minuteOfDay % 1440) + 1440) % 1440;
    final s = ((startMin % 1440) + 1440) % 1440;
    final e = ((endMin % 1440) + 1440) % 1440;
    if (s == e) return false;
    if (s < e) {
      return m >= s && m < e;
    }
    return m >= s || m < e;
  }

  /// Computes follow-up reminder minutes of day (`0..1439`, clipped at midnight)
  /// within [responseWindowMins], spaced by [repeatIntervalMins], up to [maxRepeats],
  /// automatically skipping times that fall inside user's quiet hours.
  static List<int> computeFollowUpMinutes({
    required int baseMinuteOfDay,
    required int repeatIntervalMins,
    required int maxRepeats,
    required int responseWindowMins,
    required bool quietEnabled,
    required int quietStartMin,
    required int quietEndMin,
  }) {
    if (repeatIntervalMins <= 0 || maxRepeats <= 0 || responseWindowMins <= 0) {
      return const [];
    }
    final out = <int>[];
    for (var k = 1; k <= maxRepeats; k++) {
      final offset = k * repeatIntervalMins;
      if (offset > responseWindowMins) break;
      final minute = baseMinuteOfDay + offset;
      if (minute >= 1440) break;
      if (isInQuietHours(
        minute,
        enabled: quietEnabled,
        startMin: quietStartMin,
        endMin: quietEndMin,
      )) {
        continue;
      }
      out.add(minute);
    }
    return out;
  }

  /// Learns the user's most responsive hour/minute from historical completions.
  /// Returns `null` when fewer than 3 valid completion samples exist.
  static ({int suggestedHour, int suggestedMinute, double confidence, int sampleCount})?
      learnBestReminderTime({
    required List<int> recordedMinutesOfDay,
    bool quietEnabled = false,
    int quietStartMin = 23 * 60,
    int quietEndMin = 7 * 60,
  }) {
    final valid = recordedMinutesOfDay
        .map((m) => ((m % 1440) + 1440) % 1440)
        .where((m) => !isInQuietHours(
              m,
              enabled: quietEnabled,
              startMin: quietStartMin,
              endMin: quietEndMin,
            ))
        .toList();
    if (valid.length < 3) return null;

    var bestCenter = valid.first;
    var bestCluster = <int>[];
    for (final anchor in valid) {
      final cluster = valid
          .where((m) => (m - anchor).abs() <= 30)
          .toList();
      if (cluster.length > bestCluster.length) {
        bestCluster = cluster;
        bestCenter = anchor;
      }
    }
    if (bestCluster.isEmpty) return null;

    final avg = bestCluster.reduce((a, b) => a + b) / bestCluster.length;
    // Snap 15 minutes earlier (clamped >= 0) within 15-min increments to nudge ahead of habit completion.
    var snapped = (((avg - 10) / 15).round() * 15).clamp(0, 1425);
    if (isInQuietHours(
      snapped,
      enabled: quietEnabled,
      startMin: quietStartMin,
      endMin: quietEndMin,
    )) {
      snapped = bestCenter;
    }

    return (
      suggestedHour: snapped ~/ 60,
      suggestedMinute: snapped % 60,
      confidence: (bestCluster.length / valid.length).clamp(0.0, 1.0),
      sampleCount: valid.length,
    );
  }
}
