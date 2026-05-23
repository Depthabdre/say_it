part of 'bubble_overlay_bloc.dart';

abstract class BubbleOverlayEvent extends Equatable {
  const BubbleOverlayEvent();

  @override
  List<Object?> get props => [];
}

class ToggleExpandEvent extends BubbleOverlayEvent {}

class ToggleLanguageEvent extends BubbleOverlayEvent {}

class ChangeToneEvent extends BubbleOverlayEvent {
  final ReplyTone tone;
  const ChangeToneEvent(this.tone);

  @override
  List<Object?> get props => [tone];
}

class ListeningStatusChangedEvent extends BubbleOverlayEvent {
  final bool isListening;
  const ListeningStatusChangedEvent(this.isListening);

  @override
  List<Object?> get props => [isListening];
}

class VoiceAudioRecordedEvent extends BubbleOverlayEvent {
  final String? audioPath;
  const VoiceAudioRecordedEvent(this.audioPath);

  @override
  List<Object?> get props => [audioPath];
}

class GenerateRepliesEvent extends BubbleOverlayEvent {
  final String customText;
  const GenerateRepliesEvent({required this.customText});

  @override
  List<Object?> get props => [customText];
}

class RepliesReceivedEvent extends BubbleOverlayEvent {
  final List<String> replies;
  const RepliesReceivedEvent(this.replies);

  @override
  List<Object?> get props => [replies];
}

class ErrorReceivedEvent extends BubbleOverlayEvent {
  final String error;
  const ErrorReceivedEvent(this.error);

  @override
  List<Object?> get props => [error];
}

class ClearCurrentStateEvent extends BubbleOverlayEvent {}

class ResetBubbleEvent extends BubbleOverlayEvent {}