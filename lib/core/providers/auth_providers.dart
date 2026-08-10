import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'app_state_provider.dart';

/// AuthService Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return AuthService(prefs);
});

/// SyncService Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

/// Stream of Firebase Auth state changes
final authStateStreamProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateStream ?? const Stream.empty();
});

/// Current Logged-in Firebase User
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateStreamProvider); // trigger rebuild on auth changes
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// StateNotifier for Guest (Offline-Only) Mode
class GuestModeNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  GuestModeNotifier(this._authService) : super(_authService.isGuestMode);

  Future<void> enableGuestMode() async {
    await _authService.setGuestMode(true);
    state = true;
  }

  Future<void> disableGuestMode() async {
    await _authService.setGuestMode(false);
    state = false;
  }
}

final guestModeProvider =
    StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return GuestModeNotifier(authService);
});

/// StateNotifier tracking Cloud Sync Status
class SyncStatusState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncTime;

  SyncStatusState({
    required this.status,
    this.message,
    this.lastSyncTime,
  });

  SyncStatusState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncStatusState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncStatusState> {
  final SyncService _syncService;

  SyncNotifier(this._syncService)
      : super(SyncStatusState(status: SyncStatus.idle));

  Future<SyncResult> triggerSync() async {
    state = state.copyWith(status: SyncStatus.syncing, message: 'Syncing with cloud...');
    final result = await _syncService.syncAll();

    if (result.success) {
      state = state.copyWith(
        status: SyncStatus.success,
        message: result.message,
        lastSyncTime: DateTime.now(),
      );
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        message: result.message,
      );
    }
    return result;
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncStatusState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncNotifier(syncService);
});
