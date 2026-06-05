import 'package:flutter/foundation.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/error/exceptions.dart';
import 'ai_service.dart';

class FallbackAiService implements AiService {
  final List<AiService> _services;

  FallbackAiService({required List<AiService> services}) : _services = services;

  @override
  Future<List<String>> generateReplies(GenerationRequest request) async {
    final List<String> errorHistory = [];

    for (final service in _services) {
      try {
        debugPrint('🔄 Trying generation with ${service.runtimeType}...');
        final result = await service.generateReplies(request);
        debugPrint('✅ Generation succeeded using ${service.runtimeType}.');
        return result;
      } on RateLimitException catch (e) {
        debugPrint('⚠️ Rate limit hit on ${service.runtimeType}: ${e.message}');
        errorHistory.add(' (Rate Limit): ${e.message}');
      } on Exception catch (e) {
        debugPrint('❌ Generic failure on ${service.runtimeType}: $e');
        errorHistory.add('${service.runtimeType} (Error): $e');
      }
    }

    // If we reach this point, all providers in our array failed.
    throw AiEngineException(
      message: 'All available AI providers failed. Error Trace:\n${errorHistory.join('\n')}',
    );
  }
}