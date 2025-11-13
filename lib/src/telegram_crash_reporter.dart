import 'dart:convert' as json;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelegramCrashReporter {
  static String _botToken = '';
  static int _chatId = 0;
  static bool _isInitialized = false;
  static final List<Map<String, dynamic>> _pendingCrashes = [];
  static bool _isEnabled = true;
  static bool _sendToTelegramByDefault = true;
  static bool _showDebugPrint = true;
  static const String _crashStorageKey = 'telegram_crash_reports';
  static const int _maxStoredCrashes = 50;
  static final HttpClient _httpClient = HttpClient();

  static void initialize({
    required String botToken,
    required int chatId,
    bool enable = true,
    bool sendToTelegramByDefault = true,
    bool showDebugPrint = true,
  }) {
    _botToken = botToken;
    _chatId = chatId;
    _isInitialized = true;
    _isEnabled = enable;
    _sendToTelegramByDefault = sendToTelegramByDefault;
    _showDebugPrint = showDebugPrint; // Set debug print preference

    // Configure HTTP client
    _httpClient.connectionTimeout = const Duration(seconds: 10);

    // Send any pending crashes that occurred before initialization
    _sendPendingCrashes();
  }

  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  // method to set global Telegram sending preference
  static void setSendToTelegramByDefault(bool sendByDefault) {
    _sendToTelegramByDefault = sendByDefault;
  }

  // method to control debug printing
  static void setShowDebugPrint(bool showDebug) {
    _showDebugPrint = showDebug;
  }

  // Helper method for conditional debug printing
  static void _debugPrint(String message) {
    if (_showDebugPrint) {
      debugPrint(message);
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
    await _saveCrashLocally(error, stackTrace, context, extraData);

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

    // Use provided parameter or fall back to global default
    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Event not sent to Telegram (sendToTelegram: false)');
      return;
    }

    try {
      final fullMessage = _buildEventMessage(message, context, extraData);
      await _sendTelegramMessage(fullMessage);
    } catch (e) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Failed to send event to Telegram: $e');
    }
  }

  static Future<void> sendAppStartup({
    bool? sendToTelegram,
  }) async {
    if (!_isEnabled || !_isInitialized) return;

    // Use provided parameter or fall back to global default
    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint(
          '[TelegramCrashReporter] ==> App startup notification not sent to Telegram (sendToTelegram: false)');
      return;
    }

    try {
      final message = _buildStartupMessage();
      await _sendTelegramMessage(message);
    } catch (e) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Failed to send startup notification: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalCrashLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crashesJson = prefs.getString(_crashStorageKey);

      if (crashesJson != null && crashesJson.isNotEmpty) {
        final List<dynamic> crashesList = json.jsonDecode(crashesJson);
        return crashesList.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      _debugPrint('[TelegramCrashReporter] ==> Error reading crash logs: $e');
      return [];
    }
  }

  static Future<String> getLocalCrashLogsAsString() async {
    try {
      final crashes = await getLocalCrashLogs();
      if (crashes.isEmpty) return 'No crash logs found';

      final buffer = StringBuffer();
      for (final crash in crashes) {
        buffer.writeln('=== CRASH ===');
        buffer.writeln('Time: ${crash['timestamp']}');
        buffer.writeln('Context: ${crash['context']}');
        buffer.writeln('Error: ${crash['error']}');
        buffer.writeln('Platform: ${crash['platform']}');
        buffer.writeln('Debug: ${crash['debug_mode']}');

        if (crash['extra_data'] != null) {
          buffer.writeln('Extra Data: ${crash['extra_data']}');
        }
        buffer.writeln('---');
      }

      return buffer.toString();
    } catch (e) {
      return 'Error formatting crash logs: $e';
    }
  }

  static Future<void> clearLocalCrashLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashStorageKey);
    } catch (e) {
      _debugPrint('[TelegramCrashReporter] ==> Error clearing crash logs: $e');
    }
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
      final message = _buildCrashMessage(
        error,
        stackTrace,
        context,
        fatal,
        extraData,
      );
      await _sendTelegramMessage(message);
    } catch (e) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Failed to send crash to Telegram: $e');
    }
  }

  static String _buildStartupMessage() {
    return '''
<b>🚀 App Started</b>

<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
<b>Debug</b>: ${kDebugMode ? 'YES' : 'NO'}
''';
  }

  static String _buildCrashMessage(
    dynamic error,
    StackTrace stackTrace,
    String? context,
    bool fatal,
    Map<String, dynamic>? extraData,
  ) {
    final truncatedStack = stackTrace.toString().length > 1500
        ? '${stackTrace.toString().substring(0, 1500)}...'
        : stackTrace.toString();

    // Escape HTML characters
    final escapedError = _escapeHtml(error.toString());
    final escapedStack = _escapeHtml(truncatedStack);

    var message = '''
<b>${fatal ? '🚨 FATAL CRASH' : '⚠️ ERROR'}</b>

<b>Context</b>: ${_escapeHtml(context ?? 'Unknown')}
<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
<b>Debug</b>: ${kDebugMode ? 'YES' : 'NO'}

<b>Error</b>:
<code>$escapedError</code>

<b>Stack</b>:
<pre>$escapedStack</pre>
''';

    if (extraData != null && extraData.isNotEmpty) {
      message += '\n<b>Extra Data</b>:\n';
      extraData.forEach((key, value) {
        final escapedValue = _escapeHtml(value.toString());
        message += '• $key: <code>$escapedValue</code>\n';
      });
    }

    return message;
  }

  static String _buildEventMessage(
    String message,
    String? context,
    Map<String, dynamic>? extraData,
  ) {
    var eventMessage = '''
<b>📊 Event: ${_escapeHtml(message)}</b>

<b>Context</b>: ${_escapeHtml(context ?? 'General')}
<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem}
''';

    if (extraData != null && extraData.isNotEmpty) {
      eventMessage += '\n<b>Data</b>:\n';
      extraData.forEach((key, value) {
        final escapedValue = _escapeHtml(value.toString());
        eventMessage += '• $key: <code>$escapedValue</code>\n';
      });
    }

    return eventMessage;
  }

  // HTML escaping utility
  static String _escapeHtml(String text) {
    // First escape HTML special characters
    var escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    // Remove or replace any other problematic characters
    // This regex removes control characters except newlines and tabs
    escaped =
        escaped.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    return escaped;
  }

  static Future<void> _sendTelegramMessage(String message) async {
    HttpClientRequest? request;
    try {
      final url = 'https://api.telegram.org/bot$_botToken/sendMessage';

      // Debug the URL and credentials (be careful with token in production)
      _debugPrint('[TelegramCrashReporter] ==> URL: $url');
      _debugPrint('[TelegramCrashReporter] ==> Chat ID: $_chatId');
      _debugPrint(
          '[TelegramCrashReporter] ==> Message length: ${message.length}');

      request = await _httpClient.postUrl(Uri.parse(url));

      final payload = {
        'chat_id': _chatId,
        'text': message,
        'parse_mode': 'HTML',
      };

      final jsonString = jsonEncode(payload);

      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.write(jsonString);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      _debugPrint(
          '[TelegramCrashReporter] ==> Response status: ${response.statusCode}');
      _debugPrint('[TelegramCrashReporter] ==> Response body: $responseBody');

      if (response.statusCode != 200) {
        // More detailed error information
        String errorMsg;
        try {
          final responseData = jsonDecode(responseBody);
          errorMsg = responseData['description'] ?? 'Unknown error';
        } catch (e) {
          errorMsg = responseBody;
        }

        // Specific error handling
        if (response.statusCode == 404) {
          errorMsg =
              '404 Not Found - Check: 1) Bot token, 2) Chat ID, 3) Bot added to chat';
        } else if (response.statusCode == 400) {
          errorMsg = '400 Bad Request - Check chat ID format';
        } else if (response.statusCode == 401) {
          errorMsg = '401 Unauthorized - Invalid bot token';
        }

        throw Exception('Telegram API ${response.statusCode}: $errorMsg');
      }

      _debugPrint(
          '[TelegramCrashReporter] ==> ✅ Telegram message sent successfully!');
    } catch (e) {
      _debugPrint('[TelegramCrashReporter] ==> ❌ Error: $e');
      rethrow;
    } finally {
      request?.abort();
    }
  }

  static Future<void> _saveCrashLocally(
    dynamic error,
    StackTrace stackTrace,
    String? context,
    Map<String, dynamic>? extraData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final crashData = {
        'timestamp': DateTime.now().toIso8601String(),
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
        'context': context,
        'extra_data': extraData,
        'platform':
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'debug_mode': kDebugMode,
      };

      // Get existing crashes
      List<Map<String, dynamic>> crashes = [];
      final crashesJson = prefs.getString(_crashStorageKey);

      if (crashesJson != null && crashesJson.isNotEmpty) {
        try {
          final List<dynamic> existingCrashes = json.jsonDecode(crashesJson);
          crashes = existingCrashes.cast<Map<String, dynamic>>();
        } catch (e) {
          // If corrupted, start fresh
          crashes = [];
        }
      }

      // Add new crash
      crashes.add(crashData);

      // Keep only last N crashes
      if (crashes.length > _maxStoredCrashes) {
        crashes = crashes.sublist(crashes.length - _maxStoredCrashes);
      }

      // Save back to SharedPreferences
      await prefs.setString(_crashStorageKey, json.jsonEncode(crashes));
    } catch (e) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Failed to save crash locally: $e');
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

    _debugPrint(
        '[TelegramCrashReporter] ==> Sending ${_pendingCrashes.length} pending crashes...');

    for (final crash in _pendingCrashes) {
      await _sendToTelegram(
        crash['error'],
        crash['stackTrace'],
        crash['context'],
        crash['fatal'],
        crash['extraData'],
      );
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _pendingCrashes.clear();
  }

  // Test method
  static Future<void> testConnection({bool? sendToTelegram}) async {
    if (!_isInitialized) {
      _debugPrint('[TelegramCrashReporter] ==> ❌ Not initialized');
      return;
    }

    // Use provided parameter or fall back to global default
    final shouldSend = sendToTelegram ?? _sendToTelegramByDefault;

    if (!shouldSend) {
      _debugPrint(
          '[TelegramCrashReporter] ==> Test connection skipped (sendToTelegram: false)');
      return;
    }

    _debugPrint('=== TESTING TELEGRAM CONNECTION ===');

    try {
      // Test HTML message
      await _sendTelegramMessage(
        '<b>Test connection</b> - HTML formatting works!',
      );
      _debugPrint('[TelegramCrashReporter] ==> ✅ Test passed!');
    } catch (e) {
      _debugPrint('[TelegramCrashReporter] ==> ❌ Test failed: $e');
    }
  }

  // Clean up resources
  static void dispose() {
    _httpClient.close();
  }
}
