import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/storage.dart';

// --- DATA MODEL ---
class Question {
  final String id;
  final String text;
  final String type; // 'MCQ', 'Short', 'Long'
  final int marks;
  final String rating; // Difficulty
  final List<String>? options;
  bool isSelected;

  Question({
    required this.id,
    required this.text,
    required this.type,
    required this.marks,
    required this.rating,
    this.options,
    this.isSelected = false,
  });
}

class QuestionVaultGenerator extends StatefulWidget {
  const QuestionVaultGenerator({super.key});

  @override
  State<QuestionVaultGenerator> createState() => _QuestionVaultGeneratorState();
}

class _QuestionVaultGeneratorState extends State<QuestionVaultGenerator> {
  final String apiBase = "https://api.institution.site";
  
  // --- ARCHITECT STATE ---
  String activeTab = 'bank'; // 'bank' or 'paper'
  List<Question> questionBank = [];
  bool isLoading = true;
  String? errorMessage;

  // Logic: Auto-Hydrate Paper
  List<Question> get selectedQuestions => questionBank.where((q) => q.isSelected).toList();
  int get totalMarks => selectedQuestions.fold(0, (sum, item) => sum + item.marks);

  void _showSignBox(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  // --- FETCH QUESTIONS FROM BACKEND ---
  Future<void> fetchQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final token = await StarlightStorage.getUserToken();
      
      final res = await http.get(
        Uri.parse('$apiBase/paper-scanner/question-bank'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['questions'] != null) {
          final List<dynamic> questions = data['questions'];
          setState(() {
            questionBank = questions.map((q) => Question(
              id: q['id'].toString(),
              text: q['question_text'] ?? 'No text',
              type: _mapQuestionType(q['question_type']),
              marks: q['marks'] ?? 0,
              rating: _mapDifficulty(q['difficulty']),
              options: q['options'] != null ? List<String>.from(q['options']) : null,
            )).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "No questions found in vault";
          });
        }
      } else if (res.statusCode == 401) {
        setState(() {
          isLoading = false;
          errorMessage = "Unauthorized: Please login again";
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to load questions: ${res.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Network error: $e";
      });
    }
  }

  // Map backend question types to display types
  String _mapQuestionType(String? type) {
    if (type == null) return 'Short';
    switch (type.toLowerCase()) {
      case 'mcq':
        return 'MCQ';
      case 'short':
      case 'short_answer':
        return 'Short';
      case 'long':
      case 'long_answer':
      case 'essay':
        return 'Long';
      case 'fill':
      case 'fill_in_blank':
        return 'Fill';
      case 'truefalse':
      case 'true_false':
        return 'TF';
      default:
        return 'Short';
    }
  }

  // Map backend difficulty to display rating
  String _mapDifficulty(String? difficulty) {
    if (difficulty == null) return 'Medium';
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("QUESTION VAULT ARCHITECT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildTabBar(),
        ),
      ),
      body: activeTab == 'bank' ? _buildQuestionBank() : _buildPaperPreview(),
      bottomNavigationBar: _buildActionFooter(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A237E),
      child: Row(
        children: [
          _tabBtn("QUESTION BANK", 'bank'),
          _tabBtn("PAPER PREVIEW", 'paper'),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, String tab) {
    bool active = activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? Colors.orangeAccent : Colors.transparent, width: 4)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: THE BANK ---
  Widget _buildQuestionBank() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading Question Vault...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: fetchQuestions,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (questionBank.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Question Vault is Empty",
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Use Paper Scanner to add questions",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: fetchQuestions,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: questionBank.length,
      itemBuilder: (context, index) {
        final q = questionBank[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: q.isSelected ? Colors.blue : Colors.transparent, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: CheckboxListTile(
            value: q.isSelected,
            activeColor: const Color(0xFF1A237E),
            onChanged: (val) => setState(() => q.isSelected = val!),
            title: Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("${q.type} | Marks: ${q.marks} | Difficulty: ${q.rating}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        );
      },
    );
  }

  // --- TAB 2: AUTO-HYDRATED PAPER ---
  Widget _buildPaperPreview() {
    if (selectedQuestions.isEmpty) {
      return const Center(child: Text("NO QUESTIONS SELECTED TO HYDRATE PAPER", style: TextStyle(color: Colors.grey, fontSize: 10)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Column(
                children: [
                  Text("STARLIGHT INSTITUTION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text("OFFICIAL EXAMINATION PAPER", style: TextStyle(fontSize: 8, letterSpacing: 2)),
                  Divider(thickness: 2),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Name: ________________", style: TextStyle(fontSize: 10)),
                Text("Total Marks: $totalMarks", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 30),
            ...selectedQuestions.asMap().entries.map((entry) {
              int idx = entry.key + 1;
              Question q = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Q$idx. ", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(q.text)),
                        Text("(${q.marks})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (q.type == 'MCQ' && q.options != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 25, top: 8),
                        child: Wrap(
                          spacing: 20,
                          children: q.options!.map((opt) => Text("( ) $opt", style: const TextStyle(fontSize: 12))).toList(),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: selectedQuestions.isEmpty 
            ? null 
            : () => _showSignBox("Final Paper Generated & Archived", true),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text("GENERATE FINAL PAPER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}