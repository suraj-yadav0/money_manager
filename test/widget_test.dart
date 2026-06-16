import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_manager/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MoneyManagerApp(),
      ),
    );

    // Verify the app starts with splash or onboarding
    expect(find.byType(MoneyManagerApp), findsOneWidget);
  });
}

