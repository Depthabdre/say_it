import 'dart:typed_data';

enum ReplyTone {
  normal('Normal'),
  professional('Professional'),
  friendly('Friendly'),
  crush('Crush');

  final String displayName;
  const ReplyTone(this.displayName);
}

class GenerationRequest {
  final String? screenContextText;
  final ReplyTone tone;
  final String? customInstructions;
  
  // New fields for raw audio input
  final Uint8List? audioBytes;
  final String? audioMimeType;
  final bool isAmharic;

  const GenerationRequest({
    this.screenContextText,
    required this.tone,
    this.customInstructions,
    this.audioBytes,
    this.audioMimeType,
    required this.isAmharic,
  });
}