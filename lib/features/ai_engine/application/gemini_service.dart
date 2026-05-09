import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';
  
  late final GenerativeModel _model;
  
  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file.');
    }
    
    // We use gemini-1.5-flash as it is extremely fast and optimized for free-tier text tasks.
    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      // We force the model to return a JSON array so we can easily parse the 3 options
      generationConfig: GenerationConfig(
        temperature: 0.7, // 0.7 gives good creativity without being completely random
        responseMimeType: 'application/json',
      ),
    );
  }

  /// Generates 3 reply options based on the screen context and chosen tone.
  /// Uses the Gemini API free tier.
  Future<List<String>> generateReplies(GenerationRequest request) async {
    try {
      final prompt = _buildPrompt(request);
      
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception("Gemini returned an empty response.");
      }

      // Parse the JSON array returned by Gemini
      final List<dynamic> jsonList = jsonDecode(responseText);
      return jsonList.map((e) => e.toString()).toList();

    } catch (e) {
      // It's important to handle 429 Too Many Requests gracefully on the free tier.
      if (e.toString().contains('429')) {
        throw Exception('Free tier rate limit reached. Please wait a moment and try again.');
      }
      throw Exception('Failed to generate replies: $e');
    }
  }

  String _buildPrompt(GenerationRequest request) {
    // The prompt is the most critical part of this application. 
    // It acts as the "Brain" telling Gemini exactly how to behave.
    final buffer = StringBuffer();
    
    buffer.writeln("You are TapReply, an invisible, highly intelligent AI communication assistant.");
    buffer.writeln("Your job is to read the messy context from a user's screen (often OCR text or View Node dumps) and generate the absolute perfect reply for the user to send.");
    buffer.writeln("Below is the context read from the user's screen. Figure out what the conversation is about, and what the user should reply to the latest message.\n");
    
    buffer.writeln("--- SCREEN CONTEXT START ---");
    buffer.writeln(request.screenContextText);
    buffer.writeln("--- SCREEN CONTEXT END ---\n");
    
    buffer.writeln("REQUIREMENTS:");
    buffer.writeln("1. Generate exactly 3 distinct, ready-to-send reply options.");
    buffer.writeln("2. The tone MUST be: ${request.tone.displayName}. Adhere strictly to this tone.");
    
    if (request.customInstructions != null && request.customInstructions!.trim().isNotEmpty) {
      buffer.writeln("3. CRITICAL INSTRUCTION from user: ${request.customInstructions}");
    }
    
    buffer.writeln("4. Keep the replies concise and natural. No robotic greetings. Do not wrap in quotes.");
    buffer.writeln("5. Return the result strictly as a JSON array of strings. Do not include markdown code blocks.");
    buffer.writeln("Example: [\"Reply 1\", \"Reply 2\", \"Reply 3\"]");

    return buffer.toString();
  }
}
