import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/calendar/app_calendar.dart';
import '../core/services/notification_service.dart';
import '../core/services/widget_sync_service.dart';
import '../core/sync/cloud_drive_sync_service.dart';
import '../core/sync/obsidian_sync_service.dart';
import '../core/sync/sync_ports.dart';
import '../data/db/app_database.dart';
import '../data/models/habit_models.dart';
import '../domain/habit_engine.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  Future<void> _settingsQueue = Future.value();

  Future<T> _serializeSettings<T>(Future<T> Function() fn) {
    final prev = _settingsQueue;
    final completer = Completer<void>();
    _settingsQueue = completer.future;
    return () async {
      try {
        await prev.catchError((_) {});
        return await fn();
      } finally {
        completer.complete();
      }
    }();
  }

  static bool _dayModesListEquals(List<DayModeConfig> a, List<DayModeConfig> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ma = a[i].toMap();
      final mb = b[i].toMap();
      if (!mapEquals(ma, mb)) return false;
    }
    return true;
  }

  static bool _needsPlatformSync(AppSettings? prev, AppSettings next) {
    if (prev == null) return true;
    return prev.localeCode != next.localeCode ||
        prev.calendarSystem != next.calendarSystem ||
        prev.weekStartDay != next.weekStartDay ||
        prev.dayResetMinutes != next.dayResetMinutes ||
        prev.streakGraceDaysPerMonth != next.streakGraceDaysPerMonth ||
        prev.quietHoursEnabled != next.quietHoursEnabled ||
        prev.quietStartMinutes != next.quietStartMinutes ||
        prev.quietEndMinutes != next.quietEndMinutes ||
        prev.activeDayMode != next.activeDayMode ||
        prev.allDayModeColorValue != next.allDayModeColorValue ||
        prev.allDayModeIconKey != next.allDayModeIconKey ||
        !_dayModesListEquals(prev.dayModesList, next.dayModesList) ||
        !mapEquals(prev.dayModeByDate, next.dayModeByDate) ||
        !mapEquals(prev.weekdayDayModes, next.weekdayDayModes) ||
        prev.widgetTheme != next.widgetTheme ||
        prev.widgetHabitId != next.widgetHabitId ||
        !listEquals(prev.widgetListHabitIds, next.widgetListHabitIds) ||
        prev.widgetCelebrationOverlay != next.widgetCelebrationOverlay;
  }

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final calStr = prefs.getString('calendarSystem') ?? CalendarSystem.jalali.name;
    final weekStr = prefs.getString('weekStartDay') ?? WeekStartDay.saturday.name;
    final layoutStr = prefs.getString('homeLayout') ?? HomeLayout.grid.name;
    final wThemeStr = prefs.getString('widgetTheme') ?? WidgetThemeMode.dark.name;
    final sndProfStr = prefs.getString('soundProfile') ?? SoundProfile.pop.name;
    final fontScaleStr =
        prefs.getString('fontScaleMode') ?? FontScaleMode.medium.name;
    final ratePeriodStr =
        prefs.getString('homeRatePeriod') ?? SuccessRatePeriod.weekly.name;

    return AppSettings(
      localeCode: prefs.getString('localeCode') ?? 'fa',
      calendarSystem: CalendarSystem.values.asNameMap()[calStr] ?? CalendarSystem.jalali,
      weekStartDay: WeekStartDay.values.asNameMap()[weekStr] ?? WeekStartDay.saturday,
      isDarkMode: prefs.getBool('isDarkMode') ?? true,
      homeLayout: HomeLayout.values.asNameMap()[layoutStr] ?? HomeLayout.grid,
      widgetTheme: WidgetThemeMode.values.asNameMap()[wThemeStr] ?? WidgetThemeMode.dark,
      soundProfile: SoundProfile.values.asNameMap()[sndProfStr] ?? SoundProfile.pop,
      fontScaleMode:
          FontScaleMode.values.asNameMap()[fontScaleStr] ?? FontScaleMode.medium,
      widgetCelebrationOverlay:
          prefs.getBool('widgetCelebrationOverlay') ?? true,
      customStoragePath: prefs.getString('customStoragePath'),
      dayResetMinutes: prefs.getInt('dayResetMinutes') ?? 0,
      streakGraceDaysPerMonth: prefs.getInt('streakGraceDaysPerMonth') ?? 0,
      homeRatePeriod: SuccessRatePeriod.values.asNameMap()[ratePeriodStr] ??
          SuccessRatePeriod.weekly,
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
      dayModesList: _decodeDayModesList(
        prefs.getString('dayModesList'),
        prefs.getStringList('customDayModes') ?? const [],
      ),
      allDayModeColorValue:
          prefs.getInt('allDayModeColorValue') ?? 0xFF84CC16,
      allDayModeIconKey:
          prefs.getString('allDayModeIconKey') ?? 'all_inclusive',
      dayModeByDate: _decodeStringMap(prefs.getString('dayModeByDate')),
      weekdayDayModes: _decodeIntStringMap(prefs.getString('weekdayDayModes')),
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
      isShowOnlyDueHabit: prefs.getBool('isShowOnlyDueHabit') ?? false,
      isShowAddNoteInHome: prefs.getBool('isShowAddNoteInHome') ?? true,
      isConfettiEnabled: prefs.getBool('isConfettiEnabled') ?? true,
      isAchievementSoundEnabled: prefs.getBool('isAchievementSoundEnabled') ?? true,
      isAppLockEnabled: prefs.getBool('isAppLockEnabled') ?? false,
      isOnboardingCompleted: prefs.getBool('isOnboardingCompleted') ?? true,
      widgetHabitId: prefs.getString('widgetHabitId'),
      widgetListHabitIds: prefs.getStringList('widgetListHabitIds') ?? const [],
    );
  }

  Future<void> updateSettings(
    AppSettings next, {
    bool skipSyncScheduling = false,
  }) =>
      _serializeSettings(() async {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
      prefs.setString('localeCode', next.localeCode),
      prefs.setString('calendarSystem', next.calendarSystem.name),
      prefs.setString('weekStartDay', next.weekStartDay.name),
      prefs.setBool('isDarkMode', next.isDarkMode),
      prefs.setString('homeLayout', next.homeLayout.name),
      prefs.setString('widgetTheme', next.widgetTheme.name),
      prefs.setString('soundProfile', next.soundProfile.name),
      prefs.setString('fontScaleMode', next.fontScaleMode.name),
      prefs.setBool('widgetCelebrationOverlay', next.widgetCelebrationOverlay),
      if (next.customStoragePath != null)
        prefs.setString('customStoragePath', next.customStoragePath!)
      else
        prefs.remove('customStoragePath'),
      prefs.setInt('dayResetMinutes', next.dayResetMinutes),
      prefs.setInt('streakGraceDaysPerMonth', next.streakGraceDaysPerMonth),
      prefs.setString('homeRatePeriod', next.homeRatePeriod.name),
      prefs.setBool('autoBackupEnabled', next.autoBackupEnabled),
      prefs.setInt('autoBackupIntervalDays', next.autoBackupIntervalDays),
      prefs.setInt('autoBackupHour', next.autoBackupHour),
      prefs.setInt('autoBackupMinute', next.autoBackupMinute),
      prefs.setInt('autoBackupKeepCount', next.autoBackupKeepCount),
      if (next.lastAutoBackupMs != null)
        prefs.setInt('lastAutoBackupMs', next.lastAutoBackupMs!)
      else
        prefs.remove('lastAutoBackupMs'),
      prefs.setBool('quietHoursEnabled', next.quietHoursEnabled),
      prefs.setInt('quietStartMinutes', next.quietStartMinutes),
      prefs.setInt('quietEndMinutes', next.quietEndMinutes),
      prefs.setString('activeDayMode', next.activeDayMode),
      prefs.setStringList('customDayModes', next.customDayModes),
      prefs.setString(
        'dayModesList',
        jsonEncode([for (final d in next.dayModesList) d.toMap()]),
      ),
      prefs.setInt('allDayModeColorValue', next.allDayModeColorValue),
      prefs.setString('allDayModeIconKey', next.allDayModeIconKey),
      prefs.setString('dayModeByDate', jsonEncode(next.dayModeByDate)),
      prefs.setString(
        'weekdayDayModes',
        jsonEncode({
          for (final e in next.weekdayDayModes.entries) '${e.key}': e.value,
        }),
      ),
      if (next.obsidianVaultUri != null)
        prefs.setString('obsidianVaultUri', next.obsidianVaultUri!)
      else
        prefs.remove('obsidianVaultUri'),
      prefs.setBool('obsidianSyncEnabled', next.obsidianSyncEnabled),
      if (next.lastObsidianSyncMs != null)
        prefs.setInt('lastObsidianSyncMs', next.lastObsidianSyncMs!)
      else
        prefs.remove('lastObsidianSyncMs'),
      if (next.googleDriveUri != null)
        prefs.setString('googleDriveUri', next.googleDriveUri!)
      else
        prefs.remove('googleDriveUri'),
      if (next.googleAccountEmail != null)
        prefs.setString('googleAccountEmail', next.googleAccountEmail!)
      else
        prefs.remove('googleAccountEmail'),
      if (next.googleAccountName != null)
        prefs.setString('googleAccountName', next.googleAccountName!)
      else
        prefs.remove('googleAccountName'),
      prefs.setBool('googleAutoSyncEnabled', next.googleAutoSyncEnabled),
      prefs.setBool('googleCalendarSyncEnabled', next.googleCalendarSyncEnabled),
      if (next.lastGoogleSyncMs != null)
        prefs.setInt('lastGoogleSyncMs', next.lastGoogleSyncMs!)
      else
        prefs.remove('lastGoogleSyncMs'),
      prefs.setBool('isShowOnlyDueHabit', next.isShowOnlyDueHabit),
      prefs.setBool('isShowAddNoteInHome', next.isShowAddNoteInHome),
      prefs.setBool('isConfettiEnabled', next.isConfettiEnabled),
      prefs.setBool('isAchievementSoundEnabled', next.isAchievementSoundEnabled),
      prefs.setBool('isAppLockEnabled', next.isAppLockEnabled),
      prefs.setBool('isOnboardingCompleted', next.isOnboardingCompleted),
      if (next.widgetHabitId != null)
        prefs.setString('widgetHabitId', next.widgetHabitId!)
      else
        prefs.remove('widgetHabitId'),
      prefs.setStringList('widgetListHabitIds', next.widgetListHabitIds),
        ]);
        if (!ref.mounted) return;
        final prev = state.value;
        state = AsyncData(next);
        final st = ref.read(habitStateProvider).value;
        if (st != null && _needsPlatformSync(prev, next)) {
          await NotificationService.instance.syncAllHabitReminders(
            st.habits,
            isFa: next.localeCode == 'fa',
            settings: next,
            completions: st.completions,
            checklistItems: st.checklistItems,
            completionEvents: st.completionEvents,
            pauses: st.pauses,
          );
          if (!ref.mounted) return;
          await WidgetSyncService.instance.syncAll(
            habits: st.habits,
            checklistItems: st.checklistItems,
            completions: st.completions,
            pauses: st.pauses,
            oneOffTasks: st.oneOffTasks,
            settings: next,
          );
          if (!ref.mounted) return;
        }
        if (skipSyncScheduling) return;
        if (!next.obsidianSyncEnabled) {
          ObsidianSyncService.instance.cancelPendingSync();
        } else if (next.obsidianVaultUri != null &&
            next.obsidianVaultUri!.isNotEmpty) {
          final vaultOrToggleActivated = prev?.obsidianSyncEnabled != true ||
              prev?.obsidianVaultUri != next.obsidianVaultUri;
          final relevantSettingsChanged =
              prev?.activeDayMode != next.activeDayMode ||
                  !_dayModesListEquals(
                      prev?.dayModesList ?? const [], next.dayModesList) ||
                  !mapEquals(prev?.dayModeByDate, next.dayModeByDate) ||
                  !mapEquals(prev?.weekdayDayModes, next.weekdayDayModes) ||
                  prev?.localeCode != next.localeCode ||
                  prev?.calendarSystem != next.calendarSystem ||
                  prev?.dayResetMinutes != next.dayResetMinutes;
          if (vaultOrToggleActivated) {
            ObsidianSyncService.instance.scheduleBackgroundSync(
              settings: next,
              immediate: true,
              forceFullWrite: true,
              onSynced: markObsidianSynced,
            );
          } else if (relevantSettingsChanged) {
            ObsidianSyncService.instance.scheduleBackgroundSync(
              settings: next,
              onSynced: markObsidianSynced,
            );
          }
        }

        final hasGoogleAcc = (next.googleAccountEmail ?? '').isNotEmpty;
        if (!hasGoogleAcc ||
            (!next.googleAutoSyncEnabled && !next.googleCalendarSyncEnabled)) {
          GoogleDriveSyncService.instance.cancelPendingSync();
        } else {
          final gToggledOn = prev?.googleAccountEmail != next.googleAccountEmail ||
              (prev?.googleAutoSyncEnabled != true &&
                  next.googleAutoSyncEnabled) ||
              (prev?.googleCalendarSyncEnabled != true &&
                  next.googleCalendarSyncEnabled);
          final gRelevantChanged = prev?.activeDayMode != next.activeDayMode ||
              !_dayModesListEquals(
                  prev?.dayModesList ?? const [], next.dayModesList) ||
              !mapEquals(prev?.dayModeByDate, next.dayModeByDate) ||
              !mapEquals(prev?.weekdayDayModes, next.weekdayDayModes) ||
              prev?.localeCode != next.localeCode ||
              prev?.calendarSystem != next.calendarSystem ||
              prev?.dayResetMinutes != next.dayResetMinutes;
          if (gToggledOn || gRelevantChanged) {
            GoogleDriveSyncService.instance.scheduleBackgroundSync(
              settings: next,
              immediate: gToggledOn,
              onSynced: (ts, reloadedDb, _) async {
                if (!ref.mounted) return;
                await markGoogleSynced(ts);
                if (!ref.mounted) return;
                if (reloadedDb) {
                  await ref
                      .read(habitStateProvider.notifier)
                      .reload(skipGoogleSync: true);
                }
              },
            );
          }
        }
      });

  Future<void> markObsidianSynced(int syncedAtMs) =>
      _serializeSettings(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastObsidianSyncMs', syncedAtMs);
        if (!ref.mounted) return;
        final cur = state.value;
        if (cur == null) return;
        state = AsyncData(cur.copyWith(lastObsidianSyncMs: syncedAtMs));
      });

  Future<void> markGoogleSynced(int syncedAtMs) =>
      _serializeSettings(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastGoogleSyncMs', syncedAtMs);
        if (!ref.mounted) return;
        final cur = state.value;
        if (cur == null) return;
        state = AsyncData(cur.copyWith(lastGoogleSyncMs: syncedAtMs));
      });

  /// Signs into user's Google account, automatically pulls & merges any existing
  /// cloud backup for that email, then pushes the merged snapshot + syncs calendar.
  Future<
      ({
        bool signedIn,
        bool mergedFromCloud,
        bool synced,
        bool cancelled,
        String? errorCode,
        String? errorMessage,
      })> signInAndSyncGoogle() async {
    final attempt = await GoogleDriveSyncService.instance.signInWithGoogleDetailed();
    final info = attempt.account;
    if (info == null || !ref.mounted) {
      return (
        signedIn: false,
        mergedFromCloud: false,
        synced: false,
        cancelled: attempt.cancelled,
        errorCode: attempt.errorCode,
        errorMessage: attempt.errorMessage,
      );
    }
    GoogleDriveSyncService.instance.cancelPendingSync();
    final cur = state.value ?? const AppSettings();
    var next = cur.copyWith(
      googleAccountEmail: info.email,
      googleAccountName: info.displayName,
      googleAutoSyncEnabled: true,
    );
    await updateSettings(next, skipSyncScheduling: true);
    if (!ref.mounted) {
      return (
        signedIn: false,
        mergedFromCloud: false,
        synced: false,
        cancelled: false,
        errorCode: null,
        errorMessage: null,
      );
    }

    var merged = false;
    final account =
        await GoogleDriveSyncService.instance.ensureSignedInAccount();
    if (!ref.mounted) {
      return (
        signedIn: true,
        mergedFromCloud: false,
        synced: false,
        cancelled: false,
        errorCode: null,
        errorMessage: null,
      );
    }
    if (account != null) {
      final pull = await GoogleDriveSyncService.instance
          .pullCloudBackupIntoLocalDb(account);
      if (!ref.mounted) {
        return (
          signedIn: true,
          mergedFromCloud: false,
          synced: false,
          cancelled: false,
          errorCode: null,
          errorMessage: null,
        );
      }
      if (pull.settingsMap != null) {
        final localHabitsEmpty =
            (ref.read(habitStateProvider).value?.habits.isEmpty ?? true);
        if (localHabitsEmpty) {
          await applyBackupSettingsMap(
            pull.settingsMap!,
            skipSyncScheduling: true,
          );
          if (!ref.mounted) {
            return (
              signedIn: true,
              mergedFromCloud: false,
              synced: false,
              cancelled: false,
              errorCode: null,
              errorMessage: null,
            );
          }
          next = (state.value ?? next).copyWith(
            googleAccountEmail: info.email,
            googleAccountName: info.displayName,
            googleAutoSyncEnabled: true,
          );
          await updateSettings(next, skipSyncScheduling: true);
        }
      }
      if (pull.merged && ref.mounted) {
        merged = true;
        await ref
            .read(habitStateProvider.notifier)
            .reload(skipGoogleSync: true);
      }
    }

    if (!ref.mounted) {
      return (
        signedIn: true,
        mergedFromCloud: merged,
        synced: false,
        cancelled: false,
        errorCode: null,
        errorMessage: null,
      );
    }
    final outcome = await GoogleDriveSyncService.instance.syncWithGoogleAccount(
      settings: state.value ?? next,
      pullFirst: false,
    );
    if (ref.mounted && outcome.syncedAtMs != null) {
      await markGoogleSynced(outcome.syncedAtMs!);
    }
    return (
      signedIn: true,
      mergedFromCloud: merged,
      synced: outcome.success,
      cancelled: false,
      errorCode: outcome.errorCode,
      errorMessage: null,
    );
  }

  Future<void> signOutGoogle() async {
    await GoogleDriveSyncService.instance.signOut();
    if (!ref.mounted) return;
    final cur = state.value ?? const AppSettings();
    await updateSettings(cur.copyWith(clearGoogleAccount: true));
  }

  Future<GoogleSyncOutcome> syncGoogleNow() async {
    final cur = state.value ?? const AppSettings();
    final out = await GoogleDriveSyncService.instance.syncWithGoogleAccount(
      settings: cur,
      pullFirst: true,
      interactiveSignIn: (cur.googleAccountEmail ?? '').isEmpty,
    );
    if (!ref.mounted) return out;
    if (out.mergedFromCloud) {
      await ref.read(habitStateProvider.notifier).reload(skipGoogleSync: true);
    }
    if (ref.mounted && out.syncedAtMs != null) {
      await markGoogleSynced(out.syncedAtMs!);
    }
    return out;
  }

  Future<void> applyBackupSettingsMap(
    Map<String, dynamic> m, {
    bool skipSyncScheduling = false,
  }) async {
    final cur = state.value ?? const AppSettings();
    final rawCustomPath = m['customStoragePath'] as String?;
    final rawWidgetId = m['widgetHabitId'] as String?;
    final next = cur.copyWith(
      localeCode: (m['localeCode'] as String?) ?? cur.localeCode,
      calendarSystem: CalendarSystem.values.asNameMap()[m['calendarSystem']] ??
          cur.calendarSystem,
      weekStartDay: WeekStartDay.values.asNameMap()[m['weekStartDay']] ??
          cur.weekStartDay,
      isDarkMode: (m['isDarkMode'] as bool?) ?? cur.isDarkMode,
      homeLayout:
          HomeLayout.values.asNameMap()[m['homeLayout']] ?? cur.homeLayout,
      widgetTheme: WidgetThemeMode.values.asNameMap()[m['widgetTheme']] ??
          cur.widgetTheme,
      soundProfile: SoundProfile.values.asNameMap()[m['soundProfile']] ??
          cur.soundProfile,
      fontScaleMode: FontScaleMode.values.asNameMap()[m['fontScaleMode']] ??
          cur.fontScaleMode,
      widgetCelebrationOverlay:
          (m['widgetCelebrationOverlay'] as bool?) ??
              cur.widgetCelebrationOverlay,
      customStoragePath: cur.customStoragePath ?? rawCustomPath,
      clearCustomStoragePath:
          cur.customStoragePath == null && rawCustomPath == null,
      dayResetMinutes:
          (m['dayResetMinutes'] as num?)?.toInt() ?? cur.dayResetMinutes,
      streakGraceDaysPerMonth:
          (m['streakGraceDaysPerMonth'] as num?)?.toInt() ??
              cur.streakGraceDaysPerMonth,
      homeRatePeriod:
          SuccessRatePeriod.values.asNameMap()[m['homeRatePeriod']] ??
              cur.homeRatePeriod,
      autoBackupEnabled:
          (m['autoBackupEnabled'] as bool?) ?? cur.autoBackupEnabled,
      autoBackupIntervalDays:
          (m['autoBackupIntervalDays'] as num?)?.toInt() ??
              cur.autoBackupIntervalDays,
      autoBackupHour:
          (m['autoBackupHour'] as num?)?.toInt() ?? cur.autoBackupHour,
      autoBackupMinute:
          (m['autoBackupMinute'] as num?)?.toInt() ?? cur.autoBackupMinute,
      autoBackupKeepCount:
          (m['autoBackupKeepCount'] as num?)?.toInt() ??
              cur.autoBackupKeepCount,
      quietHoursEnabled:
          (m['quietHoursEnabled'] as bool?) ?? cur.quietHoursEnabled,
      quietStartMinutes:
          (m['quietStartMinutes'] as num?)?.toInt() ?? cur.quietStartMinutes,
      quietEndMinutes:
          (m['quietEndMinutes'] as num?)?.toInt() ?? cur.quietEndMinutes,
      activeDayMode: (m['activeDayMode'] as String?) ?? cur.activeDayMode,
      customDayModes: m['customDayModes'] is List
          ? (m['customDayModes'] as List).map((e) => e.toString()).toList()
          : cur.customDayModes,
      dayModesList: m['dayModesList'] is List
          ? (m['dayModesList'] as List)
              .whereType<Map>()
              .map((e) => DayModeConfig.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : cur.dayModesList,
      allDayModeColorValue:
          (m['allDayModeColorValue'] as num?)?.toInt() ??
              cur.allDayModeColorValue,
      allDayModeIconKey:
          (m['allDayModeIconKey'] as String?) ?? cur.allDayModeIconKey,
      dayModeByDate: m['dayModeByDate'] is Map
          ? {
              for (final e in (m['dayModeByDate'] as Map).entries)
                e.key.toString(): e.value.toString(),
            }
          : cur.dayModeByDate,
      weekdayDayModes: m['weekdayDayModes'] is Map
          ? {
              for (final e in (m['weekdayDayModes'] as Map).entries)
                if (int.tryParse(e.key.toString()) case final k?)
                  k: e.value.toString(),
            }
          : cur.weekdayDayModes,
      // Preserve device-local SAF URIs and sync state on this device
      obsidianVaultUri: cur.obsidianVaultUri,
      obsidianSyncEnabled: cur.obsidianSyncEnabled,
      lastObsidianSyncMs: cur.lastObsidianSyncMs,
      googleDriveUri: cur.googleDriveUri,
      googleAccountEmail: cur.googleAccountEmail,
      googleAccountName: cur.googleAccountName,
      googleAutoSyncEnabled: cur.googleAutoSyncEnabled,
      googleCalendarSyncEnabled: cur.googleCalendarSyncEnabled,
      lastGoogleSyncMs: cur.lastGoogleSyncMs,
      isShowOnlyDueHabit:
          (m['isShowOnlyDueHabit'] as bool?) ?? cur.isShowOnlyDueHabit,
      isShowAddNoteInHome:
          (m['isShowAddNoteInHome'] as bool?) ?? cur.isShowAddNoteInHome,
      isConfettiEnabled:
          (m['isConfettiEnabled'] as bool?) ?? cur.isConfettiEnabled,
      isAchievementSoundEnabled: (m['isAchievementSoundEnabled'] as bool?) ??
          cur.isAchievementSoundEnabled,
      widgetHabitId: rawWidgetId,
      clearWidgetHabitId: rawWidgetId == null,
      widgetListHabitIds: m['widgetListHabitIds'] is List
          ? (m['widgetListHabitIds'] as List).map((e) => e.toString()).toList()
          : cur.widgetListHabitIds,
    );
    await updateSettings(next, skipSyncScheduling: skipSyncScheduling);
  }

  Future<void> addDayMode(DayModeConfig mode) async {
    final s = state.value ?? const AppSettings();
    final updated = [...s.dayModesList, mode];
    await updateSettings(s.copyWith(dayModesList: updated));
  }

  Future<void> updateDayMode({
    required String id,
    String? name,
    required int colorValue,
    required String iconKey,
  }) async {
    final s = state.value ?? const AppSettings();
    if (id == 'all') {
      await updateSettings(
        s.copyWith(
          allDayModeColorValue: colorValue,
          allDayModeIconKey: iconKey,
        ),
      );
      return;
    }
    final updated = [
      for (final d in s.dayModesList)
        d.id == id
            ? d.copyWith(
                name: name ?? d.name,
                colorValue: colorValue,
                iconKey: iconKey,
              )
            : d,
    ];
    await updateSettings(s.copyWith(dayModesList: updated));
  }

  Future<void> deleteDayMode(String id) async {
    if (id == 'all') return;
    final s = state.value ?? const AppSettings();
    final updatedList = s.dayModesList.where((d) => d.id != id).toList();
    final updatedCustom = s.customDayModes.where((e) => e != id).toList();
    final updatedDates = Map<String, String>.from(s.dayModeByDate)
      ..removeWhere((_, v) => v == id);
    final updatedWeekdays = Map<int, String>.from(s.weekdayDayModes)
      ..removeWhere((_, v) => v == id);
    final fallbackMode =
        updatedList.any((d) => d.id == 'normal') ? 'normal' : 'all';
    await updateSettings(
      s.copyWith(
        dayModesList: updatedList,
        customDayModes: updatedCustom,
        dayModeByDate: updatedDates,
        weekdayDayModes: updatedWeekdays,
        activeDayMode: s.activeDayMode == id ? fallbackMode : s.activeDayMode,
      ),
    );
    if (ref.mounted) {
      await ref
          .read(habitStateProvider.notifier)
          .stripDeletedDayMode(id, fallbackMode: fallbackMode);
    }
  }
}

List<DayModeConfig> _decodeDayModesList(
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

Map<String, String> _decodeStringMap(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final d = jsonDecode(raw);
    if (d is Map) {
      return {for (final e in d.entries) e.key.toString(): e.value.toString()};
    }
  } catch (_) {}
  return const {};
}

Map<int, String> _decodeIntStringMap(String? raw) {
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

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class XHabitState {
  XHabitState({
    required this.categories,
    required this.habits,
    required this.checklistItems,
    required this.completions,
    required this.notes,
    this.pauses = const [],
    this.oneOffTasks = const [],
    this.completionEvents = const [],
  }) {
    for (final i in checklistItems) {
      _checklistByHabit.putIfAbsent(i.habitId, () => []).add(i);
    }
    for (final c in completions) {
      _compByHabitDate.putIfAbsent(c.habitId, () => {})[c.dateKey] = c;
    }
    for (final n in notes) {
      _notesByHabit.putIfAbsent(n.habitId, () => []).add(n);
    }
    for (final p in pauses) {
      _pausesByHabit.putIfAbsent(p.habitId, () => []).add(p);
    }
    for (final t in oneOffTasks) {
      _tasksByKind.putIfAbsent(t.kind, () => []).add(t);
    }
    for (final e in completionEvents) {
      _eventsByHabit.putIfAbsent(e.habitId, () => []).add(e.minuteOfDay);
    }
  }

  final List<HabitCategory> categories;
  final List<Habit> habits;
  final List<HabitChecklistItem> checklistItems;
  final List<HabitCompletion> completions;
  final List<HabitNote> notes;
  final List<HabitPause> pauses;
  final List<OneOffTask> oneOffTasks;
  final List<CompletionEvent> completionEvents;

  final Map<String, List<HabitChecklistItem>> _checklistByHabit = {};
  final Map<String, Map<String, HabitCompletion>> _compByHabitDate = {};
  final Map<String, List<HabitNote>> _notesByHabit = {};
  final Map<String, List<HabitPause>> _pausesByHabit = {};
  final Map<OneOffKind, List<OneOffTask>> _tasksByKind = {};
  final Map<String, List<int>> _eventsByHabit = {};

  List<HabitChecklistItem> checklistFor(String habitId) =>
      _checklistByHabit[habitId] ?? const [];

  Map<String, HabitCompletion> completionsByDateFor(String habitId) =>
      _compByHabitDate[habitId] ?? const {};

  List<HabitNote> notesFor(String habitId) =>
      _notesByHabit[habitId] ?? const [];

  List<HabitPause> pausesFor(String habitId) =>
      _pausesByHabit[habitId] ?? const [];

  List<OneOffTask> oneOffTasksFor(OneOffKind kind) =>
      _tasksByKind[kind] ?? const [];

  List<int> completionMinutesFor(String habitId) {
    final specific = _eventsByHabit[habitId] ?? const [];
    if (specific.length >= 3) return specific;
    return completionEvents.map((e) => e.minuteOfDay).toList();
  }
}

class ActionFeedback {
  const ActionFeedback({
    required this.completedNow,
    this.unlockedMedalTier,
    this.allDailyCompleted = false,
  });

  final bool completedNow;
  final AchievementTier? unlockedMedalTier;
  final bool allDailyCompleted;
}

class HabitStateNotifier extends AsyncNotifier<XHabitState> {
  static const _uuid = Uuid();
  final AppDatabase _db = AppDatabase.instance;
  int _loadSeq = 0;
  Future<void> _mutationQueue = Future.value();

  Future<T> _serializeMutation<T>(Future<T> Function() fn) {
    final prev = _mutationQueue;
    final completer = Completer<void>();
    _mutationQueue = completer.future;
    return () async {
      try {
        await prev.catchError((_) {});
        return await fn();
      } finally {
        completer.complete();
      }
    }();
  }

  @override
  Future<XHabitState> build() async {
    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.hasValue
        ? settingsAsync.value!
        : await ref
            .read(settingsProvider.future)
            .catchError((_) => const AppSettings());
    final loaded = await _loadFromDb(settingsOverride: settings);
    await _syncPlatforms(loaded, settings);
    if (ref.mounted &&
        (settings.googleAccountEmail ?? '').isNotEmpty &&
        (settings.googleAutoSyncEnabled || settings.googleCalendarSyncEnabled)) {
      Future.microtask(() async {
        if (!ref.mounted) return;
        final out = await GoogleDriveSyncService.instance.syncWithGoogleAccount(
          settings: settings,
          pullFirst: true,
        );
        if (!ref.mounted) return;
        if (out.mergedFromCloud) {
          await reload(skipGoogleSync: true);
        }
        if (ref.mounted && out.syncedAtMs != null) {
          await ref
              .read(settingsProvider.notifier)
              .markGoogleSynced(out.syncedAtMs!);
        }
      });
    }
    return loaded;
  }

  Future<XHabitState> _loadFromDb({AppSettings? settingsOverride}) async {
    final settings = settingsOverride ??
        ref.read(settingsProvider).value ??
        const AppSettings();
    final isFa = settings.localeCode == 'fa';
    var categories = await _db.getCategories();
    if (categories.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final defaults = [
        HabitCategory(
          id: 'health',
          name: isFa ? 'سلامتی' : 'Health',
          colorValue: 0xFF00C48C,
          sortOrder: 0,
          updatedAtMs: now,
        ),
        HabitCategory(
          id: 'focus',
          name: isFa ? 'تمرکز' : 'Focus',
          colorValue: 0xFF3898FF,
          sortOrder: 1,
          updatedAtMs: now,
        ),
        HabitCategory(
          id: 'mind',
          name: isFa ? 'ذهن' : 'Mindset',
          colorValue: 0xFFB06CFF,
          sortOrder: 2,
          updatedAtMs: now,
        ),
      ];
      for (final c in defaults) {
        await _db.upsertCategory(c);
      }
      categories = await _db.getCategories();
    }
    final habits = await _db.getHabits(includeArchived: true);
    final checklistItems = await _db.getAllChecklistItems();
    final completions = await _db.getAllCompletions();
    final notes = await _db.getAllNotes();
    final pauses = await _db.getAllPauses();
    final oneOffTasks = await _db.getOneOffTasks();
    final completionEvents = await _db.getCompletionEvents();
    final loaded = XHabitState(
      categories: categories,
      habits: habits,
      checklistItems: checklistItems,
      completions: completions,
      notes: notes,
      pauses: pauses,
      oneOffTasks: oneOffTasks,
      completionEvents: completionEvents,
    );
    return loaded;
  }

  Future<void> _syncPlatforms(XHabitState loaded, AppSettings settings) async {
    await NotificationService.instance.syncAllHabitReminders(
      loaded.habits,
      isFa: settings.localeCode == 'fa',
      settings: settings,
      completions: loaded.completions,
      checklistItems: loaded.checklistItems,
      completionEvents: loaded.completionEvents,
      pauses: loaded.pauses,
    );
    if (!ref.mounted) return;
    await WidgetSyncService.instance.syncAll(
      habits: loaded.habits,
      checklistItems: loaded.checklistItems,
      completions: loaded.completions,
      pauses: loaded.pauses,
      oneOffTasks: loaded.oneOffTasks,
      settings: settings,
    );
  }

  Future<void> seedDemoStarterPack() async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final isFa = settings.localeCode == 'fa';
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final now = DateTime.now().millisecondsSinceEpoch;

    final h1 = Habit(
      id: 'h1',
      title: isFa ? 'دویدن و نرمش صبح' : 'Morning Run',
      description: '',
      mode: HabitMode.build,
      trackingStyle: TrackingStyle.boolean,
      frequencyType: FrequencyType.daily,
      weekdaysMask: 127,
      intervalDays: 1,
      targetCount: 1,
      countUnit: '',
      colorValue: 0xFFFFD426,
      iconKey: 'directions_run',
      categoryId: 'health',
      startDateKey: AppCalendar.toDateKey(
        DateTime(today.year, today.month, today.day - 146),
      ),
      sortOrder: 0,
      isArchived: false,
      reminderEnabled: false,
      dayModes: const ['normal', 'off'],
      updatedAtMs: now,
    );
    final h2 = Habit(
      id: 'h2',
      title: isFa ? 'نوشیدن ۸ لیوان آب' : 'Drink 8 Glasses Of Water',
      description: '',
      mode: HabitMode.build,
      trackingStyle: TrackingStyle.count,
      frequencyType: FrequencyType.daily,
      weekdaysMask: 127,
      intervalDays: 1,
      targetCount: 8,
      countUnit: isFa ? 'لیوان' : 'Glasses',
      colorValue: 0xFF3898FF,
      iconKey: 'water_drop',
      categoryId: 'health',
      startDateKey: AppCalendar.toDateKey(
        DateTime(today.year, today.month, today.day - 146),
      ),
      sortOrder: 1,
      isArchived: false,
      reminderEnabled: false,
      dayModes: const ['all'],
      updatedAtMs: now,
    );
    final h3 = Habit(
      id: 'h3',
      title: isFa ? 'کدنویسی روزانه' : 'Code Daily',
      description: '',
      mode: HabitMode.build,
      trackingStyle: TrackingStyle.boolean,
      frequencyType: FrequencyType.daily,
      weekdaysMask: 127,
      intervalDays: 1,
      targetCount: 1,
      countUnit: '',
      colorValue: 0xFFFF5C6C,
      iconKey: 'code',
      categoryId: 'focus',
      startDateKey: AppCalendar.toDateKey(
        DateTime(today.year, today.month, today.day - 146),
      ),
      sortOrder: 2,
      isArchived: false,
      reminderEnabled: false,
      dayModes: const ['normal', 'work'],
      updatedAtMs: now,
    );
    final h4 = Habit(
      id: 'h4',
      title: isFa ? 'روتین باشگاه' : 'Gym Routine',
      description: '',
      mode: HabitMode.build,
      trackingStyle: TrackingStyle.checklist,
      frequencyType: FrequencyType.daily,
      weekdaysMask: 127,
      intervalDays: 1,
      targetCount: 3,
      countUnit: '',
      colorValue: 0xFF00C48C,
      iconKey: 'fitness_center',
      categoryId: 'health',
      startDateKey: AppCalendar.toDateKey(
        DateTime(today.year, today.month, today.day - 146),
      ),
      sortOrder: 3,
      isArchived: false,
      reminderEnabled: false,
      dayModes: const ['normal', 'work', 'off'],
      updatedAtMs: now,
    );
    final h5 = Habit(
      id: 'h5',
      title: isFa ? 'بدون اسکرول بی‌هدف' : 'No Doomscrolling',
      description: '',
      mode: HabitMode.quit,
      trackingStyle: TrackingStyle.boolean,
      frequencyType: FrequencyType.daily,
      weekdaysMask: 127,
      intervalDays: 1,
      targetCount: 1,
      countUnit: '',
      colorValue: 0xFFB06CFF,
      iconKey: 'phonelink_erase',
      categoryId: 'mind',
      startDateKey: AppCalendar.toDateKey(
        DateTime(today.year, today.month, today.day - 146),
      ),
      sortOrder: 4,
      isArchived: false,
      reminderEnabled: false,
      dayModes: const ['all'],
      updatedAtMs: now,
    );

    final gymItems = [
      HabitChecklistItem(
        id: 'c1',
        habitId: 'h4',
        title: isFa ? '۱۰ دقیقه گرم کردن' : '10m Warm-up',
        sortOrder: 0,
        updatedAtMs: now,
      ),
      HabitChecklistItem(
        id: 'c2',
        habitId: 'h4',
        title: isFa ? 'تمرین قدرتی ۴۵ دقیقه' : '45m Strength Set',
        sortOrder: 1,
        updatedAtMs: now,
      ),
      HabitChecklistItem(
        id: 'c3',
        habitId: 'h4',
        title: isFa ? 'کشش و ریکاوری' : 'Stretch & Recovery',
        sortOrder: 2,
        updatedAtMs: now,
      ),
    ];

    await _db.upsertHabit(h1, const []);
    await _db.upsertHabit(h2, const []);
    await _db.upsertHabit(h3, const []);
    await _db.upsertHabit(h4, gymItems);
    await _db.upsertHabit(h5, const []);

    // Seed last 40 days of realistic completion patterns
    for (var i = 40; i >= 1; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      final k = AppCalendar.toDateKey(d);
      if (i % 5 != 0) {
        await _db.upsertCompletion(HabitCompletion(
          id: 'seed_h1_$k',
          habitId: 'h1',
          dateKey: k,
          value: 1,
          completedChecklistIds: const [],
          slipped: false,
          updatedAtMs: now,
        ));
      }
      if (i % 4 != 0) {
        await _db.upsertCompletion(HabitCompletion(
          id: 'seed_h2_$k',
          habitId: 'h2',
          dateKey: k,
          value: 8,
          completedChecklistIds: const [],
          slipped: false,
          updatedAtMs: now,
        ));
      }
      if (i % 3 != 0) {
        await _db.upsertCompletion(HabitCompletion(
          id: 'seed_h3_$k',
          habitId: 'h3',
          dateKey: k,
          value: 1,
          completedChecklistIds: const [],
          slipped: false,
          updatedAtMs: now,
        ));
      }
      if (i % 2 == 0) {
        await _db.upsertCompletion(HabitCompletion(
          id: 'seed_h4_$k',
          habitId: 'h4',
          dateKey: k,
          value: 1,
          completedChecklistIds: const ['c1', 'c2', 'c3'],
          slipped: false,
          updatedAtMs: now,
        ));
      }
      if (i != 9 && i != 23) {
        await _db.upsertCompletion(HabitCompletion(
          id: 'seed_h5_$k',
          habitId: 'h5',
          dateKey: k,
          value: 1,
          completedChecklistIds: const [],
          slipped: false,
          updatedAtMs: now,
        ));
      }
    }
    await _db.upsertCompletion(HabitCompletion(
      id: 'seed_h1_today',
      habitId: 'h1',
      dateKey: todayKey,
      value: 1,
      completedChecklistIds: const [],
      slipped: false,
      updatedAtMs: now,
    ));
    await _db.upsertCompletion(HabitCompletion(
      id: 'seed_h2_today',
      habitId: 'h2',
      dateKey: todayKey,
      value: 4,
      completedChecklistIds: const [],
      slipped: false,
      updatedAtMs: now,
    ));
    await _db.upsertCompletion(HabitCompletion(
      id: 'seed_h4_today',
      habitId: 'h4',
      dateKey: todayKey,
      value: 0,
      completedChecklistIds: const ['c1'],
      slipped: false,
      updatedAtMs: now,
    ));

    await _db.insertNote(HabitNote(
      id: _uuid.v4(),
      habitId: 'h1',
      dateKey: todayKey,
      kind: NoteKind.text,
      title: isFa ? 'رکورد جدید صبحگاهی' : 'New Morning Record',
      content: isFa
          ? 'امروز صبح ۲۵ دقیقه بدون توقف با ریتم منظم دویدم.'
          : 'Ran 25 mins non-stop with steady breathing.',
      durationMs: 0,
      createdAtMs: now,
      updatedAtMs: now,
    ));

    await reload();
  }

  Future<void> reload({
    bool skipObsidianSync = false,
    bool skipGoogleSync = false,
  }) async {
    final mySeq = ++_loadSeq;
    final loaded = await _loadFromDb();
    if (!ref.mounted || mySeq != _loadSeq) return;
    state = AsyncData(loaded);
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      await _syncPlatforms(loaded, settings);
      if (!ref.mounted || mySeq != _loadSeq) return;
    }
    if (settings == null) return;
    if (!skipObsidianSync &&
        settings.obsidianSyncEnabled &&
        settings.obsidianVaultUri != null &&
        settings.obsidianVaultUri!.isNotEmpty) {
      ObsidianSyncService.instance.scheduleBackgroundSync(
        settings: settings,
        onSynced: (ts) {
          if (ref.mounted) {
            ref.read(settingsProvider.notifier).markObsidianSynced(ts);
          }
        },
      );
    }
    if (!skipGoogleSync &&
        (settings.googleAccountEmail ?? '').isNotEmpty &&
        (settings.googleAutoSyncEnabled || settings.googleCalendarSyncEnabled)) {
      GoogleDriveSyncService.instance.scheduleBackgroundSync(
        settings: settings,
        onSynced: (ts, reloadedDb, _) async {
          if (!ref.mounted) return;
          await ref.read(settingsProvider.notifier).markGoogleSynced(ts);
          if (ref.mounted && reloadedDb) {
            await reload(skipGoogleSync: true);
          }
        },
      );
    }
  }

  Future<void> saveCategory(String name, int colorValue, {String? id}) async {
    final existing = state.value?.categories ?? const [];
    final prev = existing.where((e) => e.id == id).firstOrNull;
    final now = DateTime.now().millisecondsSinceEpoch;
    final category = HabitCategory(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      colorValue: colorValue,
      sortOrder: prev?.sortOrder ?? existing.length,
      updatedAtMs: now,
    );
    await _db.upsertCategory(category);
    await reload();
  }

  Future<bool> deleteCategorySafely(String categoryId) async {
    final cats = state.value?.categories ?? const [];
    if (cats.length <= 1) return false;
    final fallback = cats.firstWhere((c) => c.id != categoryId).id;
    await _db.softDeleteCategory(categoryId, fallbackCategoryId: fallback);
    await reload();
    return true;
  }

  Future<void> saveHabit(
    Habit habit,
    List<HabitChecklistItem> checklistItems,
  ) async {
    await _db.upsertHabit(habit, checklistItems);
    await reload();
  }

  Future<void> stripDeletedDayMode(
    String deletedModeId, {
    required String fallbackMode,
  }) =>
      _serializeMutation(() async {
        final habits = await _db.getHabits(includeArchived: true);
        final allChecklist = await _db.getAllChecklistItems();
        var changed = false;
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final h in habits) {
          final hasDeleted = h.dayModes.contains(deletedModeId);
          final legacyNormalDeleted =
              deletedModeId == 'normal' && h.dayModes.isEmpty;
          if (!hasDeleted && !legacyNormalDeleted) continue;
          final nextModes = hasDeleted
              ? h.dayModes.where((m) => m != deletedModeId).toList()
              : <String>[fallbackMode];
          final finalModes =
              nextModes.isEmpty ? <String>[fallbackMode] : nextModes;
          final items = allChecklist.where((i) => i.habitId == h.id).toList();
          await _db.upsertHabit(
            h.copyWith(dayModes: finalModes, updatedAtMs: now),
            items,
          );
          changed = true;
        }
        if (changed) await reload();
      });

  Future<void> toggleHabitDayMode(Habit habit, String modeId) =>
      _serializeMutation(() async {
        final settings = ref.read(settingsProvider).value ?? const AppSettings();
        final hasNormal = settings.dayModesList.any((d) => d.id == 'normal');
        final fallbackNonAll = hasNormal
            ? 'normal'
            : (settings.dayModesList.isNotEmpty
                ? settings.dayModesList.first.id
                : 'all');
        final normalized = habit.dayModes.isEmpty
            ? <String>[fallbackNonAll]
            : List<String>.from(habit.dayModes);
        late final List<String> nextModes;
        if (modeId == 'all') {
          nextModes = normalized.contains('all') ? [fallbackNonAll] : ['all'];
        } else if (normalized.contains('all')) {
          nextModes = [modeId];
        } else if (normalized.contains(modeId)) {
          final remaining = normalized.where((m) => m != modeId).toList();
          nextModes = remaining.isEmpty ? [fallbackNonAll] : remaining;
        } else {
          nextModes = [...normalized, modeId];
        }
        final items = state.value?.checklistFor(habit.id) ??
            (await _db.getAllChecklistItems())
                .where((i) => i.habitId == habit.id)
                .toList();
        await _db.upsertHabit(
          habit.copyWith(
            dayModes: nextModes,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
          items,
        );
        await reload();
      });

  Future<void> toggleArchiveHabit(Habit habit) =>
      _serializeMutation(() async {
        final updated = habit.copyWith(isArchived: !habit.isArchived);
        final items = state.value?.checklistFor(habit.id) ??
            (await _db.getAllChecklistItems())
                .where((i) => i.habitId == habit.id)
                .toList();
        await _db.upsertHabit(updated, items);
        await reload();
      });

  Future<void> reorderHabits(List<String> orderedIds) async {
    await _db.updateHabitOrder(orderedIds);
    await reload();
  }

  Future<void> deleteHabit(String habitId) async {
    await _db.softDeleteHabit(habitId);
    await NotificationService.instance.cancelHabitReminder(habitId);
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      final remainingList =
          settings.widgetListHabitIds.where((id) => id != habitId).toList();
      final nextWidgetId =
          settings.widgetHabitId == habitId ? null : settings.widgetHabitId;
      await ref.read(settingsProvider.notifier).updateSettings(
            settings.copyWith(
              widgetHabitId: nextWidgetId,
              clearWidgetHabitId: settings.widgetHabitId == habitId,
              widgetListHabitIds: remainingList,
            ),
          );
    }
    await reload();
  }

  Future<void> restoreCompletionSnapshot(
    Habit habit,
    DateTime date,
    HabitCompletion? previous,
  ) async {
    final key = AppCalendar.toDateKey(date);
    final now = DateTime.now().millisecondsSinceEpoch;
    final restored = previous ??
        HabitCompletion(
          id: _uuid.v4(),
          habitId: habit.id,
          dateKey: key,
          value: 0,
          completedChecklistIds: const [],
          slipped: false,
          updatedAtMs: now,
        );
    await _db.upsertCompletion(restored);
    await reload();
  }

  int _dueRemainingCount(XHabitState st, AppSettings s, DateTime today) {
    final todayKey = AppCalendar.toDateKey(today);
    var count = 0;
    final todayMode = HabitEngine.resolveDayMode(s, today);
    for (final h in st.habits) {
      if (h.isArchived) continue;
      if (HabitEngine.isPausedOn(h.id, today, st.pauses)) continue;
      if (!HabitEngine.matchesDayMode(h, todayMode)) continue;
      final byDate = st.completionsByDateFor(h.id);
      final items = st.checklistFor(h.id);
      if (HabitEngine.isScheduledOn(
            h,
            today,
            calendar: s.calendarSystem,
            weekStart: s.weekStartDay,
            completionsByDate: byDate,
            checklistItems: items,
            today: today,
          ) &&
          !HabitEngine.isCompletedOn(h, byDate[todayKey], items, today,
              today: today)) {
        count++;
      }
    }
    return count;
  }

  Future<ActionFeedback> toggleOrStepHabit(Habit habit, DateTime date) =>
      _serializeMutation(() async {
        final key = AppCalendar.toDateKey(date);
        final cur = state.value;
        final settings = ref.read(settingsProvider).value ?? const AppSettings();
        final today =
            AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
        final items = cur?.checklistFor(habit.id) ?? const [];
        final byDate = cur?.completionsByDateFor(habit.id) ?? const {};
        final oldBest = cur == null
            ? 0
            : HabitEngine.computeStats(
                habit,
                byDate,
                items,
                calendar: settings.calendarSystem,
                weekStart: settings.weekStartDay,
                today: today,
                pauses: cur.pauses,
                monthlyGraceDays: settings.streakGraceDaysPerMonth,
              ).bestStreak;
        final oldDue = cur == null ? 0 : _dueRemainingCount(cur, settings, today);

        final existing = byDate[key];
        final now = DateTime.now().millisecondsSinceEpoch;

        late final HabitCompletion nextComp;
        if (habit.isQuit) {
          final nextVal = (existing?.value ?? 0) >= 1 ? 0 : 1;
          nextComp = HabitCompletion(
            id: existing?.id ?? _uuid.v4(),
            habitId: habit.id,
            dateKey: key,
            value: nextVal,
            completedChecklistIds: existing?.completedChecklistIds ?? const [],
            slipped: false,
            updatedAtMs: now,
          );
        } else if (habit.trackingStyle == TrackingStyle.boolean) {
          final nextVal = (existing?.value ?? 0) >= 1 ? 0 : 1;
          nextComp = HabitCompletion(
            id: existing?.id ?? _uuid.v4(),
            habitId: habit.id,
            dateKey: key,
            value: nextVal,
            completedChecklistIds: existing?.completedChecklistIds ?? const [],
            slipped: false,
            updatedAtMs: now,
          );
        } else if (habit.trackingStyle == TrackingStyle.count) {
          final curVal = existing?.value ?? 0;
          final target = habit.targetCount < 1 ? 1 : habit.targetCount;
          final nextVal = curVal >= target ? 0 : curVal + 1;
          nextComp = HabitCompletion(
            id: existing?.id ?? _uuid.v4(),
            habitId: habit.id,
            dateKey: key,
            value: nextVal,
            completedChecklistIds: existing?.completedChecklistIds ?? const [],
            slipped: false,
            updatedAtMs: now,
          );
        } else {
          final allIds = items.map((e) => e.id).toList();
          final wasAll = allIds.isEmpty
              ? (existing?.value ?? 0) >= 1
              : allIds.every(
                  (id) => existing?.completedChecklistIds.contains(id) ?? false,
                );
          nextComp = HabitCompletion(
            id: existing?.id ?? _uuid.v4(),
            habitId: habit.id,
            dateKey: key,
            value: wasAll ? 0 : 1,
            completedChecklistIds: wasAll ? const [] : allIds,
            slipped: false,
            updatedAtMs: now,
          );
        }

        final nowDt = DateTime.now();
        await _db.upsertCompletion(nextComp);
        if (HabitEngine.isCompletedOn(habit, nextComp, items, date, today: today)) {
          await _db.recordCompletionEvent(habit.id, nowDt);
          await NotificationService.instance.cancelRepeatNudgesForHabit(habit.id);
        }
        await reload();
        return _evaluateFeedback(habit, nextComp, date, oldBest, oldDue);
      });

  Future<ActionFeedback> stepHabitCount(
    Habit habit,
    DateTime date,
    int delta,
  ) =>
      _serializeMutation(() async {
        final key = AppCalendar.toDateKey(date);
        final cur = state.value;
        final settings = ref.read(settingsProvider).value ?? const AppSettings();
        final today =
            AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
        final items = cur?.checklistFor(habit.id) ?? const [];
        final byDate = cur?.completionsByDateFor(habit.id) ?? const {};
        final oldBest = cur == null
            ? 0
            : HabitEngine.computeStats(
                habit,
                byDate,
                items,
                calendar: settings.calendarSystem,
                weekStart: settings.weekStartDay,
                today: today,
                pauses: cur.pauses,
                monthlyGraceDays: settings.streakGraceDaysPerMonth,
              ).bestStreak;
        final oldDue = cur == null ? 0 : _dueRemainingCount(cur, settings, today);
        final existing = byDate[key];
        final maxTarget = habit.targetCount < 1 ? 1 : habit.targetCount;
        final nextVal = ((existing?.value ?? 0) + delta).clamp(0, maxTarget);
        final nextComp = HabitCompletion(
          id: existing?.id ?? _uuid.v4(),
          habitId: habit.id,
          dateKey: key,
          value: nextVal,
          completedChecklistIds: existing?.completedChecklistIds ?? const [],
          slipped: false,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        final nowDt = DateTime.now();
        await _db.upsertCompletion(nextComp);
        if (HabitEngine.isCompletedOn(habit, nextComp, items, date, today: today)) {
          await _db.recordCompletionEvent(habit.id, nowDt);
          await NotificationService.instance.cancelRepeatNudgesForHabit(habit.id);
        }
        await reload();
        return _evaluateFeedback(habit, nextComp, date, oldBest, oldDue);
      });

  Future<ActionFeedback> toggleChecklistItem(
    Habit habit,
    DateTime date,
    String itemId,
  ) =>
      _serializeMutation(() async {
        final key = AppCalendar.toDateKey(date);
        final cur = state.value;
        final settings = ref.read(settingsProvider).value ?? const AppSettings();
        final today =
            AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
        final items = cur?.checklistFor(habit.id) ?? const [];
        final byDate = cur?.completionsByDateFor(habit.id) ?? const {};
        final oldBest = cur == null
            ? 0
            : HabitEngine.computeStats(
                habit,
                byDate,
                items,
                calendar: settings.calendarSystem,
                weekStart: settings.weekStartDay,
                today: today,
                pauses: cur.pauses,
                monthlyGraceDays: settings.streakGraceDaysPerMonth,
              ).bestStreak;
        final oldDue = cur == null ? 0 : _dueRemainingCount(cur, settings, today);

        final existing = byDate[key];
        final currentIds =
            List<String>.from(existing?.completedChecklistIds ?? const []);
        if (currentIds.contains(itemId)) {
          currentIds.remove(itemId);
        } else {
          currentIds.add(itemId);
        }
        final allDone =
            items.isNotEmpty && items.every((i) => currentIds.contains(i.id));
        final nextComp = HabitCompletion(
          id: existing?.id ?? _uuid.v4(),
          habitId: habit.id,
          dateKey: key,
          value: allDone ? 1 : 0,
          completedChecklistIds: currentIds,
          slipped: allDone ? false : (existing?.slipped ?? false),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        final nowDt = DateTime.now();
        await _db.upsertCompletion(nextComp);
        if (HabitEngine.isCompletedOn(habit, nextComp, items, date, today: today)) {
          await _db.recordCompletionEvent(habit.id, nowDt);
          await NotificationService.instance.cancelRepeatNudgesForHabit(habit.id);
        }
        await reload();
        return _evaluateFeedback(habit, nextComp, date, oldBest, oldDue);
      });

  ActionFeedback _evaluateFeedback(
    Habit habit,
    HabitCompletion nextComp,
    DateTime date,
    int oldBest,
    int oldDue,
  ) {
    final cur = state.value;
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final items = cur?.checklistFor(habit.id) ?? const [];
    final completedNow =
        HabitEngine.isCompletedOn(habit, nextComp, items, date, today: today);
    if (!completedNow || cur == null) {
      return const ActionFeedback(completedNow: false);
    }

    final newStats = HabitEngine.computeStats(
      habit,
      cur.completionsByDateFor(habit.id),
      items,
      calendar: settings.calendarSystem,
      weekStart: settings.weekStartDay,
      today: today,
      pauses: cur.pauses,
      monthlyGraceDays: settings.streakGraceDaysPerMonth,
    );
    AchievementTier? unlocked;
    for (final t in HabitEngine.achievementTiers) {
      if (oldBest < t.days && newStats.bestStreak >= t.days) {
        unlocked = t;
      }
    }
    final newDue = _dueRemainingCount(cur, settings, today);
    final allDone = AppCalendar.toDateKey(date) == AppCalendar.toDateKey(today) &&
        oldDue > 0 &&
        newDue == 0;
    return ActionFeedback(
      completedNow: true,
      unlockedMedalTier: unlocked,
      allDailyCompleted: allDone,
    );
  }

  Future<void> saveNote({
    String? id,
    required String habitId,
    required DateTime date,
    required NoteKind kind,
    String title = '',
    required String content,
    int durationMs = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = HabitNote(
      id: id ?? _uuid.v4(),
      habitId: habitId,
      dateKey: AppCalendar.toDateKey(date),
      kind: kind,
      title: title,
      content: content,
      durationMs: durationMs,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.insertNote(note);
    await reload();
  }

  Future<void> deleteNote(String noteId) async {
    await _db.softDeleteNote(noteId);
    await reload();
  }

  /// Pauses a habit from [date] onward, or resumes an active pause covering [date].
  /// Returns `true` if now paused, `false` if resumed.
  Future<bool> togglePauseHabit(Habit habit, DateTime date) async {
    final cur = state.value;
    final pauses = cur?.pausesFor(habit.id) ?? const <HabitPause>[];
    final norm = AppCalendar.normalizeDate(date);
    final dateKey = AppCalendar.toDateKey(norm);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final covering =
        pauses.where((p) => p.coversDateKey(dateKey)).toList();
    if (covering.isNotEmpty) {
      final prevKey = AppCalendar.toDateKey(
        DateTime(norm.year, norm.month, norm.day - 1),
      );
      for (final active in covering) {
        if (active.startDateKey.compareTo(dateKey) >= 0) {
          await _db.softDeletePause(active.id);
        } else {
          await _db.upsertPause(
            active.copyWith(endDateKey: prevKey, updatedAtMs: nowMs),
          );
        }
      }
      await reload();
      return false;
    } else {
      await _db.upsertPause(HabitPause(
        id: _uuid.v4(),
        habitId: habit.id,
        startDateKey: dateKey,
        endDateKey: null,
        updatedAtMs: nowMs,
      ));
      await reload();
      return true;
    }
  }

  Future<void> addOneOffTask({
    required String title,
    required OneOffKind kind,
    String quantity = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = OneOffTask(
      id: _uuid.v4(),
      title: title.trim(),
      kind: kind,
      quantity: quantity.trim(),
      isDone: false,
      sortOrder: state.value?.oneOffTasks.length ?? 0,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _db.upsertOneOffTask(task);
    await reload();
  }

  Future<void> updateOneOffTask(
    OneOffTask task, {
    required String title,
    String quantity = '',
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;
    await _db.upsertOneOffTask(
      task.copyWith(
        title: cleanTitle,
        quantity: quantity.trim(),
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await reload();
  }

  Future<void> toggleOneOffTask(OneOffTask task) async {
    await _db.upsertOneOffTask(
      task.copyWith(
        isDone: !task.isDone,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await reload();
  }

  Future<void> deleteOneOffTask(String taskId) async {
    await _db.softDeleteOneOffTask(taskId);
    await reload();
  }

  Future<void> clearCompletedOneOffTasks({OneOffKind? kind}) async {
    await _db.clearCompletedOneOffTasks(kind: kind);
    await reload();
  }

  Future<void> clearAllOneOffTasks() async {
    await _db.clearAllOneOffTasks();
    await reload();
  }

  Future<void> eraseAllData() async {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    ObsidianSyncService.instance.cancelPendingSync();
    GoogleDriveSyncService.instance.cancelPendingSync();
    await _db.eraseAllData();
    await NotificationService.instance.cancelAll();
    await ObsidianSyncService.instance.wipeXHabitVaultFolder(settings: settings);
    if (settings.googleAutoSyncEnabled || settings.googleCalendarSyncEnabled) {
      await ref.read(settingsProvider.notifier).updateSettings(
            settings.copyWith(
              googleAutoSyncEnabled: false,
              googleCalendarSyncEnabled: false,
            ),
            skipSyncScheduling: true,
          );
    }
    await reload(skipObsidianSync: true, skipGoogleSync: true);
  }
}

final habitStateProvider =
    AsyncNotifierProvider<HabitStateNotifier, XHabitState>(
        HabitStateNotifier.new);

final obsidianSyncPortProvider =
    Provider<ObsidianSyncPort>((ref) => ObsidianSyncService.instance);
final personalCloudSyncPortProvider =
    Provider<PersonalCloudSyncPort>((ref) => GoogleDriveSyncService.instance);
