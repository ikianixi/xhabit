import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';
import '../services/local_storage_service.dart';
import 'sync_ports.dart';

class GoogleAuthAccountInfo {
  const GoogleAuthAccountInfo({
    required this.email,
    required this.displayName,
  });

  final String email;
  final String displayName;
}

class GoogleSignInAttempt {
  const GoogleSignInAttempt({
    this.account,
    this.cancelled = false,
    this.errorCode,
    this.errorMessage,
  });

  final GoogleAuthAccountInfo? account;
  final bool cancelled;
  final String? errorCode;
  final String? errorMessage;
}

class GoogleSyncOutcome {
  const GoogleSyncOutcome({
    required this.success,
    this.mergedFromCloud = false,
    this.pushedDrive = false,
    this.syncedCalendarCount = 0,
    this.syncedAtMs,
    this.errorCode,
  });

  final bool success;
  final bool mergedFromCloud;
  final bool pushedDrive;
  final int syncedCalendarCount;
  final int? syncedAtMs;
  final String? errorCode;
}

/// Real Google Sign-In + Google Drive (`drive.appdata`) auto-backup/merge +
/// Google Calendar REST v3 event sync, keeping SAF/ICS as offline fallbacks.
class GoogleDriveSyncService implements PersonalCloudSyncPort {
  GoogleDriveSyncService._();

  static final GoogleDriveSyncService instance = GoogleDriveSyncService._();
  static const MethodChannel _storageChannel =
      MethodChannel('app.xhabit.tracker/storage');
  static const MethodChannel _uiStorageChannel =
      MethodChannel('app.xhabit.tracker/storage_ui');

  /// Optional Web Client ID via `--dart-define=XHABIT_GOOGLE_WEB_CLIENT_ID=...`.
  /// Omitted by default on Android since Drive/Calendar REST calls only use `authHeaders`.
  static const String webClientId = String.fromEnvironment(
    'XHABIT_GOOGLE_WEB_CLIENT_ID',
  );
  static const String _cloudFileName = 'xhabit_cloud_sync.json';
  static const List<String> _scopes = <String>[
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: webClientId.isEmpty ? null : webClientId,
    scopes: _scopes,
  );

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _rerunRequested = false;
  AppSettings? _pendingSettings;
  Future<void> Function(int syncedAtMs, bool reloadedDb,
      Map<String, dynamic>? mergedSettings)? _onSyncedCallback;
  String? _cachedDriveFileId;

  @override
  Future<bool> isConfigured() async => true;

  @override
  Future<SyncResult> pushAndPull(
    PersonalServerConfig config, {
    required int lastSyncedRevision,
    required List<SyncChangeRecord> dirtyChanges,
  }) async {
    final res = await syncWithGoogleAccount(
      settings: AppSettings(googleDriveUri: config.endpointUrl),
      pullFirst: true,
    );
    return SyncResult(
      success: res.success,
      pushedCount: res.pushedDrive ? dirtyChanges.length : 0,
      pulledCount: res.mergedFromCloud ? 1 : 0,
      newRevision: res.syncedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      errorMessage: res.errorCode,
    );
  }

  /// Launches interactive Google account sign-in dialog and ensures permissions,
  /// returning detailed outcome (account, cancelled, or error details).
  Future<GoogleSignInAttempt> signInWithGoogleDetailed() async {
    try {
      _cachedDriveFileId = null;
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInAttempt(cancelled: true);
      }
      var hasScopes = true;
      try {
        hasScopes = await _googleSignIn.canAccessScopes(_scopes);
        if (!hasScopes) {
          hasScopes = await _googleSignIn.requestScopes(_scopes);
        }
      } on UnimplementedError {
        // Some platform implementations grant scopes directly during signIn().
        hasScopes = true;
      } on MissingPluginException {
        hasScopes = true;
      }
      if (!hasScopes) {
        await _googleSignIn.signOut();
        return const GoogleSignInAttempt(
          errorCode: 'scopes_denied',
          errorMessage: 'Required Google Drive & Calendar permissions were not granted.',
        );
      }
      return GoogleSignInAttempt(
        account: GoogleAuthAccountInfo(
          email: account.email,
          displayName: (account.displayName ?? '').trim().isEmpty
              ? account.email
              : account.displayName!.trim(),
        ),
      );
    } on PlatformException catch (e) {
      return GoogleSignInAttempt(
        cancelled: e.code == 'sign_in_canceled',
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return GoogleSignInAttempt(
        errorCode: 'sign_in_error',
        errorMessage: e.toString(),
      );
    }
  }

  /// Launches interactive Google account sign-in dialog and ensures permissions.
  Future<GoogleAuthAccountInfo?> signInWithGoogle() async {
    final attempt = await signInWithGoogleDetailed();
    return attempt.account;
  }

  /// Restores an existing signed-in Google session silently without UI prompts.
  Future<GoogleSignInAccount?> ensureSignedInAccount({
    bool interactiveIfNeeded = false,
  }) async {
    try {
      var account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null && interactiveIfNeeded) {
        account = await _googleSignIn.signIn();
      }
      if (account == null) return null;
      final hasScopes = await _googleSignIn.canAccessScopes(_scopes);
      if (!hasScopes) {
        if (!interactiveIfNeeded) return null;
        final granted = await _googleSignIn.requestScopes(_scopes);
        if (!granted) return null;
      }
      return account;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    cancelPendingSync();
    _cachedDriveFileId = null;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Queues a fast debounced background sync after DB or settings changes.
  void scheduleBackgroundSync({
    required AppSettings settings,
    Future<void> Function(
      int syncedAtMs,
      bool reloadedDb,
      Map<String, dynamic>? mergedSettings,
    )? onSynced,
    bool immediate = false,
  }) {
    final hasGoogleAccount = (settings.googleAccountEmail ?? '').isNotEmpty;
    if (!hasGoogleAccount ||
        (!settings.googleAutoSyncEnabled &&
            !settings.googleCalendarSyncEnabled)) {
      return;
    }
    _pendingSettings = settings;
    if (onSynced != null) _onSyncedCallback = onSynced;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      immediate
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 1200),
      () => _drainSyncQueue(),
    );
  }

  void cancelPendingSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingSettings = null;
    _rerunRequested = false;
  }

  Future<void> _drainSyncQueue() async {
    final settings = _pendingSettings;
    if (settings == null || (settings.googleAccountEmail ?? '').isEmpty) {
      return;
    }
    if (_isSyncing) {
      _rerunRequested = true;
      return;
    }
    _isSyncing = true;
    try {
      do {
        _rerunRequested = false;
        final current = _pendingSettings ?? settings;
        if ((current.googleAccountEmail ?? '').isEmpty ||
            (!current.googleAutoSyncEnabled &&
                !current.googleCalendarSyncEnabled)) {
          break;
        }
        final out = await syncWithGoogleAccount(
          settings: current,
          pullFirst: false,
        );
        if (out.success && out.syncedAtMs != null && _onSyncedCallback != null) {
          await _onSyncedCallback!(
            out.syncedAtMs!,
            out.mergedFromCloud,
            null,
          );
        }
      } while (_rerunRequested);
    } finally {
      _isSyncing = false;
    }
  }

  /// Full cloud sync cycle:
  /// 1. Pulls & merges newer rows from user's Google Drive `appDataFolder` if [pullFirst]
  /// 2. Uploads latest snapshot back to Google Drive `appDataFolder` (when [googleAutoSyncEnabled])
  /// 3. Synchronizes active habits with Google Calendar API (when [googleCalendarSyncEnabled])
  Future<GoogleSyncOutcome> syncWithGoogleAccount({
    required AppSettings settings,
    bool pullFirst = true,
    bool interactiveSignIn = false,
  }) async {
    final account =
        await ensureSignedInAccount(interactiveIfNeeded: interactiveSignIn);
    if (account == null) {
      // Fallback to SAF Drive folder if user only picked a local SAF URI
      if (settings.googleDriveUri != null &&
          settings.googleDriveUri!.isNotEmpty) {
        final ok = await syncToDriveFolder(settings: settings);
        return GoogleSyncOutcome(
          success: ok,
          pushedDrive: ok,
          syncedAtMs: ok ? DateTime.now().millisecondsSinceEpoch : null,
          errorCode: ok ? null : 'not_signed_in',
        );
      }
      return const GoogleSyncOutcome(
        success: false,
        errorCode: 'not_signed_in',
      );
    }

    var mergedFromCloud = false;
    var pushedDrive = false;
    var calCount = 0;
    var calOk = !settings.googleCalendarSyncEnabled;

    try {
      if (settings.googleAutoSyncEnabled) {
        final existingFileId = await _findAppDataFileId(account);
        if (pullFirst && existingFileId != null) {
          final cloudRaw = await _downloadDriveFile(account, existingFileId);
          if (cloudRaw != null && cloudRaw.isNotEmpty) {
            final res = await AppDatabase.instance.mergeBackupJson(cloudRaw);
            mergedFromCloud = res.mergedRows > 0;
          }
        }

        final latestJson =
            await AppDatabase.instance.exportBackupJson(settings: settings);
        pushedDrive = await _uploadAppDataBackup(
          account: account,
          existingFileId: existingFileId,
          jsonContent: latestJson,
        );
      }

      if (settings.googleCalendarSyncEnabled) {
        final activeHabits =
            await AppDatabase.instance.getHabits(includeArchived: false);
        final calRes = await GoogleCalendarSyncService.instance
            .syncHabitsViaApi(account: account, habits: activeHabits);
        calCount = calRes.syncedCount;
        calOk = calRes.ok;
      }

      final driveOk = !settings.googleAutoSyncEnabled || pushedDrive;
      final overallOk = driveOk && calOk;
      final ts = DateTime.now().millisecondsSinceEpoch;
      if (overallOk) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('lastGoogleSyncMs', ts);
        } catch (_) {}
      }

      return GoogleSyncOutcome(
        success: overallOk,
        mergedFromCloud: mergedFromCloud,
        pushedDrive: pushedDrive,
        syncedCalendarCount: calCount,
        syncedAtMs: overallOk ? ts : null,
        errorCode: overallOk ? null : 'sync_partial_or_failed',
      );
    } on SocketException {
      return const GoogleSyncOutcome(success: false, errorCode: 'offline');
    } catch (_) {
      return const GoogleSyncOutcome(success: false, errorCode: 'sync_error');
    }
  }

  /// Pulls & returns cloud settings map during initial sign-in or restore.
  Future<({bool merged, int mergedRows, Map<String, dynamic>? settingsMap})>
      pullCloudBackupIntoLocalDb(GoogleSignInAccount account) async {
    try {
      final fileId = await _findAppDataFileId(account);
      if (fileId == null) {
        return (merged: false, mergedRows: 0, settingsMap: null);
      }
      final raw = await _downloadDriveFile(account, fileId);
      if (raw == null || raw.isEmpty) {
        return (merged: false, mergedRows: 0, settingsMap: null);
      }
      final res = await AppDatabase.instance.mergeBackupJson(raw);
      return (
        merged: res.mergedRows > 0,
        mergedRows: res.mergedRows,
        settingsMap: res.settingsMap,
      );
    } catch (_) {
      return (merged: false, mergedRows: 0, settingsMap: null);
    }
  }

  Future<bool> deleteCloudBackup() async {
    final account = await ensureSignedInAccount();
    if (account == null) return false;
    try {
      final fileId = await _findAppDataFileId(account);
      if (fileId == null) return true;
      final res = await authorizedRequest(
        account: account,
        method: 'DELETE',
        uri: Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
      );
      if (res.statusCode >= 200 && res.statusCode < 300 || res.statusCode == 404) {
        _cachedDriveFileId = null;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _findAppDataFileId(GoogleSignInAccount account) async {
    if (_cachedDriveFileId != null) return _cachedDriveFileId;
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name='$_cloudFileName' and trashed=false",
      'fields': 'files(id,name,modifiedTime)',
      'pageSize': '5',
    });
    final res = await authorizedRequest(account: account, method: 'GET', uri: uri);
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final files = body['files'] as List?;
    if (files == null || files.isEmpty) return null;
    _cachedDriveFileId = (files.first as Map)['id'] as String?;
    return _cachedDriveFileId;
  }

  Future<String?> _downloadDriveFile(
    GoogleSignInAccount account,
    String fileId,
  ) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/drive/v3/files/$fileId',
      {'alt': 'media'},
    );
    final res = await authorizedRequest(account: account, method: 'GET', uri: uri);
    if (res.statusCode == 404) {
      _cachedDriveFileId = null;
      return null;
    }
    if (res.statusCode != 200) return null;
    return res.body;
  }

  Future<bool> _uploadAppDataBackup({
    required GoogleSignInAccount account,
    required String? existingFileId,
    required String jsonContent,
  }) async {
    if (existingFileId != null) {
      final res = await authorizedRequest(
        account: account,
        method: 'PATCH',
        uri: Uri.https(
          'www.googleapis.com',
          '/upload/drive/v3/files/$existingFileId',
          {'uploadType': 'media'},
        ),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonContent,
      );
      if (res.statusCode == 404) {
        _cachedDriveFileId = null;
      } else {
        return res.statusCode >= 200 && res.statusCode < 300;
      }
    }

    final boundary = 'xhabit_drive_${DateTime.now().microsecondsSinceEpoch}';
    final metaJson = jsonEncode({
      'name': _cloudFileName,
      'parents': ['appDataFolder'],
    });
    final multipartBody = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metaJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$jsonContent\r\n'
        '--$boundary--\r\n';

    final res = await authorizedRequest(
      account: account,
      method: 'POST',
      uri: Uri.https(
        'www.googleapis.com',
        '/upload/drive/v3/files',
        {'uploadType': 'multipart', 'fields': 'id'},
      ),
      headers: {
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: multipartBody,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final created = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedDriveFileId = created['id'] as String?;
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Authenticated HTTP helper using google_sign_in token + single 401 refresh retry.
  Future<({int statusCode, String body})> authorizedRequest({
    required GoogleSignInAccount account,
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    String? body,
  }) async {
    Future<({int statusCode, String body})> sendOnce() async {
      final authHeaders = await account.authHeaders;
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      try {
        final req = await client.openUrl(method, uri);
        authHeaders.forEach((k, v) => req.headers.set(k, v));
        headers?.forEach((k, v) => req.headers.set(k, v));
        if (body != null) {
          final bytes = utf8.encode(body);
          req.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
          req.add(bytes);
        }
        final resp = await req.close().timeout(const Duration(seconds: 20));
        final respBody = await resp.transform(utf8.decoder).join();
        return (statusCode: resp.statusCode, body: respBody);
      } finally {
        client.close();
      }
    }

    var res = await sendOnce();
    if (res.statusCode == 401) {
      try {
        await account.clearAuthCache();
      } catch (_) {}
      res = await sendOnce();
    }
    return res;
  }

  /// Legacy SAF Drive folder export fallback.
  Future<bool> syncToDriveFolder({required AppSettings settings}) async {
    final uri = settings.googleDriveUri;
    if (!Platform.isAndroid || uri == null || uri.isEmpty) return false;
    final jsonStr =
        await AppDatabase.instance.exportBackupJson(settings: settings);
    try {
      await _storageChannel.invokeMethod('writeRelativeFiles', {
        'treeUri': uri,
        'rootFolder': 'XHabit',
        'files': [
          {
            'subDir': 'GoogleDriveSync',
            'fileName': 'xhabit_drive_sync.json',
            'mimeType': 'application/json',
            'content': jsonStr,
          },
        ],
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's system document picker to read a JSON backup file.
  Future<String?> pickBackupJsonFromDrive() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _uiStorageChannel.invokeMethod<String>('pickJsonDocument');
    } catch (_) {
      return null;
    }
  }
}

class GoogleCalendarSyncService {
  GoogleCalendarSyncService._();

  static final GoogleCalendarSyncService instance =
      GoogleCalendarSyncService._();
  static const MethodChannel _storageChannel =
      MethodChannel('app.xhabit.tracker/storage');
  static const MethodChannel _uiStorageChannel =
      MethodChannel('app.xhabit.tracker/storage_ui');

  /// Generates Google Calendar API-safe base32hex event ID (`[0-9a-v]`).
  static String deterministicEventId(String habitId) {
    final hex = utf8
        .encode(habitId)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final safe = 'e0$hex';
    if (safe.length <= 512) {
      return safe.length >= 16 ? safe : safe.padRight(16, '0');
    }
    return safe.substring(0, 512);
  }

  static String? _rruleForHabit(Habit h) {
    const icsDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return switch (h.frequencyType) {
      FrequencyType.weekdays => () {
          final days = <String>[];
          for (var d = 1; d <= 7; d++) {
            if ((h.weekdaysMask & (1 << (d - 1))) != 0) {
              days.add(icsDays[d - 1]);
            }
          }
          return days.isEmpty
              ? 'FREQ=DAILY'
              : 'FREQ=WEEKLY;BYDAY=${days.join(',')}';
        }(),
      FrequencyType.monthDays => () {
          final md = h.monthDays.where((d) => d >= 1 && d <= 31).toList()..sort();
          return md.isEmpty
              ? 'FREQ=MONTHLY'
              : 'FREQ=MONTHLY;BYMONTHDAY=${md.join(',')}';
        }(),
      FrequencyType.interval =>
        'FREQ=DAILY;INTERVAL=${h.intervalDays < 1 ? 1 : h.intervalDays}',
      FrequencyType.daily => 'FREQ=DAILY',
      FrequencyType.period => 'FREQ=DAILY',
    };
  }

  static Future<String> _resolveIanaTimeZone() async {
    if (Platform.isAndroid) {
      try {
        final tz = await _storageChannel.invokeMethod<String>('getLocalTimezone');
        if (tz != null && tz.trim().isNotEmpty) return tz.trim();
      } catch (_) {}
    }
    return 'UTC';
  }

  static String _rfc3339Local(DateTime dt) {
    final off = dt.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final absM = off.inMinutes.abs();
    final oh = (absM ~/ 60).toString().padLeft(2, '0');
    final om = (absM % 60).toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}T'
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:00$sign$oh:$om';
  }

  /// Creates, updates, and prunes active XHabit routines in user's Google Calendar.
  Future<({int syncedCount, bool ok})> syncHabitsViaApi({
    required GoogleSignInAccount account,
    required List<Habit> habits,
  }) async {
    final driveSvc = GoogleDriveSyncService.instance;
    final remoteIds = <String>{};
    String? pageToken;

    do {
      final listUri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/primary/events',
        {
          'privateExtendedProperty': 'xhabitApp=true',
          'maxResults': '250',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      final listRes = await driveSvc.authorizedRequest(
        account: account,
        method: 'GET',
        uri: listUri,
      );
      if (listRes.statusCode != 200) {
        return (syncedCount: 0, ok: false);
      }
      final map = jsonDecode(listRes.body) as Map<String, dynamic>;
      final items = (map['items'] as List?) ?? const [];
      for (final raw in items) {
        if (raw is Map && raw['id'] is String && raw['status'] != 'cancelled') {
          remoteIds.add(raw['id'] as String);
        }
      }
      pageToken = map['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    final tzId = await _resolveIanaTimeZone();
    final now = DateTime.now();
    final activeIds = <String>{};
    var syncedCount = 0;
    var allWritesOk = true;

    for (final h in habits) {
      if (h.isArchived) continue;
      final evId = deterministicEventId(h.id);
      activeIds.add(evId);

      final hour = h.reminderHour ?? 9;
      final minute = h.reminderMinute ?? 0;
      final start = DateTime(now.year, now.month, now.day, hour, minute);
      final end = start.add(const Duration(minutes: 30));
      final rrule = _rruleForHabit(h);

      final payloadMap = <String, dynamic>{
        'id': evId,
        'status': 'confirmed',
        'summary': h.title,
        'description':
            h.description.isEmpty ? 'XHabit Routine' : h.description,
        'start': {'dateTime': _rfc3339Local(start), 'timeZone': tzId},
        'end': {'dateTime': _rfc3339Local(end), 'timeZone': tzId},
        if (rrule != null) 'recurrence': ['RRULE:$rrule'],
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 5},
          ],
        },
        'extendedProperties': {
          'private': {
            'xhabitApp': 'true',
            'xhabitId': h.id,
          },
        },
      };

      if (remoteIds.contains(evId)) {
        final patchRes = await driveSvc.authorizedRequest(
          account: account,
          method: 'PATCH',
          uri: Uri.https(
            'www.googleapis.com',
            '/calendar/v3/calendars/primary/events/$evId',
          ),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payloadMap),
        );
        if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
          syncedCount++;
        } else {
          allWritesOk = false;
        }
      } else {
        final postRes = await driveSvc.authorizedRequest(
          account: account,
          method: 'POST',
          uri: Uri.https(
            'www.googleapis.com',
            '/calendar/v3/calendars/primary/events',
          ),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payloadMap),
        );
        if (postRes.statusCode == 409) {
          final patchRes = await driveSvc.authorizedRequest(
            account: account,
            method: 'PATCH',
            uri: Uri.https(
              'www.googleapis.com',
              '/calendar/v3/calendars/primary/events/$evId',
            ),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payloadMap),
          );
          if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
            syncedCount++;
          } else {
            allWritesOk = false;
          }
        } else if (postRes.statusCode >= 200 && postRes.statusCode < 300) {
          syncedCount++;
        } else {
          allWritesOk = false;
        }
      }
    }

    // Remove events for deleted or archived habits
    for (final staleId in remoteIds) {
      if (!activeIds.contains(staleId)) {
        final delRes = await driveSvc.authorizedRequest(
          account: account,
          method: 'DELETE',
          uri: Uri.https(
            'www.googleapis.com',
            '/calendar/v3/calendars/primary/events/$staleId',
          ),
        );
        if (delRes.statusCode >= 400 && delRes.statusCode != 404 && delRes.statusCode != 410) {
          allWritesOk = false;
        }
      }
    }

    return (syncedCount: syncedCount, ok: allWritesOk);
  }

  /// Builds valid RFC-5545 iCalendar `.ics` text for scheduled XHabit reminders.
  static String buildIcsSchedule(
    List<Habit> habits, {
    DateTime? anchorDate,
  }) {
    final base = anchorDate ?? DateTime.now();
    final buf = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//XHabit//Habit Schedule//EN')
      ..writeln('CALSCALE:GREGORIAN');

    for (final h in habits) {
      if (h.isArchived) continue;
      final hour = h.reminderHour ?? 9;
      final minute = h.reminderMinute ?? 0;
      final dtStart =
          '${base.year}${base.month.toString().padLeft(2, '0')}${base.day.toString().padLeft(2, '0')}T${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}00';
      final endDt = DateTime(base.year, base.month, base.day, hour, minute)
          .add(const Duration(minutes: 30));
      final dtEnd =
          '${endDt.year}${endDt.month.toString().padLeft(2, '0')}${endDt.day.toString().padLeft(2, '0')}T${endDt.hour.toString().padLeft(2, '0')}${endDt.minute.toString().padLeft(2, '0')}00';

      buf
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:xhabit-${h.id}@xhabit.tracker')
        ..writeln('DTSTART:$dtStart')
        ..writeln('DTEND:$dtEnd')
        ..writeln('SUMMARY:${_escapeIcs(h.title)}')
        ..writeln(
            'DESCRIPTION:${_escapeIcs(h.description.isEmpty ? 'XHabit Routine' : h.description)}')
        ..writeln('RRULE:${_rruleForHabit(h)}')
        ..writeln('BEGIN:VALARM')
        ..writeln('TRIGGER:-PT5M')
        ..writeln('ACTION:DISPLAY')
        ..writeln('DESCRIPTION:${_escapeIcs(h.title)}')
        ..writeln('END:VALARM')
        ..writeln('END:VEVENT');
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  static String _escapeIcs(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  /// Exports `.ics` file into Downloads/XHabit (`xhabit_google_calendar.ics`).
  Future<String?> exportIcsFile(List<Habit> habits) async {
    final ics = buildIcsSchedule(habits);
    return LocalStorageService.instance.saveTextDownload(
      fileName: 'xhabit_google_calendar.ics',
      content: ics,
      mimeType: 'text/calendar',
    );
  }

  /// Opens native Android Calendar insert sheet (Google Calendar compatible).
  Future<bool> addHabitToGoogleCalendar(Habit habit) async {
    if (!Platform.isAndroid) return false;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      habit.reminderHour ?? 9,
      habit.reminderMinute ?? 0,
    );
    final end = start.add(const Duration(minutes: 30));
    try {
      return await _uiStorageChannel.invokeMethod<bool>('launchCalendarInsert', {
            'title': habit.title,
            'description': habit.description.isEmpty
                ? 'XHabit Routine'
                : habit.description,
            'beginTimeMs': start.millisecondsSinceEpoch,
            'endTimeMs': end.millisecondsSinceEpoch,
            'rrule': _rruleForHabit(habit),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
