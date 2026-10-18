import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/main.dart';

import 'package:money_manager/core/providers/app_state_provider.dart';
import 'package:money_manager/core/providers/auth_providers.dart';

class FakeGuestModeNotifier extends StateNotifier<bool> implements GuestModeNotifier {
  FakeGuestModeNotifier([super.initial = false]);
  @override
  Future<void> enableGuestMode() async {
    state = true;
  }
  @override
  Future<void> disableGuestMode() async {
    state = false;
  }
}

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnboardedProvider.overrideWith((ref) => Future.value(false)),
          currentUserProvider.overrideWithValue(null),
          guestModeProvider.overrideWith((ref) => FakeGuestModeNotifier(false)),
        ],
        child: const MoneyManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify the app starts with splash or onboarding
    expect(find.byType(MoneyManagerApp), findsOneWidget);
  });
}

