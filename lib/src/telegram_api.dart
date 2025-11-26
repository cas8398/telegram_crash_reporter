import 'dart:convert';
import 'dart:io';

class TelegramApi {
  final String _botToken;
  final int _chatId;
  final HttpClient _httpClient;
  final Function(String) _debugPrint;

  TelegramApi({
    required String botToken,
    required int chatId,
    required Function(String) debugPrint,
  })  : _botToken = botToken,
        _chatId = chatId,
        _debugPrint = debugPrint,
        _httpClient = HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 10);
  }

  Future<void> sendMessage(String message) async {
    HttpClientRequest? request;
    try {
      final url = 'https://api.telegram.org/bot$_botToken/sendMessage';

      _debugPrint('URL: $url');
      _debugPrint('Chat ID: $_chatId');
      _debugPrint('Message length: ${message.length}');

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

      _debugPrint('Response status: ${response.statusCode}');
      _debugPrint('Response body: $responseBody');

      if (response.statusCode != 200) {
        String errorMsg;
        try {
          final responseData = jsonDecode(responseBody);
          errorMsg = responseData['description'] ?? 'Unknown error';
        } catch (e) {
          errorMsg = responseBody;
        }

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

      _debugPrint('✅ Telegram message sent successfully!');
    } catch (e) {
      _debugPrint('❌ Error: $e');
      rethrow;
    } finally {
      request?.abort();
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
