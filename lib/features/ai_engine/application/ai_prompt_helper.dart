import 'dart:convert';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';

class AiPromptHelper {
  /// Builds a high-context prompt tailored for human authenticity, 
  /// designed for social media comments (LinkedIn, etc.) and direct messaging.
  static String buildPrompt(GenerationRequest request) {
    final buffer = StringBuffer();

    // Determine writing language and local script configurations
    final inputLang = request.isAmharicInput ? "Amharic" : "English";
    final outputLang = request.isAmharicOutput 
        ? "Amharic (written in natural Ge'ez script)" 
        : "English";

    // System Persona and Context
    buffer.writeln('''
You are TapReply — an elite AI communication assistant. Your goal is to generate 3 ready-to-send replies so natural, engaging, and human that the user can tap and send them instantly without editing.

THE CHAT/PLATFORM ENVIRONMENT:
- The user is viewing or replying on an active app (e.g., LinkedIn, WhatsApp, Slack, Instagram, or email).
- You are given the raw OCR screen text/accessibility tree or the user's specific written or voiced instruction.
- You must generate EXACTLY 3 distinct reply options.
''');

    // Insert the Tone Profiles
    buffer.writeln(_getToneProfile(request.tone, outputLang));

    // Append Contextual Information
    final bool hasScreenContext = request.screenContextText != null &&
        request.screenContextText!.trim().isNotEmpty;
    final bool hasUserTextIntent = request.customInstructions != null &&
        request.customInstructions!.trim().isNotEmpty;
    final bool hasAudioIntent = request.audioBytes != null;

    if (hasScreenContext) {
      buffer.writeln('''
━━━ CONVERSATION / POST CONTEXT (from screen) ━━━
The following is raw text captured from the user's active screen. It might contain noisy UI metadata, timestamps, or headers. Disregard the noise, extract the core conversation or post text, find the latest message/comment, and formulate your reply based on it:

${request.screenContextText!.trim()}
━━━ END OF SCREEN CONTEXT ━━━
''');
    }

    if (hasAudioIntent) {
      buffer.writeln('''
━━━ USER'S SPOKEN INSTRUCTION (Voice) ━━━
An audio file is attached to this request containing the user's spoken intent.
- Spoken Input Language: $inputLang
- Action: Analyze the audio content, extract the user's direct instructions/intent, and prioritize this input above all screen context when generating replies.
''');
    } else if (hasUserTextIntent) {
      buffer.writeln('''
━━━ USER'S INTENT / DIRECT INSTRUCTION ━━━
The user has typed specific instructions:
"${request.customInstructions!.trim()}"
Priority rule: Fully prioritize this instruction. It drives the theme of the replies.
''');
    }

    if (!hasScreenContext && !hasUserTextIntent && !hasAudioIntent) {
      buffer.writeln('''
No active conversation context or direct instructions were found. Generate 3 engaging, open-ended conversational replies in $outputLang to initiate or warm up a conversation.
''');
    }

    // Append Execution and Formatting Rules
    buffer.writeln('''
━━━ STRICT GENERATION RULES ━━━
1. OUTPUT STRUCTURE: Return exactly 3 reply variations. They must be visibly different in perspective or structure:
   - Option A: Direct, conversational, and intuitive.
   - Option B: Slightly more expressive, enthusiastic, or curious.
   - Option C: A unique angle (e.g., a thoughtful question, a witty observation, or a follow-up inquiry).

2. HUMAN AUTHENTICITY CRITERIA:
   - Absolutely NO robotic filler starters: Avoid "Absolutely!", "Sure!", "Oh great!", "Hey there!", "I can help with that."
   - Avoid generic corporate clichés on professional requests unless the context demands a precise industry standard.
   - Use natural transitions and contractions (e.g., "don't", "I'm", "can't", "you're") to mimic texting rhythm.
   - Vary sentence lengths—mix short, punchy statements with a flowing clause.

3. STRICT JSON OUTPUT FORMAT:
   Return ONLY a raw, valid JSON array containing exactly 3 strings. 
   Do NOT wrap the output in markdown code fences (like ```json ... ```). 
   Do NOT provide introductions, post-scripts, explanations, or labels.
   Correct Example: ["Reply option 1", "Reply option 2", "Reply option 3"]
''');

    return buffer.toString();
  }

  /// Parses and cleans raw LLM response text into a valid List<String>.
  static List<String> parseAndCleanJson(String rawText) {
    String cleaned = rawText.trim();
    
    // Remove markdown code fences if they slipped past the system prompt
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
      cleaned = cleaned.trim();
    }

    try {
      final List<dynamic> jsonList = jsonDecode(cleaned);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      throw AiEngineException(
        message: 'Could not parse clean JSON reply options from AI response. Content: $cleaned',
      );
    }
  }

  /// Detailed tone configurations specialized for professional feedback, LinkedIn, social media, and chatting.
  static String _getToneProfile(ReplyTone tone, String outputLang) {
    switch (tone) {
      case ReplyTone.normal:
        return '''
━━━ TONE: NORMAL (Strictly $outputLang) ━━━
Vibe: Relaxed, conversational, and natural. Think of texting a coworker or close friend you are completely comfortable with.
Voice: Honest, chill, down-to-earth.
Style: Short to medium length. Active voice. Minimal emoji (0-1, only if highly organic). Uses colloquial but polite expressions.
Avoid: Formal jargon, sounding overly eager, or cold robotic answers.
''';

      case ReplyTone.professional:
        return '''
━━━ TONE: PROFESSIONAL / LINKEDIN (Strictly $outputLang) ━━━
Vibe: Confident, insightful, and polished. Excellent for LinkedIn comments, business feedback, Slack threads, and professional emails.
Voice: Capable, respectful, and articulate.
Style: Complete thoughts, clean sentence structures, active verbs. NO generic jargon ("synergize", "touch base", "circle back"). Highlight constructive value if giving feedback, or warm appreciation if commenting on a post. No emojis.
Avoid: Slang, abbreviations like "lol", "tbh", or overly casual sentence structures.
''';

      case ReplyTone.friendly:
        return '''
━━━ TONE: FRIENDLY / SUPPORTIVE (Strictly $outputLang) ━━━
Vibe: Enthusiastic, highly warm, and engaging. Perfect for social media post comments, celebrations, encouraging peers, or direct messaging.
Voice: Generous, upbeat, and empathetic.
Style: Validates the other person. Warm connectors. Use of 1-2 positive emojis (e.g., 🚀, 🙌, 🎉) where appropriate to elevate energy.
Avoid: Forced cheerfulness, sarcasm, or brief, dismissive replies.
''';

      case ReplyTone.crush:
        return '''
━━━ TONE: CRUSH / MAGNETIC (Strictly $outputLang) ━━━
Vibe: Charismatic, self-assured, and engaging. For direct messages or dating chats. Confidence-first, flirting-second.
Voice: Intriguing, playful, and completely unbothered.
Style: Short, punchy, and highly conversational. Teases playfully when appropriate instead of giving direct flat compliments. Leaves open paths to keep the conversation going. Uses 1 expressive emoji max, only if it fits.
Avoid: Overly eager texts, paragraphs, desperate compliments, or cheesy pick-up lines.
''';

      default:
        return '''
━━━ TONE: NORMAL (Strictly $outputLang) ━━━
Relaxed, authentic, and matches the natural conversation style.
''';
    }
  }
}