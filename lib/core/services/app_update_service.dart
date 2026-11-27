import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
  });

  final String versionName;
  final int versionCode;
}

class UpdateReleaseInfo {
  const UpdateReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.htmlUrl,
    this.apkAssetName,
    this.apkDownloadUrl,
    this.apkSizeBytes = 0,
  });

  final String tagName;
  final String cleanVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String htmlUrl;
  final String? apkAssetName;
  final String? apkDownloadUrl;
  final int apkSizeBytes;

  bool get hasApkAsset =>
      apkDownloadUrl != null && apkDownloadUrl!.isNotEmpty;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.hasUpdate,
    this.latestRelease,
    this.errorMessage,
  });

  final AppVersionInfo currentVersion;
  final bool hasUpdate;
  final UpdateReleaseInfo? latestRelease;
  final String? errorMessage;

  bool get isError => errorMessage != null;
}

/// Checks GitHub Releases for newer XHabit APKs, downloads them inside the app
/// with progress reporting, and triggers Android's native package installer.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const MethodChannel _storageChannel =
      MethodChannel('app.xhabit.tracker/storage');
  static const MethodChannel _uiStorageChannel =
      MethodChannel('app.xhabit.tracker/storage_ui');

  /// Override via `--dart-define=XHABIT_UPDATE_REPO=owner/repo` if forked.
  static const String githubRepo = String.fromEnvironment(
    'XHABIT_UPDATE_REPO',
    defaultValue: 'ikianixi/xhabit',
  );

  static const String _fallbackVersionName = '1.0.0';
  static const int _fallbackVersionCode = 1;

  Future<AppVersionInfo> getInstalledVersion() async {
    if (Platform.isAndroid) {
      try {
        final raw = await _storageChannel
            .invokeMapMethod<String, dynamic>('getAppVersion');
        if (raw != null) {
          final vName =
              (raw['versionName'] as String?)?.trim() ?? _fallbackVersionName;
          final vCode = (raw['versionCode'] as int?) ?? _fallbackVersionCode;
          return AppVersionInfo(
            versionName: vName.isEmpty ? _fallbackVersionName : vName,
            versionCode: vCode,
          );
        }
      } catch (_) {}
    }
    return const AppVersionInfo(
      versionName: _fallbackVersionName,
      versionCode: _fallbackVersionCode,
    );
  }

  Future<UpdateCheckResult> checkForUpdates() async {
    final current = await getInstalledVersion();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      Map<String, dynamic>? releaseJson;

      // Try /releases/latest first; fall back to /releases?per_page=1 if needed.
      final latestUri =
          Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final res = await _getJson(client, latestUri);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        releaseJson = res.data as Map<String, dynamic>;
      } else if (res.statusCode == 404) {
        final listUri = Uri.parse(
            'https://api.github.com/repos/$githubRepo/releases?per_page=1');
        final listRes = await _getJson(client, listUri);
        if (listRes.statusCode == 200 &&
            listRes.data is List &&
            (listRes.data as List).isNotEmpty) {
          final first = (listRes.data as List).first;
          if (first is Map<String, dynamic>) releaseJson = first;
        } else if (listRes.statusCode == 404 ||
            (listRes.statusCode == 200 && (listRes.data as List).isEmpty)) {
          return UpdateCheckResult(
            currentVersion: current,
            hasUpdate: false,
          );
        } else {
          return UpdateCheckResult(
            currentVersion: current,
            hasUpdate: false,
            errorMessage: 'http_${listRes.statusCode}',
          );
        }
      } else {
        return UpdateCheckResult(
          currentVersion: current,
          hasUpdate: false,
          errorMessage: 'http_${res.statusCode}',
        );
      }

      if (releaseJson == null) {
        return UpdateCheckResult(currentVersion: current, hasUpdate: false);
      }

      final tag = (releaseJson['tag_name'] as String?)?.trim() ?? '';
      final cleanRemote = _normalizeVersion(tag);
      final cleanLocal = _normalizeVersion(current.versionName);
      final name = (releaseJson['name'] as String?)?.trim() ?? tag;
      final body = (releaseJson['body'] as String?)?.trim() ?? '';
      final htmlUrl = (releaseJson['html_url'] as String?)?.trim() ??
          'https://github.com/$githubRepo/releases';

      String? apkName;
      String? apkUrl;
      var apkSize = 0;
      final assets = (releaseJson['assets'] as List?) ?? const [];
      for (final raw in assets) {
        if (raw is! Map) continue;
        final aName = (raw['name'] as String?) ?? '';
        final aUrl = (raw['browser_download_url'] as String?) ?? '';
        if (aName.toLowerCase().endsWith('.apk') && aUrl.isNotEmpty) {
          apkName = aName;
          apkUrl = aUrl;
          apkSize = (raw['size'] as int?) ?? 0;
          break;
        }
      }

      final info = UpdateReleaseInfo(
        tagName: tag.isEmpty ? cleanRemote : tag,
        cleanVersion: cleanRemote,
        releaseTitle: name,
        releaseNotes: body,
        htmlUrl: htmlUrl,
        apkAssetName: apkName,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
      );

      return UpdateCheckResult(
        currentVersion: current,
        hasUpdate: compareSemver(cleanRemote, cleanLocal) > 0,
        latestRelease: info,
      );
    } on SocketException {
      return UpdateCheckResult(
        currentVersion: current,
        hasUpdate: false,
        errorMessage: 'offline',
      );
    } on TimeoutException {
      return UpdateCheckResult(
        currentVersion: current,
        hasUpdate: false,
        errorMessage: 'timeout',
      );
    } catch (_) {
      return UpdateCheckResult(
        currentVersion: current,
        hasUpdate: false,
        errorMessage: 'error',
      );
    } finally {
      client.close();
    }
  }

  Future<({int statusCode, dynamic data})> _getJson(
    HttpClient client,
    Uri uri,
  ) async {
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'XHabit-Android-Updater');
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode == 200) {
      return (statusCode: resp.statusCode, data: jsonDecode(body));
    }
    return (statusCode: resp.statusCode, data: null);
  }

  Future<String?>? _inFlightDownload;
  String? _inFlightUrl;

  /// Streams the APK asset into app storage and reports download progress (0..1).
  Future<String?> downloadApk(
    UpdateReleaseInfo release, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final url = release.apkDownloadUrl;
    if (url == null || url.isEmpty) return null;
    if (_inFlightDownload != null && _inFlightUrl == url) {
      return _inFlightDownload;
    }
    _inFlightUrl = url;
    final fut = _downloadApkInternal(release, url, onProgress: onProgress);
    _inFlightDownload = fut;
    try {
      return await fut;
    } finally {
      if (_inFlightDownload == fut) {
        _inFlightDownload = null;
        _inFlightUrl = null;
      }
    }
  }

  Future<String?> _downloadApkInternal(
    UpdateReleaseInfo release,
    String url, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final dir = await _updatesDirectory();
    final safeName = (release.apkAssetName ?? 'XHabit-${release.cleanVersion}.apk')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final partFile = File(p.join(dir.path, '$safeName.part'));
    final finalFile = File(p.join(dir.path, safeName));

    // Remove older stale APK/part files before saving a new release.
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path != finalFile.path) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (await partFile.exists()) await partFile.delete();
    if (await finalFile.exists() &&
        release.apkSizeBytes > 0 &&
        await finalFile.length() == release.apkSizeBytes) {
      onProgress?.call(1.0, release.apkSizeBytes, release.apkSizeBytes);
      return finalFile.path;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'XHabit-Android-Updater');
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return null;
      }

      final total = resp.contentLength > 0
          ? resp.contentLength
          : release.apkSizeBytes;
      var received = 0;
      sink = partFile.openWrite();

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress?.call(prog, received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalFile.path);
      return finalFile.path;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  /// Launches Android's package installer for a downloaded APK.
  /// Returns `'launched'`, `'needs_permission'`, or `'error'`.
  Future<String> installDownloadedApk(String filePath) async {
    if (!Platform.isAndroid) return 'error';
    try {
      return await _uiStorageChannel.invokeMethod<String>('installApk', {
            'filePath': filePath,
          }) ??
          'error';
    } catch (_) {
      return 'error';
    }
  }

  Future<Directory> _updatesDirectory() async {
    final base =
        (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
            await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'XHabit', 'Updates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _normalizeVersion(String raw) {
    final stripped = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = stripped.split('+').first.split('-').first;
    return core.trim();
  }

  /// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
  static int compareSemver(String a, String b) {
    List<int> parts(String v) => _normalizeVersion(v)
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}
