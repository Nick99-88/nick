import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';

class ContextualQuizScreen extends StatefulWidget {
  const ContextualQuizScreen({super.key});

  @override
  State<ContextualQuizScreen> createState() => _ContextualQuizScreenState();
}

class _ContextualQuizScreenState extends State<ContextualQuizScreen> {
  final _picker = ImagePicker();
  final _apiBase = StarlightConstants.apiBaseUrl;
  final Color primaryColor = const Color(0xFF1A237E);

  String _difficulty = 'medium';
  int _questionCount = 5;
  File? _selectedFile;
  bool _isProcessing = false;
  String? _errorMessage;

  bool _quizStarted = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  final Map<int, bool> _answerRevealed = {};
  int _correctCount = 0;
  bool _isCompleted = false;

  final _difficulties = [
    {'key': 'easy', 'label': 'Easy', 'icon': Icons.sentiment_satisfied_alt, 'color': Colors.green},
    {'key': 'medium', 'label': 'Medium', 'icon': Icons.sentiment_neutral, 'color': Colors.orange},
    {'key': 'hard', 'label': 'Hard', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.red},
  ];

  static const int _maxFileSize = 10 * 1024 * 1024;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      if (bytes.length > _maxFileSize) {
        _showSizeError();
        return;
      }
      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/${result.files.single.name}';
      final file = File(tempPath);
      await file.writeAsBytes(bytes);
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final size = await file.length();
      if (size > _maxFileSize) {
        _showSizeError();
        return;
      }
      setState(() => _selectedFile = file);
    }
  }

  void _showSizeError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("File too large. Maximum size is 10 MB."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateQuiz() async {
    if (_selectedFile == null) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = _selectedFile!.path.toLowerCase().split('.').last;
      final mimeType = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';
      final token = await StarlightStorage.getUserToken();

      final response = await http.post(
        Uri.parse('$_apiBase/document-translator/generate-contextual-quiz'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'imageData': base64Image,
          'mimeType': mimeType,
          'difficulty': _difficulty,
          'count': _questionCount,
        }),
      ).timeout(const Duration(seconds: 120));

      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        final data = result['data'] as List? ?? [];
        if (data.isEmpty) {
          _errorMessage = 'No questions were generated. Try a different image.';
        } else {
          setState(() {
            _questions = data.cast<Map<String, dynamic>>();
            _quizStarted = true;
          });
        }
      } else {
        _errorMessage = result['message'] ?? 'Failed to generate quiz';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _selectOption(String option) {
    if (_answerRevealed[_currentIndex] == true) return;
    final letter = option.isNotEmpty ? option[0] : '';
    setState(() {
      _userAnswers[_currentIndex] = letter;
      _answerRevealed[_currentIndex] = true;
      final correct = _questions[_currentIndex]['correctAnswer']?.toString() ?? '';
      if (letter == correct) _correctCount++;
    });
  }

  void _goNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _isCompleted = true);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _reset() {
    setState(() {
      _quizStarted = false;
      _questions = [];
      _currentIndex = 0;
      _userAnswers.clear();
      _answerRevealed.clear();
      _correctCount = 0;
      _isCompleted = false;
      _selectedFile = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          _isCompleted ? 'Results' : _quizStarted ? 'Contextual Quiz' : 'Contextual Quiz',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: _isCompleted
          ? _buildResultScreen()
          : _quizStarted
              ? _buildQuizView()
              : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contextual Quiz', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Upload a document or image. AI will generate quiz questions based on the content.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(height: 4),
                Text('PDF, JPG, PNG · up to 10 MB',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 12))),
                  GestureDetector(onTap: () => setState(() => _errorMessage = null), child: const Icon(Icons.close, size: 16)),
                ],
              ),
            ),
          const Text('DIFFICULTY LEVEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: _difficulties.map((d) {
              final selected = _difficulty == d['key'];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: d['key'] == 'easy' ? 0 : 6, right: d['key'] == 'hard' ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = d['key'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selected ? d['color'] as Color : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? d['color'] as Color : Colors.grey.shade300, width: selected ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Icon(d['icon'] as IconData, color: selected ? Colors.white : d['color'] as Color, size: 24),
                          const SizedBox(height: 6),
                          Text(d['label'] as String,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('NUMBER OF QUESTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [3, 5, 10].map((n) {
              final selected = _questionCount == n;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _questionCount = n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? primaryColor : Colors.grey.shade300),
                      ),
                      child: Text('$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('UPLOAD DOCUMENT / IMAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          if (_selectedFile == null)
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 40, color: primaryColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('Tap to select a file', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('PDF, JPG, PNG · up to 10 MB', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.image_outlined, color: primaryColor),
                          onPressed: _pickImage,
                          tooltip: 'Pick from gallery',
                        ),
                        const Text('|', style: TextStyle(color: Colors.grey)),
                        TextButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('Browse'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.insert_drive_file, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_selectedFile!.path.split('\\').last.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedFile = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.close, color: Colors.red.shade400, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing || _selectedFile == null ? null : _generateQuiz,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high_rounded, size: 20),
              label: Text(_isProcessing ? 'GENERATING...' : 'GENERATE QUIZ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: primaryColor.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'No questions loaded.', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _reset, child: const Text('Try Again')),
          ],
        ),
      );
    }

    final question = _questions[_currentIndex];
    final qText = question['question']?.toString() ?? '';
    final options = (question['options'] as List?)?.cast<String>() ?? [];
    final correctAnswer = question['correctAnswer']?.toString() ?? '';
    final explanation = question['explanation']?.toString() ?? '';
    final userAnswer = _userAnswers[_currentIndex];
    final revealed = _answerRevealed[_currentIndex] == true;
    final isCorrect = revealed && userAnswer == correctAnswer;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey.shade200,
          color: primaryColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentIndex + 1} of ${_questions.length}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text('$_correctCount / ${_userAnswers.length} correct',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade600)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _difficulty.toUpperCase(),
                              style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('MCQ', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(qText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
                      const SizedBox(height: 20),
                      ...options.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final opt = entry.value;
                        final optLetter = opt.isNotEmpty ? opt[0].toUpperCase() : '';
                        final isUserAnswer = userAnswer == optLetter;
                        final isCorrectAnswer = correctAnswer == optLetter;

                        Color bgColor = Colors.grey.shade50;
                        Color borderColor = Colors.grey.shade200;
                        Color textColor = Colors.black87;
                        IconData? trailingIcon;

                        if (revealed) {
                          if (isCorrectAnswer) {
                            bgColor = Colors.green.shade50;
                            borderColor = Colors.green;
                            textColor = Colors.green.shade800;
                            trailingIcon = Icons.check_circle;
                          } else if (isUserAnswer && !isCorrectAnswer) {
                            bgColor = Colors.red.shade50;
                            borderColor = Colors.red;
                            textColor = Colors.red.shade800;
                            trailingIcon = Icons.cancel;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => _selectOption(optLetter),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor, width: revealed && (isCorrectAnswer || isUserAnswer) ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: revealed && isCorrectAnswer
                                          ? Colors.green
                                          : revealed && isUserAnswer && !isCorrectAnswer
                                              ? Colors.red
                                              : primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(optLetter,
                                          style: TextStyle(
                                            color: revealed && (isCorrectAnswer || (isUserAnswer && !isCorrectAnswer)) ? Colors.white : primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt.length > 2 ? opt.substring(2).trim() : opt,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                                    ),
                                  ),
                                  if (trailingIcon != null)
                                    Icon(trailingIcon, color: isCorrectAnswer ? Colors.green : Colors.red, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (revealed && explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCorrect ? Colors.green.shade200 : Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.emoji_events : Icons.lightbulb_outline,
                              color: isCorrect ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct!' : 'Incorrect',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCorrect ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        if (!isCorrect) ...[
                          const SizedBox(height: 8),
                          Text(
                            'The correct answer is $correctAnswer.',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green.shade800),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          explanation,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goPrev,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text("PREV", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _goNext,
                    icon: Icon(_currentIndex == _questions.length - 1 ? Icons.check : Icons.arrow_forward, size: 16),
                    label: Text(_currentIndex == _questions.length - 1 ? "FINISH" : "NEXT",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    final total = _questions.length;
    final pct = total > 0 ? (_correctCount / total * 100) : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pct >= 60 ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 80,
              color: pct >= 60 ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text("Quiz Complete!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 8),
            Text('Difficulty: ${_difficulty.toUpperCase()}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '$_correctCount / $total',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total Questions',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text("TRY AGAIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.home_rounded, size: 18),
                    label: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
