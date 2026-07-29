import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LanguageNotifier extends Notifier<String> {
  @override
  String build() {
    final box = Hive.box<String>('settings');
    // Default to 'en'
    return box.get('appLanguage') ?? 'en';
  }

  void setLanguage(String langCode) {
    if (state == langCode) return;
    state = langCode;
    Hive.box<String>('settings').put('appLanguage', langCode);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(() {
  return LanguageNotifier();
});
