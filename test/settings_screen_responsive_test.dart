import 'dart:ffi' show DynamicLibrary;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqlite3/open.dart';

import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/core/providers/app_state_provider.dart';
import 'package:money_manager/core/providers/auth_providers.dart';
import 'package:money_manager/core/providers/update_providers.dart';
import 'package:money_manager/features/settings/screens/settings_screen.dart';
import 'package:money_manager/features/sms/providers/sms_providers.dart';

void main() {
  setUpAll(() {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = db.createMigrator();
    await migrator.createAll();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('SettingsScreen renders iOS grouped layout without overflow on compact viewports',
      (tester) async {
    const viewports = [280.0, 320.0, 375.0, 412.0, 600.0];
    const textScales = [1.0, 1.2];

    for (final width in viewports) {
      for (final scale in textScales) {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              currentUserProvider.overrideWithValue(null),
              pendingSmsCountProvider.overrideWith((ref) => 3),
              packageInfoProvider.overrideWith(
                (ref) => Future.value(
                  PackageInfo(
                    appName: 'Quantro',
                    packageName: 'com.surajyadav.quantro',
                    version: '1.0.11',
                    buildNumber: '12',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: SettingsScreen(key: ValueKey('settings_${width}_$scale')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Validate top iOS section headers
        expect(find.text('ACCOUNT & CLOUD'), findsOneWidget);
        expect(find.text('BANK ACCOUNTS & SMS'), findsOneWidget);
        expect(find.text('FINANCES & CURRENCY'), findsOneWidget);
        expect(find.text('Monthly Income'), findsOneWidget);
        expect(find.text('Primary Currency'), findsOneWidget);

        // Scroll to reveal appearance section
        await tester.scrollUntilVisible(
          find.text('APPEARANCE & THEME'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('APPEARANCE & THEME'), findsOneWidget);
        expect(find.text('Interface Style'), findsOneWidget);
        expect(find.text('Fintech Palette'), findsOneWidget);

        // Scroll to reveal data and about sections
        await tester.scrollUntilVisible(
          find.text('ABOUT QUANTRO'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('ABOUT QUANTRO'), findsOneWidget);
        expect(find.text('Clear All Data'), findsOneWidget);

        // Zero exceptions or overflows
        expect(tester.takeException(), isNull);
      }
    }

    addTearDown(tester.view.resetPhysicalSize);
  });
}
