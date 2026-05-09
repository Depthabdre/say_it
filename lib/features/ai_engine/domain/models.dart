// lib/features/ai_engine/domain/models.dart

/// Represents the tone the user wants the generated reply to be in.
enum ReplyTone {
  professional("Professional"),
  friendly("Friendly"),
  crush("Crush/Flirty"),
  normal("Normal/Neutral");

  final String displayName;
  const ReplyTone(this.displayName);
}

/// Represents the request sent to the AI service.
class GenerationRequest {
  final String screenContextText;
  final ReplyTone tone;
  final String? customInstructions;

  GenerationRequest({
    required this.screenContextText,
    this.tone = ReplyTone.normal,
    this.customInstructions,
  });
}
