part of 'bubble_overlay_bloc.dart';

class BubbleOverlayState extends Equatable {
  final bool isExpanded;
  final bool isGenerating;
  final String? errorMessage;
  final List<String> generatedReplies;
  final ReplyTone selectedTone;
  final bool isListening;
  final bool isAmharic;

  const BubbleOverlayState({
    this.isExpanded = false,
    this.isGenerating = false,
    this.errorMessage,
    this.generatedReplies = const [],
    this.selectedTone = ReplyTone.normal,
    this.isListening = false,
    this.isAmharic = true,
  });

  BubbleOverlayState copyWith({
    bool? isExpanded,
    bool? isGenerating,
    String? errorMessage,
    List<String>? generatedReplies,
    ReplyTone? selectedTone,
    bool? isListening,
    bool? isAmharic,
  }) {
    return BubbleOverlayState(
      isExpanded: isExpanded ?? this.isExpanded,
      isGenerating: isGenerating ?? this.isGenerating,
      // If an empty string is passed, clear the error message completely
      errorMessage: errorMessage != null ? (errorMessage.isEmpty ? null : errorMessage) : this.errorMessage,
      generatedReplies: generatedReplies ?? this.generatedReplies,
      selectedTone: selectedTone ?? this.selectedTone,
      isListening: isListening ?? this.isListening,
      isAmharic: isAmharic ?? this.isAmharic,
    );
  }

  BubbleOverlayState clearError() {
    return BubbleOverlayState(
      isExpanded: isExpanded,
      isGenerating: isGenerating,
      errorMessage: null,
      generatedReplies: generatedReplies,
      selectedTone: selectedTone,
      isListening: isListening,
      isAmharic: isAmharic,
    );
  }

  @override
  List<Object?> get props => [
        isExpanded,
        isGenerating,
        errorMessage,
        generatedReplies,
        selectedTone,
        isListening,
        isAmharic,
      ];
}
