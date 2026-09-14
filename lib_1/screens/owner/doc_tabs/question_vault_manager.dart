import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/storage.dart';

// --- DATA MODEL ---
class VaultQuestion {
  final String id;
  String questionText;
  String questionType;
  int marks;
  String difficulty;
  String subject;
  String grade;
  int priority; // Added priority field
  List<dynamic>? options;
  List<dynamic>? subQuestions;
  bool isActive;
  bool isSelected;

  VaultQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.marks,
    required this.difficulty,
    required this.subject,
    required this.grade,
    this.priority = 3, // Default priority (normal)
    this.options,
    this.subQuestions,
    this.isActive = true,
    this.isSelected = false,
  });

  factory VaultQuestion.fromJson(Map<String, dynamic> json) {
    return VaultQuestion(
      id: json['id']?.toString() ?? '',
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? 'short',
      marks: (json['marks'] is int) ? json['marks'] : int.tryParse(json['marks'].toString()) ?? 0,
      difficulty: json['difficulty'] ?? 'medium',
      subject: json['subject'] ?? '',
      grade: json['grade'] ?? '',
      priority: (json['priority'] is int) ? json['priority'] : int.tryParse(json['priority'].toString()) ?? 3,
      options: json['options'],
      subQuestions: json['sub_questions'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class QuestionVaultManager extends StatefulWidget {
  const QuestionVaultManager({super.key});

  @override
  State<QuestionVaultManager> createState() => _QuestionVaultManagerState();
}

class _QuestionVaultManagerState extends State<QuestionVaultManager> {
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF1A237E);

  // --- STATE ---
  List<VaultQuestion> allQuestions = [];
  List<VaultQuestion> filteredQuestions = [];
  bool isLoading = true;
  String? errorMessage;

  // Filters
  List<String> availableSections = [];
  List<String> availableSubjects = [];
  String? selectedSection;
  String? selectedSubject;
  String selectedType = 'all'; // 'all', 'mcq', 'short', 'long', 'fill', 'truefalse'

  // Question Types
  final List<Map<String, dynamic>> questionTypes = [
    {'id': 'all', 'label': 'All', 'icon': Icons.format_list_bulleted},
    {'id': 'mcq', 'label': 'MCQ', 'icon': Icons.check_circle_outline},
    {'id': 'short', 'label': 'Short', 'icon': Icons.short_text},
    {'id': 'long', 'label': 'Long', 'icon': Icons.subject},
    {'id': 'fill', 'label': 'Fill', 'icon': Icons.edit_note},
    {'id': 'truefalse', 'label': 'T/F', 'icon': Icons.rule},
  ];

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    await fetchSections();
    await fetchQuestions();
  }

  // --- FETCH SECTIONS ---
  Future<void> fetchSections() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('$apiBase/paper-scanner/sections'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          availableSections = data.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
    }
  }

  // --- FETCH QUESTIONS ---
  Future<void> fetchQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();

      // Build query params
      final queryParams = <String, String>{};
      if (selectedSection != null && selectedSection!.isNotEmpty) {
        queryParams['grade'] = selectedSection!;
      }
      if (selectedSubject != null && selectedSubject!.isNotEmpty) {
        queryParams['subject'] = selectedSubject!;
      }
      if (selectedType != 'all') {
        queryParams['question_type'] = selectedType;
      }

      final uri = Uri.parse('$apiBase/paper-scanner/question-bank')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['questions'] != null) {
          final List<dynamic> questions = data['questions'];
          setState(() {
            allQuestions = questions.map((q) => VaultQuestion.fromJson(q)).toList();
            filteredQuestions = List.from(allQuestions);

            // Extract unique subjects from questions
            final subjects = allQuestions.map((q) => q.subject).toSet().toList();
            availableSubjects = subjects.where((s) => s.isNotEmpty).toList();

            isLoading = false;
          });
        } else {
          setState(() {
            allQuestions = [];
            filteredQuestions = [];
            isLoading = false;
          });
        }
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

  // --- DELETE QUESTION ---
  Future<void> deleteQuestion(String questionId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.delete(
        Uri.parse('$apiBase/paper-scanner/question/$questionId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showSignBox('Question deleted successfully', true);
          await fetchQuestions();
        } else {
          _showSignBox('Failed to delete question', false);
        }
      } else {
        _showSignBox('Failed to delete question: ${res.statusCode}', false);
      }
    } catch (e) {
      _showSignBox('Error deleting question: $e', false);
    }
  }

  // --- UPDATE QUESTION ---
  Future<void> updateQuestion(VaultQuestion question) async {
    try {
      final token = await StarlightStorage.getUserToken();
      
      final res = await http.put(
        Uri.parse('$apiBase/paper-scanner/question/${question.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'question_text': question.questionText,
          'marks': question.marks,
          'priority': question.priority,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showSignBox('Question updated successfully', true);
          await fetchQuestions();
        } else {
          _showSignBox('Failed to update question', false);
        }
      } else {
        _showSignBox('Failed to update question: ${res.statusCode}', false);
      }
    } catch (e) {
      _showSignBox('Error updating question: $e', false);
    }
  }

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

  // --- EDIT QUESTION DIALOG ---
  // --- EDIT QUESTION DIALOG ---
  void _showEditDialog(VaultQuestion question) {
    final textController = TextEditingController(text: question.questionText);
    final marksController = TextEditingController(text: question.marks.toString());
    int currentPriority = question.priority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Question', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Question Text', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: marksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Priority:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final priority = index + 1;
                    return IconButton(
                      icon: Icon(
                        currentPriority >= priority ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () => setDialogState(() => currentPriority = priority),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                question.questionText = textController.text;
                question.marks = int.tryParse(marksController.text) ?? question.marks;
                question.priority = currentPriority;
                Navigator.pop(context);
                updateQuestion(question);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // --- DELETE CONFIRMATION ---
  void _showDeleteConfirmation(VaultQuestion question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to delete this question?\n\n"${question.questionText.substring(0, question.questionText.length > 50 ? 50 : question.questionText.length)}..."'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteQuestion(question.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("QUESTION VAULT", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchQuestions,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- FILTER BAR ---
          _buildFilterBar(),
          // --- TYPE TABS ---
          _buildTypeTabs(),
          // --- QUESTIONS LIST ---
          Expanded(child: _buildQuestionsList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "FILTERS",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Section Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("Select Section"),
                      value: selectedSection,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSection = newValue;
                        });
                        fetchQuestions();
                      },
                      items: availableSections.map<DropdownMenuItem<String>>((String section) {
                        return DropdownMenuItem<String>(
                          value: section,
                          child: Text(section, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Subject Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text("Select Subject"),
                      value: selectedSubject,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                        fetchQuestions();
                      },
                      items: availableSubjects.map<DropdownMenuItem<String>>((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: questionTypes.length,
        itemBuilder: (context, index) {
          final type = questionTypes[index];
          final isSelected = selectedType == type['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedType = type['id'];
                });
                fetchQuestions();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(type['icon'], size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      type['label'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionsList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            Text(errorMessage!),
            ElevatedButton(onPressed: fetchQuestions, child: const Text("Retry")),
          ],
        ),
      );
    }

    final selectedCount = allQuestions.where((q) => q.isSelected).length;

    return Column(
      children: [
        if (allQuestions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    final allSelected = allQuestions.every((q) => q.isSelected);
                    for (var q in allQuestions) {
                      q.isSelected = !allSelected;
                    }
                  }),
                  child: Text(
                    allQuestions.every((q) => q.isSelected) ? "Deselect All" : "Select All",
                  ),
                ),
                const Spacer(),
                if (selectedCount > 0)
                  ElevatedButton.icon(
                    onPressed: () => _showBulkEditDialog(),
                    icon: const Icon(Icons.edit),
                    label: Text("Bulk Edit ($selectedCount)"),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredQuestions.length,
            itemBuilder: (context, index) {
              return _buildQuestionCard(filteredQuestions[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(VaultQuestion q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Checkbox(
          value: q.isSelected,
          onChanged: (val) => setState(() => q.isSelected = val ?? false),
        ),
        title: Text(
          q.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _getTypeColor(q.questionType).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(q.questionType.toUpperCase(), style: TextStyle(fontSize: 9, color: _getTypeColor(q.questionType))),
            ),
            const SizedBox(width: 8),
            Text("${q.marks} marks", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            // Display stars
            Row(
              children: List.generate(5, (index) => Icon(
                index < q.priority ? Icons.star : Icons.star_border,
                size: 14,
                color: Colors.amber,
              )),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Difficulty: ${q.difficulty}", style: const TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _showEditDialog(q)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _showDeleteConfirmation(q)),
                      ],
                    ),
                  ],
                ),
                if (q.options != null && q.options!.isNotEmpty) ...[
                  const Text("Options:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Wrap(
                    spacing: 8,
                    children: q.options!.map((opt) => Chip(label: Text(opt.toString(), style: const TextStyle(fontSize: 11)))).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BULK EDIT MARKS AND PRIORITY ---
  void _showBulkEditDialog() {
    final marksController = TextEditingController();
    int? selectedPriority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bulk Edit Selected'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: marksController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Marks', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text("Select Priority:"),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final priority = index + 1;
                  return IconButton(
                    icon: Icon(
                      selectedPriority != null && selectedPriority! >= priority
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setDialogState(() => selectedPriority = priority),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newMarks = int.tryParse(marksController.text);
                final selectedIds = allQuestions.where((q) => q.isSelected).map((q) => q.id).toList();
                
                Navigator.pop(context);
                setState(() => isLoading = true);
                
                final updates = <String, dynamic>{};
                if (newMarks != null) updates['marks'] = newMarks;
                if (selectedPriority != null) updates['priority'] = selectedPriority;
                
                if (updates.isNotEmpty) {
                  await bulkUpdate(selectedIds, updates);
                } else {
                  setState(() => isLoading = false);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> bulkUpdate(List<String> questionIds, Map<String, dynamic> updates) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.put(
        Uri.parse('$apiBase/paper-scanner/questions/bulk-update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'question_ids': questionIds,
          'updates': updates,
        }),
      );
      if (res.statusCode == 200) {
        _showSignBox('Bulk update successful', true);
        await fetchQuestions();
      } else {
        _showSignBox('Bulk update failed: ${res.statusCode}', false);
      }
    } catch (e) {
      _showSignBox('Error: $e', false);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'mcq':
        return Colors.blue;
      case 'short':
        return Colors.orange;
      case 'long':
      case 'essay':
        return Colors.purple;
      case 'fill':
      case 'fill_in_blank':
        return Colors.teal;
      case 'truefalse':
      case 'true_false':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
