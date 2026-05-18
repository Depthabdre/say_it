import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../../../features/ai_engine/domain/models.dart';
import '../../../../features/ai_engine/application/gemini_service.dart';
import '../../../../core/native_bridge/accessibility_service.dart';

part 'bubble_overlay_event.dart';
part 'bubble_overlay_state.dart';

class BubbleOverlayBloc extends Bloc<BubbleOverlayEvent, BubbleOverlayState> {
  final GeminiService geminiService;

  BubbleOverlayBloc({required this.geminiService})
      : super(const BubbleOverlayState()) {
    on<ToggleExpandEvent>(_onToggleExpand);
    on<ToggleLanguageEvent>(_onToggleLanguage);
    on<ChangeToneEvent>(_onChangeTone);
    on<ListeningStatusChangedEvent>(_onListeningStatusChanged);
    on<GenerateRepliesEvent>(_onGenerateReplies);
    on<RepliesReceivedEvent>(_onRepliesReceived);
    on<ErrorReceivedEvent>(_onErrorReceived);
    on<ResetBubbleEvent>(_onResetBubble);
  }

  Future<void> _onToggleExpand(
    ToggleExpandEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    final newIsExpanded = !state.isExpanded;
    emit(state.copyWith(
      isExpanded: newIsExpanded,
      generatedReplies: newIsExpanded ? state.generatedReplies : [],
      errorMessage: newIsExpanded ? state.errorMessage : '',
      isGenerating: newIsExpanded ? state.isGenerating : false,
      isListening: newIsExpanded ? state.isListening : false,
    ));

    if (newIsExpanded) {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        450,
        true,
      );
    } else {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      await FlutterOverlayWindow.resizeOverlay(150, 150, true);
    }
  }

  void _onToggleLanguage(
    ToggleLanguageEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.copyWith(isAmharic: !state.isAmharic));
  }

  void _onChangeTone(
    ChangeToneEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.copyWith(selectedTone: event.tone));
  }

  void _onListeningStatusChanged(
    ListeningStatusChangedEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.copyWith(isListening: event.isListening));
  }

  Future<void> _onGenerateReplies(
    GenerateRepliesEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    emit(state.clearError().copyWith(isGenerating: true, generatedReplies: []));

    try {
      String screenText = "";
      final customText = event.customText;

      if (customText.isEmpty) {
        final extractedText =
            await AccessibilityServiceBridge.extractScreenText();
        if (extractedText == null ||
            extractedText.trim().isEmpty ||
            extractedText == "NO_ROOT_NODE") {
          emit(state.copyWith(
            isGenerating: false,
            errorMessage:
                "Could not read screen. Please open a chat app first or provide text manually.",
          ));
          return;
        }
        screenText = extractedText;
        debugPrint('Captured Screen Context: \\n"""\\n$screenText\\n"""');
      } else {
        screenText = "User provided contextual input: $customText";
      }

      final request = GenerationRequest(
        screenContextText: screenText,
        tone: state.selectedTone,
        customInstructions: customText.isEmpty ? null : customText,
      );

      final replies = await geminiService.generateReplies(request);

      emit(state.copyWith(
        generatedReplies: replies,
        isGenerating: false,
      ));

      if (state.isExpanded) {
        await FlutterOverlayWindow.resizeOverlay(
            WindowSize.matchParent, 600, true);
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString(),
        isGenerating: false,
      ));
    }
  }

  void _onRepliesReceived(
    RepliesReceivedEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    emit(state.copyWith(
      isGenerating: false,
      generatedReplies: event.replies,
      errorMessage: '', // Clears the error
    ));
    if (state.isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, 600, true);
    }
  }

  void _onErrorReceived(
    ErrorReceivedEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.copyWith(
      isGenerating: false,
      errorMessage: event.error,
    ));
  }

  void _onResetBubble(
    ResetBubbleEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.clearError().copyWith(
      isExpanded: false,
      isGenerating: false,
      generatedReplies: [],
      isListening: false,
    ));
  }
}
