import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class OpenRouterProvider implements AiService {
  final http.Client _httpClient;

  OpenRouterProvider({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    final proxyUrl = dotenv.env['PROXY_BASE_URL'];
    if (proxyUrl == null || proxyUrl.isEmpty) {
      throw UnknownException(message: 'PROXY_BASE_URL not found in .env');
    }

    try {
      final prompt = AiPromptHelper.buildPrompt(request);

      final response = await _httpClient.post(
        Uri.parse(proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Provider': 'openrouter',
        },
        body: jsonEncode({
          'model': 'openrouter/free',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.85,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 429) {
        throw RateLimitException(
          providerName: 'OpenRouter', 
          message: 'OpenRouter free usage limits exceeded.',
        );
      }

      if (response.statusCode != 200) {
        throw AiEngineException(
          message: 'OpenRouter failed through proxy: status ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final String rawOutput = responseJson['choices'][0]['message']['content'] ?? '';

      return AiPromptHelper.parseAndCleanJson(rawOutput);
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw AiEngineException(message: 'OpenRouterProvider failed: $e');
    }
  }
}