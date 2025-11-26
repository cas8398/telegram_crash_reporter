import 'dart:io';
import 'package:flutter/foundation.dart';
import 'crash_storage.dart';
import 'telegram_api.dart';
import 'message_builder.dart';
import 'models/crash_data.dart';

class TelegramCrashReporter {
  static bool _isInitialized = false;
  static final List<Map<String, dynamic>> _pendingCrashes = [];
  static bool _isEnabled = true;
  static bool _sendToTelegramByDefault = true;
  static bool _showDebugPrint = true;

  static late TelegramApi _telegramApi;
  static late CrashStorage _crashStorage;

  static void initialize({
    required String botToken,
    required int chatId,
    bool enable = true,
    bool sendToTelegramByDefault = true,
    bool showDebugPrint = true,
  }) {
    _isInitialized = true;
    _isEnabled = enable;
    _sendToTelegramByDefault = sendToTelegramByDefault;
    _showDebugPrint = showDebugPrint;

    _telegramApi = TelegramApi(
      botToken: botToken,
      chatId: chatId,
      debugPrint: _debugPrint,
    );

    _crashStorage = CrashStorage(debugPrint: _debugPrint);

    _sendPendingCrashes();
  }

  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  static void setSendToTelegramByDefault(bool sendByDefault) {
    _sendToTelegramByDefault = sendByDefault;
  }

  static void setShowDebugPrint(bool showDebug) {
    _showDebugPrint = showDebug;
  }

  static void _debugPrint(String message) {
    if (_showDebugPrint) {
      debugPrint('[TelegramCrashReporter] ==> $message');
    }
  }

  static Future<void> reportCrash({
    required dynamic error,
    required StackTrace stackTrace,
    String? context,
    bool fatal = false,
    Map<String, dynamic>? extraData,
    bool sendToTelegram = true,
  }) async {
    if (!_isEnabled) return;

    // Always debugPrint to console for local debugging
    _debugPrintToConsole(error, stackTrace, context, fatal);

    // Save to local storage immediately
    final crashData = CrashData(
      error: error.toString(),
      stackTrace: stackTrace.toString(),
      context: context,
      extraData: extraData,
      platform:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      debugMode: kDebugMode,
    );

    await _crashStorage.saveCrashLocally(crashData);

    // If not initialized, queue the crash for later
    if (!_isInitialized) {
      _pendingCrashes.add({
        'error': error,
        'stackTrace': stackTrace,
        'context': context,
        'fatal': fatal,
        'extraData': extraData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    // Send to Telegram if requested
    if (sendToTelegram) {
      await _sendToTelegram(error, stackTrace, context, fatal, extraData);
    }
  }

  static Future<void> sendEvent({
    required String message,
    String? context,
    Map<String, dynamic>? extraData,
    bool? sendToTelegram,
  }) async {
    if (!_isEnabled || !_isInitialized) return;

    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint('Event not sent to Telegram (sendToTelegram: false)');
      return;
    }

    try {
      final fullMessage = MessageBuilder.buildEventMessage(
        message: message,
        context: context,
        extraData: extraData,
      );
      await _telegramApi.sendMessage(fullMessage);
    } catch (e) {
      _debugPrint('Failed to send event to Telegram: $e');
    }
  }

  static Future<void> sendAppStartup({
    bool? sendToTelegram,
  }) async {
    if (!_isEnabled || !_isInitialized) return;

    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint(
          'App startup notification not sent to Telegram (sendToTelegram: false)');
      return;
    }

    try {
      final message = MessageBuilder.buildStartupMessage();
      await _telegramApi.sendMessage(message);
    } catch (e) {
      _debugPrint('Failed to send startup notification: $e');
    }
  }

  static Future<List<CrashData>> getLocalCrashLogs() async {
    return await _crashStorage.getLocalCrashLogs();
  }

  static Future<String> getLocalCrashLogsAsString() async {
    try {
      final crashes = await getLocalCrashLogs();
      if (crashes.isEmpty) return 'No crash logs found';

      final buffer = StringBuffer();
      for (final crash in crashes) {
        buffer.writeln('=== CRASH ===');
        buffer.writeln('Time: ${crash.timestamp}');
        buffer.writeln('Context: ${crash.context}');
        buffer.writeln('Error: ${crash.error}');
        buffer.writeln('Platform: ${crash.platform}');
        buffer.writeln('Debug: ${crash.debugMode}');

        if (crash.extraData != null) {
          buffer.writeln('Extra Data: ${crash.extraData}');
        }
        buffer.writeln('---');
      }

      return buffer.toString();
    } catch (e) {
      return 'Error formatting crash logs: $e';
    }
  }

  static Future<void> clearLocalCrashLogs() async {
    await _crashStorage.clearLocalCrashLogs();
  }

  static Future<int> getCrashCount() async {
    final crashes = await getLocalCrashLogs();
    return crashes.length;
  }

  // PRIVATE METHODS

  static Future<void> _sendToTelegram(
    dynamic error,
    StackTrace stackTrace,
    String? context,
    bool fatal,
    Map<String, dynamic>? extraData,
  ) async {
    try {
      final message = MessageBuilder.buildCrashMessage(
        error: error,
        stackTrace: stackTrace,
        context: context,
        fatal: fatal,
        extraData: extraData,
      );
      await _telegramApi.sendMessage(message);
    } catch (e) {
      _debugPrint('Failed to send crash to Telegram: $e');
    }
  }

  static void _debugPrintToConsole(
    dynamic error,
    StackTrace stackTrace,
    String? context,
    bool fatal,
  ) {
    if (_showDebugPrint) {
      debugPrint('''
=== CRASH REPORT ===
Context: $context
Fatal: $fatal
Error: $error
Stack: $stackTrace
====================
''');
    }
  }

  static Future<void> _sendPendingCrashes() async {
    if (_pendingCrashes.isEmpty) return;

    _debugPrint('Sending ${_pendingCrashes.length} pending crashes...');

    for (final crash in _pendingCrashes) {
      await _sendToTelegram(
        crash['error'],
        crash['stackTrace'],
        crash['context'],
        crash['fatal'],
        crash['extraData'],
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _pendingCrashes.clear();
  }

  // Test method
  static Future<void> testConnection({bool? sendToTelegram}) async {
    if (!_isInitialized) {
      _debugPrint('❌ Not initialized');
      return;
    }

    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint('Test connection skipped (sendToTelegram: false)');
      return;
    }

    _debugPrint('=== TESTING TELEGRAM CONNECTION ===');

    try {
      await _telegramApi
          .sendMessage('<b>Test connection</b> - HTML formatting works!');
      _debugPrint('✅ Test passed!');
    } catch (e) {
      _debugPrint('❌ Test failed: $e');
    }
  }

  // Clean up resources
  static void dispose() {
    _telegramApi.dispose();
  }
}
