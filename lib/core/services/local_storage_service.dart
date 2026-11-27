import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';

class LocalStorageService {
  LocalStorageService._();

  static final LocalStorageService instance = LocalStorageService._();
  static const MethodChannel _channel =
      MethodChannel('app.xhabit.tracker/storage');
  static const MethodChannel _uiChannel =
      MethodChannel('app.xhabit.tracker/storage_ui');

  /// Saves backup JSON directly into Android Downloads/XHabit (no forced Share sheet).
  Future<String?> downloadBackupJson({
    required String fileName,
    required String jsonContent,
  }) =>
      saveTextDownload(
        fileName: fileName,
        content: jsonContent,
        mimeType: 'application/json',
      );

  /// Saves any UTF-8 text export (JSON / ICS / Markdown) into Downloads/XHabit.
  Future<String?> saveTextDownload({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (Platform.isAndroid) {
      try {
        final saved = await _channel.invokeMethod<String>('saveToDownloads', {
          'fileName': fileName,
          'bytes': bytes,
          'mimeType': mimeType,
        });
        if (saved != null && saved.isNotEmpty) return saved;
      } catch (_) {}
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'XHabit', 'Backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final out = File(p.join(dir.path, fileName));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }

  /// Launches Android SAF folder chooser and returns persisted tree URI string.
  Future<String?> pickDeviceFolder() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _uiChannel.invokeMethod<String>('pickTreeFolder');
    } catch (_) {
      return null;
    }
  }

  /// Writes organized Database + Human-readable JSON + Media into device storage.
  Future<String?> syncOrganizedFolder({
    required AppSettings settings,
  }) async {
    final rawJson =
        await AppDatabase.instance.exportBackupJson(settings: settings);
    final prettyJson = const JsonEncoder.withIndent('  ')
        .convert(jsonDecode(rawJson) as Map<String, dynamic>);

    final dbPath = await AppDatabase.instance.databaseFilePath();
    final notes = await AppDatabase.instance.getAllNotes();
    final mediaFiles = <String>[];
    for (final n in notes) {
      if ((n.kind == NoteKind.image || n.kind == NoteKind.audio) &&
          n.content.isNotEmpty &&
          await File(n.content).exists()) {
        mediaFiles.add(n.content);
      }
    }

    if (Platform.isAndroid) {
      try {
        final res =
            await _channel.invokeMethod<String>('syncOrganizedData', {
          'readableJson': prettyJson,
          'sqliteDbPath': dbPath,
          'mediaPaths': mediaFiles,
          'customTreeUri': settings.customStoragePath,
        });
        if (res != null && res.isNotEmpty) return res;
      } catch (_) {}
    }

    final base = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(base.path, 'XHabit'));
    for (final sub in ['Database', 'Backups', 'Media', 'Exports']) {
      final d = Directory(p.join(root.path, sub));
      if (!await d.exists()) await d.create(recursive: true);
    }
    await File(p.join(root.path, 'Database', 'xhabit_data.json'))
        .writeAsString(prettyJson, flush: true);
    if (await File(dbPath).exists()) {
      await File(dbPath).copy(p.join(root.path, 'Database', 'xhabit.sqlite'));
    }
    return root.path;
  }

  /// Checks auto-backup schedule, writes timestamped JSON if due (or [force]),
  /// and prunes oldest snapshots beyond [settings.autoBackupKeepCount].
  Future<({String path, int savedAtMs})?> runScheduledAutoBackupIfDue(
    AppSettings settings, {
    bool force = false,
  }) async {
    if (!force && !settings.autoBackupEnabled) return null;

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final lastMs = settings.lastAutoBackupMs;
    if (!force && lastMs != null) {
      final elapsedHours = (nowMs - lastMs) / 3600000.0;
      final minHours = settings.autoBackupIntervalDays.clamp(1, 30) * 24.0 - 2.0;
      if (elapsedHours < minHours) return null;
      final curMin = now.hour * 60 + now.minute;
      final targetMin = settings.autoBackupHour * 60 + settings.autoBackupMinute;
      if (elapsedHours < 24.0 && curMin < targetMin) return null;
    }

    final jsonStr =
        await AppDatabase.instance.exportBackupJson(settings: settings);
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'xhabit_auto_$stamp.json';

    Directory baseDir;
    try {
      baseDir = (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final autoDir = Directory(p.join(baseDir.path, 'XHabit', 'AutoBackups'));
    if (!await autoDir.exists()) await autoDir.create(recursive: true);

    final outFile = File(p.join(autoDir.path, fileName));
    await outFile.writeAsString(jsonStr, flush: true);

    // Retention cleanup: keep newest [autoBackupKeepCount] auto-backup files.
    final keep = settings.autoBackupKeepCount.clamp(1, 30);
    final entries = autoDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('xhabit_auto_') && f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (var i = keep; i < entries.length; i++) {
      try {
        await entries[i].delete();
      } catch (_) {}
    }

    // Also update Downloads/XHabit copy on Android and sync custom organized folder if set.
    await downloadBackupJson(fileName: fileName, jsonContent: jsonStr);
    if (settings.customStoragePath != null) {
      await syncOrganizedFolder(settings: settings);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastAutoBackupMs', nowMs);
    return (path: outFile.path, savedAtMs: nowMs);
  }
}
