import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/config/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_shell.dart';
import 'core/providers/app_state_provider.dart';
import 'core/providers/auth_providers.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initialize();
  runApp(const ProviderScope(child: MoneyManagerApp()));
}

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Quantro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnboardedAsync = ref.watch(isOnboardedProvider);

    return isOnboardedAsync.when(
      data: (isOnboarded) {
        if (!isOnboarded) {
          return const OnboardingScreen();
        }

        final currentUser = ref.watch(currentUserProvider);
        final isGuestMode = ref.watch(guestModeProvider);

        if (currentUser != null || isGuestMode) {
          return const AppShell();
        }

        return const AuthScreen();
      },
      loading: () => const _SplashScreen(),
      error: (err, stack) => const OnboardingScreen(),
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
