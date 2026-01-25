import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';

/// Provides the AppDatabase instance
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Checks if user has completed onboarding
final isOnboardedProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = await db.select(db.userSettings).getSingleOrNull();
  return settings?.isOnboarded ?? false;
});

/// Gets current user settings
final userSettingsProvider = StreamProvider<UserSetting?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.userSettings).watchSingleOrNull();
});

/// Shared preferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});
