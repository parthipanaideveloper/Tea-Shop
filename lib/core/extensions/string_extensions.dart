import 'package:hive/hive.dart';
import '../localization/translations.dart';

extension TranslationExt on String {
  String tr(String langCode) {
    if (langCode == 'en') return this;

    if (langCode == 'ta') {
      try {
        final tBox = Hive.box<String>('category_translations');
        if (tBox.isOpen && tBox.containsKey(this)) {
          final customVal = tBox.get(this);
          if (customVal != null && customVal.isNotEmpty) {
            return customVal;
          }
        }
      } catch (_) {}
    }

    // Check if the current string exists in the translation map
    final translationsForLang = appTranslations[langCode];
    if (translationsForLang != null) {
      final searchStr = this.trim().toLowerCase();
      final key = translationsForLang.keys.firstWhere((k) {
        final tk = k.trim().toLowerCase();
        final ek = appTranslations['en']?[k]?.trim().toLowerCase();
        return (ek == searchStr) ||
            (tk == searchStr) ||
            (tk == searchStr.replaceAll(' ', '_'));
      }, orElse: () => '');

      if (key.isNotEmpty && translationsForLang.containsKey(key)) {
        return translationsForLang[key]!;
      }

      // Direct lookup as fallback
      if (translationsForLang.containsKey(this)) {
        return translationsForLang[this]!;
      }
    }

    return this; // Return English if no translation found
  }

  // Helper to fix common bad AI translations in Tamil
  String fixTamil() {
    if (this.isEmpty) return this;
    return this
        .replaceAll('காய்கிரேவி', 'காய்கறி')
        .replaceAll('அரிசி', 'சாதம்') // Rice
        .replaceAll('குடுவை', 'பாட்டில்') // Bottle
        .replaceAll('வறுத்த தோசை', 'ரோஸ்ட்') // Roast
        .replaceAll(
          ' கறி',
          ' கிரேவி') // Space before so it doesn't break 'காய்கறி' (vegetable)
        .replaceAll('தோச ', 'தோசை ') // Typo in dosa
        .replaceAll(RegExp(r'தோச$'), 'தோசை') // Typo in dosa at end
        .replaceAll(
          RegExp(r'veg fired rice', caseSensitive: false),
          'வெஜ் பிரைட் ரைஸ்')
        .replaceAll(
          RegExp(r'veg fried rice', caseSensitive: false),
          'வெஜ் பிரைட் ரைஸ்')
        .replaceAll(RegExp(r'paneer 65', caseSensitive: false), 'பன்னீர் 65')
        .replaceAll(
          RegExp(r'paneer gravy', caseSensitive: false),
          'பன்னீர் கிரேவி')
        .replaceAll(RegExp(r'kal dosa', caseSensitive: false), 'கல் தோசை')
        .replaceAll(
          RegExp(r'channa masala', caseSensitive: false),
          'சன்னா மசாலா')
        .replaceAll(RegExp(r'veg rice', caseSensitive: false), 'வெஜ் ரைஸ்')
        .replaceAll(
          RegExp(r'cold water bottle', caseSensitive: false),
          'குளிர்ந்த தண்ணீர் பாட்டில்')
        .replaceAll(
          RegExp(r'vadu satham', caseSensitive: false),
          'வெஜ் பிரைட் ரைஸ்')
        .replaceAll(RegExp(r'dinner', caseSensitive: false), 'இரவு உணவு');
  }
}
