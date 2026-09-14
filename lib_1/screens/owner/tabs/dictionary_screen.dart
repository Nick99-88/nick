import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../../../core/storage.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _textController = TextEditingController();
  List<String> _tags = []; // For Word mode
  Map<String, dynamic>? _translationResult;
  bool _isLoading = false;
  
  // Language and content type selection
  String _fromLang = 'English';
  String _toLang = 'Urdu';
  String _contentType = 'Word'; // Word or Sentence
  
  final List<String> _languages = ['English', 'Urdu', 'Arabic', 'Spanish', 'French', 'German', 'Chinese'];
  final List<String> _contentTypes = ['Word', 'Sentence'];

  @override
  void initState() {
    super.initState();
  }

  void _addTag(String text) {
    if (text.trim().isNotEmpty && !_tags.contains(text.trim())) {
      setState(() {
        _tags.add(text.trim());
        _textController.clear();
      });
    }
  }

  Future<void> _translateWithAI() async {
    final textToTranslate = _contentType == 'Word' ? _tags.join(', ') : _textController.text.trim();
    
    if (textToTranslate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to translate')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dictionary/translate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': textToTranslate,
          'from_lang': _fromLang,
          'to_lang': _toLang,
          'content_type': _contentType.toLowerCase(),
        }),
      );

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        
        if (responseJson['status'] == 'success') {
          setState(() {
            _translationResult = responseJson['data'];
          });
        } else {
          throw Exception('Translation failed: ${responseJson['message']}');
        }
      } else {
        throw Exception('Translation failed: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AI DICTIONARY',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language and Content Type Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Translation Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    // From Language
                    const Text('From Language', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _fromLang,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _languages.map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      )).toList(),
                      onChanged: (value) => setState(() => _fromLang = value!),
                    ),
                    const SizedBox(height: 16),
                    
                    // To Language
                    const Text('To Language', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _toLang,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _languages.map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      )).toList(),
                      onChanged: (value) => setState(() => _toLang = value!),
                    ),
                    const SizedBox(height: 16),
                    
                    // Content Type
                    const Text('Content Type', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _contentType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _contentTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        _contentType = value!;
                        _tags.clear();
                        _textController.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Text Input Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _contentType == 'Word' ? 'Add Words (Press Enter)' : 'Enter Sentence',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_contentType == 'Word')
                      Wrap(
                        spacing: 8,
                        children: _tags.map((tag) => Chip(
                          label: Text(tag),
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        )).toList(),
                      ),

                    TextField(
                      controller: _textController,
                      maxLength: _contentType == 'Sentence' ? 50 : null,
                      onSubmitted: _contentType == 'Word' ? _addTag : null,
                      decoration: InputDecoration(
                        hintText: _contentType == 'Word' ? 'Type a word and press Enter...' : 'Enter a sentence...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        suffixIcon: _contentType == 'Word'
                            ? IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _addTag(_textController.text),
                              )
                            : null,
                      ),
                      maxLines: _contentType == 'Word' ? 1 : 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _translateWithAI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Translate with AI', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Translation Results
            if (_translationResult != null) ...[
              const SizedBox(height: 20),
              _buildTranslationResults(),
            ],
            
            // History Section (Optional - can be added later)
            if (false) ...[
              const SizedBox(height: 20),
              const Text(
                'Recent Translations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              // Future: Add translation history here
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationResults() {
    if (_translationResult == null) return const SizedBox.shrink();
    
    final result = _translationResult!;
    print('🔍 Translation Result Data: ${result.toString()}'); // Debug log
    
    // Build the children list dynamically
    List<Widget> children = [
      // Original Text
      _buildResultCard('📝 Original Text', result['original_text'] ?? 'N/A'),
      
      // Translation
      _buildResultCard('🔄 Translation', result['translation'] ?? 'N/A'),
    ];
    
    // Pronunciation in original language
    if (result['pronunciation_from'] != null) {
      children.add(_buildResultCard('🔊 Pronunciation ($_fromLang)', result['pronunciation_from']));
    }
    
    // Pronunciation in target language
    if (result['pronunciation_to'] != null) {
      children.add(_buildResultCard('🔊 Pronunciation ($_toLang)', result['pronunciation_to']));
    }
    
    // Word Type (for words)
    if (_contentType == 'Word' && result['word_type'] != null) {
      children.add(_buildResultCard('📚 Word Type', result['word_type']));
    }
    
    // Grammar Info - Handle complex grammar object
    if (result['grammar'] != null) {
      children.add(_buildGrammarSection(result['grammar']));
    }
    
    // Meanings in both languages
    if (result['meaning_from'] != null) {
      children.add(_buildResultCard('📖 Meaning ($_fromLang)', result['meaning_from']));
    }
    
    if (result['meaning_to'] != null) {
      children.add(_buildResultCard('📖 Meaning ($_toLang)', result['meaning_to']));
    }
    
    // Synonyms and Antonyms (for words)
    if (_contentType == 'Word') {
      if (result['synonyms'] != null) {
        children.add(_buildListResultCard('🔗 Synonyms', List<String>.from(result['synonyms'])));
      }
      
      if (result['antonyms'] != null) {
        children.add(_buildListResultCard('⚡ Antonyms', List<String>.from(result['antonyms'])));
      }
    }
    
    // Examples
    if (result['examples'] != null) {
      children.add(_buildListResultCard('💡 Examples', List<String>.from(result['examples'])));
    }
    
    return ExpansionTile(
      title: const Text(
        '📖 Translation Results (Tap to Expand)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5)),
      ),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.all(16),
      childrenPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.blue[50],
      collapsedBackgroundColor: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      children: children,
    );
  }

  Widget _buildResultCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListResultCard(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF4F46E5))),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildGrammarSection(dynamic grammar) {
    if (grammar is! Map) {
      return _buildResultCard('📋 Grammar Analysis', grammar.toString());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Grammar Analysis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 8),
            if (grammar['original_sentence'] != null)
              _buildGrammarItem('Original Sentence', grammar['original_sentence']),
            if (grammar['urdu_translation'] != null)
              _buildGrammarItem('Urdu Translation', grammar['urdu_translation']),
            if (grammar['structure'] != null)
              _buildGrammarItem('Structure', grammar['structure']),
            if (grammar['components'] != null && grammar['components'] is List)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text('Components:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ...List<Map<String, dynamic>>.from(grammar['components']).map((component) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      '• ${component['word']} (${component['part_of_speech']})',
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrammarItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
