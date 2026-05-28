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
  final Uint8List? audioBytes;
  final String? audioMimeType;
  
  // Independent language controls
  final bool isAmharicInput;
  final bool isAmharicOutput;

  const GenerationRequest({
    this.screenContextText,
    required this.tone,
    this.customInstructions,
    this.audioBytes,
    this.audioMimeType,
    required this.isAmharicInput,
    required this.isAmharicOutput,
  });
}