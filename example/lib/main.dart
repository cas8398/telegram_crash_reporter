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
