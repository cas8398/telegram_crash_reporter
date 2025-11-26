import 'dart:io';
import 'package:flutter/foundation.dart';

class MessageBuilder {
  static String buildStartupMessage() {
    return '''
<b>🚀 App Started</b>

<b>Time</b>: ${DateTime.now()}
<b>Platform</b>: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
<b>Debug</b>: ${kDebugMode ? 'YES' : 'NO'}
''';
  }

  static String buildCrashMessage({
    required dynamic error,
    required StackTrace stackTrace,
    String? context,
    bool fatal = false,
    Map<String, dynamic>? extraData,
  }) {
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

  static String buildEventMessage({
    required String message,
    String? context,
    Map<String, dynamic>? extraData,
  }) {
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
    var escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    escaped =
        escaped.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    return escaped;
  }
}
