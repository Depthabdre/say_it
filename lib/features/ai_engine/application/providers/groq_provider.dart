import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class GroqProvider implements AiService {
  final http.Client _httpClient;
  static const String _modelName = 'llama-3.3-70b-versatile';

  GroqProvider({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw UnknownException(message: 'GROQ_API_KEY not found in .env file.');
    }

    try {
      final prompt = AiPromptHelper.buildPrompt(request);
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.85,
          'response_format': {'type': 'json_object'} // Enforces JSON constraints at API level
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        throw RateLimitException(
          providerName: 'Groq',
          message: 'Groq free tier usage limits exceeded.',
        );
      }

      if (response.statusCode != 200) {
        throw AiEngineException(
          message: 'Groq returned invalid status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final String rawOutput = responseJson['choices'][0]['message']['content'] ?? '';

      return AiPromptHelper.parseAndCleanJson(rawOutput);
    } on SocketException catch (_) {
      throw AiEngineException(message: 'Failed to connect to Groq server. Check internet connection.');
    } on http.ClientException catch (e) {
      throw AiEngineException(message: 'Groq HTTP client request failed: $e');
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw AiEngineException(message: 'GroqProvider failed: $e');
    }
  }
}