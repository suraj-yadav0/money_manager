import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';

/// Provider for UpdateService singleton
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// Provider for current platform package info
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

/// State for the update check process
class UpdateCheckState {
  final bool isChecking;
  final AppUpdateInfo? updateInfo;
  final String? error;
  final DateTime? lastChecked;

  const UpdateCheckState({
    this.isChecking = false,
    this.updateInfo,
    this.error,
    this.lastChecked,
  });

  UpdateCheckState copyWith({
    bool? isChecking,
    AppUpdateInfo? updateInfo,
    String? error,
    DateTime? lastChecked,
  }) {
    return UpdateCheckState(
      isChecking: isChecking ?? this.isChecking,
      updateInfo: updateInfo ?? this.updateInfo,
      error: error,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

/// Notifier managing checking for updates
class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  final UpdateService _service;
  static const String _prefLastCheckKey = 'last_update_check_epoch';
  static const Duration _autoCheckInterval = Duration(hours: 12);

  UpdateCheckNotifier(this._service) : super(const UpdateCheckState());

  /// Check for updates. If [force] is false, throttles automatic checks.
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (kIsWeb) return null;

    final prefs = await SharedPreferences.getInstance();
    final lastEpoch = prefs.getInt(_prefLastCheckKey) ?? 0;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastEpoch);
    final now = DateTime.now();

    if (!force && lastEpoch > 0 && now.difference(lastTime) < _autoCheckInterval) {
      return state.updateInfo;
    }

    state = state.copyWith(isChecking: true, error: null);

    try {
      final info = await _service.checkLatestRelease();
      await prefs.setInt(_prefLastCheckKey, now.millisecondsSinceEpoch);

      state = state.copyWith(
        isChecking: false,
        updateInfo: info,
        lastChecked: now,
      );
      return info;
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

final updateCheckNotifierProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>((ref) {
  final service = ref.watch(updateServiceProvider);
  return UpdateCheckNotifier(service);
});

/// Notifier managing active OTA download and installation
class OtaDownloadNotifier extends StateNotifier<UpdateProgress> {
  final UpdateService _service;
  StreamSubscription<UpdateProgress>? _subscription;

  OtaDownloadNotifier(this._service) : super(const UpdateProgress.idle());

  Future<void> startUpdate(String downloadUrl) async {
    await _subscription?.cancel();
    state = const UpdateProgress(
      status: UpdateDownloadStatus.downloading,
      percentage: 0,
    );

    _subscription = _service.startOtaUpdate(downloadUrl).listen(
      (progress) {
        state = progress;
      },
      onError: (err) {
        state = UpdateProgress(
          status: UpdateDownloadStatus.failed,
          error: err.toString(),
        );
      },
      onDone: () {
        if (state.status == UpdateDownloadStatus.downloading) {
          state = const UpdateProgress(
            status: UpdateDownloadStatus.installing,
            percentage: 100,
          );
        }
      },
    );
  }

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    state = const UpdateProgress.idle();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final otaDownloadNotifierProvider =
    StateNotifierProvider<OtaDownloadNotifier, UpdateProgress>((ref) {
  final service = ref.watch(updateServiceProvider);
  return OtaDownloadNotifier(service);
});
