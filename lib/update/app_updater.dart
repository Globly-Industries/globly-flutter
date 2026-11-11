import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// A newer release on GitHub than the installed app.
class AppUpdate {
  final String version;
  final String currentVersion;
  final String apkUrl;
  final String apkName;

  const AppUpdate({
    required this.version,
    required this.currentVersion,
    required this.apkUrl,
    required this.apkName,
  });
}

/// Self-update for sideloaded Android builds: checks the latest release in the public
/// globly-releases repo (published there by .github/workflows/android-release.yml), downloads its
/// APK and hands it to Android's installer.
/// The user still confirms the install; Android doesn't allow silent installs outside the Play Store.
class AppUpdater {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/Globly-Industries/globly-releases/releases/latest';
  static const _channel = MethodChannel('globly/updater');

  /// Only release builds on Android. Debug builds and local release builds are signed with the
  /// debug key, so Android would refuse the CI-signed APK as an update anyway.
  static bool get supported => kReleaseMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final Dio _dio;

  AppUpdater([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
            ));

  /// The newer release, or null when the app is up to date. Throws on network errors.
  Future<AppUpdate?> check() async {
    final info = await PackageInfo.fromPlatform();
    final response = await _dio.get<Map<String, dynamic>>(
      _latestReleaseUrl,
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    await _deleteOldDownloads();
    return parseRelease(response.data ?? const {}, info.version);
  }

  /// Downloads the APK into the app's cache and returns its path.
  Future<String> download(AppUpdate update, {void Function(double progress)? onProgress, CancelToken? cancel}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    final path = '${dir.path}/${update.apkName}';
    await _dio.download(
      update.apkUrl,
      path,
      cancelToken: cancel,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    return path;
  }

  /// Opens Android's installer for the downloaded APK. The first time, Android asks the user to
  /// allow installs from Globly and then continues.
  Future<void> install(String apkPath) => _channel.invokeMethod('install', {'path': apkPath});

  /// Removes APKs from earlier updates (the app was replaced, so they are no longer needed).
  Future<void> _deleteOldDownloads() async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best effort; the cache is cleared by Android eventually.
    }
  }
}

/// Picks the release's APK if the release is newer than [currentVersion]. Drafts and prereleases
/// are never returned by GitHub's /releases/latest.
@visibleForTesting
AppUpdate? parseRelease(Map<String, dynamic> release, String currentVersion) {
  final tag = release['tag_name'];
  if (tag is! String || compareVersions(tag, currentVersion) <= 0) return null;

  final assets = release['assets'];
  if (assets is! List) return null;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = asset['name'];
    final url = asset['browser_download_url'];
    if (name is String && url is String && name.toLowerCase().endsWith('.apk')) {
      return AppUpdate(
        version: _clean(tag),
        currentVersion: _clean(currentVersion),
        apkUrl: url,
        apkName: name,
      );
    }
  }
  return null;
}

/// Compares versions like "v0.1.10" and "0.1.9" numerically. Negative when [a] is older.
@visibleForTesting
int compareVersions(String a, String b) {
  final pa = _parts(a), pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final diff = pa[i] - pb[i];
    if (diff != 0) return diff;
  }
  return 0;
}

String _clean(String version) {
  var v = version.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  return v.split('+').first.split('-').first;
}

List<int> _parts(String version) {
  final parts = _clean(version).split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}
