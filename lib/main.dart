import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';
import 'app/xhabit_app.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/widget_sync_service.dart';
import 'core/sync/cloud_drive_sync_service.dart';
import 'core/sync/obsidian_sync_service.dart';
import 'data/db/app_database.dart';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final db = AppDatabase.instance;
      final habits = await db.getHabits(includeArchived: false);
      final checklist = await db.getAllChecklistItems();
      final completions = await db.getAllCompletions();
      final pauses = await db.getAllPauses();
      final settings = await readWidgetSettingsSnapshot();
      try {
        await WidgetSyncService.instance.syncAll(
          habits: habits,
          checklistItems: checklist,
          completions: completions,
          pauses: pauses,
          settings: settings,
        );
      } catch (_) {}
      try {
        await LocalStorageService.instance.runScheduledAutoBackupIfDue(settings);
      } catch (_) {}
      if (settings.obsidianSyncEnabled &&
          settings.obsidianVaultUri != null &&
          settings.obsidianVaultUri!.isNotEmpty) {
        try {
          await ObsidianSyncService.instance.syncFullVaultNow(
            settings: settings,
            forceFullWrite: false,
          );
        } catch (_) {}
      }
      if ((settings.googleAccountEmail ?? '').isNotEmpty &&
          (settings.googleAutoSyncEnabled ||
              settings.googleCalendarSyncEnabled)) {
        try {
          await GoogleDriveSyncService.instance.syncWithGoogleAccount(
            settings: settings,
            pullFirst: true,
          );
        } catch (_) {}
      }
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  await Workmanager().initialize(workmanagerCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'xhabit_widget_refresh',
    'refreshHomeWidgets',
    frequency: const Duration(hours: 6),
  );

  runApp(const ProviderScope(child: XHabitApp()));
}
