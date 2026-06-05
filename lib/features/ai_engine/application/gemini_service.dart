import 'package:say_it/features/ai_engine/domain/models.dart';
import 'ai_service.dart';
import 'providers/gemini_provider.dart';
import 'providers/groq_provider.dart';
import 'providers/openrouter_provider.dart';
import 'fallback_ai_service.dart';

/// Legacy interface wrapper for our fallback orchestration chain.
/// This maintains compatibility with [BubbleOverlayBloc] without breaking imports.
class GeminiService {
  late final FallbackAiService _fallbackAiService;

  GeminiService() {
    _fallbackAiService = FallbackAiService(
      services: [
        GeminiProvider(),
        GroqProvider(),
        OpenRouterProvider(),
      ],
    );
  }

  /// Sequential failover endpoint used by the overlay UI bloc.
  Future<List<String>> generateReplies(GenerationRequest request) async {
    return _fallbackAiService.generateReplies(request);
  }
}