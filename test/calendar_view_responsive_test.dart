import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/features/dashboard/screens/calendar_view_screen.dart';

void main() {
  testWidgets('CalendarViewScreen renders without overflow in landscape and portrait',
      (tester) async {
    final testSizes = [
      // Landscape orientations
      const Size(1080, 508),
      const Size(800, 400),
      const Size(900, 360),
      const Size(640, 340),
      // Portrait orientations
      const Size(412, 900),
      const Size(360, 780),
    ];
    const textScales = [1.0, 1.25];

    for (final size in testSizes) {
      for (final scale in textScales) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: const CalendarViewScreen(),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Calendar View'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }

    addTearDown(tester.view.resetPhysicalSize);
  });
}
