import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_manager/features/dashboard/widgets/analytics_card.dart';
import 'package:money_manager/features/dashboard/providers/chart_type_provider.dart';
import 'package:money_manager/features/dashboard/providers/dashboard_providers.dart';
import 'package:money_manager/features/dashboard/screens/dashboard_screen.dart';

void main() {
  testWidgets('AnalyticsCard renders responsively without overflow across screen sizes and text scales',
      (tester) async {
    const screenWidths = [280.0, 320.0, 360.0, 390.0, 412.0, 600.0, 900.0];
    const textScales = [1.0, 1.25, 1.4];

    for (final width in screenWidths) {
      for (final scale in textScales) {
        tester.view.physicalSize = Size(width, 900);
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
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AnalyticsCard(),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Expense'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
        expect(find.byIcon(Icons.pie_chart_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
        expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);

        expect(tester.takeException(), isNull);
      }
    }

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('AnalyticsCard controls switch states seamlessly', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AnalyticsCard(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Default state: expense, pie
    expect(container.read(dashboardTransactionTypeProvider), 'expense');
    expect(container.read(dashboardChartTypeProvider), DashboardChartType.pie);

    // Switch to Income
    await tester.tap(find.text('Income'));
    await tester.pump();
    expect(container.read(dashboardTransactionTypeProvider), 'income');

    // Switch to Bar
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pump();
    expect(container.read(dashboardChartTypeProvider), DashboardChartType.bar);

    // Switch to Line/Trend
    await tester.tap(find.byIcon(Icons.show_chart_rounded));
    await tester.pump();
    expect(container.read(dashboardChartTypeProvider), DashboardChartType.line);

    // Switch back to Expense and Pie
    await tester.tap(find.text('Expense'));
    await tester.pump();
    expect(container.read(dashboardTransactionTypeProvider), 'expense');

    await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded));
    await tester.pump();
    expect(container.read(dashboardChartTypeProvider), DashboardChartType.pie);
  });

  testWidgets('DashboardScreen renders AnalyticsCard responsively', (tester) async {
    const screenWidths = [320.0, 390.0, 600.0];

    for (final width in screenWidths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnalyticsCard), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
  });
}

