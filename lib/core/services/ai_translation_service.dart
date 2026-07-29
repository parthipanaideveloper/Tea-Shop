import 'package:google_generative_ai/google_generative_ai.dart';

class AiTranslationService {
  final String apiKey;

  AiTranslationService({required this.apiKey});

  Future<String> translateToTamil(String text) async {
    if (apiKey.isEmpty || text.trim().isEmpty) return '';

    // Hardcoded overrides for common items where AI gets the dialect wrong
    final lowerText = text.trim().toLowerCase();
    if (lowerText == 'vegetable gravy') return 'வெஜிடபிள் கறி';
    if (lowerText == 'vegetable rice') return 'வெஜிடபிள் ரைஸ்';

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final prompt =
          'Translate the following short product/category name to colloquial Tamil suitable for a South Indian restaurant menu (e.g., Rice should be translated as Saatham, not Arisi). Provide ONLY the translated Tamil text and nothing else. No punctuation, no quotes, no explanations. Text to translate: "$text"';
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text?.trim() ?? '';
    } catch (e) {
      print('AI Translation Error: $e');
      return '';
    }
  }
}
