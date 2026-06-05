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
        return await service.generateReplies(request);
      } on RateLimitException catch (e) {
        errorHistory.add('${e.providerName} (Rate Limit): ${e.message}');
      } on AiEngineException catch (e) {
        errorHistory.add('${service.runtimeType} (AiEngineException): ${e.message}');
      } on Exception catch (e) {
        errorHistory.add('${service.runtimeType} (Exception): $e');
      }
    }

    throw AiEngineException(
      message: 'All available AI providers failed. Error Trace:\n${errorHistory.join('\n')}',
    );
  }
}