import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
    on<VoiceAudioRecordedEvent>(_onVoiceAudioRecorded);
    on<GenerateRepliesEvent>(_onGenerateReplies);
    on<RepliesReceivedEvent>(_onRepliesReceived);
    on<ErrorReceivedEvent>(_onErrorReceived);
    on<ClearCurrentStateEvent>(_onClearCurrentState);
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
      recordedAudioPath: newIsExpanded ? state.recordedAudioPath : null,
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

  void _onVoiceAudioRecorded(
    VoiceAudioRecordedEvent event,
    Emitter<BubbleOverlayState> emit,
  ) {
    emit(state.copyWith(recordedAudioPath: event.audioPath));
  }

  Future<void> _onGenerateReplies(
    GenerateRepliesEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    emit(state.clearError().copyWith(isGenerating: true, generatedReplies: []));

    try {
      String screenText = "";
      final customText = event.customText;
      final bool hasAudio = state.recordedAudioPath != null;

      // Ensure we extract conversational screen text
      final extractedText = await AccessibilityServiceBridge.extractScreenText();
      if (extractedText != null &&
          extractedText.trim().isNotEmpty &&
          extractedText != "NO_ROOT_NODE") {
        screenText = extractedText;
      } else {
        screenText = "No active screen conversation context found.";
      }

      Uint8List? audioBytes;
      String? mimeType;

      if (hasAudio) {
        final file = File(state.recordedAudioPath!);
        if (await file.exists()) {
          audioBytes = await file.readAsBytes();
          // Setting AAC/M4A mime type matching standard flutter audio recorder outputs
          mimeType = Platform.isIOS ? 'audio/x-m4a' : 'audio/aac';
        }
      }

      final request = GenerationRequest(
        screenContextText: screenText,
        tone: state.selectedTone,
        customInstructions: customText.isEmpty ? null : customText,
        audioBytes: audioBytes,
        audioMimeType: mimeType,
        isAmharic: state.isAmharic,
      );

      final replies = await geminiService.generateReplies(request);

      // Clean up the temporary recording file once submitted to conserve storage
      if (state.recordedAudioPath != null) {
        try {
          await File(state.recordedAudioPath!).delete();
        } catch (_) {}
      }

      emit(state.copyWith(
        generatedReplies: replies,
        isGenerating: false,
        recordedAudioPath: null, // Clear the processed voice clip path
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
      
      Future.delayed(const Duration(seconds: 4), () {
        if (!isClosed) {
           add(ClearCurrentStateEvent());
        }
      });
    }
  }

  void _onRepliesReceived(
    RepliesReceivedEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    emit(state.copyWith(
      isGenerating: false,
      generatedReplies: event.replies,
      errorMessage: '',
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
    
    Future.delayed(const Duration(seconds: 4), () {
      if (!isClosed) {
         add(ClearCurrentStateEvent());
      }
    });
  }

  void _onClearCurrentState(
    ClearCurrentStateEvent event,
    Emitter<BubbleOverlayState> emit,
  ) async {
    emit(state.clearError().copyWith(
      generatedReplies: [],
      recordedAudioPath: null,
    ));
    if (state.isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 450, true);
    }
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
      recordedAudioPath: null,
    ));
  }
}