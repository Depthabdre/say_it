import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class GeminiProvider implements AiService {
  final http.Client _httpClient;

  GeminiProvider({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    final proxyUrl = dotenv.env['PROXY_BASE_URL'];
    if (proxyUrl == null || proxyUrl.isEmpty) {
      throw UnknownException(message: 'PROXY_BASE_URL not found in .env');
    }

    try {
      final prompt = AiPromptHelper.buildPrompt(request);
      final List<Map<String, dynamic>> parts = [
        {'text': prompt}
      ];

      // Convert audio inline bytes if they are present in the voice instructions
      if (request.audioBytes != null && request.audioMimeType != null) {
        parts.add({
          'inlineData': {
            'mimeType': request.audioMimeType!,
            'data': base64Encode(request.audioBytes!),
          }
        });
      }

      final response = await _httpClient.post(
        Uri.parse(proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Provider': 'gemini',
        },
        body: jsonEncode({
          'contents': [
            {'parts': parts}
          ],
          'generationConfig': {
            'temperature': 1.0,
            'responseMimeType': 'application/json',
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 429) {
        throw RateLimitException(
          providerName: 'Gemini', 
          message: 'Gemini rate limits exceeded.',
        );
      }

      if (response.statusCode != 200) {
        throw AiEngineException(
          message: 'Gemini request failed through proxy: status ${response.statusCode}',
        );
      }

      final Map<String, dynamic> responseJson = jsonDecode(response.body);
      final String rawText = responseJson['candidates'][0]['content']['parts'][0]['text'] ?? '';

      return AiPromptHelper.parseAndCleanJson(rawText);
    } catch (e) {
      if (e is RateLimitException) rethrow;
      throw AiEngineException(message: 'GeminiProvider failed: $e');
    }
  }
}