# telegram_crash_reporter

A lightweight Flutter plugin that sends **crash reports, errors, and custom logs** directly to your **Telegram chat or channel** via a bot. Perfect for real-time debugging and monitoring without relying on third-party crash analytics.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Pub Version](https://img.shields.io/pub/v/telegram_crash_reporter?color=blue&style=for-the-badge)
![License](https://img.shields.io/github/license/cas8398/telegram_crash_reporter?style=for-the-badge)

---

## 🚀 Features

- **Instant crash reporting** to Telegram
- Send **custom logs** and **error messages**
- Works with `runZonedGuarded` for uncaught exceptions
- Supports **async error handling**
- **Lightweight** — minimal dependencies
- No external analytics SDKs — full control & privacy

---

## 🧩 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  telegram_crash_reporter: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## ⚙️ Setup

### 1. Create a Telegram Bot

- Open Telegram and search for [@BotFather](https://t.me/BotFather)
- Send `/newbot` and follow the instructions
- Copy the **Bot Token** (e.g., `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`)

### 2. Get Your Chat ID

The easiest way is to use [@InstantChatIDBot](https://t.me/InstantChatIDBot):

- Open Telegram and start a chat with [@InstantChatIDBot](https://t.me/InstantChatIDBot)
- It will instantly show your **Chat ID**
- Copy that ID and use it in your initialization code

---

**Alternative (manual method):**

**For personal chat:**

- Message your bot, then visit:  
  `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
- Look for `"chat":{"id":...}` → copy the number

**For channels:**

- Add your bot as an admin
- Use `@channelusername` or the **negative ID** from the API response (e.g., `-1001234567890`)

### 3. Initialize in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:telegram_crash_reporter/telegram_crash_reporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize early
  await TelegramCrashReporter.initialize(
    botToken: 'YOUR_BOT_TOKEN',
    chatId: 123456, // YOUR_CHAT_ID
  );

}
```

---

## 🧠 Usage Examples

### Report a Caught Exception

```dart
try {
  throw Exception("Something went wrong!");
} catch (e, s) {
  TelegramCrashReporter.report(e, s);
}
```

### Send a Custom Log Message

```dart
TelegramCrashReporter.sendMessage("User logged in successfully!");
```

### Advanced: Custom Formatting

```dart
TelegramCrashReporter.report(
  error,
  stackTrace,
  extraInfo: {
    'user_id': '12345',
    'screen': 'HomePage',
    'version': '1.2.0',
  },
);
```

---

## 📝 API

| Method                                   | Description                           |
| ---------------------------------------- | ------------------------------------- |
| `initialize({botToken, chatId})`         | Must call before reporting            |
| `report(error, stackTrace, {extraInfo})` | Send error with stack trace           |
| `sendMessage(text)`                      | Send plain text message               |
| `setUserIdentifier(id)`                  | Optionally tag reports with a user ID |

---

## 🛠 Configuration (Optional)

```dart
await TelegramCrashReporter.initialize(
  botToken: '123...',
  chatId: '-1001234567890', // Channel example
  enableLogging: true,      // Print to console (debug only)
);
```

---

## 🔒 Privacy & Security

- No data leaves your app except what **you** send
- Bot token is stored securely in memory
- No analytics, tracking, or third-party servers
