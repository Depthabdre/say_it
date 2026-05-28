part of 'bubble_overlay_bloc.dart';

class BubbleOverlayState extends Equatable {
  final bool isExpanded;
  final bool isAmharicInput;   // For mic and input text definition
  final bool isAmharicOutput;  // For generated reply language
  final ReplyTone selectedTone;
  final bool isListening; 
  final String? recordedAudioPath;
  final List<String> generatedReplies;
  final bool isGenerating;
  final String? errorMessage;

  const BubbleOverlayState({
    this.isExpanded = false,
    this.isAmharicInput = false,
    this.isAmharicOutput = false,
    this.selectedTone = ReplyTone.normal,
    this.isListening = false,
    this.recordedAudioPath,
    this.generatedReplies = const [],
    this.isGenerating = false,
    this.errorMessage,
  });

  BubbleOverlayState copyWith({
    bool? isExpanded,
    bool? isAmharicInput,
    bool? isAmharicOutput,
    ReplyTone? selectedTone,
    bool? isListening,
    String? recordedAudioPath,
    List<String>? generatedReplies,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return BubbleOverlayState(
      isExpanded: isExpanded ?? this.isExpanded,
      isAmharicInput: isAmharicInput ?? this.isAmharicInput,
      isAmharicOutput: isAmharicOutput ?? this.isAmharicOutput,
      selectedTone: selectedTone ?? this.selectedTone,
      isListening: isListening ?? this.isListening,
      recordedAudioPath: recordedAudioPath ?? this.recordedAudioPath,
      generatedReplies: generatedReplies ?? this.generatedReplies,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  BubbleOverlayState clearError() {
    return BubbleOverlayState(
      isExpanded: isExpanded,
      isAmharicInput: isAmharicInput,
      isAmharicOutput: isAmharicOutput,
      selectedTone: selectedTone,
      isListening: isListening,
      recordedAudioPath: recordedAudioPath,
      generatedReplies: generatedReplies,
      isGenerating: isGenerating,
      errorMessage: null,
    );
  }

  @override
  List<Object?> get props => [
        isExpanded,
        isAmharicInput,
        isAmharicOutput,
        selectedTone,
        isListening,
        recordedAudioPath,
        generatedReplies,
        isGenerating,
        errorMessage,
      ];
}