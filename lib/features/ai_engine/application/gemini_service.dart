import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide ServerException;
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw UnknownException(message: 'GEMINI_API_KEY not found in .env file.');
    }
    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.85,
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Generates 3 reply options based on screen context, user intent (text or audio), and tone.
  Future<List<String>> generateReplies(GenerationRequest request) async {
    try {
      final prompt = _buildPrompt(request);
      final List<Part> parts = [TextPart(prompt)];

      if (request.audioBytes != null && request.audioMimeType != null) {
        parts.add(DataPart(request.audioMimeType!, request.audioBytes!));
      }

      final response = await _model.generateContent([Content.multi(parts)]);
      final rawResponseText = response.text;

      if (rawResponseText == null || rawResponseText.isEmpty) {
        throw AiEngineException(message: 'Gemini returned an empty response.');
      }

      final cleanedJsonText = _cleanResponsePayload(rawResponseText);
      final List<dynamic> jsonList = jsonDecode(cleanedJsonText);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      if (e.toString().contains('429')) {
        throw ServerException(
          message: 'Free tier rate limit reached. Please wait a moment and try again.',
        );
      }
      throw AiEngineException(message: 'Failed to generate replies: $e');
    }
  }

  /// Strips any potential markdown code blocks to protect JSON parsing.
  String _cleanResponsePayload(String rawText) {
    String cleaned = rawText.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
      cleaned = cleaned.trim();
    }
    return cleaned;
  }

  String _buildPrompt(GenerationRequest request) {
    final buffer = StringBuffer();
    
    final targetLanguage = request.isAmharic ? "Amharic (written in natural Ge'ez script)" : "English";
    final screenContext = request.screenContextText ?? "None";
    final userIntent = request.customInstructions ?? "None";

    // Single-paragraph realistic human prompt as requested
    buffer.writeln(
      "Generate exactly 3 reply options in $targetLanguage based on the context: '$screenContext' and user intent: '$userIntent' under the tone '${request.tone.displayName}'. "
      "Be more human, act like how real life people respond to such things in human-sounding and human words without explaining, being preachy, or trying very hard on each tone. "
      "Return ONLY a raw JSON array of 3 strings (e.g. [\"reply 1\", \"reply 2\", \"reply 3\"]) with no markdown code blocks, intro, or explanation."
    );

    return buffer.toString();
  }
}