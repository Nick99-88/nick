import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/gemini_service.dart';
import '../../../services/paper_scanner_service.dart';
import '../../../models/scanned_question_models.dart';
import '../../../core/theme.dart';
import '../../../core/storage.dart';

class EnhancedPaperScanner extends StatefulWidget {
  const EnhancedPaperScanner({super.key});

  @override
  State<EnhancedPaperScanner> createState() => _EnhancedPaperScannerState();
}

class _EnhancedPaperScannerState extends State<EnhancedPaperScanner> {
  final ImagePicker _imagePicker = ImagePicker();
  final _uuid = const Uuid();
  final String apiBase = "https://api.institution.site";
  
  bool _isScanning = false;
  bool _hasImage = false;
  File? _selectedImage;
  Uint8List? _imageBytes;
  ScannedPaper? _scannedPaper;
  
  // Controllers for paper info editing
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  
  // Section selection
  List<String> availableSections = [];
  String? selectedSection;
  bool isLoadingSections = false;

  @override
  void initState() {
    super.initState();
    fetchSections();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  // --- SECTIONS FETCHING (Similar to Syllabus) ---
  Future<void> fetchSections() async {
    setState(() => isLoadingSections = true);
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
          isLoadingSections = false;
        });
      } else {
        setState(() => isLoadingSections = false);
      }
    } catch (e) {
      setState(() => isLoadingSections = false);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      _showError('Failed to select image: $e');
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      setState(() {
        _selectedImage = imageFile;
        _imageBytes = Uint8List.fromList(bytes);
        _hasImage = true;
        _scannedPaper = null; // Reset previous scan
      });
    } catch (e) {
      _showError('Failed to process image: $e');
    }
  }

  Future<void> _scanPaperWithAI() async {
    if (_imageBytes == null) {
      _showError('Please select an image first');
      return;
    }

    setState(() => _isScanning = true);
    
    try {
      print('Starting AI paper scanning...');
      final result = await GeminiService.scanPaper(_imageBytes!);
      print('AI scanning completed, validating results...');
      
      // Check for errors in the result
      if (result.containsKey('error')) {
        print('AI scanning error: ${result['error']}');
        _showError('AI scanning failed: ${result['error']}');
        setState(() => _isScanning = false);
        return;
      }

      // Validate and clean the data
      print('Calling validateScannedData...');
      final validatedData = GeminiService.validateScannedData(result);
      print('Data validation completed');
      print('ValidatedData keys: ${validatedData.keys}');
      print('paperInfo type: ${validatedData['paperInfo'].runtimeType}');
      print('questions type: ${validatedData['questions'].runtimeType}');

      print('Parsing PaperInfo...');
      final paperInfo = PaperInfo.fromJson(Map<String, dynamic>.from(validatedData['paperInfo'] as Map));
      print('Parsing questions...');
      final questions = (validatedData['questions'] as List)
          .map((q) => ScannedQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();

      print('Parsed ${questions.length} questions');

      // Update controllers with extracted info
      _titleController.text = paperInfo.title.isNotEmpty ? paperInfo.title : 'Scanned Paper';
      _subjectController.text = paperInfo.subject.isNotEmpty ? paperInfo.subject : '';

      setState(() {
        _scannedPaper = ScannedPaper(
          id: _uuid.v4(),
          paperInfo: paperInfo,
          questions: questions,
          scannedAt: DateTime.now(),
        );
        _isScanning = false;
      });

      _showSuccess('Paper scanned successfully! Found ${questions.length} questions');
    } catch (e) {
      print('Scanning exception: $e');
      _showError('Scanning failed: $e');
      setState(() => _isScanning = false);
    }
  }

  void _toggleQuestionSelection(int index) {
    if (_scannedPaper == null) return;
    
    final updatedQuestions = List<ScannedQuestion>.from(_scannedPaper!.questions);
    updatedQuestions[index] = updatedQuestions[index].copyWithSelection(
      !updatedQuestions[index].isSelected
    );
    
    setState(() {
      _scannedPaper = _scannedPaper!.copyWithUpdatedQuestions(updatedQuestions);
    });
  }

  void _selectAllQuestions() {
    if (_scannedPaper == null) return;
    
    final updatedQuestions = _scannedPaper!.questions
        .map((q) => q.copyWithSelection(true))
        .toList();
    
    setState(() {
      _scannedPaper = _scannedPaper!.copyWithUpdatedQuestions(updatedQuestions);
    });
  }

  void _deselectAllQuestions() {
    if (_scannedPaper == null) return;
    
    final updatedQuestions = _scannedPaper!.questions
        .map((q) => q.copyWithSelection(false))
        .toList();
    
    setState(() {
      _scannedPaper = _scannedPaper!.copyWithUpdatedQuestions(updatedQuestions);
    });
  }

  Future<void> _saveSelectedQuestions() async {
    if (_scannedPaper == null || _scannedPaper!.selectedQuestions.isEmpty) {
      _showError('Please select at least one question to save');
      return;
    }

    setState(() => _isScanning = true);
    
    try {
      // Validate section is selected
      if (selectedSection == null || selectedSection!.isEmpty) {
        _showError('Please select a section');
        setState(() => _isScanning = false);
        return;
      }

      // Update paper info with form values
      final updatedPaperInfo = _scannedPaper!.paperInfo.copyWith(
        title: _titleController.text.isNotEmpty ? _titleController.text : _scannedPaper!.paperInfo.title,
        subject: _subjectController.text.isNotEmpty ? _subjectController.text : _scannedPaper!.paperInfo.subject,
        grade: selectedSection!, // Use selected section as grade
      );

      final result = await PaperScannerService.saveQuestions(
        paperId: _scannedPaper!.id,
        paperInfo: updatedPaperInfo,
        selectedQuestions: _scannedPaper!.selectedQuestions,
      );

      if (result['status'] == 'success') {
        _showSuccess(result['message'] ?? 'Questions saved successfully!');
        
        // Optionally clear the form after successful save
        setState(() {
          _scannedPaper = null;
          _hasImage = false;
          _selectedImage = null;
          _imageBytes = null;
          _titleController.clear();
          _subjectController.clear();
          selectedSection = null;
        });
      } else {
        _showError('Failed to save questions: ${result['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showError('Error saving questions: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "AI PAPER SCANNER",
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_hasImage) _buildImageSelectionSection(),
            if (_hasImage) _buildScannedImageSection(),
            if (_scannedPaper != null) ...[
              const SizedBox(height: 20),
              _buildPaperInfoSection(),
              const SizedBox(height: 20),
              _buildQuestionsSection(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 80,
            color: StarlightTheme.primaryBlue.withOpacity(0.7),
          ),
          const SizedBox(height: 20),
          const Text(
            "Scan Your Paper",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Take a photo or select an image of your question paper",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Take Photo"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: StarlightTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: StarlightTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildScannedImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanPaperWithAI,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isScanning ? "Scanning..." : "Scan with AI"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.grey : StarlightTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _hasImage = false;
                      _selectedImage = null;
                      _imageBytes = null;
                      _scannedPaper = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Paper Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 15),
          // Title Field
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: "Paper Title",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          // Subject Field
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: "Subject",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          // Section Dropdown
          isLoadingSections
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : availableSections.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey, size: 16),
                          SizedBox(width: 8),
                          Text(
                            "No sections available",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
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
                          },
                          items: availableSections
                              .map<DropdownMenuItem<String>>((String section) {
                            return DropdownMenuItem<String>(
                              value: section,
                              child: Text(section),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection() {
    if (_scannedPaper == null || _scannedPaper!.questions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.quiz_outlined, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "No questions found",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Extracted Questions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _selectAllQuestions,
                    child: const Text("Select All"),
                  ),
                  TextButton(
                    onPressed: _deselectAllQuestions,
                    child: const Text("Deselect All"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${_scannedPaper!.selectedCount} of ${_scannedPaper!.questions.length} selected (${_scannedPaper!.selectedTotalMarks} marks)",
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 15),
          ..._scannedPaper!.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return _buildQuestionCard(question, index);
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ScannedQuestion question, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        border: Border.all(
          color: question.isSelected ? StarlightTheme.primaryBlue : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        color: question.isSelected ? StarlightTheme.primaryBlue.withOpacity(0.05) : Colors.white,
      ),
      child: InkWell(
        onTap: () => _toggleQuestionSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: question.isSelected,
                    onChanged: (_) => _toggleQuestionSelection(index),
                    activeColor: StarlightTheme.primaryBlue,
                  ),
                  Expanded(
                    child: Text(
                      "Q${question.questionNumber} - ${question.typeDisplay}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(question.difficulty),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      question.difficultyDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${question.totalMarks} marks",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: StarlightTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                question.questionText,
                style: const TextStyle(fontSize: 14),
              ),
              if (question.options.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...question.options.asMap().entries.map((entry) {
                  final optionIndex = entry.key;
                  final option = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      "${String.fromCharCode(65 + optionIndex)}. $option",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }),
              ],
              if (question.subQuestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...question.subQuestions.asMap().entries.map((entry) {
                  final subQuestion = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      "${subQuestion.part}. ${subQuestion.text} (${subQuestion.marks} marks)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
      case Difficulty.unknown:
        return Colors.grey;
    }
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSelectedQuestions,
              icon: const Icon(Icons.save),
              label: Text("Save ${_scannedPaper?.selectedCount ?? 0} Selected Questions"),
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
