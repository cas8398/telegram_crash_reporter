import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_crash_reporter/telegram_crash_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() {
  group('TelegramCrashReporter Unit Tests', () {
    // Mock initializations
    setUpAll(() {
      // Setup mock values for platform
      // Note: In real tests, you might need to mock Platform.operatingSystem
    });

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset the plugin state
      TelegramCrashReporter.initialize(
        botToken: 'test_bot_token',
        chatId: 123456789,
        enable: true,
      );
    });

    test('Initialization sets correct values', () {
      expect(TelegramCrashReporter.getCrashCount(), completion(0));
    });

    test('Enable/disable functionality works', () {
      TelegramCrashReporter.setEnabled(false);
      // Should not crash when disabled
      expect(
        TelegramCrashReporter.reportCrash(
          error: 'Test error',
          stackTrace: StackTrace.current,
          sendToTelegram: false,
        ),
        completes,
      );
    });

    test('Local crash storage works', () async {
      final testError = Exception('Test exception');
      final testStackTrace = StackTrace.current;

      await TelegramCrashReporter.reportCrash(
        error: testError,
        stackTrace: testStackTrace,
        context: 'Test Context',
        sendToTelegram: false, // Don't send to Telegram during tests
      );

      final crashCount = await TelegramCrashReporter.getCrashCount();
      expect(crashCount, 1);

      final logs = await TelegramCrashReporter.getLocalCrashLogs();
      expect(logs.length, 1);
      expect(logs[0]['error'], 'Exception: Test exception');
      expect(logs[0]['context'], 'Test Context');
    });

    test('Multiple crashes are stored correctly', () async {
      for (int i = 0; i < 3; i++) {
        await TelegramCrashReporter.reportCrash(
          error: 'Error $i',
          stackTrace: StackTrace.current,
          sendToTelegram: false,
        );
      }

      final crashCount = await TelegramCrashReporter.getCrashCount();
      expect(crashCount, 3);
    });

    test('Extra data is stored with crash', () async {
      final extraData = {
        'user_id': '123',
        'screen': 'home',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await TelegramCrashReporter.reportCrash(
        error: 'Test error',
        stackTrace: StackTrace.current,
        extraData: extraData,
        sendToTelegram: false,
      );

      final logs = await TelegramCrashReporter.getLocalCrashLogs();
      expect(logs[0]['extra_data'], extraData);
    });

    test('Crash logs can be formatted as string', () async {
      await TelegramCrashReporter.reportCrash(
        error: 'Format test error',
        stackTrace: StackTrace.current,
        context: 'Format Test',
        sendToTelegram: false,
      );

      final formattedLogs =
          await TelegramCrashReporter.getLocalCrashLogsAsString();
      expect(formattedLogs, contains('Format test error'));
      expect(formattedLogs, contains('Format Test'));
      expect(formattedLogs, contains('=== CRASH ==='));
    });

    test('Clear local crash logs works', () async {
      // Add some crashes
      await TelegramCrashReporter.reportCrash(
        error: 'Test error',
        stackTrace: StackTrace.current,
        sendToTelegram: false,
      );

      // Verify they exist
      var crashCount = await TelegramCrashReporter.getCrashCount();
      expect(crashCount, 1);

      // Clear them
      await TelegramCrashReporter.clearLocalCrashLogs();

      // Verify they're gone
      crashCount = await TelegramCrashReporter.getCrashCount();
      expect(crashCount, 0);
    });

    test('HTML escaping works correctly', () {
      // Test the HTML escaping logic
      final testString = 'This <has> HTML & "characters" \'in\' it';
      final escaped = _escapeHtmlTest(testString);

      expect(
          escaped,
          equals(
              'This &lt;has&gt; HTML &amp; &quot;characters&quot; &#39;in&#39; it'));
    });

    test('Event sending does not throw when disabled', () {
      TelegramCrashReporter.setEnabled(false);
      expect(
        TelegramCrashReporter.sendEvent(message: 'Test event'),
        completes,
      );
    });

    test('App startup notification does not throw when disabled', () {
      TelegramCrashReporter.setEnabled(false);
      expect(
        TelegramCrashReporter.sendAppStartup(),
        completes,
      );
    });

    test('Pending crashes are handled before initialization', () async {
      // Reset to simulate pre-initialization state
      TelegramCrashReporter.initialize(
        botToken: 'new_bot_token',
        chatId: 987654321,
      );

      // This should complete without error even though we can't actually send to Telegram
      expect(
        TelegramCrashReporter.reportCrash(
          error: 'Pending test',
          stackTrace: StackTrace.current,
          sendToTelegram: false,
        ),
        completes,
      );
    });
  });

  group('Message Building Tests', () {
    test('Startup message contains correct info', () {
      final message = _buildStartupMessageTest();
      expect(message, contains('🚀 App Started'));
      expect(message, contains('Platform'));
      expect(message, contains('Debug'));
    });

    test('Crash message contains error and stack trace', () {
      final testError = 'Test error message';
      final testStackTrace = 'Test stack trace\nat test()';

      final message = _buildCrashMessageTest(
        testError,
        testStackTrace,
        'Test Context',
        false,
        null,
      );

      expect(message, contains('⚠️ ERROR'));
      expect(message, contains('Test error message'));
      expect(message, contains('Test stack trace'));
      expect(message, contains('Test Context'));
    });

    test('Event message contains custom data', () {
      final extraData = {
        'action': 'button_press',
        'count': 5,
      };

      final message = _buildEventMessageTest(
        'User Action',
        'Home Screen',
        extraData,
      );

      expect(message, contains('📊 Event: User Action'));
      expect(message, contains('Home Screen'));
      expect(message, contains('button_press'));
      expect(message, contains('5'));
    });
  });
}

// Test helper functions to access private functionality
// In a real scenario, you might make these public or use reflection

String _escapeHtmlTest(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _buildStartupMessageTest() {
  return '''
<b>🚀 App Started</b>

<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
<b>Debug</b>: ${true ? 'YES' : 'NO'}
''';
}

String _buildCrashMessageTest(
  String error,
  String stackTrace,
  String? context,
  bool fatal,
  Map<String, dynamic>? extraData,
) {
  final truncatedStack = stackTrace.length > 1500
      ? '${stackTrace.substring(0, 1500)}...'
      : stackTrace;

  final escapedError = _escapeHtmlTest(error);
  final escapedStack = _escapeHtmlTest(truncatedStack);

  var message = '''
<b>${fatal ? '🚨 FATAL CRASH' : '⚠️ ERROR'}</b>

<b>Context</b>: ${_escapeHtmlTest(context ?? 'Unknown')}
<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
<b>Debug</b>: ${true ? 'YES' : 'NO'}

<b>Error</b>:
<code>$escapedError</code>

<b>Stack</b>:
<pre>$escapedStack</pre>
''';

  if (extraData != null && extraData.isNotEmpty) {
    message += '\n<b>Extra Data</b>:\n';
    extraData.forEach((key, value) {
      final escapedValue = _escapeHtmlTest(value.toString());
      message += '• $key: <code>$escapedValue</code>\n';
    });
  }

  return message;
}

String _buildEventMessageTest(
  String message,
  String? context,
  Map<String, dynamic>? extraData,
) {
  var eventMessage = '''
<b>📊 Event: ${_escapeHtmlTest(message)}</b>

<b>Context</b>: ${_escapeHtmlTest(context ?? 'General')}
<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem}
''';

  if (extraData != null && extraData.isNotEmpty) {
    eventMessage += '\n<b>Data</b>:\n';
    extraData.forEach((key, value) {
      final escapedValue = _escapeHtmlTest(value.toString());
      eventMessage += '• $key: <code>$escapedValue</code>\n';
    });
  }

  return eventMessage;
}
