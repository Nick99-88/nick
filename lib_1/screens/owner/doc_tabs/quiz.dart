import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import 'contextual_quiz_screen.dart';

class QuizPage extends StatefulWidget {
  final Map<String, dynamic>? initialQuiz;
  const QuizPage({super.key, this.initialQuiz});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final Color primaryColor = const Color(0xFF1A237E);

  // Setup state
  bool _isLoadingTopics = true;
  List<String> _availableTopics = [];
  String? _selectedTopic;
  final TextEditingController _countController = TextEditingController(text: '10');
  bool _isGenerating = false;

  // Quiz state
  late List<Map<String, dynamic>> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _isCompleted = false;
  bool _quizStarted = false;
  final Map<int, String> _selectedAnswers = {};
  String? _quizTitle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (widget.initialQuiz != null) {
      final rawQuestions = widget.initialQuiz!['questions'] as List? ?? [];
      _questions = rawQuestions.cast<Map<String, dynamic>>();
      final info = widget.initialQuiz!['paperInfo'] as Map? ?? {};
      _quizTitle = info['title']?.toString() ?? 'Scanned Quiz';
      _quizStarted = _questions.isNotEmpty;
    } else {
      _questions = [];
      _loadTopics();
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        setState(() {
          _isLoadingTopics = false;
          _errorMessage = "Authentication required.";
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/question-vault/topics'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final topics = List<String>.from(data['topics'] ?? []);
        setState(() {
          _availableTopics = topics;
          _isLoadingTopics = false;
        });
      } else {
        setState(() {
          _availableTopics = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies', 'Islamiat', 'Computer Science', 'General Knowledge'];
          _isLoadingTopics = false;
        });
      }
    } catch (_) {
      setState(() {
        _availableTopics = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'Urdu', 'Pakistan Studies', 'Islamiat', 'Computer Science', 'General Knowledge'];
        _isLoadingTopics = false;
      });
    }
  }

  Future<void> _generateQuiz() async {
    if (_selectedTopic == null) {
      _showMessage("Please select a topic");
      return;
    }

    final count = int.tryParse(_countController.text) ?? 10;
    if (count < 1 || count > 50) {
      _showMessage("Question count must be between 1 and 50");
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        _showMessage("Authentication required.");
        setState(() => _isGenerating = false);
        return;
      }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/question-vault/generate-quiz'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topic': _selectedTopic,
          'count': count,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);

        if (questions.isEmpty) {
          _showMessage("No questions available for this topic.");
          setState(() => _isGenerating = false);
          return;
        }

        setState(() {
          _questions = questions;
          _quizTitle = _selectedTopic;
          _quizStarted = true;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _isGenerating = false;
          _errorMessage = "Failed to load quiz: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = "Error: $e";
      });
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_quizStarted ? _quizTitle ?? "QUIZ" : "QUIZ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: _quizStarted ? _buildQuizView() : _buildSetupView(),
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
                Text("Quiz Setup",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("Select a topic and number of questions to begin.",
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              child: Text(_errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          const Text("SELECT TOPIC",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _isLoadingTopics
              ? const Center(child: CircularProgressIndicator())
              : _buildTopicGrid(),
          const SizedBox(height: 24),
          const Text("NUMBER OF QUESTIONS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: "e.g. 10",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text("max 50", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContextualQuizScreen())),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
              label: const Text('CONTEXTUAL QUIZ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: const Color(0xFF1A237E),
                side: const BorderSide(color: Color(0xFF1A237E), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateQuiz,
              icon: _isGenerating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(_isGenerating ? "GENERATING..." : "CONTINUE",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: primaryColor.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableTopics.map((topic) {
        final isSelected = _selectedTopic == topic;
        return InkWell(
          onTap: () => setState(() => _selectedTopic = topic),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              topic,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── QUIZ VIEW ───

  Widget _buildQuizView() {
    if (_questions.isEmpty) {
      return const Center(child: Text("No questions loaded."));
    }
    return _isCompleted ? _buildResultScreen() : _buildQuizScreen();
  }

  Widget _buildQuizScreen() {
    final question = _questions[_currentIndex];
    final qType = question['type']?.toString().toLowerCase() ?? question['question_type']?.toString().toLowerCase() ?? 'short';
    final options = question['options'] as List? ?? [];
    final qText = question['questionText']?.toString() ?? question['question_text']?.toString() ?? '';

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
                  Text(qText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  if (options.isNotEmpty)
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
    final controller = TextEditingController(text: _selectedAnswers[_currentIndex] ?? '');
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
      if (answer != null && answer.isNotEmpty) {
        score += (_questions[i]['marks'] as num?)?.toInt() ?? 1;
      }
    }
    setState(() {
      _score = score;
      _isCompleted = true;
    });
  }

  Widget _buildResultScreen() {
    final total = _questions.fold<int>(0, (sum, q) => sum + ((q['marks'] as num?)?.toInt() ?? 1));
    final pct = total > 0 ? (_score / total * 100) : 0.0;
    final grade = pct >= 80 ? "A" : pct >= 60 ? "B" : pct >= 40 ? "C" : "F";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pct >= 40 ? Icons.emoji_events_rounded : Icons.replay_rounded,
              size: 80,
              color: pct >= 40 ? Colors.amber : Colors.grey,
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
              ),
              child: Column(
                children: [
                  Text("Grade: $grade",
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 15),
                  Text("$_score / $total",
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
                  const SizedBox(height: 5),
                  Text("${pct.toStringAsFixed(1)}%",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
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
