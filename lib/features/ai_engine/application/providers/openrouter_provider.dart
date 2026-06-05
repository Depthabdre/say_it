import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class OpenRouterProvider implements AiService {
  final http.Client _httpClient;
  static const String _modelName = 'openrouter/free'; // Routes dynamically to active free tier models

  OpenRouterProvider({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw UnknownException(message: 'OPENROUTER_API_KEY not found in .env file.');
    }

    try {
      final prompt = AiPromptHelper.buildPrompt(request);
      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/say_it', // Identifies app for OpenRouter usage
          'X-OpenRouter-Title': 'TapReply App',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.85,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 429) {
        throw RateLimitException(
          providerName: 'OpenRouter',
          message: 'OpenRouter free routing limits exceeded.',
        );
      }

      if (response.statusCode != 200) {
        throw AiEngineException(
          message: 'OpenRouter returned invalid status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final String rawOutput = responseJson['choices'][0]['message']['content'] ?? '';

      return AiPromptHelper.parseAndCleanJson(rawOutput);
    } on SocketException catch (_) {
      throw AiEngineException(message: 'Failed to connect to OpenRouter server.');
    } on http.ClientException catch (e) {
      throw AiEngineException(message: 'OpenRouter request failed: $e');
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw AiEngineException(message: 'OpenRouterProvider failed: $e');
    }
  }
}