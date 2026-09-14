import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../../../core/storage.dart';

class ScanQuizPaper extends StatefulWidget {
  const ScanQuizPaper({super.key});

  @override
  State<ScanQuizPaper> createState() => _ScanQuizPaperState();
}

class _ScanQuizPaperState extends State<ScanQuizPaper> {
  final Color primaryColor = const Color(0xFF1A237E);
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _errorMessage;
  Map<String, dynamic>? _generatedQuiz;
  final Set<int> _selectedQuestionIndices = {};
  String? _saveMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("SCAN QUIZ PAPER",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUploadCard(),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            if (_isProcessing) ...[
              const SizedBox(height: 30),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text("Analyzing document with AI...",
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    SizedBox(height: 5),
                    Text("Extracting content and generating quiz questions.",
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ],
            if (_generatedQuiz != null && !_isProcessing) ...[
              const SizedBox(height: 20),
              _buildQuizPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Icon(Icons.document_scanner_rounded, size: 60, color: primaryColor.withOpacity(0.3)),
          const SizedBox(height: 15),
          const Text("Upload Document or Image",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _fileName ?? "PDF, PNG, JPG, TXT supported. Max 20 MB.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickFile,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text("CHOOSE FILE",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: primaryColor),
                    foregroundColor: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (_fileBytes != null) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _scanWithAI,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(_isProcessing ? "PROCESSING..." : "SCAN WITH AI",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizPreview() {
    final info = _generatedQuiz!['paperInfo'] as Map? ?? {};
    final questions = _generatedQuiz!['questions'] as List? ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade400, size: 24),
                  const SizedBox(width: 10),
                  Text("Quiz Generated",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
                ],
              ),
              const SizedBox(height: 15),
              if (info['title'] != null)
                Text("Title: ${info['title']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 5),
              Text("${questions.length} questions generated — select to save to question bank",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 15),
              ...questions.asMap().entries.map((entry) {
                final i = entry.key;
                final q = entry.value as Map;
                final isSelected = _selectedQuestionIndices.contains(i);
                final type = q['type']?.toString().toLowerCase() ?? 'short';
                final options = q['options'] as List? ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedQuestionIndices.remove(i);
                      } else {
                        _selectedQuestionIndices.add(i);
                      }
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withOpacity(0.06) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                              color: isSelected ? primaryColor : Colors.grey,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(type).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(type.toUpperCase(),
                                          style: TextStyle(color: _getTypeColor(type), fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text("${q['marks'] ?? 1} marks",
                                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(q['questionText'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                if (options.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ...options.take(2).map((o) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text("• $o",
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  )),
                                  if (options.length > 2)
                                    Text("+${options.length - 2} more options",
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectedQuestionIndices.isNotEmpty && !_isSaving
                          ? _saveSelectedQuestions
                          : null,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                          _isSaving ? "SAVING..." : "SAVE SELECTED (${_selectedQuestionIndices.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: primaryColor),
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ScannedQuizPage(initialQuiz: _generatedQuiz!),
                        ));
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text("START QUIZ",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
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
        if (_saveMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_saveMessage!,
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt'],
      withData: true,
    );

    if (result != null && result.files.single.path != null) {
      PlatformFile file = result.files.single;

      if (file.size > 20 * 1024 * 1024) {
        setState(() => _errorMessage = "File is too large! Maximum limit is 20 MB.");
        return;
      }

      Uint8List bytes = await File(file.path!).readAsBytes();

      setState(() {
        _fileName = file.name;
        _fileBytes = bytes;
        _errorMessage = null;
        _generatedQuiz = null;
      });
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'mcq': return Colors.blue;
      case 'truefalse': return Colors.teal;
      case 'short': return Colors.orange;
      case 'long': return Colors.deepPurple;
      case 'fill': return Colors.cyan;
      default: return Colors.grey;
    }
  }

  Future<void> _saveSelectedQuestions() async {
    final questions = _generatedQuiz!['questions'] as List;
    final info = _generatedQuiz!['paperInfo'] as Map? ?? {};

    final selected = _selectedQuestionIndices.map((i) => questions[i]).toList();

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication required.")));
        setState(() => _isSaving = false);
        return;
      }

      final payload = {
        'questions': selected.map((q) => {
          'questionText': q['questionText'] ?? '',
          'type': q['type']?.toString().toLowerCase() ?? 'short',
          'marks': (q['marks'] as num?)?.toInt() ?? 1,
          'difficulty': q['difficulty']?.toString().toLowerCase() ?? 'medium',
          'topic': q['topic'] ?? '',
          'options': (q['options'] as List?)?.map((o) => o.toString()).toList() ?? [],
          'correct_answer': q['correct_answer'] ?? '',
          'subQuestions': (q['subQuestions'] as List?) ?? [],
        }).toList(),
        'subject': info['subject'] ?? '',
        'grade': info['grade'] ?? '',
        'paper_title': info['title'] ?? '',
      };

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/question-vault/save-questions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          setState(() {
            _isSaving = false;
            _saveMessage = result['message'] ?? "Questions saved successfully!";
            _selectedQuestionIndices.clear();
          });
        } else {
          throw Exception(result['message'] ?? "Save failed.");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e")),
        );
      }
    }
  }

  Future<void> _scanWithAI() async {
    if (_fileBytes == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _generatedQuiz = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Authentication required. Please login first.";
        });
        return;
      }

      String base64Image = base64Encode(_fileBytes!);
      final payload = {'imageData': base64Image, 'fileName': _fileName ?? 'image.jpg'};

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/scan-to-quiz/process'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          final data = Map<String, dynamic>.from(result['data'] as Map);
          final questions = data['questions'] as List? ?? [];
          final paperInfo = data['paperInfo'] as Map? ?? {};

          setState(() {
            _isProcessing = false;
            _generatedQuiz = {
              'paperInfo': paperInfo,
              'questions': questions,
            };
          });
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = result['message'] ?? "AI processing failed.";
          });
        }
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Server error: ${response.statusCode}";
        });
      }
    } on http.ClientException {
      setState(() {
        _isProcessing = false;
        _errorMessage = "Network error. Check your connection.";
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = "Error: $e";
      });
    }
  }
}

class ScannedQuizPage extends StatefulWidget {
  final Map<String, dynamic>? initialQuiz;
  const ScannedQuizPage({super.key, this.initialQuiz});

  @override
  State<ScannedQuizPage> createState() => _ScannedQuizPageState();
}

class _ScannedQuizPageState extends State<ScannedQuizPage> {
  final Color primaryColor = const Color(0xFF1A237E);
  int _currentIndex = 0;
  int _score = 0;
  bool _isCompleted = false;
  final Map<int, String> _selectedAnswers = {};

  late List<Map<String, dynamic>> _questions;
  String? _quizTitle;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuiz != null) {
      final rawQuestions = widget.initialQuiz!['questions'] as List? ?? [];
      _questions = rawQuestions.cast<Map<String, dynamic>>();
      final info = widget.initialQuiz!['paperInfo'] as Map? ?? {};
      _quizTitle = info['title']?.toString() ?? 'Scanned Quiz';
    } else {
      _questions = [];
      _quizTitle = 'Quiz';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_quizTitle ?? "QUIZ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: _questions.isEmpty
          ? _buildEmptyState()
          : _isCompleted
              ? _buildResultScreen()
              : _buildQuizScreen(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text("No questions loaded.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text("Go Back"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    final question = _questions[_currentIndex];
    final qType = question['type']?.toString().toLowerCase() ?? 'short';
    final options = question['options'] as List? ?? [];

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
              Text("Question ${_currentIndex + 1} of ${_questions.length}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text("Score: $_score",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(qType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(qType.toUpperCase(),
                            style: TextStyle(color: _getTypeColor(qType), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      if (question['marks'] != null) ...[
                        const SizedBox(width: 8),
                        Text("${question['marks']} marks",
                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(question['questionText'] ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  if (qType == 'mcq' || qType == 'truefalse' || options.isNotEmpty)
                    ...options.map((opt) => _buildOption(opt.toString()))
                  else
                    _buildTextAnswer(),
                ],
              ),
            ),
          ),
        ),
        Container(
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
                    onPressed: () => setState(() => _currentIndex--),
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
      ],
    );
  }

  Widget _buildOption(String option) {
    final isSelected = _selectedAnswers[_currentIndex] == option;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedAnswers[_currentIndex] = option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? primaryColor : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(option, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextAnswer() {
    final controller = TextEditingController(
      text: _selectedAnswers[_currentIndex] ?? '',
    );
    return TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: "Type your answer...",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
      onChanged: (v) => _selectedAnswers[_currentIndex] = v,
    );
  }

  void _goNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final answer = _selectedAnswers[i];
      final question = _questions[i];
      if (answer != null && answer.isNotEmpty) {
        score += (question['marks'] as num?)?.toInt() ?? 1;
      }
    }
    setState(() {
      _score = score;
      _isCompleted = true;
    });
  }

  Widget _buildResultScreen() {
    final total = _questions.fold<int>(0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 1));
    final percentage = total > 0 ? (_score / total * 100).toStringAsFixed(1) : "0";
    final grade = double.parse(percentage) >= 80
        ? "A"
        : double.parse(percentage) >= 60
            ? "B"
            : double.parse(percentage) >= 40
                ? "C"
                : "F";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              double.parse(percentage) >= 40 ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 80,
              color: double.parse(percentage) >= 40 ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text("Quiz Complete!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)],
              ),
              child: Column(
                children: [
                  Text("Grade: $grade",
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 15),
                  Text("$_score / $total",
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
                  const SizedBox(height: 5),
                  Text("$percentage%",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  const SizedBox(height: 5),
                  Text("${_questions.length} Questions",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'mcq': return Colors.blue;
      case 'truefalse': return Colors.teal;
      case 'short': return Colors.orange;
      case 'long': return Colors.deepPurple;
      case 'fill': return Colors.cyan;
      default: return Colors.grey;
    }
  }
}
