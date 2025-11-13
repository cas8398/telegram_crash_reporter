import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_crash_reporter/telegram_crash_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TelegramCrashReporter Widget Tests', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Initialize with sendToTelegram disabled by default
      TelegramCrashReporter.initialize(
        botToken: 'test_bot_token',
        chatId: 123456789,
        enable: true,
      );
    });

    testWidgets('Plugin can be used in widget tree without errors',
        (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // This should not throw even if Telegram is unreachable
                      TelegramCrashReporter.sendEvent(
                        message: 'Button pressed',
                        context: 'Widget Test',
                        sendToTelegram: false, // Don't actually send
                      );
                    },
                    child: Text('Test Button'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap the button and ensure no errors
      await tester.tap(find.text('Test Button'));
      await tester.pump();

      // Verify the button is still there (no crashes)
      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('Crash reporting works in widget context',
        (WidgetTester tester) async {
      bool crashReported = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  try {
                    throw Exception('Widget test exception');
                  } catch (e, stack) {
                    await TelegramCrashReporter.reportCrash(
                      error: e,
                      stackTrace: stack,
                      context: 'Widget Test',
                      sendToTelegram: false, // Don't send to Telegram
                    );
                    crashReported = true; // This should execute
                  }
                },
                child: Text('Cause Crash'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cause Crash'));
      await tester.pumpAndSettle(); // Wait for async operations

      expect(crashReported, isTrue);
    });

    testWidgets('Multiple rapid events dont cause issues',
        (WidgetTester tester) async {
      int eventCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  for (int i = 0; i < 5; i++) {
                    await TelegramCrashReporter.sendEvent(
                      message: 'Rapid event $i',
                      sendToTelegram: false, // Don't actually send
                    );
                    eventCount++;
                  }
                },
                child: Text('Rapid Events'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Rapid Events'));
      await tester.pumpAndSettle(); // Wait for all events

      expect(eventCount, 5);
    });

    testWidgets('Plugin works with async widget operations',
        (WidgetTester tester) async {
      final results = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      results.add('start');

                      await Future.delayed(Duration(milliseconds: 100));

                      await TelegramCrashReporter.sendEvent(
                        message: 'Async event',
                        sendToTelegram: false, // Don't actually send
                      );

                      results.add('end');
                    },
                    child: Text('Async Test'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Async Test'));
      await tester.pumpAndSettle(Duration(milliseconds: 200));

      expect(results, contains('start'));
      expect(results, contains('end'));
    });

    testWidgets('Local storage works in widget context',
        (WidgetTester tester) async {
      int? finalCrashCount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await TelegramCrashReporter.reportCrash(
                    error: 'Widget storage test',
                    stackTrace: StackTrace.current,
                    sendToTelegram: false,
                  );

                  finalCrashCount = await TelegramCrashReporter.getCrashCount();
                },
                child: Text('Test Storage'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Storage'));
      await tester.pumpAndSettle();

      expect(finalCrashCount, 1);
    });
  });
}
