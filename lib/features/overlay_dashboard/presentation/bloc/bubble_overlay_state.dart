part of 'bubble_overlay_bloc.dart';

class BubbleOverlayState extends Equatable {
  final bool isExpanded;
  final bool isAmharic;
  final ReplyTone selectedTone;
  final bool isListening; // Serves as the active voice recording flag
  final String? recordedAudioPath; // Stores recorded voice path
  final List<String> generatedReplies;
  final bool isGenerating;
  final String? errorMessage;

  const BubbleOverlayState({
    this.isExpanded = false,
    this.isAmharic = false,
    this.selectedTone = ReplyTone.normal,
    this.isListening = false,
    this.recordedAudioPath,
    this.generatedReplies = const [],
    this.isGenerating = false,
    this.errorMessage,
  });

  BubbleOverlayState copyWith({
    bool? isExpanded,
    bool? isAmharic,
    ReplyTone? selectedTone,
    bool? isListening,
    String? recordedAudioPath,
    List<String>? generatedReplies,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return BubbleOverlayState(
      isExpanded: isExpanded ?? this.isExpanded,
      isAmharic: isAmharic ?? this.isAmharic,
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
      isAmharic: isAmharic,
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
        isAmharic,
        selectedTone,
        isListening,
        recordedAudioPath,
        generatedReplies,
        isGenerating,
        errorMessage,
      ];
}