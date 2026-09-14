import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage.dart';
import '../../../services/gemini_service.dart';
import 'testArchitect.dart' show TestArchitect;

// --- DATA MODELS (Compatible with TestArchitect Template System) ---
class SubPart {
  String id;
  String label;
  String text;
  SubPart({required this.id, required this.label, required this.text});
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'text': text};
}

class ArchitectQuestion {
  String id;
  String text;
  List<SubPart> subParts;
  String type;
  int marks;
  String difficulty;
  String subject;
  String grade;
  List<dynamic>? options;
  bool isSelected;

  ArchitectQuestion({
    required this.id,
    required this.text,
    this.subParts = const [],
    required this.type,
    required this.marks,
    required this.difficulty,
    required this.subject,
    required this.grade,
    this.options,
    this.isSelected = false,
  });

  factory ArchitectQuestion.fromVaultJson(Map<String, dynamic> json) {
    debugPrint('🔍 Parsing Question JSON: $json');
    final subQuestions = json['sub_questions'] as List<dynamic>?;
    
    // Safely parse marks whether it comes as int or string
    final rawMarks = json['marks'];
    final int parsedMarks = (rawMarks is int) 
        ? rawMarks 
        : int.tryParse(rawMarks?.toString() ?? '0') ?? 0;

    try {
      return ArchitectQuestion(
        id: json['id']?.toString() ?? 'unknown',
        text: json['question_text']?.toString() ?? '',
        type: json['question_type']?.toString() ?? 'short',
        marks: parsedMarks,
        difficulty: json['difficulty']?.toString() ?? 'medium',
        subject: json['subject']?.toString() ?? '',
        grade: json['grade']?.toString() ?? '',
        options: json['options'],
        subParts: subQuestions?.map((sq) => SubPart(
          id: sq['part']?.toString() ?? '',
          label: sq['part']?.toString() ?? '',
          text: sq['text']?.toString() ?? '',
        )).toList() ?? [],
      );
    } catch (e) {
      debugPrint('❌ Error parsing question: $e');
      rethrow;
    }
  }
}

class PaperArchitect extends StatefulWidget {
  const PaperArchitect({super.key});

  @override
  State<PaperArchitect> createState() => _PaperArchitectState();
}

class _PaperArchitectState extends State<PaperArchitect> {
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF1A237E);
  final _uuid = const Uuid();

  // --- STATE ---
  List<ArchitectQuestion> allQuestions = [];
  bool isLoading = true;
  String? errorMessage;
  bool _isGeneratingAi = false;

  // AI Paper Generation Options
  bool optShowLogo = true;
  bool optShowNotes = true;
  bool optShowBubbleSheet = false;
  bool optShowWatermark = true;
  bool optShowMarksPerQuestion = true;
  bool optShowSectionMarks = true;
  bool optShowAttemptInstructions = true;

  // Paper Configuration
  final TextEditingController _paperTitleController = TextEditingController(text: 'Examination Paper');
  final TextEditingController _durationController = TextEditingController(text: '3 Hours');
  final TextEditingController _instructionsController = TextEditingController(
    text: '1. Answer all questions.\n2. Write your name and roll number on the answer sheet.\n3. Use of calculators is not allowed.',
  );

  // Filters
  List<String> availableSections = [];
  List<String> availableSubjects = [];
  String? selectedSection;
  String? selectedSubject;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    _paperTitleController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
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
      final queryParams = <String, String>{};
      if (selectedSection != null && selectedSection!.isNotEmpty) {
        queryParams['grade'] = selectedSection!;
      }
      if (selectedSubject != null && selectedSubject!.isNotEmpty) {
        queryParams['subject'] = selectedSubject!;
      }

      final uri = Uri.parse('$apiBase/paper-scanner/question-bank')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['questions'] != null) {
          final List<dynamic> questions = data['questions'];
          setState(() {
            allQuestions = questions.map((q) => ArchitectQuestion.fromVaultJson(q)).toList();
            final subjects = allQuestions.map((q) => q.subject).toSet().toList();
            availableSubjects = subjects.where((s) => s.isNotEmpty).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            allQuestions = [];
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

  // --- Convert selected questions to TestArchitect format and navigate ---
  void _navigateToTestArchitect({
    required List<Map<String, dynamic>> blocks,
    String title = 'Examination Paper',
    String subject = '',
    String className = '',
    String duration = '3 Hours',
    String instructions = '',
  }) {
    final paperData = {
      'id': _uuid.v4(),
      'fileName': title,
      'instName': 'STARLIGHT INSTITUTION',
      'subject': subject,
      'class': className,
      'type': 'Final',
      'notice': instructions,
      'pages': [
        {
          'id': 1,
          'blocks': blocks,
        }
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestArchitect(initialPaper: paperData),
      ),
    );
  }

  // --- Build TestArchitect blocks from selected questions ---
  List<Map<String, dynamic>> _buildBlocksFromSelection(List<ArchitectQuestion> selected) {
    if (selected.isEmpty) return [];

    final mcqQuestions = selected.where((q) => q.type.toLowerCase() == 'mcq').toList();
    final shortQuestions = selected.where((q) =>
      ['short', 'short_answer', 'fill', 'fill_in_blank', 'truefalse', 'true_false']
      .contains(q.type.toLowerCase())).toList();
    final longQuestions = selected.where((q) =>
      ['long', 'long_answer', 'essay'].contains(q.type.toLowerCase())).toList();

    final blocks = <Map<String, dynamic>>[];
    int blockId = 1;

    void addBlock(String type, String header, List<ArchitectQuestion> questions) {
      if (questions.isEmpty) return;
      blocks.add({
        'id': 'block_$blockId',
        'type': type,
        'marks': questions.fold(0, (sum, q) => sum + q.marks),
        'choice': 0,
        'headerText': header,
        'sectionHeading': '',
        'startNumber': 1,
        'questions': questions.map((q) => {
          'id': q.id,
          'text': q.text,
          'subParts': q.subParts.map((sp) => {
            'id': sp.id,
            'label': sp.label,
            'text': sp.text,
          }).toList(),
        }).toList(),
        'showBubbleSheet': type == 'MCQs',
        'bubbleSheetPosition': 'end',
        'bubbleOptions': 4,
      });
      blockId++;
    }

    addBlock('MCQs', 'Multiple Choice Questions', mcqQuestions);
    addBlock('Short', 'Short Answer Questions', shortQuestions);
    addBlock('Long', 'Long Answer Questions', longQuestions);

    if (blocks.isEmpty) {
      addBlock('Custom', 'Questions', selected);
    }

    return blocks;
  }

  // --- Build TestArchitect blocks from Gemini paper structure ---
  List<Map<String, dynamic>> _buildBlocksFromGeminiStructure(Map<String, dynamic> structure) {
    final sections = structure['sections'] as List<dynamic>?;
    if (sections == null || sections.isEmpty) return [];

    final blocks = <Map<String, dynamic>>[];
    int blockId = 1;

    for (final section in sections) {
      final questions = (section['questions'] as List<dynamic>?) ?? [];
      final qs = questions.map((q) {
        // Convert options to subParts
        final options = (q['options'] as List<dynamic>?) ?? [];
        final existingSubParts = (q['sub_parts'] as List<dynamic>?) ?? [];
        final allSubParts = <Map<String, dynamic>>[];

        int optIdx = 0;
        for (final opt in options) {
          final optStr = opt.toString().trim();
          // Strip leading label like "A)", "a)", "A.", "a."
          final cleanText = optStr.replaceFirst(RegExp(r'^[A-Da-d][).]\s*'), '');
          allSubParts.add({
            'id': 'opt_$optIdx',
            'label': String.fromCharCode(97 + optIdx),
            'text': cleanText,
          });
          optIdx++;
        }

        for (final sp in existingSubParts) {
          allSubParts.add({
            'id': sp['id']?.toString() ?? 'sp_${allSubParts.length}',
            'label': sp['part']?.toString() ?? '',
            'text': sp['text']?.toString() ?? '',
          });
        }

        return {
          'id': q['number']?.toString() ?? 'q_$blockId',
          'text': q['text']?.toString() ?? '',
          'marks': (q['marks'] as int?) ?? 0,
          'subParts': allSubParts,
        };
      }).toList();

      final attemptInstr = section['attempt_instruction']?.toString() ?? '';
      int choice = 0;
      if (attemptInstr.isNotEmpty) {
        final match = RegExp(r'(\d+)').firstMatch(attemptInstr);
        if (match != null) choice = int.tryParse(match.group(1)!) ?? 0;
      }

      // Determine type from section name or questions
      final secName = (section['name']?.toString() ?? '').toLowerCase();
      String type = 'Custom';
      if (secName.contains('mcq') || secName.contains('multiple choice')) {
        type = 'MCQs';
      } else if (secName.contains('short')) {
        type = 'Short';
      } else if (secName.contains('long') || secName.contains('essay')) {
        type = 'Long';
      } else if (questions.isNotEmpty) {
        final qType = (questions.first['type']?.toString() ?? '').toLowerCase();
        if (qType == 'mcq') type = 'MCQs';
        else if (['short', 'short_answer', 'fill'].contains(qType)) type = 'Short';
        else if (['long', 'long_answer', 'essay'].contains(qType)) type = 'Long';
      }

      int qsMarks = 0;
      for (final qm in qs) {
        qsMarks += (qm['marks'] as int? ?? 0);
      }
      blocks.add({
        'id': 'block_$blockId',
        'type': type,
        'marks': (section['marks'] as int?) ?? qsMarks,
        'choice': choice,
        'headerText': section['name']?.toString() ?? 'Section',
        'sectionHeading': '',
        'startNumber': 1,
        'questions': qs,
        'showBubbleSheet': type == 'MCQs',
        'bubbleSheetPosition': 'end',
        'bubbleOptions': 4,
      });
      blockId++;
    }

    return blocks;
  }

  // --- INTELLIGENT TEMPLATE HYDRATION ---
  void _hydrateTestTemplate() {
    final selected = allQuestions.where((q) => q.isSelected).toList();
    if (selected.isEmpty) {
      _showSignBox('Please select at least one question', false);
      return;
    }

    final blocks = _buildBlocksFromSelection(selected);
    if (blocks.isEmpty) {
      _showSignBox('Could not organize questions', false);
      return;
    }

    _navigateToTestArchitect(
      blocks: blocks,
      title: _paperTitleController.text,
      subject: selectedSubject ?? '',
      className: selectedSection ?? '',
      duration: _durationController.text,
      instructions: _instructionsController.text,
    );

    _showSignBox('Template hydrated! ${selected.length} questions sent to Paper Designer Pro', true);
  }



  // --- AI PAPER GENERATION ---
  Uint8List? _aiLogoBytes;
  String _aiLogoShape = 'circle';

  void _showPaperOptionsDialog() {
    final titleCtrl = TextEditingController(text: _paperTitleController.text);
    final instCtrl = TextEditingController(text: 'STARLIGHT INSTITUTION');
    final subjectCtrl = TextEditingController(text: selectedSubject ?? '');
    final classCtrl = TextEditingController(text: selectedSection ?? '');
    final durationCtrl = TextEditingController(text: _durationController.text);
    final instructionsCtrl = TextEditingController(text: _instructionsController.text);
    bool showNotes = optShowNotes;
    bool showBubbleSheet = optShowBubbleSheet;
    bool showWatermark = optShowWatermark;
    bool showMarksPerQ = optShowMarksPerQuestion;
    bool showSectionMarks = optShowSectionMarks;
    bool showAttemptInstructions = optShowAttemptInstructions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.deepPurple),
                        const SizedBox(width: 10),
                        const Text("AI PAPER REQUIREMENTS",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Logo Picker
                    Row(
                      children: [
                        const Text("Logo: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: ctx,
                              builder: (lctx) => StatefulBuilder(
                                builder: (lctx, setLogoState) => AlertDialog(
                                  title: const Text("Select Logo"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_aiLogoBytes != null)
                                        Container(
                                          width: 80, height: 80,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            shape: _aiLogoShape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                                            borderRadius: _aiLogoShape == 'square' ? BorderRadius.circular(8) : null,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: _aiLogoShape == 'square' ? BorderRadius.circular(8) : (_aiLogoShape == 'circle' ? BorderRadius.circular(40) : BorderRadius.zero),
                                            child: Image.memory(_aiLogoBytes!, fit: BoxFit.cover),
                                          ),
                                        ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _logoShapeChip('circle', 'Circle'),
                                          const SizedBox(width: 8),
                                          _logoShapeChip('square', 'Square'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final picker = ImagePicker();
                                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 120, maxHeight: 120);
                                          if (file != null) {
                                            final bytes = await file.readAsBytes();
                                            setState(() => _aiLogoBytes = bytes);
                                            setLogoState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.photo_library, size: 18),
                                        label: const Text("Pick from Gallery"),
                                      ),
                                      if (_aiLogoBytes != null)
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() => _aiLogoBytes = null);
                                            setLogoState(() {});
                                          },
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          label: const Text("Remove", style: TextStyle(color: Colors.red)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _aiLogoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.memory(_aiLogoBytes!, fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.add_photo_alternate, size: 24, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Header Fields
                    const Text("HEADER DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Paper Title', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title, size: 18)),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: instCtrl,
                      decoration: const InputDecoration(labelText: 'Institution Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.school, size: 18)),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), prefixIcon: Icon(Icons.book, size: 18)),
                          style: const TextStyle(fontSize: 13),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: classCtrl,
                          decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder(), prefixIcon: Icon(Icons.group, size: 18)),
                          style: const TextStyle(fontSize: 13),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: durationCtrl,
                      decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder(), prefixIcon: Icon(Icons.timer, size: 18)),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    // Formatting Options
                    const Text("FORMATTING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _optionTile("Show Instructions/Notes", showNotes, (v) { setDialogState(() => showNotes = v); setState(() => optShowNotes = v); }),
                    _optionTile("Show Marks Per Question", showMarksPerQ, (v) { setDialogState(() => showMarksPerQ = v); setState(() => optShowMarksPerQuestion = v); }),
                    _optionTile("Show Section Marks", showSectionMarks, (v) { setDialogState(() => showSectionMarks = v); setState(() => optShowSectionMarks = v); }),
                    _optionTile("Show Bubble Sheet for MCQs", showBubbleSheet, (v) { setDialogState(() => showBubbleSheet = v); setState(() => optShowBubbleSheet = v); }),
                    _optionTile("Show Watermark", showWatermark, (v) { setDialogState(() => showWatermark = v); setState(() => optShowWatermark = v); }),
                    _optionTile("Show Attempt Instructions", showAttemptInstructions, (v) { setDialogState(() => showAttemptInstructions = v); setState(() => optShowAttemptInstructions = v); }),
                    if (showNotes) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: instructionsCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Instructions / Notes', border: OutlineInputBorder(), prefixIcon: Icon(Icons.info, size: 18)),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _generateWithAI(
                            title: titleCtrl.text,
                            institution: instCtrl.text,
                            subject: subjectCtrl.text,
                            targetClass: classCtrl.text,
                            duration: durationCtrl.text,
                            instructions: instructionsCtrl.text,
                          );
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text("GENERATE PAPER WITH AI",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _optionTile(String label, bool value, void Function(bool) onChange) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: (v) => onChange(v ?? false),
      dense: true,
      activeColor: Colors.deepPurple,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _logoShapeChip(String value, String label) {
    final active = _aiLogoShape == value;
    return GestureDetector(
      onTap: () => setState(() => _aiLogoShape = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.deepPurple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  Future<void> _generateWithAI({
    String title = '',
    String institution = '',
    String subject = '',
    String targetClass = '',
    String duration = '',
    String instructions = '',
  }) async {
    final selected = allQuestions.where((q) => q.isSelected).toList();
    if (selected.isEmpty) {
      _showSignBox('Please select at least one question first', false);
      return;
    }

    setState(() => _isGeneratingAi = true);
    _showSignBox('Sending to AI for paper structuring...', true);

    final questionsPayload = selected.map((q) => {
      'id': q.id,
      'text': q.text,
      'type': q.type,
      'marks': q.marks,
      'difficulty': q.difficulty,
      'options': q.options ?? [],
      'sub_parts': q.subParts.map((s) => s.toJson()).toList(),
    }).toList();

    String? logoBase64;
    if (_aiLogoBytes != null) {
      logoBase64 = base64Encode(_aiLogoBytes!);
    }

    final optionsPayload = {
      'show_logo': logoBase64 != null,
      'show_notes': optShowNotes,
      'show_bubble_sheet': optShowBubbleSheet,
      'show_watermark': optShowWatermark,
      'show_marks_per_question': optShowMarksPerQuestion,
      'show_section_marks': optShowSectionMarks,
      'show_attempt_instructions': optShowAttemptInstructions,
      'paper_title': title.isNotEmpty ? title : _paperTitleController.text,
      'institution_name': institution.isNotEmpty ? institution : 'STARLIGHT INSTITUTION',
      'subject': subject.isNotEmpty ? subject : (selectedSubject ?? ''),
      'class_name': targetClass.isNotEmpty ? targetClass : (selectedSection ?? ''),
      'time_allowed': duration.isNotEmpty ? duration : _durationController.text,
      'instructions_text': instructions.isNotEmpty ? instructions : _instructionsController.text,
      'logo_data': logoBase64,
      'logo_shape': _aiLogoShape,
    };

    final result = await GeminiService.generatePaper(
      questions: questionsPayload,
      options: optionsPayload,
    );

    setState(() => _isGeneratingAi = false);

    if (result['error'] != null) {
      _showSignBox('AI Generation Failed: ${result['error']}', false);
      return;
    }

    // Try to use AI paper structure; fall back to type-based grouping
    final paperStructure = result['paper_structure'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> blocks;
    final String aiTitle;
    final String aiSubject;
    final String aiClass;
    final String aiDuration;
    final String aiInstructions;

    if (paperStructure != null) {
      blocks = _buildBlocksFromGeminiStructure(paperStructure);
      final header = paperStructure['header'] as Map<String, dynamic>? ?? {};
      aiTitle = paperStructure['title']?.toString() ?? title;
      aiSubject = header['subject']?.toString() ?? subject;
      aiClass = header['class']?.toString() ?? targetClass;
      aiDuration = header['time_allowed']?.toString() ?? duration;
      final instrs = (paperStructure['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .join('\n') ??
          instructions;
      aiInstructions = instrs;
    } else {
      blocks = _buildBlocksFromSelection(selected);
      aiTitle = title;
      aiSubject = subject;
      aiClass = targetClass;
      aiDuration = duration;
      aiInstructions = instructions;
    }

    if (blocks.isEmpty) {
      _showSignBox('Could not organize questions from AI response', false);
      return;
    }

    _navigateToTestArchitect(
      blocks: blocks,
      title: aiTitle,
      subject: aiSubject,
      className: aiClass,
      duration: aiDuration,
      instructions: aiInstructions,
    );

    _showSignBox('AI Paper loaded into Paper Designer Pro!', true);
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

  void _toggleQuestionSelection(int index) {
    setState(() {
      allQuestions[index].isSelected = !allQuestions[index].isSelected;
    });
  }

  void _selectAll() {
    setState(() {
      for (var q in allQuestions) {
        q.isSelected = true;
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (var q in allQuestions) {
        q.isSelected = false;
      }
    });
  }

  void _autoSelectByMarks(int targetMarks) {
    setState(() {
      for (var q in allQuestions) {
        q.isSelected = false;
      }
      final sorted = List<ArchitectQuestion>.from(allQuestions)
        ..sort((a, b) => _difficultyValue(a.difficulty).compareTo(_difficultyValue(b.difficulty)));
      int currentMarks = 0;
      for (var q in sorted) {
        if (currentMarks + q.marks <= targetMarks) {
          q.isSelected = true;
          currentMarks += q.marks;
        }
        if (currentMarks >= targetMarks) break;
      }
    });
  }

  int _difficultyValue(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return 1;
      case 'medium': return 2;
      case 'hard': return 3;
      default: return 2;
    }
  }

  List<ArchitectQuestion> get selectedQuestions =>
      allQuestions.where((q) => q.isSelected).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("PAPER ARCHITECT", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchQuestions,
          ),
        ],
      ),
      body: _buildSelectionView(),
    );
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        // Paper Configuration
        _buildPaperConfigHeader(),
        // Filters
        _buildFilters(),
        // Actions Bar
        _buildActionsBar(),
        // Questions List
        Expanded(child: _buildQuestionsList()),
        // Hydrate Button
        _buildHydrateButton(),
      ],
    );
  }

  Widget _buildPaperConfigHeader() {
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
            "PAPER CONFIGURATION",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paperTitleController,
            decoration: const InputDecoration(
              labelText: 'Paper Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _instructionsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.info),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
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
              Expanded(
                child: _buildDropdown(
                  hint: "Select Section",
                  value: selectedSection,
                  items: availableSections,
                  onChanged: (value) {
                    setState(() => selectedSection = value);
                    fetchQuestions();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  hint: "Select Subject",
                  value: selectedSubject,
                  items: availableSubjects,
                  onChanged: (value) {
                    setState(() => selectedSubject = value);
                    fetchQuestions();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: value,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(value: item, child: Text(item, style: const TextStyle(fontSize: 14)));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionsBar() {
    final selected = selectedQuestions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Text(
            "${selected.length} selected | ${selected.fold(0, (sum, q) => sum + q.marks)} marks",
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text("All"),
          ),
          TextButton.icon(
            onPressed: _deselectAll,
            icon: const Icon(Icons.deselect, size: 18),
            label: const Text("Clear"),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAutoSelectDialog(),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text("Auto"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showAutoSelectDialog() {
    final marksController = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Select Questions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Automatically select questions to reach target marks (prioritizes easier questions)'),
            const SizedBox(height: 16),
            TextField(
              controller: marksController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Total Marks',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final target = int.tryParse(marksController.text) ?? 100;
              Navigator.pop(context);
              _autoSelectByMarks(target);
            },
            child: const Text('Auto Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading Questions...", style: TextStyle(color: Colors.grey)),
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
            ElevatedButton.icon(
              onPressed: fetchQuestions,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (allQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const Text("No Questions Found", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Add questions using Paper Scanner first", style: TextStyle(color: Colors.grey, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: fetchQuestions,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allQuestions.length,
      itemBuilder: (context, index) {
        final q = allQuestions[index];
        return _buildQuestionCard(q, index);
      },
    );
  }

  Widget _buildQuestionCard(ArchitectQuestion q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: q.isSelected ? primaryColor : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: InkWell(
        onTap: () => _toggleQuestionSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: q.isSelected,
                    onChanged: (_) => _toggleQuestionSelection(index),
                    activeColor: primaryColor,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(q.type),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(q.type.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(q.difficulty),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(q.difficulty.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  Text("${q.marks} marks", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(q.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (q.options != null && q.options!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: q.options!.asMap().entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text("${String.fromCharCode(65 + entry.key)}. ${entry.value}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHydrateButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _hydrateTestTemplate,
          icon: const Icon(Icons.auto_awesome, size: 24),
          label: const Text(
            "HYDRATE TEST TEMPLATE",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'mcq': return Colors.blue;
      case 'short': return Colors.orange;
      case 'long': return Colors.purple;
      case 'fill': return Colors.teal;
      case 'truefalse': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'hard': return Colors.red;
      default: return Colors.grey;
    }
  }

}
