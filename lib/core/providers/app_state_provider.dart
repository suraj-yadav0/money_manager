import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../database/database.dart';
import '../theme/app_theme.dart';

/// Provides the AppDatabase instance
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  db.deduplicateAll();
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

/// Gets current currency symbol
final currencyProvider = Provider<String>((ref) {
  final settingsAsync = ref.watch(userSettingsProvider);

  return settingsAsync.when(
    data: (settings) {
      final code = settings?.currency ?? AppConstants.defaultCurrency;
      return AppConstants.supportedCurrencies[code] ??
          AppConstants.currencySymbol;
    },
    loading: () => AppConstants.currencySymbol,
    error: (_, _) => AppConstants.currencySymbol,
  );
});

/// Shared preferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// Theme Mode state notifier with SharedPreferences persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == ThemeMode.light) {
        await prefs.setString(_key, 'light');
      } else if (mode == ThemeMode.dark) {
        await prefs.setString(_key, 'dark');
      } else {
        await prefs.setString(_key, 'system');
      }
    } catch (_) {}
  }
}

final themeModeNotifierProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Fintech Palette state notifier with SharedPreferences persistence
class FintechPaletteNotifier extends StateNotifier<FintechPalette> {
  static const String _key = 'app_fintech_palette';

  FintechPaletteNotifier() : super(FintechPalette.credObsidian) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_key);
      if (savedId != null) {
        state = FintechPalette.fromId(savedId);
      }
    } catch (_) {}
  }

  Future<void> setPalette(FintechPalette palette) async {
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, palette.id);
    } catch (_) {}
  }
}

final fintechPaletteNotifierProvider =
    StateNotifierProvider<FintechPaletteNotifier, FintechPalette>((ref) {
  return FintechPaletteNotifier();
});
