import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure({this.message = 'Oops! Something went wrong. Please try again.'});

  @override
  List<Object> get props => [message];
}

// 🌐 Server Issues
class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Our servers are experiencing a hiccup. We are working on it!'});
}

// 📶 No Internet
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'It seems you are offline. Please check your connection to continue.',
  });
}

// 🎤 Speech Recognition Issues
class SpeechRecognitionFailure extends Failure {
  const SpeechRecognitionFailure({
    super.message = "We couldn't quite catch that. Could you try speaking again?",
  });
}

// 🤖 AI/Gemini Issues (Rate Limit / Quota / Unparseable)
class AiEngineFailure extends Failure {
  const AiEngineFailure({
    super.message = 'The AI is taking a little break. Please try again in a moment.',
  });
}

// 🔒 Microphone Permission Denied
class MicrophonePermissionFailure extends Failure {
  const MicrophonePermissionFailure({
    super.message = 'Say It needs microphone access to hear you. Please enable it in Settings.',
  });
}

// 📌 Overlay Permission Denied (required for floating the UI)
class OverlayPermissionFailure extends Failure {
  const OverlayPermissionFailure({
    super.message = 'Display over other apps permission is required to show the assistant.',
  });
}

// ⏱️ Timeout 
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'The request took too long. Please make sure you have a stable connection and try again.',
  });
}

// ⚠️ Unknown / Generic
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something unexpected happened. We are looking into it.',
  });
}
