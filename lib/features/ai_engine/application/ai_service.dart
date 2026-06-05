import 'package:say_it/features/ai_engine/domain/models.dart';

/// The standard contract that every AI model engine must implement.
abstract interface class AiService {
  Future<List<String>> generateReplies(GenerationRequest request);
}

/// Thrown specifically when a provider hits a rate limit (HTTP 429),
/// signaling the orchestrator to try the next provider.
class RateLimitException implements Exception {
  final String providerName;
  final String message;

  RateLimitException({
    required this.providerName,
    required this.message,
  });

  @override
  String toString() => 'RateLimitException [$providerName]: $message';
}