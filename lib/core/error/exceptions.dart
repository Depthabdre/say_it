// Base exceptions mapped to the failures

class ServerException implements Exception {
  final String message;
  ServerException({this.message = 'Server Error'});
}

class NetworkException implements Exception {
  final String message;
  NetworkException({this.message = 'Network Error'});
}

class SpeechRecognitionException implements Exception {
  final String message;
  SpeechRecognitionException({this.message = 'Speech Recognition Error'});
}

class AiEngineException implements Exception {
  final String message;
  AiEngineException({this.message = 'AI Engine Error'});
}

class MicrophonePermissionException implements Exception {
  final String message;
  MicrophonePermissionException({this.message = 'Microphone Permission Denied'});
}

class OverlayPermissionException implements Exception {
  final String message;
  OverlayPermissionException({this.message = 'Overlay Permission Denied'});
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException({this.message = 'Request Timeout'});
}

class UnknownException implements Exception {
  final String message;
  UnknownException({this.message = 'Unknown Error'});
}
