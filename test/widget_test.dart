// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viewsys/main.dart';
import 'package:viewsys/screens/ticker_screen.dart';
import 'package:viewsys/providers/player_provider.dart';
import 'package:viewsys/models/ticker_item.dart';
import 'package:viewsys/services/sync_service.dart';
import 'package:viewsys/services/heartbeat_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Initialize SharedPreferences with empty mock values for the test.
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      Phoenix(
        child: const MyApp(),
      ),
    );

    // Wait for the splash screen timer (3000ms) and pump transition frames.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(); // Trigger the Timer callback
    await tester.pump(); // Flush SharedPreferences async lookup microtask
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Scroll to and tap the simulation button on the ActivationScreen.
    final simulateBtn = find.text('Simulate Activation Pairing');
    expect(simulateBtn, findsOneWidget);
    await tester.ensureVisible(simulateBtn);
    await tester.tap(simulateBtn);
    await tester.pump(); // Flush SharedPreferences async write microtask

    // Wait for the activation simulation timer (2500ms) and pump transition frames.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(); // Trigger the Timer callback
    await tester.pump(); // Flush routing microtask
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify that the screen player page is shown.
    expect(find.text('No Content Scheduled'), findsOneWidget);

    // Open settings/diagnostics dialog by tapping settings gear icon.
    final settingsBtn = find.byIcon(Icons.settings_rounded);
    expect(settingsBtn, findsOneWidget);
    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();

    // Tap the disconnect button inside dialog to verify we can go back to the activation screen.
    final disconnectBtn = find.text('Disconnect Screen');
    expect(disconnectBtn, findsOneWidget);
    await tester.tap(disconnectBtn);
    await tester.pump(); // Flush preferences write microtask

    // Wait for the transition back to the activation screen.
    await tester.pump(const Duration(milliseconds: 3000)); // Wait for splash screen
    await tester.pump(); // Trigger the Timer callback
    await tester.pump(); // Flush SharedPreferences lookup
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify we are back on the linking page.
    expect(find.text('Link Your Screen'), findsOneWidget);
  });

  testWidgets('TickerScreen renders ticker items and animates', (WidgetTester tester) async {
    // Initialize SharedPreferences with empty mock values for this test.
    SharedPreferences.setMockInitialValues({});

    // Build TickerScreen wrapped with ProviderScope containing mock tickers.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tickersProvider.overrideWith((ref) {
            final notifier = TickersNotifier();
            notifier.state = [
              TickerItem(id: 1, text: 'Test Ticker 1', bgColor: '#FF0000', textColor: '#FFFFFF'),
              TickerItem(id: 2, text: 'Test Ticker 2', bgColor: '#00FF00', textColor: '#000000'),
            ];
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: TickerScreen(),
        ),
      ),
    );

    // Initial frame builds the opacity 0.0 row to measure it
    await tester.pump();

    // Trigger the post frame callback and allow the animation controller to build
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    // Verify both ticker texts are rendered on the screen
    expect(find.text('Test Ticker 1'), findsOneWidget);
    expect(find.text('Test Ticker 2'), findsOneWidget);

    // Dispose the widget tree to trigger TickerScreen dispose and cancel its internal timers
    await tester.pumpWidget(const SizedBox.shrink());

    // Stop background timers to prevent test teardown failures
    SyncService.instance.stop();
    HeartbeatService.instance.stop();
  });
}
