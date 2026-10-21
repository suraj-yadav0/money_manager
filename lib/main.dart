import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_shell.dart';
import 'core/providers/app_state_provider.dart';
import 'core/providers/auth_providers.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await FirebaseConfig.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
      child: const MoneyManagerApp(),
    ),
  );
}

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeNotifierProvider);
    final palette = ref.watch(fintechPaletteNotifierProvider);

    return MaterialApp(
      title: 'Quantro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(palette, Brightness.light),
      darkTheme: AppTheme.buildTheme(palette, Brightness.dark),
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuestMode = ref.watch(guestModeProvider);

    // If user is an active offline guest, bypass auth gate
    if (isGuestMode) {
      return const AppShell();
    }

    final authStateAsync = ref.watch(authStateStreamProvider);

    return authStateAsync.when(
      data: (user) {
        if (user != null) {
          return const AppShell();
        }

        final isOnboardedAsync = ref.watch(isOnboardedProvider);
        return isOnboardedAsync.when(
          data: (isOnboarded) {
            if (!isOnboarded) {
              return const OnboardingScreen();
            }
            return const AuthScreen();
          },
          loading: () => const _SplashScreen(),
          error: (err, stack) => const OnboardingScreen(),
        );
      },
      loading: () => const _SplashScreen(),
      error: (err, stack) {
        final currentUser = ref.watch(currentUserProvider);
        if (currentUser != null) {
          return const AppShell();
        }
        return const AuthScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              'Quantro',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
