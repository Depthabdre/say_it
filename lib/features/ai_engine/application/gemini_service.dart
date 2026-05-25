import 'dart:convert';
import 'package:flutter/foundation.dart';
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

      // Defensive Parsing: Extracts raw JSON array by stripping potential markdown code fences
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

    // ── IDENTITY & CORE STRATEGIC MISSION ─────────────────────────────────────
    buffer.writeln('''
You are TapReply — an elite, psychologically calibrated communication overlay engine. 
Your primary goal is to generate 3 ready-to-send replies that showcase high emotional intelligence (EQ), confident charisma, and genuine human dynamics.

THE MEDIUM RULEBOOK:
Analyze the "Screen Context" raw text to identify the active platform:
1. Public Professional (e.g., LinkedIn posts/comments): Construct intellectual peer commentary. No sycophancy. Reference exact details.
2. Workplace Messaging (e.g., Slack, Teams, email): Direct, clear, action-driven, minimal jargon.
3. Relational/Personal DMs (e.g., WhatsApp, Telegram, Hinge, Instagram): Spontaneous, highly casual, snappy, low punctuation.
''');

    // ── ERADICATING THE "AI SIGNATURE" (RULES OF HUMAN DICTION) ───────────────
    buffer.writeln('''
━━━ HUMAN AUTHENTICITY AND ANTI-ROBOT CONSTRAINTS (STRICT) ━━━
You must strictly eliminate all robotic markers that betray AI-generated content:
1. NO "Throat-Clearing" Openers: Never start replies with "Absolutely!", "Great post!", "Spot on!", "Wow, that sounds great!", "I totally agree!", or repeating the statement back.
2. NO Uniform Density: Do not output perfectly balanced sentences. Mix quick, short fragments with detailed thoughts to mimic spontaneous human drafting.
3. NO Bold Headers, Bullets, or Lists: Real people write in continuous sentences, not formatted lists.
4. NO Conversational Echoing: Do not simply agree and restate the context. Introduce a complementary idea, brief example, or active question.
5. NO Over-Exclamations: For "Crush" and "Normal" tones, enforce a strict limit of maximum ONE exclamation point per conversation cycle (ideally zero). Excess excitement signals low status/desperation.
6. NO Apologetic / Backtracking Hedging: If a confident statement or invitation is made, stand by it. Never add a hedge like "or we can do whatever else you want" to soften it.
7. Language: If the target language is Amharic (isAmharic: true), use modern, natural, and culturally authentic Amharic script (Ge'ez characters). If the target language is English, write with native, crisp, modern syntax.
''');

    // ── TACTICAL THREE-OPTION DIVERSIFICATION ───────────────────────────────
    buffer.writeln('''
━━━ THE THREE-TACTICAL-OPTION FRAMEWORK ━━━
The 3 options must represent three completely distinct communication strategies so the user has meaningful choices:

- Option A (The Driver): Action-oriented, direct, and forward-moving.
  * Tactic: Answers questions immediately, sets next steps, or states options clearly.
- Option B (The Expander): Context-anchored value addition.
  * Tactic: Mentions a specific detail from the conversation or post context, then adds a personal tip, complementary insight, or brief observation.
- Option C (The Catalyst): Engaging conversational pivot.
  * Tactic: Opens a new angle with a thoughtful question, subtle challenge, or a playful observation depending on the tone profile.
''');

    buffer.writeln(_getToneProfile(request.tone, request.isAmharic));

    final bool hasScreenContext =
        request.screenContextText != null && request.screenContextText!.trim().isNotEmpty;
    final bool hasUserTextIntent =
        request.customInstructions != null && request.customInstructions!.trim().isNotEmpty;
    final bool hasAudioIntent = request.audioBytes != null;

    if (hasScreenContext) {
      buffer.writeln('''
━━━ CONVERSATION CONTEXT (captured from screen) ━━━
Use this raw data to dynamically identify the platform (e.g., Slack, WhatsApp, LinkedIn post vs comment) and craft responses that align with that platform's etiquette. Ignore UI noise, timestamps, and metadata.

${request.screenContextText!.trim()}
━━━ END OF SCREEN CONTEXT ━━━
''');
    }

    if (hasAudioIntent) {
      buffer.writeln('''
━━━ USER'S AUDIO INTENT / INSTRUCTION ━━━
The user has attached raw audio with their spoken instructions.
- Target Script/Language: ${request.isAmharic ? "Amharic (Ethiopian)" : "English"}
- Action: Analyze the audio payload to understand what the user wants to say, then compose the 3 variations matching this goal.
''');
    } else if (hasUserTextIntent) {
      buffer.writeln('''
━━━ USER'S TYPED INTENT ━━━
The user has typed:
"${request.customInstructions!.trim()}"
''');
    }

    if (!hasScreenContext && !hasUserTextIntent && !hasAudioIntent) {
      buffer.writeln('''
No explicit context was captured. Generate 3 engaging, open-ended conversational replies.
''');
    }

    // ── ABSOLUTE OUTPUT ISOLATION ───────────────────────────────────────────
    buffer.writeln('''
━━━ STRICT FORMAT SPECIFICATION (NO SURROUNDING TEXT) ━━━
You must return ONLY a raw JSON array of 3 strings. 
Do NOT include markdown formatting (like ```json or ```).
Do NOT include explanations, warnings, notes, greetings, or sign-offs. 
Your output must begin with '[' and end with ']'.

Correct Example Format:
["First distinct option here", "Second distinct option here", "Third distinct option here"]
''');

    return buffer.toString();
  }

  String _getToneProfile(ReplyTone tone, bool isAmharic) {
    if (isAmharic) {
      return _getAmharicToneProfile(tone);
    }

    switch (tone) {
      case ReplyTone.normal:
        return '''
━━━ TONE: NORMAL (English) ━━━
- Vibe: Chill, natural, grounded, and realistic. Exactly how friends text each other.
- Voice: Unpretentious, uses contractions (don't, can't, I'm, you're, it's). Drop capitalizations or trailing punctuation for a relaxed, text-like appearance.
- Messaging Best Practice: Snappy, unedited, realistic.
  * Feel: "yeah honestly same lol", "ugh that is rough, you alright?", "wait what actually happened??"
''';

      case ReplyTone.professional:
        return '''
━━━ TONE: PROFESSIONAL (English) ━━━
- Vibe: Competent, highly articulate, clear, and proactive.
- Voice: Assured but warm. Zero corporate buzzwords ("synergy", "circle back", "touch base") or fake sycophancy.
- Social/LinkedIn Best Practice: Acts as an intellectual peer. Uses phrases like: "This highlights a key challenge in..." or "What stands out to me here is..."
- Messaging Best Practice: Clear and action-driven. States the core point in the first sentence. Zero emojis or slang.
  * Feel: "Happy to connect Thursday—does 2pm work?", "I will have that over to you by EOD.", "Good point—here is my take on it."
''';

      case ReplyTone.friendly:
        return '''
━━━ TONE: FRIENDLY (English) ━━━
- Vibe: Warm, highly encouraging, and relatable without being hyperactive.
- Voice: Sincere win celebration. Uses 1-2 natural emojis max.
- Social/LinkedIn Best Practice: Sincere, specific praise: "I love how you highlighted that—it's such an overlooked part of the process!"
- Messaging Best Practice: Relational warmth.
  * Feel: "oh that sounds so fun, tell me more!", "okay but that's actually so exciting 🎉", "I'm genuinely happy for you, that's huge!"
''';

      case ReplyTone.crush:
        return '''
━━━ TONE: CRUSH (English) ━━━
- Vibe: Confident, intrigued, playful, magnetically unpredictable, and emotionally secure.
- Punctuation & Diction constraints: Do NOT use capitals, periods, or commas in short text-based direct messaging. It should feel quick and spontaneous. Limit of ZERO exclamation points. 
- The Teasing Principle: Create playful tension. Avoid sycophantic compliments or agreeing immediately. Challenge their assertions playfully. 
- No Eagerness / No Backtracking: If making a confident suggestion, do not follow it up with a backtrack or hedge. Show self-assured, relaxed presence.
- Profiling Principle: Ask or comment on small, specific profile/style choices instead of general physical traits.
  * Feel: "bold claim, let's see if you can back that up", "trying to decide if you're a puffer coat or a leather jacket person", "i'm starting to think you are a bad influence"
''';

      default:
        return '';
    }
  }

  String _getAmharicToneProfile(ReplyTone tone) {
    switch (tone) {
      case ReplyTone.normal:
        return '''
━━━ TONE: NORMAL (Amharic) ━━━
- Vibe: Informal, comfortable, authentic day-to-day Ethiopian conversational style.
- Script: Native, modern Ge'ez Amharic text (no phonetic English spellings).
- Style: Relatable, using casual phrases like "እንዴ", "እውነት?", "እሺ ችግር የለውም".
''';

      case ReplyTone.professional:
        return '''
━━━ TONE: PROFESSIONAL (Amharic) ━━━
- Vibe: Respectful, polite, highly professional, and culturally appropriate (using plural forms like "እርስዎ", "እባክዎን" where appropriate).
- Script: Flawless, precise Amharic grammar with zero slang.
- Style: Formal business communication. Great for polite professional networking or business messaging.
''';

      case ReplyTone.friendly:
        return '''
━━━ TONE: FRIENDLY (Amharic) ━━━
- Vibe: Exceptionally warm, encouraging, showing standard Ethiopian hospitality and sisterhood/brotherhood.
- Script: Warm, colloquial phrases like "በጣም ደስ ይላል!", "እንኳን ደስ አለህ/አለሽ", with positive energy.
''';

      case ReplyTone.crush:
        return '''
━━━ TONE: CRUSH (Amharic) ━━━
- Vibe: Playful, sweet, confident, magnetically secure, and charmingly unpredictable.
- Script: Uses charming Ge'ez script. Avoids overly dramatic romantic poetry or intense expressions. Instead, focus on light, culturally-appropriate playful teasing, relaxed interest, and warm conversational hooks.
''';

      default:
        return '';
    }
  }
}