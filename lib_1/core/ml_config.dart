class MLConfig {
  // 🏛️ Google ML Kit API Configuration
  static const String apiKey = 'AIzaSyB3HIlXzmalZ9gSv-X7Wx4K_DxNAe0KGFs';
  
  // 🏛️ ML Kit Service Configuration
  static Map<String, dynamic> getLanguageIdConfig() {
    return {
      'apiKey': apiKey,
      'confidenceThreshold': 0.5,
      'useOnDevice': true,
    };
  }
  
  static Map<String, dynamic> getTextRecognitionConfig() {
    return {
      'apiKey': apiKey,
      'script': 'latin',
      'useOnDevice': true,
    };
  }
  
  static Map<String, dynamic> getTranslationConfig() {
    return {
      'apiKey': apiKey,
      'useOnDevice': true,
      'cacheSize': 100,
    };
  }
}

// 🏛️ Supported Languages for Translation
enum SupportedLanguage {
  english,
  urdu,
  arabic,
  punjabi,
  sindhi,
  pashto,
  hindi,
  spanish,
  french,
  german,
  chinese,
  japanese,
  korean,
}

// 🏛️ Language Code Mappings
class LanguageCodes {
  static const Map<SupportedLanguage, String> translationCodes = {
    SupportedLanguage.english: 'en',
    SupportedLanguage.urdu: 'ur',
    SupportedLanguage.arabic: 'ar',
    SupportedLanguage.punjabi: 'pa',
    SupportedLanguage.sindhi: 'sd',
    SupportedLanguage.pashto: 'ps',
    SupportedLanguage.hindi: 'hi',
    SupportedLanguage.spanish: 'es',
    SupportedLanguage.french: 'fr',
    SupportedLanguage.german: 'de',
    SupportedLanguage.chinese: 'zh',
    SupportedLanguage.japanese: 'ja',
    SupportedLanguage.korean: 'ko',
  };
  
  static const Map<String, String> scriptCodes = {
    'latin': 'Latn',
    'chinese': 'Hans',
    'devanagari': 'Deva',
    'japanese': 'Jpan',
    'korean': 'Kore',
    'arabic': 'Arab',
    'bengali': 'Beng',
    'tamil': 'Taml',
    'thai': 'Thai',
  };
}
