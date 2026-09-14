import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_file/open_file.dart';
import '../../../widgets/pdf_viewer_screen.dart'; // Add this import
import '../../../universal_keyboard/universal_keyboard.dart';

class AdvancedNotesScreen extends StatefulWidget {
  const AdvancedNotesScreen({super.key});

  @override
  State<AdvancedNotesScreen> createState() => _AdvancedNotesScreenState();
}

class _AdvancedNotesScreenState extends State<AdvancedNotesScreen> {
  // 🏛️ Page-based Document State
  final List<TextEditingController> _pageControllers = [TextEditingController()];
  int _currentPage = 0;
  final int _linesPerPage = 30;

  // 🏛️ Services
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // 🏛️ State
  bool _isListening = false;
  String _currentLang = 'en-US';
  String _speechStatus = 'idle'; // idle, listening, processing, error
  bool _showCustomKeyboard = true;

  // 🏛️ Reserved Symbols Architect
  final Map<String, Map<String, dynamic>> _customSymbols = {
    "comma": {"symbol": ",", "enabled": true},
    "period": {"symbol": ".", "enabled": true},
    "new line": {"symbol": "\n", "enabled": true},
    "slash": {"symbol": "/", "enabled": true},
    "question mark": {"symbol": "?", "enabled": true},
  };

  TextEditingController get _consoleController => _pageControllers[_currentPage];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    UniversalKeyboardManager().registerController(_consoleController);
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) {
        setState(() {
          _isListening = false;
          _speechStatus = 'error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Speech recognition error: $error"), backgroundColor: Colors.red),
        );
      },
      onStatus: (status) {
        setState(() {
          switch (status) {
            case 'listening':
              _speechStatus = 'listening';
              break;
            case 'notListening':
              _speechStatus = 'idle';
              _isListening = false;
              break;
            case 'done':
              _speechStatus = 'idle';
              _isListening = false;
              break;
            case 'unavailable':
              _speechStatus = 'error';
              _isListening = false;
              break;
            default:
              _speechStatus = 'processing';
          }
        });
      },
    );
    
    if (!available) {
      setState(() => _speechStatus = 'error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Speech recognition not available"), backgroundColor: Colors.red),
      );
    }
    
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  // 🏛️ Symbol Translation Engine (Logic from processTranscript in TSX)
  String _processText(String text) {
    if (text.isEmpty) return text;
    
    String processed = text.toLowerCase().trim();

    // Replace words with symbols (only enabled ones)
    _customSymbols.forEach((word, symbolData) {
      if (symbolData['enabled'] == true) {
        // Use word boundaries to avoid partial matches
        processed = processed.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b'), symbolData['symbol']);
      }
    });

    // 🏛️ Smart Capitalization Logic
    final currentText = _consoleController.text;
    final cursorPosition = _consoleController.selection.baseOffset;
    final textBeforeCursor = currentText.substring(0, cursorPosition);
    
    // Capitalize if at start of text or after sentence-ending punctuation
    if (textBeforeCursor.isEmpty ||
        textBeforeCursor.trim().endsWith('.') ||
        textBeforeCursor.trim().endsWith('!') ||
        textBeforeCursor.trim().endsWith('?') ||
        textBeforeCursor.trim().endsWith('\n')) {
      processed = processed.isNotEmpty
          ? processed[0].toUpperCase() + processed.substring(1)
          : processed;
    }

    // Add space if needed (except for certain symbols)
    if (processed.isNotEmpty && 
        !['.', ',', '!', '?', '\n', ':', ';'].contains(processed[processed.length - 1])) {
      processed += ' ';
    }

    return processed;
  }

  // Debug method to test reserved words processing
  void _testReservedWords() {
    final testText = "this is a test comma period new line and question mark";
    final processed = _processText(testText);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Test: '$testText' → '$processed'"),
        backgroundColor: const Color(0xFFD4AF37),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _toggleMic() async {
    if (_isListening) {
      setState(() {
        _speechStatus = 'processing';
      });
      _speech.stop();
      setState(() {
        _isListening = false;
        _speechStatus = 'idle';
      });
    } else {
      setState(() => _speechStatus = 'processing');
      
      // Check if speech is already initialized
      bool available = await _speech.initialize(
        onError: (error) {
          setState(() {
            _isListening = false;
            _speechStatus = 'error';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Speech recognition error: $error"), backgroundColor: Colors.red),
          );
        },
        onStatus: (status) {
          setState(() {
            switch (status) {
              case 'listening':
                _speechStatus = 'listening';
                break;
              case 'notListening':
                _speechStatus = 'idle';
                _isListening = false;
                break;
              case 'done':
                _speechStatus = 'idle';
                _isListening = false;
                break;
              case 'unavailable':
                _speechStatus = 'error';
                _isListening = false;
                break;
              default:
                _speechStatus = 'processing';
            }
          });
        },
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _speechStatus = 'listening';
        });
        
        _speech.listen(
          localeId: _currentLang,
          onResult: (val) {
            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              setState(() => _speechStatus = 'processing');
              final processed = _processText(val.recognizedWords);
              setState(() {
                // Get current cursor position
                final cursorPosition = _consoleController.selection.baseOffset;
                final currentText = _consoleController.text;
                
                // Ensure cursor position is valid
                final validCursorPosition = cursorPosition < 0 ? 0 : cursorPosition;
                final validCursorPosition2 = validCursorPosition > currentText.length ? currentText.length : validCursorPosition;
                
                // Insert processed text at cursor position
                final newText = currentText.substring(0, validCursorPosition2) + 
                               processed + 
                               currentText.substring(validCursorPosition2);
                
                _consoleController.text = newText;
                
                // Set cursor position after inserted text
                final newCursorPosition = validCursorPosition2 + processed.length;
                _consoleController.selection = TextSelection.fromPosition(
                  TextPosition(offset: newCursorPosition),
                );
                
                _speechStatus = 'listening';
              });
              // Check pagination after speech insertion
              _onPageTextChanged();
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: true,
        );
      } else {
        setState(() => _speechStatus = 'error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Speech recognition not available"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080A), // Architect Dark Theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1C),
        title: const Text('DOCUMENT COMPOSER',
            style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _showCustomKeyboard ? Icons.keyboard_hide : Icons.keyboard,
              color: _showCustomKeyboard ? const Color(0xFFD4AF37) : const Color(0xFF666666),
            ),
            onPressed: () => setState(() => _showCustomKeyboard = !_showCustomKeyboard),
            tooltip: _showCustomKeyboard ? 'Hide Keyboard' : 'Show Keyboard',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Color(0xFF666666)),
            onPressed: () => _testReservedWords(),
            tooltip: 'Test Reserved Words',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF666666)),
            onPressed: () => _showSymbolSettings(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLanguageBar(),
          Expanded(child: _buildArchitectConsole()),
          _buildControls(),
          if (_showCustomKeyboard) const UniversalKeyboardUI(),
        ],
      ),
    );
  }

  Widget _buildLanguageBar() {
    final langs = ['en-US', 'ur-PK', 'ar-SA'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: langs.map((lang) {
          bool isActive = _currentLang == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentLang = lang),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
                  border: Border.all(color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF1A1A1C)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(lang.split('-')[0].toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF666666))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onPageTextChanged() {
    final text = _consoleController.text;
    final lines = '\n'.allMatches(text).length + 1;
    if (lines > _linesPerPage) {
      // Find the split point at the _linesPerPage-th newline
      int splitIndex = 0;
      int count = 0;
      for (int i = 0; i < text.length; i++) {
        if (text[i] == '\n') {
          count++;
          if (count == _linesPerPage) {
            splitIndex = i + 1;
            break;
          }
        }
      }

      final keep = text.substring(0, splitIndex);
      final overflow = text.substring(splitIndex);

      setState(() {
        _pageControllers[_currentPage].text = keep;

        if (_currentPage + 1 < _pageControllers.length) {
          _pageControllers[_currentPage + 1].text =
              overflow + _pageControllers[_currentPage + 1].text;
          _currentPage++;
        } else {
          final nextCtrl = TextEditingController(text: overflow);
          _pageControllers.add(nextCtrl);
          _currentPage++;
        }
      });
    }
  }

  Widget _buildArchitectConsole() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomKeyboard = true;
        });
        UniversalKeyboardManager().registerController(_consoleController);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121214),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1A1A1C)),
        ),
        child: TextField(
          controller: _consoleController,
          maxLines: null,
          readOnly: true,
          showCursor: true,
          cursorColor: const Color(0xFFD4AF37),
          cursorWidth: 2.0,
          cursorRadius: const Radius.circular(1),
          onChanged: (_) => _onPageTextChanged(),
          style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'Start typing or speaking...',
            hintStyle: TextStyle(color: Color(0xFF333333)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFFD4AF37)),
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                        UniversalKeyboardManager().registerController(_consoleController);
                      }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Page ${_currentPage + 1} / ${_pageControllers.length}",
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                onPressed: _currentPage < _pageControllers.length - 1
                    ? () {
                        setState(() => _currentPage++);
                        UniversalKeyboardManager().registerController(_consoleController);
                      }
                    : null,
              ),
              const SizedBox(width: 20),
              // Line counter
              Text(
                "${'\n'.allMatches(_consoleController.text).length + 1} / $_linesPerPage lines",
                style: const TextStyle(color: Color(0xFF666666), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _circleBtn(Icons.delete_outline, _clearAllPages),
              _buildAnimatedMicButton(),
              _circleBtn(Icons.add_circle_outline, _addPage),
              _circleBtn(Icons.save_outlined, _saveDocument),
            ],
          ),
        ],
      ),
    );
  }

  void _addPage() {
    setState(() {
      _pageControllers.add(TextEditingController());
      _currentPage = _pageControllers.length - 1;
      UniversalKeyboardManager().registerController(_consoleController);
    });
  }

  void _clearAllPages() {
    setState(() {
      for (var ctrl in _pageControllers) {
        ctrl.dispose();
      }
      _pageControllers
        ..clear()
        ..add(TextEditingController());
      _currentPage = 0;
      UniversalKeyboardManager().registerController(_consoleController);
    });
  }

  Widget _buildAnimatedMicButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggleMic,
          child: _buildMicButtonForState(),
        ),
        const SizedBox(height: 8),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildMicButtonForState() {
    switch (_speechStatus) {
      case 'listening':
        return _buildListeningAnimation();
      case 'processing':
        return _buildProcessingAnimation();
      case 'error':
        return _buildErrorAnimation();
      default:
        return _buildIdleMicButton();
    }
  }

  Widget _buildStatusIndicator() {
    String statusText;
    Color statusColor;
    
    switch (_speechStatus) {
      case 'listening':
        statusText = 'Listening...';
        statusColor = Colors.redAccent;
        break;
      case 'processing':
        statusText = 'Processing...';
        statusColor = Colors.orange;
        break;
      case 'error':
        statusText = 'Error';
        statusColor = Colors.red;
        break;
      default:
        statusText = 'Tap to speak';
        statusColor = const Color(0xFF666666);
    }
    
    return Text(
      statusText,
      style: TextStyle(
        color: statusColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ).animate()
      .fadeIn(duration: 200.ms)
      .slideY(begin: 0.1, end: 0, duration: 200.ms);
  }

  Widget _buildIdleMicButton() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.mic, size: 35, color: Colors.black),
    ).animate()
      .scale(duration: 200.ms, begin: const Offset(1.0, 1.0), end: const Offset(0.95, 0.95))
      .then()
      .scale(duration: 200.ms, begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0));
  }

  Widget _buildListeningAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing rings
        ...List.generate(3, (index) => 
          Container(
            width: 80.0 + (index * 20.0),
            height: 80.0 + (index * 20.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3 - (index * 0.1)),
                width: 2,
              ),
            ),
          ).animate(
            key: ValueKey('pulse_$index'),
          )
          .scale(
            duration: 1500.ms,
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.2, 1.2),
            curve: Curves.easeInOut,
          )
          .fadeIn(duration: 300.ms)
          .then()
          .fadeOut(duration: 300.ms)
          .then(delay: 900.ms)
          .animate(),
        ),
        
        // Main microphone button
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(Icons.mic, size: 35, color: Colors.white),
        ).animate()
          .scale(
            duration: 800.ms,
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.1, 1.1),
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            duration: 800.ms,
            begin: const Offset(1.1, 1.1),
            end: const Offset(1.0, 1.0),
            curve: Curves.easeInOut,
          )
          .animate(),
        
        // Sound waves animation
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildSoundWave(0),
                _buildSoundWave(1),
                _buildSoundWave(2),
                _buildSoundWave(3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSoundWave(int index) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(2),
      ),
    ).animate(
      key: ValueKey('wave_$index'),
    )
    .scale(
      duration: 600.ms,
      begin: const Offset(1.0, 0.2),
      end: const Offset(1.0, 1.0),
      curve: Curves.easeInOut,
    )
    .then(delay: (index * 100).ms)
    .scale(
      duration: 600.ms,
      begin: const Offset(1.0, 1.0),
      end: const Offset(1.0, 0.2),
      curve: Curves.easeInOut,
    )
    .animate();
  }

  Widget _buildProcessingAnimation() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.hourglass_empty, size: 35, color: Colors.white),
    ).animate()
      .rotate(duration: 1000.ms, begin: 0, end: 2 * 3.14159, curve: Curves.linear)
      .animate();
  }

  Widget _buildErrorAnimation() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.error_outline, size: 35, color: Colors.white),
    ).animate()
      .scale(duration: 300.ms, begin: const Offset(1.0, 1.0), end: const Offset(0.9, 0.9))
      .then()
      .scale(duration: 300.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0))
      .then(delay: 400.ms)
      .animate();
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF666666), size: 28),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A1C),
        padding: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showSymbolSettings() {
    final TextEditingController wordController = TextEditingController();
    final TextEditingController symbolController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121214),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("RESERVED SYMBOLS ARCHITECT",
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 20),
              
              // Add new symbol section
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add New Symbol", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wordController,
                            decoration: const InputDecoration(
                              hintText: "Word (e.g., 'comma')",
                              hintStyle: TextStyle(color: Color(0xFF666666)),
                              border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: symbolController,
                            decoration: const InputDecoration(
                              hintText: "Symbol (e.g., ',')",
                              hintStyle: TextStyle(color: Color(0xFF666666)),
                              border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () {
                            if (wordController.text.trim().isNotEmpty && 
                                symbolController.text.trim().isNotEmpty) {
                              setState(() {
                                _customSymbols[wordController.text.trim()] = {
                                  "symbol": symbolController.text.trim(),
                                  "enabled": true
                                };
                              });
                              setModalState(() {});
                              wordController.clear();
                              symbolController.clear();
                            }
                          },
                          icon: const Icon(Icons.add, color: Color(0xFFD4AF37)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Existing symbols list
              const Text("Existing Symbols", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _customSymbols.length,
                  itemBuilder: (context, index) {
                    final entry = _customSymbols.entries.elementAt(index);
                    final word = entry.key;
                    final symbolData = entry.value;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Enable/Disable toggle
                          Switch(
                            value: symbolData['enabled'] ?? true,
                            onChanged: (value) {
                              setState(() {
                                _customSymbols[word]!['enabled'] = value;
                              });
                              setModalState(() {});
                            },
                            activeColor: const Color(0xFFD4AF37),
                          ),
                          
                          // Word and symbol display
                          Expanded(
                            child: Text(
                              "$word → ${symbolData['symbol']}",
                              style: TextStyle(
                                color: symbolData['enabled'] == true 
                                    ? Colors.white 
                                    : const Color(0xFF666666),
                                decoration: symbolData['enabled'] == false 
                                    ? TextDecoration.lineThrough 
                                    : null,
                              ),
                            ),
                          ),
                          
                          // Delete button
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _customSymbols.remove(word);
                              });
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDocument() async {
    final fullText = _pageControllers.map((c) => c.text).join('\n').trim();
    if (fullText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nothing to save — document is empty"), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final bytes = await _buildPdfBytes(fullText);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Document_$timestamp.pdf";
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(filePath: filePath, title: "Document"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showExportOptions(String fullText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121214),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "EXPORT DOCUMENT",
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD4AF37)),
                title: const Text("Download PDF", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Save PDF on this phone", style: TextStyle(color: Color(0xFF999999))),
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadPdf(fullText);
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Color(0xFFD4AF37)),
                title: const Text("Print PDF", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Open device print dialog", style: TextStyle(color: Color(0xFF999999))),
                onTap: () async {
                  Navigator.pop(context);
                  await _printPdf(fullText);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes(String content) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStamp =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            "Starlight Document",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text("Generated: $dateStamp", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text(content, style: const pw.TextStyle(fontSize: 12, lineSpacing: 3)),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _downloadPdf(String content) async {
    try {
      final bytes = await _buildPdfBytes(content);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Document_$timestamp.pdf";
      final filePath = "${dir.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF saved: $fileName"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "SHARE",
            textColor: Colors.white,
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: "Starlight PDF Document"),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF save failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _printPdf(String content) async {
    try {
      final bytes = await _buildPdfBytes(content);
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Print failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    UniversalKeyboardManager().unregisterController(_consoleController);
    for (var ctrl in _pageControllers) {
      ctrl.dispose();
    }
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
