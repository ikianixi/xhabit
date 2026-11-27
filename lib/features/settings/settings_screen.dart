import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/calendar/app_calendar.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/sync/cloud_drive_sync_service.dart';
import '../../core/sync/obsidian_sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_logos.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../habits/reorder_habits_screen.dart';
import '../security/app_lock_screen.dart';
import 'widgets_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _storage = FlutterSecureStorage();

  Future<void> _openLayoutSheet(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeLayoutLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 12),
          for (final opt in [
            (HomeLayout.grid, l10n.gridView, Icons.grid_view_rounded),
            (
              HomeLayout.list,
              l10n.listView,
              Icons.format_list_bulleted_rounded
            ),
          ]) ...[
            GestureDetector(
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(homeLayout: opt.$1));
                Navigator.pop(ctx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: settings.homeLayout == opt.$1 ? xc.lime : xc.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(opt.$3, size: 17, color: xc.text),
                        const SizedBox(width: 9),
                        Text(
                          opt.$2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: xc.text,
                          ),
                        ),
                      ],
                    ),
                    if (settings.homeLayout == opt.$1)
                      Icon(Icons.check_rounded, size: 16, color: xc.lime),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openGeneralSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final s = cRef.watch(settingsProvider).value ?? const AppSettings();
          final notifier = cRef.read(settingsProvider.notifier);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.generalSettings,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: xc.text,
                ),
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.languageLabel,
                child: Row(
                  children: [
                    _GenChip(
                      label: 'فارسی',
                      active: s.localeCode == 'fa',
                      onTap: () =>
                          notifier.updateSettings(s.copyWith(localeCode: 'fa')),
                    ),
                    const SizedBox(width: 6),
                    _GenChip(
                      label: 'English',
                      active: s.localeCode == 'en',
                      onTap: () =>
                          notifier.updateSettings(s.copyWith(localeCode: 'en')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GenRow(
                label: l10n.calendarSystem,
                child: Row(
                  children: [
                    _GenChip(
                      label: l10n.calendarJalali,
                      active: s.calendarSystem == CalendarSystem.jalali,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(calendarSystem: CalendarSystem.jalali)),
                    ),
                    const SizedBox(width: 6),
                    _GenChip(
                      label: l10n.calendarGregorian,
                      active: s.calendarSystem == CalendarSystem.gregorian,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(calendarSystem: CalendarSystem.gregorian)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GenRow(
                label: l10n.weekStartDay,
                child: Row(
                  children: [
                    _GenChip(
                      label: l10n.weekStartSaturday,
                      active: s.weekStartDay == WeekStartDay.saturday,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(weekStartDay: WeekStartDay.saturday)),
                    ),
                    const SizedBox(width: 5),
                    _GenChip(
                      label: l10n.weekStartMonday,
                      active: s.weekStartDay == WeekStartDay.monday,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(weekStartDay: WeekStartDay.monday)),
                    ),
                    const SizedBox(width: 5),
                    _GenChip(
                      label: l10n.weekStartSunday,
                      active: s.weekStartDay == WeekStartDay.sunday,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(weekStartDay: WeekStartDay.sunday)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GenRow(
                label: l10n.achievementSound,
                child: _GenChip(
                  label: s.isAchievementSoundEnabled
                      ? l10n.appLockStatusOn
                      : l10n.appLockStatusOff,
                  active: s.isAchievementSoundEnabled,
                  onTap: () {
                    final next = !s.isAchievementSoundEnabled;
                    notifier.updateSettings(
                        s.copyWith(isAchievementSoundEnabled: next));
                    if (next) {
                      SoundService.instance.play(ChimeKind.step,
                          enabled: true, profile: s.soundProfile);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              _GenRow(
                label: l10n.soundStyleLabel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, pair) in [
                      (SoundProfile.pop, l10n.soundPop),
                      (SoundProfile.drop, l10n.soundDrop),
                      (SoundProfile.wood, l10n.soundWood),
                      (SoundProfile.minimal, l10n.soundMinimal),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 4),
                      _GenChip(
                        label: pair.$2,
                        active: s.soundProfile == pair.$1,
                        onTap: () {
                          notifier.updateSettings(s.copyWith(
                            soundProfile: pair.$1,
                            isAchievementSoundEnabled: true,
                          ));
                          SoundService.instance.play(ChimeKind.done,
                              enabled: true, profile: pair.$1);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.fontSizeLabel,
                child: Row(
                  children: [
                    _GenChip(
                      label: l10n.fontSmall,
                      active: s.fontScaleMode == FontScaleMode.small,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(fontScaleMode: FontScaleMode.small)),
                    ),
                    const SizedBox(width: 5),
                    _GenChip(
                      label: l10n.fontMedium,
                      active: s.fontScaleMode == FontScaleMode.medium,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(fontScaleMode: FontScaleMode.medium)),
                    ),
                    const SizedBox(width: 5),
                    _GenChip(
                      label: l10n.fontLarge,
                      active: s.fontScaleMode == FontScaleMode.large,
                      onTap: () => notifier.updateSettings(
                          s.copyWith(fontScaleMode: FontScaleMode.large)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.dayResetLabel,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showXTimePickerSheet(
                      context: ctx,
                      title: l10n.dayResetLabel,
                      initialTime: TimeOfDay(
                        hour: s.dayResetMinutes ~/ 60,
                        minute: s.dayResetMinutes % 60,
                      ),
                      confirmLabel: l10n.save,
                      localeCode: s.localeCode,
                    );
                    if (picked != null) {
                      await notifier.updateSettings(
                        s.copyWith(
                          dayResetMinutes: picked.hour * 60 + picked.minute,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: xc.borderStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: xc.lime),
                        const SizedBox(width: 6),
                        Text(
                          AppCalendar.localizeDigits(
                            '${(s.dayResetMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.dayResetMinutes % 60).toString().padLeft(2, '0')}',
                            s.localeCode,
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: xc.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.dayResetHint,
                  style: TextStyle(fontSize: 11, color: xc.muted),
                ),
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.streakGraceLabel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => notifier.updateSettings(
                        s.copyWith(
                          streakGraceDaysPerMonth:
                              (s.streakGraceDaysPerMonth - 1).clamp(0, 7),
                        ),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: xc.border),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.remove_rounded,
                            size: 16, color: xc.text),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        AppCalendar.localizeDigits(
                          l10n.streakGraceDaysUnit(s.streakGraceDaysPerMonth),
                          s.localeCode,
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => notifier.updateSettings(
                        s.copyWith(
                          streakGraceDaysPerMonth:
                              (s.streakGraceDaysPerMonth + 1).clamp(0, 7),
                        ),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: xc.border),
                        ),
                        alignment: Alignment.center,
                        child:
                            Icon(Icons.add_rounded, size: 16, color: xc.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openRemindersSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final s = cRef.watch(settingsProvider).value ?? const AppSettings();
          final st = cRef.watch(habitStateProvider).value;
          final active = st?.habits.where((h) => !h.isArchived).toList() ??
              const <Habit>[];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.dailyRemindersTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final ok = await NotificationService.instance
                          .showTestNotification(isFa: s.localeCode == 'fa');
                      if (ctx.mounted) {
                        showXToast(
                          ctx,
                          ok
                              ? l10n.testNotificationSent
                              : l10n.notificationPermDenied,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: xc.lime.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: xc.lime),
                      ),
                      child: Text(
                        l10n.testNotification,
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
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: xc.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bedtime_outlined,
                            size: 17,
                            color: s.quietHoursEnabled ? xc.lime : xc.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.quietHoursLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                              Text(
                                l10n.quietHoursHint,
                                style: TextStyle(fontSize: 10.5, color: xc.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => cRef
                              .read(settingsProvider.notifier)
                              .updateSettings(s.copyWith(
                                  quietHoursEnabled: !s.quietHoursEnabled)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 38,
                            height: 22,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: s.quietHoursEnabled ? xc.lime : xc.card3,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: s.quietHoursEnabled
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: s.quietHoursEnabled
                                    ? HabitPalette.contrastFg(xc.lime)
                                    : xc.muted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s.quietHoursEnabled) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showXTimePickerSheet(
                                  context: ctx,
                                  title: l10n.quietStartLabel,
                                  initialTime: TimeOfDay(
                                    hour: s.quietStartMinutes ~/ 60,
                                    minute: s.quietStartMinutes % 60,
                                  ),
                                  confirmLabel: l10n.save,
                                  localeCode: s.localeCode,
                                );
                                if (picked != null && ctx.mounted) {
                                  final curS =
                                      cRef.read(settingsProvider).value ?? s;
                                  await cRef
                                      .read(settingsProvider.notifier)
                                      .updateSettings(curS.copyWith(
                                        quietStartMinutes:
                                            picked.hour * 60 + picked.minute,
                                      ));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: xc.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: xc.border),
                                ),
                                child: Text(
                                  '${l10n.quietStartLabel}: ${AppCalendar.localizeDigits('${(s.quietStartMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.quietStartMinutes % 60).toString().padLeft(2, '0')}', s.localeCode)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: xc.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showXTimePickerSheet(
                                  context: ctx,
                                  title: l10n.quietEndLabel,
                                  initialTime: TimeOfDay(
                                    hour: s.quietEndMinutes ~/ 60,
                                    minute: s.quietEndMinutes % 60,
                                  ),
                                  confirmLabel: l10n.save,
                                  localeCode: s.localeCode,
                                );
                                if (picked != null && ctx.mounted) {
                                  final curS =
                                      cRef.read(settingsProvider).value ?? s;
                                  await cRef
                                      .read(settingsProvider.notifier)
                                      .updateSettings(curS.copyWith(
                                        quietEndMinutes:
                                            picked.hour * 60 + picked.minute,
                                      ));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: xc.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: xc.border),
                                ),
                                child: Text(
                                  '${l10n.quietEndLabel}: ${AppCalendar.localizeDigits('${(s.quietEndMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.quietEndMinutes % 60).toString().padLeft(2, '0')}', s.localeCode)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: xc.text,
                                  ),
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
              if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      l10n.noHabitsYet,
                      style: TextStyle(fontSize: 13, color: xc.muted),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: active.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = active[i];
                      final accent = Color(h.colorValue);
                      final items = st?.checklistFor(h.id) ?? const [];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(HabitPalette.iconFor(h.iconKey),
                                size: 18, color: accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                            ),
                            if (h.reminderEnabled) ...[
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showXTimePickerSheet(
                                    context: ctx,
                                    title: l10n.reminderTime,
                                    initialTime: TimeOfDay(
                                      hour: h.reminderHour ?? 8,
                                      minute: h.reminderMinute ?? 30,
                                    ),
                                    confirmLabel: l10n.doneAction,
                                    localeCode: s.localeCode,
                                  );
                                  if (picked != null && ctx.mounted) {
                                    final st =
                                        cRef.read(habitStateProvider).value;
                                    final latest = st?.habits
                                            .where((x) => x.id == h.id)
                                            .firstOrNull ??
                                        h;
                                    final curItems =
                                        st?.checklistFor(h.id) ?? items;
                                    await cRef
                                        .read(habitStateProvider.notifier)
                                        .saveHabit(
                                          latest.copyWith(
                                            reminderHour: picked.hour,
                                            reminderMinute: picked.minute,
                                          ),
                                          curItems,
                                        );
                                  }
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsetsDirectional.only(end: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: xc.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: xc.border),
                                  ),
                                  child: Text(
                                    AppCalendar.localizeDigits(
                                      '${(h.reminderHour ?? 8).toString().padLeft(2, '0')}:${(h.reminderMinute ?? 30).toString().padLeft(2, '0')}',
                                      s.localeCode,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: xc.text,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            GestureDetector(
                              onTap: () async {
                                final enabling = !h.reminderEnabled;
                                if (enabling) {
                                  await NotificationService.instance
                                      .requestPermissions();
                                }
                                if (!ctx.mounted) return;
                                final st =
                                    cRef.read(habitStateProvider).value;
                                final latest = st?.habits
                                        .where((x) => x.id == h.id)
                                        .firstOrNull ??
                                    h;
                                final curItems = st?.checklistFor(h.id) ?? items;
                                await cRef
                                    .read(habitStateProvider.notifier)
                                    .saveHabit(
                                      latest.copyWith(
                                        reminderEnabled: enabling,
                                        reminderHour: latest.reminderHour ?? 8,
                                        reminderMinute:
                                            latest.reminderMinute ?? 30,
                                      ),
                                      curItems,
                                    );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 38,
                                height: 22,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: h.reminderEnabled ? accent : xc.card3,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: h.reminderEnabled
                                    ? AlignmentDirectional.centerEnd
                                    : AlignmentDirectional.centerStart,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: h.reminderEnabled
                                        ? HabitPalette.contrastFg(accent)
                                        : xc.muted,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPinFlow(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;

    if (settings.isAppLockEnabled) {
      final choice = await showXModalSheet<String>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appLock,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: xc.text,
              ),
            ),
            const SizedBox(height: 12),
            _SheetPillRow(
              label: l10n.lockAppNow,
              onTap: () => Navigator.pop(ctx, 'lock_now'),
            ),
            const SizedBox(height: 8),
            _SheetPillRow(
              label: l10n.changePasscode,
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            const SizedBox(height: 8),
            _SheetPillRow(
              label: l10n.disablePasscode,
              color: const Color(0xFFEF4444),
              onTap: () => Navigator.pop(ctx, 'disable'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (choice == 'lock_now') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (lCtx) => PopScope(
              canPop: false,
              child: AppLockScreen(onUnlocked: () => Navigator.pop(lCtx)),
            ),
          ),
        );
        return;
      } else if (choice == 'disable') {
        final verified = await _promptPinKeypad(
          context,
          title: l10n.enterPasscode,
          verifyAgainstStored: true,
        );
        if (verified != null && context.mounted) {
          await _storage.delete(key: 'xhabit_pin');
          if (!context.mounted) return;
          final curSettings = ref.read(settingsProvider).value ?? settings;
          await ref
              .read(settingsProvider.notifier)
              .updateSettings(curSettings.copyWith(isAppLockEnabled: false));
          if (context.mounted) {
            showXToast(context, l10n.disablePasscode);
          }
        }
        return;
      } else if (choice == 'change') {
        final verified = await _promptPinKeypad(
          context,
          title: l10n.enterPasscode,
          verifyAgainstStored: true,
        );
        if (verified == null || !context.mounted) return;
      } else {
        return;
      }
    }

    if (!context.mounted) return;
    final first = await _promptPinKeypad(context, title: l10n.setPasscode);
    if (first == null || !context.mounted) return;
    final second =
        await _promptPinKeypad(context, title: l10n.confirmPasscode);
    if (second == null || !context.mounted) return;

    if (first != second) {
      showXToast(context, l10n.passcodeMismatch);
      return;
    }
    await _storage.write(key: 'xhabit_pin', value: first);
    if (!context.mounted) return;
    final curSettings = ref.read(settingsProvider).value ?? settings;
    await ref
        .read(settingsProvider.notifier)
        .updateSettings(curSettings.copyWith(isAppLockEnabled: true));
    if (context.mounted) {
      showXToast(context, l10n.appLockStatusOn);
    }
  }

  Future<String?> _promptPinKeypad(
    BuildContext context, {
    required String title,
    bool verifyAgainstStored = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    var entry = '';
    var verifying = false;
    String? errorMsg;

    return showXModalSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '<', '0', 'X'];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: xc.lime.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.lock_outline_rounded,
                        size: 21, color: xc.lime),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: xc.text,
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = entry.length > i;
                        return Container(
                          width: 13,
                          height: 13,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? xc.lime : Colors.transparent,
                            border: Border.all(
                              color: filled ? xc.lime : xc.borderStrong,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.75,
                      children: keys.map((k) {
                      return GestureDetector(
                        onTap: () async {
                          if (k == 'X') {
                            Navigator.pop(ctx);
                            return;
                          }
                          if (verifying) return;
                          if (k == '<') {
                            if (entry.isNotEmpty) {
                              setLocal(() {
                                entry = entry.substring(0, entry.length - 1);
                                errorMsg = null;
                              });
                            }
                            return;
                          }
                          if (entry.length >= 4) return;
                          final attempt = '$entry$k';
                          setLocal(() {
                            entry = attempt;
                            errorMsg = null;
                          });
                          if (attempt.length == 4) {
                            if (verifyAgainstStored) {
                              verifying = true;
                              try {
                                final saved =
                                    await _storage.read(key: 'xhabit_pin');
                                if (!ctx.mounted) return;
                                if (saved != null &&
                                    saved.isNotEmpty &&
                                    attempt == saved) {
                                  Navigator.pop(ctx, attempt);
                                } else {
                                  setLocal(() {
                                    entry = '';
                                    errorMsg = l10n.wrongPasscode;
                                  });
                                }
                              } catch (_) {
                                if (!ctx.mounted) return;
                                setLocal(() {
                                  entry = '';
                                  errorMsg = l10n.wrongPasscode;
                                });
                              } finally {
                                verifying = false;
                              }
                            } else {
                              Navigator.pop(ctx, attempt);
                            }
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: xc.card2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: xc.border),
                          ),
                          alignment: Alignment.center,
                          child: k == '<'
                              ? Icon(Icons.backspace_outlined,
                                  size: 17, color: xc.text)
                              : k == 'X'
                                  ? Icon(Icons.close_rounded,
                                      size: 17, color: xc.muted)
                                  : Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: xc.text,
                                      ),
                                    ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Future<void> _openCategoriesSheet(BuildContext context, WidgetRef ref) async {
    final addCtrl = TextEditingController();
    final editCtrl = TextEditingController();
    String? editingCatId;
    var addingCat = false;
    final xc = context.xc;

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Consumer(
          builder: (ctx, cRef, _) {
            final l10n = AppLocalizations.of(ctx);
            final cats =
                cRef.watch(habitStateProvider).value?.categories ?? const [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.categoriesLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                ),
                const SizedBox(height: 12),
                ...cats.map((c) {
                  if (editingCatId == c.id) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                        color: xc.card2,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: XDarkField(
                              controller: editCtrl,
                              hintText: l10n.renameCategoryHint,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 7),
                              onSubmitted: (_) async {
                                final v = editCtrl.text.trim();
                                if (v.isNotEmpty) {
                                  await cRef
                                      .read(habitStateProvider.notifier)
                                      .saveCategory(v, c.colorValue, id: c.id);
                                }
                                if (ctx.mounted) {
                                  setLocal(() => editingCatId = null);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              final v = editCtrl.text.trim();
                              if (v.isNotEmpty) {
                                await cRef
                                    .read(habitStateProvider.notifier)
                                    .saveCategory(v, c.colorValue, id: c.id);
                              }
                              if (ctx.mounted) {
                                setLocal(() => editingCatId = null);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: xc.lime,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(Icons.check_rounded,
                                  size: 16,
                                  color: HabitPalette.contrastFg(xc.lime)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: xc.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                editCtrl.text = c.name;
                                setLocal(() => editingCatId = c.id);
                              },
                              child: Icon(Icons.edit_outlined,
                                  size: 16, color: xc.muted),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () async {
                                final removed = await cRef
                                    .read(habitStateProvider.notifier)
                                    .deleteCategorySafely(c.id);
                                if (!removed && ctx.mounted) {
                                  showXToast(ctx, l10n.keepOneCategory);
                                }
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: XDarkField(
                        controller: addCtrl,
                        hintText: l10n.newCategory,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 9),
                        onSubmitted: (_) async {
                          if (addingCat) return;
                          final v = addCtrl.text.trim();
                          if (v.isEmpty) return;
                          addingCat = true;
                          try {
                            await cRef
                                .read(habitStateProvider.notifier)
                                .saveCategory(v, 0xFF84CC16);
                            if (ctx.mounted) addCtrl.clear();
                          } finally {
                            addingCat = false;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        if (addingCat) return;
                        final v = addCtrl.text.trim();
                        if (v.isEmpty) return;
                        addingCat = true;
                        try {
                          await cRef
                              .read(habitStateProvider.notifier)
                              .saveCategory(v, 0xFF84CC16);
                          if (ctx.mounted) addCtrl.clear();
                        } finally {
                          addingCat = false;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
            );
          },
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      addCtrl.dispose();
      editCtrl.dispose();
    });
  }

  Future<void> _openArchiveSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final arch = cRef
                  .watch(habitStateProvider)
                  .value
                  ?.habits
                  .where((h) => h.isArchived)
                  .toList() ??
              const <Habit>[];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.archivedHabits,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: xc.text,
                ),
              ),
              const SizedBox(height: 12),
              if (arch.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      l10n.noArchivedHabits,
                      style: TextStyle(fontSize: 13, color: xc.muted),
                    ),
                  ),
                )
              else
                ...arch.map(
                  (h) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(HabitPalette.iconFor(h.iconKey),
                            size: 18, color: Color(h.colorValue)),
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => cRef
                              .read(habitStateProvider.notifier)
                              .toggleArchiveHabit(h),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: xc.card,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: xc.border),
                            ),
                            child: Text(
                              l10n.unarchive,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            final ok = await showXConfirmSheet(
                              context: ctx,
                              icon: Icons.delete_rounded,
                              title: l10n.delete,
                              message: l10n.deleteHabitConfirm,
                              cancelLabel: l10n.noCancel,
                              confirmLabel: l10n.yesDelete,
                            );
                            if (ok && ctx.mounted) {
                              await cRef
                                  .read(habitStateProvider.notifier)
                                  .deleteHabit(h.id);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: xc.card,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: xc.border),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                size: 17, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _downloadBackup(
      BuildContext context, AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final jsonStr =
        await AppDatabase.instance.exportBackupJson(settings: settings);
    final fileName =
        'xhabit_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final savedPath = await LocalStorageService.instance.downloadBackupJson(
      fileName: fileName,
      jsonContent: jsonStr,
    );
    if (context.mounted) {
      showXToast(
        context,
        savedPath != null
            ? '${l10n.backupDownloaded}: $savedPath'
            : l10n.backupSuccess,
      );
    }
  }

  Future<void> _shareBackup(
      BuildContext context, AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final jsonStr =
        await AppDatabase.instance.exportBackupJson(settings: settings);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(
      dir.path,
      'xhabit_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    ));
    await file.writeAsString(jsonStr);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'XHabit Backup'),
    );
    if (context.mounted) {
      showXToast(context, l10n.backupSuccess);
    }
  }

  Future<void> _openStorageFolderSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final s = cRef.watch(settingsProvider).value ?? const AppSettings();
          final displayFolder = s.customStoragePath == null
              ? l10n.storageDefaultLabel
              : Uri.decodeFull(s.customStoragePath!.split('/').last);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.storageFolderLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: xc.text,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: xc.border),
                ),
                child: Text(
                  displayFolder,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: xc.muted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedUri = await LocalStorageService.instance
                            .pickDeviceFolder();
                        if (pickedUri != null && ctx.mounted) {
                          final cur = cRef.read(settingsProvider).value ?? s;
                          final next =
                              cur.copyWith(customStoragePath: pickedUri);
                          await cRef
                              .read(settingsProvider.notifier)
                              .updateSettings(next);
                          await LocalStorageService.instance
                              .syncOrganizedFolder(settings: next);
                          if (ctx.mounted) {
                            showXToast(ctx, l10n.folderSynced);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: xc.borderStrong),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.chooseFolder,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: xc.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final cur = cRef.read(settingsProvider).value ?? s;
                        await LocalStorageService.instance
                            .syncOrganizedFolder(settings: cur);
                        if (ctx.mounted) {
                          showXToast(ctx, l10n.folderSynced);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: xc.lime,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          l10n.syncFolderNow,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: HabitPalette.contrastFg(xc.lime),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAutoBackupSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    var runningBackup = false;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, cRef, _) {
          final l10n = AppLocalizations.of(ctx);
          final s = cRef.watch(settingsProvider).value ?? const AppSettings();
          final notifier = cRef.read(settingsProvider.notifier);
          final lastText = s.lastAutoBackupMs == null
              ? l10n.neverBackedUp
              : AppCalendar.monthDayLabel(
                  DateTime.fromMillisecondsSinceEpoch(s.lastAutoBackupMs!),
                  s.calendarSystem,
                  s.localeCode,
                );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.autoBackupTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => notifier.updateSettings(
                        s.copyWith(autoBackupEnabled: !s.autoBackupEnabled)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 42,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: s.autoBackupEnabled ? xc.lime : xc.card3,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: s.autoBackupEnabled
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: s.autoBackupEnabled
                              ? HabitPalette.contrastFg(xc.lime)
                              : xc.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.autoBackupIntervalLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: xc.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _GenChip(
                    label: l10n.autoBackupDaily,
                    active: s.autoBackupIntervalDays == 1,
                    onTap: () => notifier
                        .updateSettings(s.copyWith(autoBackupIntervalDays: 1)),
                  ),
                  _GenChip(
                    label: l10n.autoBackupEvery3Days,
                    active: s.autoBackupIntervalDays == 3,
                    onTap: () => notifier
                        .updateSettings(s.copyWith(autoBackupIntervalDays: 3)),
                  ),
                  _GenChip(
                    label: l10n.autoBackupWeekly,
                    active: s.autoBackupIntervalDays == 7,
                    onTap: () => notifier
                        .updateSettings(s.copyWith(autoBackupIntervalDays: 7)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.autoBackupTimeLabel,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showXTimePickerSheet(
                      context: ctx,
                      title: l10n.autoBackupTimeLabel,
                      initialTime: TimeOfDay(
                        hour: s.autoBackupHour,
                        minute: s.autoBackupMinute,
                      ),
                      confirmLabel: l10n.save,
                      localeCode: s.localeCode,
                    );
                    if (picked != null) {
                      await notifier.updateSettings(s.copyWith(
                        autoBackupHour: picked.hour,
                        autoBackupMinute: picked.minute,
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: xc.borderStrong),
                    ),
                    child: Text(
                      AppCalendar.localizeDigits(
                        '${s.autoBackupHour.toString().padLeft(2, '0')}:${s.autoBackupMinute.toString().padLeft(2, '0')}',
                        s.localeCode,
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: xc.text,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _GenRow(
                label: l10n.autoBackupKeepLabel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => notifier.updateSettings(
                        s.copyWith(
                          autoBackupKeepCount:
                              (s.autoBackupKeepCount - 1).clamp(1, 30),
                        ),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: xc.border),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.remove_rounded,
                            size: 16, color: xc.text),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        AppCalendar.localizeDigits(
                          l10n.autoBackupCountUnit(s.autoBackupKeepCount),
                          s.localeCode,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => notifier.updateSettings(
                        s.copyWith(
                          autoBackupKeepCount:
                              (s.autoBackupKeepCount + 1).clamp(1, 30),
                        ),
                      ),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: xc.card2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: xc.border),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.add_rounded, size: 16, color: xc.text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${l10n.lastAutoBackupLabel}: $lastText',
                style: TextStyle(fontSize: 11, color: xc.muted),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  if (runningBackup) return;
                  runningBackup = true;
                  try {
                    final curS = cRef.read(settingsProvider).value ?? s;
                    final res = await LocalStorageService.instance
                        .runScheduledAutoBackupIfDue(curS, force: true);
                    if (res != null && ctx.mounted) {
                      await notifier.updateSettings(
                          curS.copyWith(lastAutoBackupMs: res.savedAtMs));
                      if (ctx.mounted) {
                        showXToast(ctx, l10n.autoBackupDoneToast);
                      }
                    } else if (ctx.mounted) {
                      showXToast(ctx, l10n.autoBackupFailedToast);
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      showXToast(ctx, l10n.autoBackupFailedToast);
                    }
                  } finally {
                    runningBackup = false;
                  }
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
                    l10n.autoBackupRunNow,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: HabitPalette.contrastFg(xc.lime),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openObsidianSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    var obsBusy = false;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Consumer(
          builder: (ctx, cRef, _) {
            final l10n = AppLocalizations.of(ctx);
            final s = cRef.watch(settingsProvider).value ?? const AppSettings();
            final notifier = cRef.read(settingsProvider.notifier);
            final hasVault =
                s.obsidianVaultUri != null && s.obsidianVaultUri!.isNotEmpty;
            String safeDecodeSegment(String raw) {
              try {
                return Uri.decodeFull(raw);
              } catch (_) {
                return raw;
              }
            }
            final vaultName = hasVault
                ? safeDecodeSegment(s.obsidianVaultUri!.split('/').last)
                : l10n.obsidianVaultUnset;
            final lastSyncDt = s.lastObsidianSyncMs != null
                ? DateTime.fromMillisecondsSinceEpoch(s.lastObsidianSyncMs!)
                : null;
            final lastSyncStr = lastSyncDt == null
                ? null
                : '${AppCalendar.monthDayLabel(lastSyncDt, s.calendarSystem, s.localeCode)} ${lastSyncDt.hour.toString().padLeft(2, '0')}:${lastSyncDt.minute.toString().padLeft(2, '0')}';

            Future<void> pickVault({bool enableSyncIfPicked = true}) async {
              if (obsBusy) return;
              final uri = await LocalStorageService.instance.pickDeviceFolder();
              if (uri != null && ctx.mounted) {
                final curS = cRef.read(settingsProvider).value ?? s;
                await notifier.updateSettings(
                  curS.copyWith(
                    obsidianVaultUri: uri,
                    obsidianSyncEnabled:
                        enableSyncIfPicked ? true : curS.obsidianSyncEnabled,
                  ),
                );
              }
            }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ObsidianLogoIcon(size: 22),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        l10n.obsidianTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.obsidianSub,
                  style: TextStyle(fontSize: 12, color: xc.muted),
                ),
                const SizedBox(height: 14),

                // Step 1: Pick or display Obsidian Vault folder
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasVault
                          ? xc.lime.withValues(alpha: 0.45)
                          : xc.borderStrong,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasVault
                                ? Icons.folder_open_rounded
                                : Icons.create_new_folder_outlined,
                            size: 18,
                            color: hasVault ? xc.lime : xc.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasVault ? '$vaultName / XHabit' : vaultName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => pickVault(enableSyncIfPicked: true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: hasVault ? xc.card : xc.lime,
                            borderRadius: BorderRadius.circular(10),
                            border: hasVault
                                ? Border.all(color: xc.borderStrong)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            hasVault
                                ? l10n.obsidianChangeVault
                                : l10n.obsidianPickVault,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: hasVault
                                  ? xc.text
                                  : HabitPalette.contrastFg(xc.lime),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Automatic Sync Toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: xc.card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: xc.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.obsidianAutoSyncToggle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.obsidianAutoSyncHint,
                              style: TextStyle(
                                fontSize: 11,
                                color: xc.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: s.obsidianSyncEnabled && hasVault,
                        activeTrackColor: xc.lime,
                        activeThumbColor: HabitPalette.contrastFg(xc.lime),
                        onChanged: (val) async {
                          if (obsBusy) return;
                          if (val && !hasVault) {
                            await pickVault(enableSyncIfPicked: true);
                            return;
                          }
                          final curS = cRef.read(settingsProvider).value ?? s;
                          await notifier.updateSettings(
                            curS.copyWith(obsidianSyncEnabled: val),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (hasVault) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (lastSyncStr != null)
                        Expanded(
                          child: Text(
                            AppCalendar.localizeDigits(
                              l10n.obsidianLastSyncedLabel(lastSyncStr),
                              s.localeCode,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: xc.muted,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          if (obsBusy) return;
                          setModalState(() => obsBusy = true);
                          try {
                            final curS =
                                cRef.read(settingsProvider).value ?? s;
                            final res = await ObsidianSyncService.instance
                                .syncFullVaultNow(
                              settings: curS,
                              forceFullWrite: true,
                            );
                            if (res.success && ctx.mounted) {
                              await notifier
                                  .markObsidianSynced(res.newRevision);
                              if (ctx.mounted) {
                                showXToast(ctx, l10n.obsidianExportedToast);
                              }
                            } else if (ctx.mounted) {
                              showXToast(ctx, l10n.obsidianExportFailedToast);
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              showXToast(ctx, l10n.obsidianExportFailedToast);
                            }
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => obsBusy = false);
                            } else {
                              obsBusy = false;
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: xc.lime,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: obsBusy
                              ? SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: HabitPalette.contrastFg(xc.lime),
                                  ),
                                )
                              : Text(
                                  l10n.obsidianExportNow,
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

                const SizedBox(height: 14),

                // Plain, non-technical explanation card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: xc.card2.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: xc.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.obsidianHowItWorksTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: xc.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final point in [
                        l10n.obsidianGuidePoint1,
                        l10n.obsidianGuidePoint2,
                        l10n.obsidianGuidePoint3,
                        l10n.obsidianGuidePoint4,
                      ]) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: xc.lime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  point,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.45,
                                    color: xc.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
          },
        ),
      ),
    );
  }

  Future<void> _openGoogleSyncSheet(BuildContext context, WidgetRef ref) async {
    final xc = context.xc;
    var busy = false;
    String? inlineFeedback;
    var inlineFeedbackIsError = false;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Consumer(
          builder: (ctx, cRef, _) {
            final l10n = AppLocalizations.of(ctx);
            final s = cRef.watch(settingsProvider).value ?? const AppSettings();
            final st = cRef.watch(habitStateProvider).value;
            final activeHabits =
                st?.habits.where((h) => !h.isArchived).toList() ??
                    const <Habit>[];
            final notifier = cRef.read(settingsProvider.notifier);
            final isSignedIn = (s.googleAccountEmail ?? '').isNotEmpty;
            final lastDt = s.lastGoogleSyncMs != null
                ? DateTime.fromMillisecondsSinceEpoch(s.lastGoogleSyncMs!)
                : null;
            final lastStr = lastDt == null
                ? null
                : '${AppCalendar.monthDayLabel(lastDt, s.calendarSystem, s.localeCode)} ${lastDt.hour.toString().padLeft(2, '0')}:${lastDt.minute.toString().padLeft(2, '0')}';

            Future<bool> handleSignIn() async {
              if (busy) return false;
              setModalState(() {
                busy = true;
                inlineFeedback = null;
                inlineFeedbackIsError = false;
              });
              try {
                final res = await notifier.signInAndSyncGoogle();
                if (ctx.mounted) {
                  if (!res.signedIn) {
                    if (!res.cancelled) {
                      final code = res.errorCode ?? '';
                      final msg = (res.errorMessage ?? '').trim();
                      final detail = [
                        if (code.isNotEmpty) code,
                        if (msg.isNotEmpty)
                          msg.length > 140 ? '${msg.substring(0, 140)}...' : msg,
                      ].join(': ');
                      final fullMsg = detail.isEmpty
                          ? l10n.googleSyncOfflineToast
                          : '${l10n.googleSyncOfflineToast} ($detail)';
                      setModalState(() {
                        inlineFeedback = fullMsg;
                        inlineFeedbackIsError = true;
                      });
                      showXToast(ctx, fullMsg);
                    }
                  } else if (res.mergedFromCloud) {
                    setModalState(() {
                      inlineFeedback = l10n.googleSignedInMergedToast;
                      inlineFeedbackIsError = false;
                    });
                    showXToast(ctx, l10n.googleSignedInMergedToast);
                  } else if (res.synced) {
                    setModalState(() {
                      inlineFeedback = l10n.googleDriveSyncedToast;
                      inlineFeedbackIsError = false;
                    });
                    showXToast(ctx, l10n.googleDriveSyncedToast);
                  } else {
                    setModalState(() {
                      inlineFeedback = l10n.googleSyncOfflineToast;
                      inlineFeedbackIsError = true;
                    });
                    showXToast(ctx, l10n.googleSyncOfflineToast);
                  }
                }
                return res.signedIn;
              } finally {
                if (ctx.mounted) {
                  setModalState(() => busy = false);
                } else {
                  busy = false;
                }
              }
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GoogleLogoIcon(size: 22),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.googleSyncTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: xc.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.googleSub,
                    style: TextStyle(fontSize: 12, color: xc.muted),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: xc.card3,
                        color: const Color(0xFF4285F4),
                      ),
                    ),
                  ],
                  if (inlineFeedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: inlineFeedbackIsError
                            ? const Color(0x1AEF4444)
                            : xc.lime.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: inlineFeedbackIsError
                              ? const Color(0x55EF4444)
                              : xc.lime.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        inlineFeedback!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: inlineFeedbackIsError
                              ? const Color(0xFFEF4444)
                              : xc.lime,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Step 1: Google Account Sign-In / Connected Email Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSignedIn
                            ? xc.lime.withValues(alpha: 0.45)
                            : xc.borderStrong,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSignedIn
                                  ? Icons.verified_user_rounded
                                  : Icons.account_circle_outlined,
                              size: 20,
                              color: isSignedIn ? xc.lime : xc.muted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isSignedIn &&
                                      (s.googleAccountName ?? '').isNotEmpty)
                                    Text(
                                      s.googleAccountName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: xc.text,
                                      ),
                                    ),
                                  Text(
                                    isSignedIn
                                        ? s.googleAccountEmail!
                                        : l10n.googleNotConnected,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSignedIn ? 11.5 : 12,
                                      fontWeight: isSignedIn
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color: isSignedIn ? xc.lime : xc.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!isSignedIn)
                          OfficialGoogleSignInButton(
                            label: l10n.googleSignInBtn,
                            isLoading: busy,
                            isDark: Theme.of(ctx).brightness == Brightness.dark,
                            onTap: handleSignIn,
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (busy) return;
                                    setModalState(() => busy = true);
                                    try {
                                      await notifier.signOutGoogle();
                                    } finally {
                                      if (ctx.mounted) {
                                        setModalState(() => busy = false);
                                      } else {
                                        busy = false;
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 9),
                                    decoration: BoxDecoration(
                                      color: xc.card,
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: xc.borderStrong),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      l10n.googleSignOutBtn,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: xc.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (busy) return;
                                    setModalState(() => busy = true);
                                    final out = await notifier.syncGoogleNow();
                                    if (ctx.mounted) {
                                      setModalState(() => busy = false);
                                      if (out.success) {
                                        showXToast(
                                          ctx,
                                          out.mergedFromCloud
                                              ? l10n.googleSignedInMergedToast
                                              : l10n.googleDriveSyncedToast,
                                        );
                                      } else {
                                        showXToast(
                                            ctx, l10n.googleSyncOfflineToast);
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 9),
                                    decoration: BoxDecoration(
                                      color: xc.lime,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: busy
                                        ? SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: HabitPalette.contrastFg(
                                                  xc.lime),
                                            ),
                                          )
                                        : Text(
                                            l10n.googleSyncNowBtn,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: HabitPalette.contrastFg(
                                                  xc.lime),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Auto Account Sync Switch
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.googleAutoDriveToggle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.googleAutoDriveHint,
                                style: TextStyle(fontSize: 11, color: xc.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: isSignedIn && s.googleAutoSyncEnabled,
                          activeTrackColor: xc.lime,
                          activeThumbColor: HabitPalette.contrastFg(xc.lime),
                          onChanged: (val) async {
                            if (busy) return;
                            if (val && !isSignedIn) {
                              await handleSignIn();
                              return;
                            }
                            setModalState(() => busy = true);
                            try {
                              final curS =
                                  cRef.read(settingsProvider).value ?? s;
                              await notifier.updateSettings(
                                curS.copyWith(googleAutoSyncEnabled: val),
                              );
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => busy = false);
                              } else {
                                busy = false;
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Auto Google Calendar Switch
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.googleCalendarToggle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.googleCalendarHint,
                                style: TextStyle(fontSize: 11, color: xc.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: isSignedIn && s.googleCalendarSyncEnabled,
                          activeTrackColor: xc.lime,
                          activeThumbColor: HabitPalette.contrastFg(xc.lime),
                          onChanged: (val) async {
                            if (busy) return;
                            if (val && !isSignedIn) {
                              final signedIn = await handleSignIn();
                              if (!signedIn || !ctx.mounted) return;
                              final curS =
                                  cRef.read(settingsProvider).value ?? s;
                              await notifier.updateSettings(
                                curS.copyWith(googleCalendarSyncEnabled: true),
                              );
                              return;
                            }
                            setModalState(() => busy = true);
                            try {
                              final curS =
                                  cRef.read(settingsProvider).value ?? s;
                              await notifier.updateSettings(
                                curS.copyWith(googleCalendarSyncEnabled: val),
                              );
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => busy = false);
                              } else {
                                busy = false;
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  if (isSignedIn && lastStr != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      AppCalendar.localizeDigits(
                        l10n.obsidianLastSyncedLabel(lastStr),
                        s.localeCode,
                      ),
                      style: TextStyle(fontSize: 11, color: xc.muted),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Plain, non-technical explanation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: xc.card2.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.obsidianHowItWorksTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: xc.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final pt in [
                          l10n.googleGuidePoint1,
                          l10n.googleGuidePoint2,
                          l10n.googleGuidePoint3,
                          l10n.googleGuidePoint4,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: xc.lime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pt,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: xc.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Optional offline .ics export + delete cloud copy controls
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await GoogleCalendarSyncService.instance
                                .exportIcsFile(activeHabits);
                            if (ctx.mounted) {
                              showXToast(ctx, l10n.googleCalendarExportedToast);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: xc.card2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: xc.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.googleCalendarExportIcs,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSignedIn) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (busy) return;
                              final ok = await showXConfirmSheet(
                                context: ctx,
                                icon: Icons.cloud_off_rounded,
                                iconColor: const Color(0xFFEF4444),
                                title: l10n.googleDeleteCloudBtn,
                                message: l10n.googleDeleteCloudConfirmMsg,
                                cancelLabel: l10n.noCancel,
                                confirmLabel: l10n.yesDelete,
                              );
                              if (!ok || !ctx.mounted) return;
                              setModalState(() => busy = true);
                              try {
                                final deleted = await GoogleDriveSyncService
                                    .instance
                                    .deleteCloudBackup();
                                if (ctx.mounted) {
                                  showXToast(
                                    ctx,
                                    deleted
                                        ? l10n.googleCloudDeletedToast
                                        : l10n.googleSyncOfflineToast,
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => busy = false);
                                } else {
                                  busy = false;
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0x18EF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0x44EF4444),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.googleDeleteCloudBtn,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.path == null || !context.mounted) return;
    final ok = await showXConfirmSheet(
      context: context,
      icon: Icons.download_rounded,
      iconColor: xc.lime,
      title: l10n.confirmImportTitle,
      message: l10n.confirmImportMsg,
      cancelLabel: l10n.noCancel,
      confirmLabel: l10n.yesRestore,
      confirmBgColor: xc.lime,
      confirmFgColor: HabitPalette.contrastFg(xc.lime),
    );
    if (!ok || !context.mounted) return;
    try {
      final content = await File(picked.path!).readAsString();
      final backupSettings = await AppDatabase.instance.importBackupJson(content);
      if (backupSettings != null) {
        await ref
            .read(settingsProvider.notifier)
            .applyBackupSettingsMap(backupSettings);
      }
      await ref.read(habitStateProvider.notifier).reload();
      if (context.mounted) {
        showXToast(context, l10n.restoreSuccess);
      }
    } catch (_) {
      if (context.mounted) {
        showXToast(context, l10n.restoreInvalid);
      }
    }
  }

  Future<void> _openUpdateSheet(
    BuildContext context,
    AppSettings settings,
  ) async {
    final xc = context.xc;
    var initialized = false;
    var checking = true;
    var downloading = false;
    var installing = false;
    double progress = 0;
    UpdateCheckResult? checkRes;
    String? downloadedApkPath;

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final l10n = AppLocalizations.of(ctx);

          Future<void> runCheck() async {
            if (!ctx.mounted) return;
            setModalState(() {
              checking = true;
              downloadedApkPath = null;
            });
            final r = await AppUpdateService.instance.checkForUpdates();
            if (ctx.mounted) {
              setModalState(() {
                checking = false;
                checkRes = r;
              });
            }
          }

          Future<void> triggerInstall(String path) async {
            if (installing) return;
            installing = true;
            try {
              final res =
                  await AppUpdateService.instance.installDownloadedApk(path);
              if (!ctx.mounted) return;
              if (res == 'needs_permission') {
                showXToast(ctx, l10n.updateUnknownSourcesHint);
              } else if (res == 'error') {
                showXToast(ctx, l10n.updateCheckFailedMsg);
              }
            } finally {
              installing = false;
            }
          }

          Future<void> startDownload(UpdateReleaseInfo rel) async {
            if (downloading) return;
            setModalState(() {
              downloading = true;
              progress = 0;
            });
            final savedPath = await AppUpdateService.instance.downloadApk(
              rel,
              onProgress: (p, _, __) {
                if (ctx.mounted) {
                  setModalState(() => progress = p);
                }
              },
            );
            if (!ctx.mounted) return;
            setModalState(() {
              downloading = false;
              downloadedApkPath = savedPath;
            });
            if (savedPath == null) {
              showXToast(ctx, l10n.updateCheckFailedMsg);
              return;
            }
            await triggerInstall(savedPath);
          }

          if (!initialized) {
            initialized = true;
            Future.microtask(runCheck);
          }

          final curVer = checkRes?.currentVersion.versionName ?? '1.0.0';
          final rel = checkRes?.latestRelease;
          final pct = (progress * 100).round().clamp(0, 100);

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.checkForUpdatesTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppCalendar.localizeDigits(
                    l10n.updateCurrentLabel(curVer),
                    settings.localeCode,
                  ),
                  style: TextStyle(fontSize: 12, color: xc.muted),
                ),
                const SizedBox(height: 14),
                if (checking)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: xc.lime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.updateCheckingMsg,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: xc.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (checkRes?.isError == true)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x44EF4444)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.updateCheckFailedMsg,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: xc.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: runCheck,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: xc.lime,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.updateCheckAgainBtn,
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
                  )
                else if (checkRes?.hasUpdate == true && rel != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: xc.lime.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.new_releases_rounded,
                                size: 19, color: xc.lime),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.updateAvailableTitle,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: xc.text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: xc.lime.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                AppCalendar.localizeDigits(
                                  'v${rel.cleanVersion}',
                                  settings.localeCode,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: xc.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (rel.releaseNotes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 130),
                            child: SingleChildScrollView(
                              child: Text(
                                rel.releaseNotes,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: xc.muted,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (downloading) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              minHeight: 7,
                              backgroundColor: xc.card,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(xc.lime),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppCalendar.localizeDigits(
                              l10n.updateDownloadingPct(pct),
                              settings.localeCode,
                            ),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: xc.lime,
                            ),
                          ),
                        ] else if (downloadedApkPath != null)
                          GestureDetector(
                            onTap: () => triggerInstall(downloadedApkPath!),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: xc.lime,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.updateInstallNowBtn,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: HabitPalette.contrastFg(xc.lime),
                                ),
                              ),
                            ),
                          )
                        else if (rel.hasApkAsset)
                          GestureDetector(
                            onTap: () => startDownload(rel),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: xc.lime,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                l10n.updateDownloadInstallBtn,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: HabitPalette.contrastFg(xc.lime),
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            l10n.updateNoApkAssetMsg,
                            style: TextStyle(fontSize: 12, color: xc.muted),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 18, color: xc.lime),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.updateUpToDateMsg,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: runCheck,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: xc.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: xc.borderStrong),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.updateCheckAgainBtn,
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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAboutSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _AboutLogoPainter(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'XHabit',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: xc.lime.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.aboutVersion,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: xc.lime,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.75,
              color: xc.text.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 2.35,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              (Icons.calendar_today_outlined, l10n.aboutFeat1),
              (Icons.widgets_outlined, l10n.aboutFeat2),
              (Icons.lock_outline_rounded, l10n.aboutFeat3),
              (Icons.bar_chart_rounded, l10n.aboutFeat4),
            ].map((f) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: xc.card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: xc.border),
                ),
                child: Row(
                  children: [
                    Icon(f.$1, size: 16, color: xc.lime),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: xc.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutFooter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: xc.muted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEraseAllData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showXConfirmSheet(
      context: context,
      icon: Icons.delete_rounded,
      title: l10n.confirmEraseTitle,
      message: l10n.confirmEraseMsg,
      cancelLabel: l10n.noCancel,
      confirmLabel: l10n.yesDelete,
    );
    if (ok && context.mounted) {
      await ref.read(habitStateProvider.notifier).eraseAllData();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    final st = ref.watch(habitStateProvider).value;
    final active = st?.habits.where((h) => !h.isArchived).toList() ?? const [];
    final archived = st?.habits.where((h) => h.isArchived).toList() ?? const [];
    final remCount = active.where((h) => h.reminderEnabled).length;
    final wHabit = active.where((x) => x.id == settings.widgetHabitId).firstOrNull ??
        active.firstOrNull;
    final genSub =
        '${settings.localeCode == 'fa' ? 'فارسی' : 'EN'} • ${settings.calendarSystem == CalendarSystem.jalali ? l10n.calendarJalali : l10n.calendarGregorian}';
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // `.add-topbar` header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  XNavBackButton(onTap: () => Navigator.pop(context)),
                  Text(
                    l10n.navSettings,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: xc.text,
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: 28 + bottomInset),
                children: [
                  // Group 1
                  _SetGroup(
                    rows: [
                      _SetRow(
                        icon: Icons.palette_outlined,
                        label: l10n.darkMode,
                        trailingText:
                            settings.isDarkMode ? l10n.oledBlack : l10n.lightMode,
                        showChevron: false,
                        onTap: () => notifier.updateSettings(
                            settings.copyWith(isDarkMode: !settings.isDarkMode)),
                      ),
                      _SetRow(
                        icon: Icons.grid_view_rounded,
                        label: l10n.homeLayoutLabel,
                        trailingText: settings.homeLayout == HomeLayout.list
                            ? l10n.listView
                            : l10n.gridView,
                        showChevron: false,
                        onTap: () => _openLayoutSheet(context, ref, settings),
                      ),
                      _SetRow(
                        icon: Icons.tune_rounded,
                        label: l10n.generalSettings,
                        trailingText: genSub,
                        onTap: () => _openGeneralSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.notifications_none_rounded,
                        label: l10n.dailyRemindersTitle,
                        trailingText:
                            '${AppCalendar.localizeDigits('$remCount', settings.localeCode)} ${l10n.activeRemindersSuffix}',
                        onTap: () => _openRemindersSheet(context, ref),
                      ),
                    ],
                  ),

                  // Group 2
                  _SetGroup(
                    rows: [
                      _SetRow(
                        icon: Icons.widgets_outlined,
                        label: l10n.homeWidgetsTitle,
                        trailingText: wHabit?.title ?? '',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const WidgetsSettingsScreen()),
                        ),
                      ),
                      _SetRow(
                        icon: Icons.reorder_rounded,
                        label: l10n.reorderHabits,
                        trailingText: AppCalendar.localizeDigits(
                            '(${active.length})', settings.localeCode),
                        onTap: () => showReorderHabitsSheet(context),
                      ),
                      _SetRow(
                        icon: Icons.category_outlined,
                        label: l10n.categoriesLabel,
                        trailingText: AppCalendar.localizeDigits(
                            '(${st?.categories.length ?? 0})',
                            settings.localeCode),
                        onTap: () => _openCategoriesSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.archive_outlined,
                        label: l10n.archivedHabits,
                        trailingText: AppCalendar.localizeDigits(
                            '(${archived.length})', settings.localeCode),
                        onTap: () => _openArchiveSheet(context, ref),
                      ),
                    ],
                  ),

                  // Group 3
                  _SetGroup(
                    rows: [
                      _SetRow(
                        icon: Icons.lock_outline_rounded,
                        label: l10n.appLock,
                        trailingText: settings.isAppLockEnabled
                            ? l10n.appLockStatusOn
                            : l10n.appLockStatusOff,
                        trailingColor:
                            settings.isAppLockEnabled ? xc.lime : null,
                        trailingWeight: settings.isAppLockEnabled
                            ? FontWeight.w800
                            : FontWeight.w500,
                        onTap: () => _openPinFlow(context, ref, settings),
                      ),
                      _SetRow(
                        icon: Icons.folder_open_rounded,
                        label: l10n.storageFolderLabel,
                        trailingText: settings.customStoragePath == null
                            ? l10n.storageDefaultLabel
                            : Uri.decodeFull(
                                settings.customStoragePath!.split('/').last),
                        onTap: () => _openStorageFolderSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.autorenew_rounded,
                        label: l10n.autoBackupTitle,
                        trailingText: settings.autoBackupEnabled
                            ? AppCalendar.localizeDigits(
                                l10n.autoBackupCountUnit(
                                    settings.autoBackupKeepCount),
                                settings.localeCode,
                              )
                            : l10n.appLockStatusOff,
                        trailingColor:
                            settings.autoBackupEnabled ? xc.lime : null,
                        onTap: () => _openAutoBackupSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.download_for_offline_outlined,
                        label: l10n.downloadBackup,
                        onTap: () => _downloadBackup(context, settings),
                      ),
                      _SetRow(
                        icon: Icons.ios_share_rounded,
                        label: l10n.shareBackup,
                        onTap: () => _shareBackup(context, settings),
                      ),
                      _SetRow(
                        icon: Icons.upload_file_rounded,
                        label: l10n.importBackup,
                        onTap: () => _importBackup(context, ref),
                      ),
                    ],
                  ),

                  // Group 4: Integrations & About
                  _SetGroup(
                    rows: [
                      _SetRow(
                        icon: Icons.description_outlined,
                        leadingWidget: const ObsidianLogoIcon(size: 19),
                        label: l10n.obsidianTitle,
                        trailingText: (settings.obsidianVaultUri != null &&
                                settings.obsidianVaultUri!.isNotEmpty)
                            ? (settings.obsidianSyncEnabled
                                ? l10n.appLockStatusOn
                                : l10n.appLockStatusOff)
                            : '',
                        trailingColor: (settings.obsidianSyncEnabled &&
                                settings.obsidianVaultUri != null &&
                                settings.obsidianVaultUri!.isNotEmpty)
                            ? xc.lime
                            : null,
                        onTap: () => _openObsidianSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.cloud_sync_outlined,
                        leadingWidget: const GoogleLogoIcon(size: 19),
                        label: l10n.googleSyncTitle,
                        trailingText:
                            (settings.googleAccountEmail ?? '').isNotEmpty
                                ? ((settings.googleAutoSyncEnabled ||
                                        settings.googleCalendarSyncEnabled)
                                    ? l10n.appLockStatusOn
                                    : l10n.appLockStatusOff)
                                : '',
                        trailingColor:
                            ((settings.googleAccountEmail ?? '').isNotEmpty &&
                                    (settings.googleAutoSyncEnabled ||
                                        settings.googleCalendarSyncEnabled))
                                ? xc.lime
                                : null,
                        onTap: () => _openGoogleSyncSheet(context, ref),
                      ),
                      _SetRow(
                        icon: Icons.system_update_rounded,
                        label: l10n.checkForUpdatesTitle,
                        onTap: () => _openUpdateSheet(context, settings),
                      ),
                      _SetRow(
                        icon: Icons.info_outline_rounded,
                        label: l10n.aboutXHabit,
                        trailingText: AppCalendar.localizeDigits(
                            'v1.0.0', settings.localeCode),
                        showChevron: false,
                        onTap: () => _openAboutSheet(context),
                      ),
                    ],
                  ),

                  // Separate bottom Danger Zone card
                  _SetGroup(
                    borderColor: const Color(0x47EF4444),
                    rows: [
                      _SetRow(
                        icon: Icons.delete_rounded,
                        label: l10n.eraseAllData,
                        textColor: const Color(0xFFEF4444),
                        iconColor: const Color(0xFFEF4444),
                        onTap: () => _confirmEraseAllData(context, ref),
                      ),
                    ],
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

class _SetGroup extends StatelessWidget {
  const _SetGroup({required this.rows, this.borderColor});

  final List<_SetRow> rows;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: xc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? xc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) Container(height: 1, color: xc.border),
          ],
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.leadingWidget,
    this.trailingText = '',
    this.showChevron = true,
    this.textColor,
    this.iconColor,
    this.trailingColor,
    this.trailingWeight,
  });

  final IconData icon;
  final Widget? leadingWidget;
  final String label;
  final VoidCallback onTap;
  final String trailingText;
  final bool showChevron;
  final Color? textColor;
  final Color? iconColor;
  final Color? trailingColor;
  final FontWeight? trailingWeight;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    leadingWidget ??
                        Icon(icon, size: 17, color: iconColor ?? xc.muted),
                    const SizedBox(width: 13),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor ?? xc.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailingText.isNotEmpty)
                      Flexible(
                        child: Text(
                          trailingText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: trailingWeight ?? FontWeight.w500,
                            color: trailingColor ?? xc.muted,
                          ),
                        ),
                      ),
                    if (showChevron) ...[
                      if (trailingText.isNotEmpty) const SizedBox(width: 6),
                      Icon(
                        xForwardChevron(context),
                        size: 18,
                        color: textColor ?? xc.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenRow extends StatelessWidget {
  const _GenRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: xc.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}

class _GenChip extends StatelessWidget {
  const _GenChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: xc.card2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? xc.lime : xc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? xc.lime : xc.muted,
          ),
        ),
      ),
    );
  }
}

class _SheetPillRow extends StatelessWidget {
  const _SheetPillRow({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: xc.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: xc.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color ?? xc.text,
          ),
        ),
      ),
    );
  }
}

class _AboutLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(34 * s, 54 * s)
      ..lineTo(47 * s, 67 * s)
      ..lineTo(74 * s, 40 * s);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _AboutLogoPainter oldDelegate) => false;
}
