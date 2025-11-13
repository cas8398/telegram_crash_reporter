import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:telegram_crash_reporter/telegram_crash_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with your credentials
  TelegramCrashReporter.initialize(
    botToken: 'YOUR_BOT_TOKEN', // Replace with actual token
    chatId: 12345689, // Replace with actual chat ID
    showDebugPrint: true,
  );

  // Catch Flutter UI framework errors
  FlutterError.onError = (details) {
    TelegramCrashReporter.reportCrash(
      error: details.exception,
      stackTrace: details.stack ?? StackTrace.current,
      context: 'Flutter UI Error: ${details.library}',
      fatal: true,
      extraData: {
        'library': details.library,
        'stackFiltered': details.stackFilter,
      },
    );
  };

  // Catch unhandled Dart runtime errors
  PlatformDispatcher.instance.onError = (error, stack) {
    TelegramCrashReporter.reportCrash(
      error: error,
      stackTrace: stack,
      context: 'Dart Runtime Error',
      fatal: true,
    );
    return true; // Keep app running
  };

  // Optional: Catch errors in the widget tree
  ErrorWidget.builder = (errorDetails) {
    TelegramCrashReporter.reportCrash(
      error: errorDetails.exception,
      stackTrace: errorDetails.stack!,
      context: 'Error Widget',
      fatal: false,
    );
    return ErrorWidget(errorDetails.exception);
  };

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Crash Reporter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  @override
  _DemoPageState createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Demo')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                try {
                  throw Exception('Test exception from demo app');
                } catch (e, stack) {
                  TelegramCrashReporter.reportCrash(
                    error: e,
                    stackTrace: stack,
                    context: 'Demo Button',
                  );
                }
              },
              child: Text('Test Crash'),
            ),
          ],
        ),
      ),
    );
  }
}
