import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Information about an available app update
class AppUpdateInfo {
  final String tagName;
  final String versionName;
  final int? buildNumber;
  final String title;
  final String notes;
  final String downloadUrl;
  final int apkSize;
  final DateTime? publishedAt;
  final bool isNewer;
  final String currentVersion;
  final String currentBuild;

  const AppUpdateInfo({
    required this.tagName,
    required this.versionName,
    this.buildNumber,
    required this.title,
    required this.notes,
    required this.downloadUrl,
    required this.apkSize,
    this.publishedAt,
    required this.isNewer,
    required this.currentVersion,
    required this.currentBuild,
  });

  String get formattedSize {
    if (apkSize <= 0) return '';
    final mb = apkSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Status of an active in-app update download
enum UpdateDownloadStatus {
  idle,
  downloading,
  installing,
  completed,
  failed,
}

/// Progress model for the active OTA update
class UpdateProgress {
  final UpdateDownloadStatus status;
  final int percentage;
  final String? error;

  const UpdateProgress({
    required this.status,
    this.percentage = 0,
    this.error,
  });

  const UpdateProgress.idle()
      : status = UpdateDownloadStatus.idle,
        percentage = 0,
        error = null;
}

/// Service handling release version checking and in-app OTA APK installation
class UpdateService {
  static const String repoOwner = 'suraj-yadav0';
  static const String repoName = 'money_manager';
  static const String apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compare two semver strings: returns true if [remote] is newer than [current]
  static bool isNewer(
    String remoteTag,
    String currentVersion, {
    int? currentBuild,
  }) {
    final cleanRemote = remoteTag.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanCurrent = currentVersion.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final remoteParts = cleanRemote.split('+');
    final remoteVer = remoteParts[0].split('.');
    final remoteBuild =
        remoteParts.length > 1 ? int.tryParse(remoteParts[1]) : null;

    final currentParts = cleanCurrent.split('+');
    final currentVer = currentParts[0].split('.');
    final currBuild = currentBuild ??
        (currentParts.length > 1 ? int.tryParse(currentParts[1]) : null);

    final maxLen = remoteVer.length > currentVer.length
        ? remoteVer.length
        : currentVer.length;

    for (int i = 0; i < maxLen; i++) {
      final rNum = i < remoteVer.length ? int.tryParse(remoteVer[i]) ?? 0 : 0;
      final cNum = i < currentVer.length ? int.tryParse(currentVer[i]) ?? 0 : 0;

      if (rNum > cNum) return true;
      if (rNum < cNum) return false;
    }

    if (remoteBuild != null && currBuild != null) {
      return remoteBuild > currBuild;
    }

    return false;
  }

  /// Check GitHub for the latest release
  Future<AppUpdateInfo?> checkLatestRelease() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      final currBuildNum = int.tryParse(currentBuild);

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(apiUrl));
      request.headers.set('User-Agent', 'Quantro-App');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final title = json['name'] as String? ?? tagName;
      final notes = json['body'] as String? ?? '';
      final publishedAtStr = json['published_at'] as String?;
      final publishedAt =
          publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final assets = (json['assets'] as List<dynamic>?) ?? [];
      Map<String, dynamic>? apkAsset;

      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          if (name.contains('quantro') || apkAsset == null) {
            apkAsset = a as Map<String, dynamic>;
          }
        }
      }

      if (apkAsset == null) {
        return null;
      }

      final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
      final size = apkAsset['size'] as int? ?? 0;

      final cleanTag = tagName.replaceFirst(RegExp(r'^[vV]'), '');
      final tagParts = cleanTag.split('+');
      final remoteVer = tagParts[0];
      final remoteBuild =
          tagParts.length > 1 ? int.tryParse(tagParts[1]) : null;

      final hasUpdate = isNewer(
        tagName,
        currentVersion,
        currentBuild: currBuildNum,
      );

      return AppUpdateInfo(
        tagName: tagName,
        versionName: remoteVer,
        buildNumber: remoteBuild,
        title: title,
        notes: notes,
        downloadUrl: downloadUrl,
        apkSize: size,
        publishedAt: publishedAt,
        isNewer: hasUpdate,
        currentVersion: currentVersion,
        currentBuild: currentBuild,
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Start the in-app OTA download and trigger installation
  Stream<UpdateProgress> startOtaUpdate(String downloadUrl) async* {
    if (kIsWeb || !Platform.isAndroid) {
      yield const UpdateProgress(
        status: UpdateDownloadStatus.failed,
        error: 'In-app update is only supported on Android devices.',
      );
      return;
    }

    try {
      yield const UpdateProgress(
        status: UpdateDownloadStatus.downloading,
        percentage: 0,
      );

      final stream = OtaUpdate().execute(
        downloadUrl,
        destinationFilename: 'quantro_update.apk',
        androidProviderAuthority:
            'com.example.money_manager.ota_update_provider',
      );

      await for (final event in stream) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final progress = int.tryParse(event.value ?? '0') ?? 0;
            yield UpdateProgress(
              status: UpdateDownloadStatus.downloading,
              percentage: progress.clamp(0, 100),
            );
            break;
          case OtaStatus.INSTALLING:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.installing,
              percentage: 100,
            );
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.failed,
              error: 'An update is already running in the background.',
            );
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.failed,
              error:
                  'Storage or install permission denied. Please allow install unknown apps in settings.',
            );
            break;
          case OtaStatus.DOWNLOAD_ERROR:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.failed,
              error: 'Failed to download update package. Check your network.',
            );
            break;
          case OtaStatus.INSTALLATION_DONE:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.completed,
              percentage: 100,
            );
            break;
          case OtaStatus.INSTALLATION_ERROR:
            yield UpdateProgress(
              status: UpdateDownloadStatus.failed,
              error: 'Installation failed: ${event.value ?? "error"}',
            );
            break;
          case OtaStatus.CANCELED:
            yield const UpdateProgress(
              status: UpdateDownloadStatus.idle,
              percentage: 0,
            );
            break;
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
            yield UpdateProgress(
              status: UpdateDownloadStatus.failed,
              error: 'Update failed: ${event.value ?? "internal error"}',
            );
            break;
        }
      }
    } catch (e) {
      yield UpdateProgress(
        status: UpdateDownloadStatus.failed,
        error: 'Unable to start update: $e',
      );
    }
  }
}
