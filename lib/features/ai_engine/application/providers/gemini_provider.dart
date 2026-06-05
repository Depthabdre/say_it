import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide ServerException;
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import '../ai_service.dart';
import '../ai_prompt_helper.dart';

class GeminiProvider implements AiService {
  static const String _modelName = 'gemini-2.5-flash';
  late final GenerativeModel _model;

  GeminiProvider() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw UnknownException(message: 'GEMINI_API_KEY not found in .env file.');
    }
    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 1.0, // Recommends 1.0 for Gemini 3.5/2.5 flash models
        responseMimeType: 'application/json',
      ),
    );
  }

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    try {
      final prompt = AiPromptHelper.buildPrompt(request);
      final List<Part> parts = [TextPart(prompt)];

      // Append recorded voice audio if present
      if (request.audioBytes != null && request.audioMimeType != null) {
        parts.add(DataPart(request.audioMimeType!, request.audioBytes!));
      }

      final response = await _model.generateContent([Content.multi(parts)]);
      final rawText = response.text ?? '';

      return AiPromptHelper.parseAndCleanJson(rawText);
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains('429') || errorString.contains('RESOURCE_EXHAUSTED')) {
        throw RateLimitException(
          providerName: 'Gemini',
          message: 'Gemini rate limits exceeded or resource exhausted.',
        );
      }
      throw AiEngineException(message: 'GeminiProvider failed: $e');
    }
  }
}