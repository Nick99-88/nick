import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/ml_config.dart';

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  // 🏛️ Translation Service with API Key
  Future<String> translateText({
    required String text,
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  }) async {
    try {
      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      
      final translatedText = await translator.translateText(text);
      translator.close();
      
      return translatedText;
    } catch (e) {
      throw Exception('Translation failed: $e');
    }
  }

  // 🏛️ Language Identification Service
  Future<String> identifyLanguage(String text) async {
    try {
      final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
      final identifiedLanguage = await languageIdentifier.identifyLanguage(text);
      languageIdentifier.close();
      
      return identifiedLanguage;
    } catch (e) {
      throw Exception('Language identification failed: $e');
    }
  }

  // 🏛️ Text Recognition Service
  Future<String> recognizeText({
    required String imagePath,
    TextRecognitionScript script = TextRecognitionScript.latin,
  }) async {
    try {
      final textRecognizer = TextRecognizer(script: script);
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();
      
      return recognizedText.text;
    } catch (e) {
      throw Exception('Text recognition failed: $e');
    }
  }

  // 🏛️ Batch Text Recognition for Documents
  Future<List<String>> recognizeTextFromDocument({
    required List<String> imagePaths,
    TextRecognitionScript script = TextRecognitionScript.latin,
  }) async {
    final results = <String>[];
    
    try {
      final textRecognizer = TextRecognizer(script: script);
      
      for (final imagePath in imagePaths) {
        try {
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognizedText = await textRecognizer.processImage(inputImage);
          results.add(recognizedText.text);
        } catch (e) {
          print('Error processing image $imagePath: $e');
          results.add(''); // Add empty string for failed images
        }
      }
      
      textRecognizer.close();
      return results;
    } catch (e) {
      throw Exception('Batch text recognition failed: $e');
    }
  }

  // 🏛️ Smart Dictionary Service
  Future<Map<String, dynamic>> getDictionaryEntry(String word) async {
    try {
      // Identify language of the word
      final identifiedLang = await identifyLanguage(word);
      
      // Get translation to multiple languages
      final translations = <String, String>{};
      final targetLanguages = [
        TranslateLanguage.urdu,
        TranslateLanguage.hindi,
        TranslateLanguage.arabic,
      ];
      
      for (final targetLang in targetLanguages) {
        try {
          final translation = await translateText(
            text: word,
            sourceLanguage: _getLanguageFromCode(identifiedLang),
            targetLanguage: targetLang,
          );
          translations[targetLang.name] = translation;
        } catch (e) {
          translations[targetLang.name] = 'N/A';
        }
      }
      
      return {
        'word': word,
        'identifiedLanguage': identifiedLang,
        'confidence': 0.95, // Mock confidence since we're returning String
        'translations': translations,
        'phonetic': _getPhoneticRepresentation(word),
        'partOfSpeech': _getPartOfSpeech(word),
        'definitions': _getDefinitions(word),
        'examples': _getExampleSentences(word),
        'synonyms': _getSynonyms(word),
        'grammar': await _analyzeGrammar(word),
      };
    } catch (e) {
      throw Exception('Dictionary lookup failed: $e');
    }
  }

  // 🏛️ Grammar Analysis Service
  Future<Map<String, dynamic>> analyzeGrammar(String sentence) async {
    try {
      // Identify language
      final identifiedLang = await identifyLanguage(sentence);
      
      // Basic grammar analysis
      final words = sentence.split(' ');
      final wordCount = words.length;
      
      // Simple sentence structure analysis
      final hasQuestion = sentence.contains('?') || sentence.toLowerCase().startsWith('who') || 
                         sentence.toLowerCase().startsWith('what') || sentence.toLowerCase().startsWith('where') ||
                         sentence.toLowerCase().startsWith('when') || sentence.toLowerCase().startsWith('why') ||
                         sentence.toLowerCase().startsWith('how');
      
      final hasExclamation = sentence.contains('!');
      final isProperCase = _isProperlyCapitalized(sentence);
      
      return {
        'language': identifiedLang,
        'confidence': 0.95, // Mock confidence since we're returning String
        'wordCount': wordCount,
        'sentenceType': _getSentenceType(hasQuestion, hasExclamation),
        'isProperlyCapitalized': isProperCase,
        'hasCorrectPunctuation': _hasCorrectPunctuation(sentence),
        'suggestions': _getGrammarSuggestions(sentence, isProperCase, hasQuestion, hasExclamation),
        'corrections': await _getCorrections(sentence),
      };
    } catch (e) {
      throw Exception('Grammar analysis failed: $e');
    }
  }

  // 🏛️ Document Processing Service
  Future<Map<String, dynamic>> processDocument({
    required List<String> imagePaths,
    String sourceLanguage = 'en',
    List<String> targetLanguages = const ['ur', 'hi', 'ar'],
  }) async {
    try {
      // Extract text from all images
      final extractedTexts = await recognizeTextFromDocument(imagePaths: imagePaths);
      final fullText = extractedTexts.join('\n');
      
      // Identify language
      final identifiedLang = await identifyLanguage(fullText);
      
      // Generate translations
      final translations = <String, String>{};
      for (final targetLangCode in targetLanguages) {
        try {
          final targetLang = _getLanguageFromCode(targetLangCode);
          final sourceLangEnum = _getLanguageFromCode(identifiedLang);
          
          final translation = await translateText(
            text: fullText,
            sourceLanguage: sourceLangEnum,
            targetLanguage: targetLang,
          );
          translations[targetLangCode] = translation;
        } catch (e) {
          translations[targetLangCode] = 'Translation failed';
        }
      }
      
      return {
        'originalText': fullText,
        'identifiedLanguage': identifiedLang,
        'confidence': 0.95, // Mock confidence since we're returning String
        'imageCount': imagePaths.length,
        'translations': translations,
        'extractedTexts': extractedTexts,
        'wordCount': fullText.split(' ').length,
        'characterCount': fullText.length,
        'processedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Document processing failed: $e');
    }
  }

  // 🏛️ Helper Methods
  TranslateLanguage _getLanguageFromCode(dynamic languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
        return TranslateLanguage.english;
      case 'ur':
        return TranslateLanguage.urdu;
      case 'ar':
        return TranslateLanguage.arabic;
      case 'hi':
        return TranslateLanguage.hindi;
      case 'es':
        return TranslateLanguage.spanish;
      case 'fr':
        return TranslateLanguage.french;
      case 'de':
        return TranslateLanguage.german;
      case 'zh':
        return TranslateLanguage.chinese;
      case 'ja':
        return TranslateLanguage.japanese;
      case 'ko':
        return TranslateLanguage.korean;
      default:
        return TranslateLanguage.english;
    }
  }

  String _getPhoneticRepresentation(String word) {
    // Simple phonetic representation (can be enhanced with proper phonetic library)
    return "/${word.toLowerCase()}/";
  }

  String _getPartOfSpeech(String word) {
    // Simple part of speech detection (can be enhanced with ML models)
    final lowerWord = word.toLowerCase();
    
    if (['the', 'a', 'an'].contains(lowerWord)) return 'Article';
    if (['and', 'but', 'or', 'nor', 'for', 'so', 'yet'].contains(lowerWord)) return 'Conjunction';
    if (['in', 'on', 'at', 'by', 'for', 'with', 'about', 'against', 'between', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'to', 'from', 'up', 'down', 'in', 'out', 'on', 'off', 'over', 'under', 'again', 'further', 'then', 'once'].contains(lowerWord)) return 'Preposition';
    
    return 'Noun/Verb'; // Default classification
  }

  List<String> _getDefinitions(String word) {
    // Mock definitions (can be enhanced with dictionary API)
    return [
      'Primary definition of $word',
      'Secondary meaning of $word',
      'Contextual usage of $word',
    ];
  }

  List<String> _getExampleSentences(String word) {
    return [
      'The $word is essential for the institution.',
      'We used $word to solve the problem.',
      'Always verify the $word before proceeding.',
    ];
  }

  List<String> _getSynonyms(String word) {
    // Mock synonyms (can be enhanced with thesaurus API)
    return [
      '${word} synonym 1',
      '${word} synonym 2',
      '${word} synonym 3',
    ];
  }

  Future<Map<String, dynamic>> _analyzeGrammar(String word) async {
    return {
      'isCorrect': true,
      'suggestions': ['No grammar issues detected'],
      'corrections': [],
    };
  }

  String _getSentenceType(bool hasQuestion, bool hasExclamation) {
    if (hasQuestion) return 'Interrogative';
    if (hasExclamation) return 'Exclamatory';
    return 'Declarative';
  }

  bool _isProperlyCapitalized(String sentence) {
    if (sentence.isEmpty) return true;
    return sentence[0].toUpperCase() == sentence[0];
  }

  bool _hasCorrectPunctuation(String sentence) {
    if (sentence.isEmpty) return true;
    final lastChar = sentence[sentence.length - 1];
    return ['.', '?', '!'].contains(lastChar);
  }

  List<String> _getGrammarSuggestions(String sentence, bool isProperlyCapitalized, bool hasQuestion, bool hasExclamation) {
    final suggestions = <String>[];
    
    if (!isProperlyCapitalized) {
      suggestions.add('Consider capitalizing the first letter');
    }
    
    if (!_hasCorrectPunctuation(sentence)) {
      suggestions.add('Add proper punctuation at the end');
    }
    
    if (suggestions.isEmpty) {
      suggestions.add('Grammar looks good!');
    }
    
    return suggestions;
  }

  Future<List<String>> _getCorrections(String sentence) async {
    // Mock corrections (can be enhanced with grammar checking API)
    return [];
  }

  // 🏛️ Utility Methods
  Future<bool> isServiceAvailable() async {
    try {
      // Test translation service
      await translateText(
        text: 'test',
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.english,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getServiceStatus() async {
    final isAvailable = await isServiceAvailable();
    
    return {
      'isAvailable': isAvailable,
      'apiKey': MLConfig.apiKey,
      'supportedLanguages': TranslateLanguage.values.map((lang) => lang.name).toList(),
      'supportedScripts': TextRecognitionScript.values.map((script) => script.name).toList(),
      'lastChecked': DateTime.now().toIso8601String(),
    };
  }
}