import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class GroqProvider implements AiService {
  final http.Client _httpClient;

  GroqProvider({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

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
          'X-Provider': 'groq',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.85,
          'response_format': {'type': 'json_object'}
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        throw RateLimitException(
          providerName: 'Groq', 
          message: 'Groq usage limits exceeded.',
        );
      }

      if (response.statusCode != 200) {
        throw AiEngineException(
          message: 'Groq failed through proxy: status ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final String rawOutput = responseJson['choices'][0]['message']['content'] ?? '';

      return AiPromptHelper.parseAndCleanJson(rawOutput);
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw AiEngineException(message: 'GroqProvider failed: $e');
    }
  }
}