import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'paper_pdf_generator.dart';

enum PaperLang { en, ur, ar }

class SubPart {
  String id;
  String label;
  String text;
  SubPart({required this.id, required this.label, required this.text});

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'text': text,
  };

  factory SubPart.fromJson(Map<String, dynamic> json) => SubPart(
    id: json['id'],
    label: json['label'],
    text: json['text'],
  );
}

class Question {
  String id;
  String text;
  List<SubPart> subParts;
  Question({required this.id, required this.text, required this.subParts});

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'subParts': subParts.map((e) => e.toJson()).toList(),
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'],
    text: json['text'],
    subParts: (json['subParts'] as List).map((e) => SubPart.fromJson(e)).toList(),
  );
}

class QuestionBlock {
  String id;
  String type;
  int marks;
  int choice;
  String headerText;
  String sectionHeading;
  int startNumber;
  List<Question> questions;
  bool showBubbleSheet;
  String bubbleSheetPosition; // 'start' or 'end'
  int bubbleOptions; // number of options per question (3 or 4)
  QuestionBlock({
    required this.id,
    required this.type,
    required this.marks,
    required this.choice,
    required this.headerText,
    this.sectionHeading = '',
    this.startNumber = 1,
    required this.questions,
    this.showBubbleSheet = false,
    this.bubbleSheetPosition = 'end',
    this.bubbleOptions = 4,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'marks': marks,
    'choice': choice,
    'headerText': headerText,
    'sectionHeading': sectionHeading,
    'startNumber': startNumber,
    'questions': questions.map((e) => e.toJson()).toList(),
    'showBubbleSheet': showBubbleSheet,
    'bubbleSheetPosition': bubbleSheetPosition,
    'bubbleOptions': bubbleOptions,
  };

  factory QuestionBlock.fromJson(Map<String, dynamic> json) => QuestionBlock(
    id: json['id'],
    type: json['type'],
    marks: json['marks'],
    choice: json['choice'],
    headerText: json['headerText'],
    sectionHeading: json['sectionHeading'] ?? '',
    startNumber: json['startNumber'] ?? 1,
    questions: (json['questions'] as List).map((e) => Question.fromJson(e)).toList(),
    showBubbleSheet: json['showBubbleSheet'] ?? false,
    bubbleSheetPosition: json['bubbleSheetPosition'] ?? 'end',
    bubbleOptions: json['bubbleOptions'] ?? 4,
  );
}

class PaperPage {
  int id;
  List<QuestionBlock> blocks;
  PaperPage({required this.id, required this.blocks});

  Map<String, dynamic> toJson() => {
    'id': id,
    'blocks': blocks.map((e) => e.toJson()).toList(),
  };

  factory PaperPage.fromJson(Map<String, dynamic> json) => PaperPage(
    id: json['id'],
    blocks: (json['blocks'] as List).map((e) => QuestionBlock.fromJson(e)).toList(),
  );
}

class TestArchitect extends StatefulWidget {
  final Map<String, dynamic>? initialPaper;
  const TestArchitect({super.key, this.initialPaper});

  @override
  State<TestArchitect> createState() => _TestArchitectState();
}

class _TestArchitectState extends State<TestArchitect> {
  final _uuid = const Uuid();

  String activeTab = "design";
  String instName = "MY INSTITUTION";
  String subject = "English";
  String targetClass = "General";
  String paperType = "Final";
  String duration = "3h";
  PaperLang lang = PaperLang.en;

  List<PaperPage> pages = [PaperPage(id: 1, blocks: [])];
  int currentPageIndex = 0;

  String activeType = "";
  bool configOpen = false;
  String customStatement = "";
  late TextEditingController qtyController;
  late TextEditingController choiceController;
  late TextEditingController marksController;
  late TextEditingController instNameController;

  List<Map<String, dynamic>> pendingVault = [];
  List<Map<String, dynamic>> architectVault = [];
  String? editingPaperId;

  String institutionalNotice = "Note: Mobile phones and calculators are strictly prohibited. Use of lead pencil is not allowed.";

  final double a4Width = 595.0;
  final Color primaryColor = const Color(0xFF1A237E);

  bool _isGeneratingPdf = false;
  Uint8List? _logoBytes;
  String _logoShape = 'circle';

  final Map<PaperLang, Map<String, String>> langMap = {
    PaperLang.en: { "sub":"SUB", "class":"CLASS", "type":"TYPE", "time":"TIME", "mcq":"Multiple Choice Questions", "short":"Short Questions", "long":"Long Questions", "subject":"Subject", "class_label":"Class", "type_label":"Type", "time_label":"Time" },
    PaperLang.ur: { "sub":"مضمون", "class":"جماعت", "type":"قسم", "time":"وقت", "mcq":"کثیر الانتخابی سوالات", "short":"مختصر سوالات", "long":"انشائیہ سوالات", "subject":"مضمون", "class_label":"جماعت", "type_label":"قسم", "time_label":"وقت" },
    PaperLang.ar: { "sub":"المادة", "class":"الصف", "type":"نوع", "time":"وقت", "mcq":"أسئلة الاختيار من متعدد", "short":"أسئلة قصيرة", "long":"أسئلة طويلة", "subject":"المادة", "class_label":"الصف", "type_label":"نوع", "time_label":"وقت" },
  };

  @override
  void initState() {
    super.initState();
    qtyController = TextEditingController(text: "1");
    choiceController = TextEditingController(text: "1");
    marksController = TextEditingController(text: "1");
    _bubbleOptController = TextEditingController(text: "4");
    _sectionHeadingController = TextEditingController();
    _startNumberController = TextEditingController(text: "1");
    instNameController = TextEditingController(text: instName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final paper = widget.initialPaper;
      if (paper != null) {
        _hydrateForEdit(paper);
      }
    });
  }

  @override
  void dispose() {
    qtyController.dispose();
    choiceController.dispose();
    marksController.dispose();
    instNameController.dispose();
    super.dispose();
  }

  Question _makeQuestion([String text = ""]) {
    return Question(id: _uuid.v4(), text: text, subParts: []);
  }

  String _getLocalizedNum(int n) {
    if (lang == PaperLang.en) return n.toString();
    const urduDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final digits = lang == PaperLang.ar ? arabicDigits : urduDigits;
    final isNegative = n < 0;
    final absStr = n.abs().toString();
    final result = absStr.split('').map((d) {
      final idx = int.tryParse(d);
      return idx != null ? digits[idx] : d;
    }).join('');
    return isNegative ? '-$result' : result;
  }

  String _getLocalizedOption(int index) {
    if (lang == PaperLang.en) return String.fromCharCode(97 + index);
    if (lang == PaperLang.ur) {
      const urduAlphas = ['الف', 'ب', 'ج', 'د'];
      return urduAlphas[index % 4];
    }
    if (lang == PaperLang.ar) {
      const arabicAlphas = ['أ', 'ب', 'ج', 'د'];
      return arabicAlphas[index % 4];
    }
    return String.fromCharCode(97 + index);
  }

  String _getLocalizedText(String key) {
    return langMap[lang]?[key.toLowerCase()] ?? key;
  }

  // --- ACTIONS ---
  void _addSectionToPaper() {
    int qty = int.tryParse(qtyController.text) ?? 1;
    int choice = int.tryParse(choiceController.text) ?? qty;
    int marks = int.tryParse(marksController.text) ?? 1;

    String hText = "";
    if (activeType == "Custom") {
      hText = customStatement.isEmpty ? "Section" : customStatement;
    } else {
      String mapKey = activeType == "MCQs" ? "mcq" : activeType == "Short" ? "short" : "long";
      hText = _getLocalizedText(mapKey);
    }

    setState(() {
      pages[currentPageIndex].blocks.add(QuestionBlock(
        id: _uuid.v4(),
        type: activeType,
        marks: marks,
        choice: choice,
        headerText: hText,
        sectionHeading: _sectionHeadingController.text.trim(),
        startNumber: int.tryParse(_startNumberController.text) ?? 1,
        questions: List.generate(qty, (_) => _makeQuestion()),
        showBubbleSheet: activeType == "MCQs" && _bubbleSheetForNew,
        bubbleSheetPosition: _bubbleSheetPosForNew,
        bubbleOptions: _bubbleOptionsForNew,
      ));
      configOpen = false;
    });
    _showStatus("${activeType} Added Successfully", true);
  }

  void _addSubPart(Question q, String blockType) {
    setState(() {
      String nextLabel;
      if (blockType == "MCQs") {
        nextLabel = _getLocalizedOption(q.subParts.length);
      } else {
        nextLabel = (q.subParts.length + 1).toString();
      }

      q.subParts.add(SubPart(
        id: _uuid.v4(),
        label: nextLabel,
        text: "",
      ));
    });
  }

  void _removeQuestion(QuestionBlock block, int index) {
    setState(() {
      block.questions.removeAt(index);
      // Automatically remove empty sections
      if (block.questions.isEmpty) {
        pages[currentPageIndex].blocks.remove(block);
      }
    });
  }

  void _updateLanguage(PaperLang newLang) {
    setState(() {
      lang = newLang;
      // Update Block Headers while keeping manual edits safe
      for (var page in pages) {
        for (var block in page.blocks) {
          String mapKey = block.type == "MCQs" ? "mcq" : block.type == "Short" ? "short" : "long";
          if (langMap[newLang]!.containsKey(mapKey)) {
            block.headerText = langMap[newLang]![mapKey]!;
          }
        }
      }
    });
  }

  void _manualCreatePage() {
    setState(() {
      pages.add(PaperPage(id: pages.length + 1, blocks: []));
      currentPageIndex = pages.length - 1;
    });
    _showStatus("New Page Created", true);
  }

  void _manualDeletePage() {
    if (pages.length == 1) {
      _showStatus("Cannot delete the first page", false);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Page"),
        content: Text("Are you sure you want to delete Page ${currentPageIndex + 1}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                pages.removeAt(currentPageIndex);
                for (int i = 0; i < pages.length; i++) {
                  pages[i].id = i + 1;
                }
                currentPageIndex = currentPageIndex > 0 ? currentPageIndex - 1 : 0;
              });
              _showStatus("Page Removed", false);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveToVault() async {
    TextEditingController nameCtrl = TextEditingController(text: "$subject Paper");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Name this Paper", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: "e.g. Midterm 2026"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              _executeSave(nameCtrl.text);
              Navigator.pop(context);
            },
            child: const Text("SAVE TO VAULT"),
          ),
        ],
      ),
    );
  }

  void _executeSave(String fileName) {
    final paperData = {
      "id": editingPaperId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      "fileName": fileName,
      "instName": instName,
      "subject": subject,
      "class": targetClass,
      "type": paperType,
      "notice": institutionalNotice,
      "pages": pages.map((e) => e.toJson()).toList(),
      "timestamp": DateTime.now().toString(),
    };

    setState(() {
      if (editingPaperId != null) {
        int idx = pendingVault.indexWhere((p) => p['id'] == editingPaperId);
        if (idx != -1) {
          pendingVault[idx] = paperData;
        }
        editingPaperId = null;
      } else {
        pendingVault.add(paperData);
      }
      activeTab = "vault";
    });
    _showStatus("Paper '$fileName' secured in Vault", true);
  }

  void _hydrateForEdit(Map<String, dynamic> paper) {
    setState(() {
      editingPaperId = paper['id'];
      instName = paper['instName'];
      subject = paper['subject'];
      targetClass = paper['class'];
      paperType = paper['type'];
      institutionalNotice = paper['notice'];
      pages = (paper['pages'] as List).map((e) => PaperPage.fromJson(e)).toList();
      activeTab = "design";
      currentPageIndex = 0;
    });
    instNameController.text = instName;
    _showStatus("Resuming Draft: ${paper['fileName'] ?? paper['subject']}", true);
  }

  Future<void> _installAsPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final generator = PaperPdfGenerator(
        instName: instName,
        subject: subject,
        targetClass: targetClass,
        paperType: paperType,
        duration: duration,
        lang: lang,
        institutionalNotice: institutionalNotice,
        pages: pages,
        logoBytes: _logoBytes,
        logoShape: _logoShape,
      );

      final path = await generator.generateAndInstall();
      if (mounted) _showStatus("PDF Installed: $path", true);
    } catch (e) {
      if (mounted) _showStatus("Installation Failed: $e", false);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _showStatus(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Deep midnight blue
      appBar: _buildSuperAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: activeTab == "design" ? _buildDesignView() : _buildVaultView(),
            ),
            if (activeTab == "design") _buildPublishFooter(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSuperAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text("PAPER DESIGNER PRO",
          style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            pages = [PaperPage(id: 1, blocks: [])];
            currentPageIndex = 0;
            editingPaperId = null;
          }),
          child: const Text("NEW PAPER", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _tabItem("DESIGN", activeTab == "design", () => setState(() => activeTab = "design")),
          _tabItem("VAULT", activeTab == "vault", () => setState(() => activeTab = "vault")),
        ],
      ),
    );
  }

  Widget _tabItem(String title, bool active, VoidCallback tap) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? primaryColor : Colors.transparent, width: 3)),
          ),
          child: Text(title, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? primaryColor : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildDesignView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBlueprintCard(),
          _buildPageControls(),
          _drawPaperCanvas(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildBlueprintCard() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("LANGUAGE LAYOUT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
          DropdownButton<PaperLang>(
            isExpanded: true,
            value: lang,
            items: const [
              DropdownMenuItem(value: PaperLang.en, child: Text("English (Standard)")),
              DropdownMenuItem(value: PaperLang.ur, child: Text("Urdu (Nastaliq RTL)")),
              DropdownMenuItem(value: PaperLang.ar, child: Text("Arabic (Modern Standard)")),
            ],
            onChanged: (v) => _updateLanguage(v!),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["MCQs", "Short", "Long", "Custom"].map((t) => _typeBtn(t)).toList(),
          ),
          if (configOpen) _buildConfigPanel(),
        ],
      ),
    );
  }

  Widget _typeBtn(String t) {
    bool selected = activeType == t;
    return InkWell(
      onTap: () => setState(() { activeType = t; configOpen = true; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          border: Border.all(color: selected ? primaryColor : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
      ),
    );
  }

  bool _bubbleSheetForNew = false;
  String _bubbleSheetPosForNew = 'end';
  int _bubbleOptionsForNew = 4;
  late TextEditingController _bubbleOptController;
  late TextEditingController _sectionHeadingController;
  late TextEditingController _startNumberController;

  Widget _buildConfigPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SECTION HEADING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          TextField(
            controller: _sectionHeadingController,
            decoration: const InputDecoration(
              hintText: "e.g. Section - I, Part - A, Objective ...",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text("QUESTION SETTINGS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          if (activeType == "Custom") ...[
            const SizedBox(height: 14),
            const Text("BLOCK HEADING (Custom)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              onChanged: (v) => customStatement = v,
              decoration: const InputDecoration(hintText: "e.g. Section, Part, etc.", border: OutlineInputBorder()),
            ),
          ],
          Row(
            children: [
              Expanded(child: _confInput("Qty", qtyController)),
              const SizedBox(width: 10),
              Expanded(child: _confInput("Attempt", choiceController)),
              const SizedBox(width: 10),
              Expanded(child: _confInput("Marks", marksController)),
              const SizedBox(width: 10),
              Expanded(child: _confInput("Start Q#", _startNumberController)),
            ],
          ),
          if (activeType == "MCQs") ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Bubble Sheet: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _bubbleSheetForNew = !_bubbleSheetForNew),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bubbleSheetForNew ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_bubbleSheetForNew ? "ON" : "OFF",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _bubbleSheetForNew ? Colors.white : Colors.black)),
                  ),
                ),
                if (_bubbleSheetForNew) ...[
                  const SizedBox(width: 8),
                  const Text("Pos:", style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  _posChip("Start"),
                  const SizedBox(width: 4),
                  _posChip("End"),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextField(
                      controller: _bubbleOptController,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _bubbleOptionsForNew = int.tryParse(v) ?? 4,
                      decoration: const InputDecoration(
                        hintText: "Opts",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _addSectionToPaper,
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, minimumSize: const Size(double.infinity, 45)),
            child: const Text("ADD SECTION"),
          )
        ],
      ),
    );
  }

  Widget _posChip(String pos) {
    final selected = _bubbleSheetPosForNew == pos.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _bubbleSheetPosForNew = pos.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          border: Border.all(color: selected ? primaryColor : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(pos, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
      ),
    );
  }



  Widget _confInput(String label, TextEditingController ctrl) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: label, filled: true, fillColor: Colors.white, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildPageControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => setState(() => currentPageIndex = currentPageIndex > 0 ? currentPageIndex - 1 : 0)),
              Text("PAGE ${currentPageIndex + 1} / ${pages.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), onPressed: () => setState(() => currentPageIndex = currentPageIndex < pages.length - 1 ? currentPageIndex + 1 : currentPageIndex)),
            ],
          ),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _manualCreatePage, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("+ ADD NEW PAGE"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: _manualDeletePage, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("DELETE THIS PAGE"))),
            ],
          )
        ],
      ),
    );
  }

  Widget _drawPaperCanvas() {
    PaperPage currentPage = pages[currentPageIndex];
    return Directionality(
      textDirection: lang == PaperLang.en ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        width: a4Width,
        constraints: const BoxConstraints(minHeight: 842),
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(40),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black54)]),
        child: Stack(
          children: [
            // The Watermark
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.05,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: const Text("MADE BY STARLIGHT",
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (currentPageIndex == 0) ...[
                  _buildPaperHeader(),
                ] else ...[
                  Column(
                    children: [
                      Text(instName.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_getLocalizedText('sub')}: $subject", style: const TextStyle(fontSize: 9)),
                          Text("${_getLocalizedText('class')}: $targetClass", style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                      const Divider(thickness: 1, color: Colors.black),
                    ],
                  ),
                ],
                ...currentPage.blocks.map((block) => _buildQuestionBlock(block)).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showLogoPicker(),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _logoBytes != null
                      ? (_logoShape == 'circle'
                          ? ClipOval(child: Image.memory(_logoBytes!, fit: BoxFit.cover))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                            ))
                      : const Icon(Icons.school, size: 40, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  children: [
                    _buildEditableField(instName, (v) => setState(() => instName = v),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center, controller: instNameController),
                    const Divider(color: Colors.black, thickness: 1),
                    _headerRow("subject", subject, (v) => setState(() => subject = v),
                        "class", targetClass, (v) => setState(() => targetClass = v)),
                    _headerRow("type", paperType, (v) => setState(() => paperType = v),
                        "time", duration, (v) => setState(() => duration = v)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _buildEditableField(institutionalNotice, (v) => setState(() => institutionalNotice = v),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
              hintText: "Enter paper notices here..."),
        ),
      ],
    );
  }

  Widget _buildEditableField(String value, Function(String) onChanged,
      {TextStyle? style, TextAlign textAlign = TextAlign.start, String? hintText, TextEditingController? controller}) {
    controller ??= TextEditingController(text: value);
    if (controller.text != value) {
      controller.text = value;
      controller.selection = TextSelection.fromPosition(TextPosition(offset: value.length));
    }
    return TextField(
      textAlign: textAlign,
      controller: controller,
      onChanged: onChanged,
      style: style ?? const TextStyle(fontSize: 10),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: hintText,
      ),
    );
  }

  Widget _headerRow(String key1, String v1, Function(String) c1, String key2, String v2, Function(String) c2) {
    String label1 = _getLocalizedText(key1);
    String label2 = _getLocalizedText(key2);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text("$label1: ", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Expanded(
                child: _buildEditableField(v1, c1,
                    style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text("$label2: ", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Expanded(
                child: _buildEditableField(v2, c2,
                    style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBlock(QuestionBlock block) {
    int totalAvailable = block.questions.length;
    String attemptText = (block.choice < totalAvailable)
        ? "Attempt any ${block.choice} from $totalAvailable"
        : "Attempt all questions";

    final questions = block.questions.asMap().entries.map((e) => _drawQuestionRow(block, e.value, e.key)).toList();
    final bubbleSheet = block.showBubbleSheet && block.type == "MCQs" ? _buildBubbleSheet(block) : null;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.sectionHeading.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(block.sectionHeading,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
              ),
            ),
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.headerText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(attemptText, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (block.type == "MCQs")
                      GestureDetector(
                        onTap: () => setState(() {
                          block.showBubbleSheet = !block.showBubbleSheet;
                          if (block.showBubbleSheet) block.bubbleSheetPosition = 'end';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: block.showBubbleSheet ? Colors.green : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text("Bubble ${block.showBubbleSheet ? "ON" : "OFF"}",
                              style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: block.showBubbleSheet ? Colors.white : Colors.black)),
                        ),
                      ),
                    if (block.showBubbleSheet) ...[
                      _bubblePosBtn(block, "S", "start"),
                      const SizedBox(width: 4),
                      _bubblePosBtn(block, "E", "end"),
                      const SizedBox(width: 8),
                    ],
                    Text("(${block.choice * block.marks} Marks)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          if (block.showBubbleSheet && block.bubbleSheetPosition == 'start' && bubbleSheet != null) bubbleSheet,
          ...questions,
          if (block.showBubbleSheet && block.bubbleSheetPosition == 'end' && bubbleSheet != null) bubbleSheet,
        ],
      ),
    );
  }

  Widget _bubblePosBtn(QuestionBlock block, String label, String pos) {
    final active = block.bubbleSheetPosition == pos;
    return GestureDetector(
      onTap: () => setState(() => block.bubbleSheetPosition = pos),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: active ? primaryColor : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  void _showLogoPicker() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Logo"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_logoBytes != null)
                Container(
                  width: 100, height: 100,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    shape: _logoShape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: _logoShape == 'square' ? BorderRadius.circular(8) : null,
                  ),
                  child: ClipRRect(
                    borderRadius: _logoShape == 'square' ? BorderRadius.circular(8) : (_logoShape == 'circle' ? BorderRadius.circular(50) : BorderRadius.zero),
                    child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _shapeChip("circle", "Circle", onChanged: () => setDialogState(() {})),
                  const SizedBox(width: 8),
                  _shapeChip("square", "Square", onChanged: () => setDialogState(() {})),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 120, maxHeight: 120);
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setState(() => _logoBytes = bytes);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text("Pick from Gallery"),
                ),
              ),
              if (_logoBytes != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _logoBytes = null);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text("Remove Logo", style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shapeChip(String value, String label, {VoidCallback? onChanged}) {
    final active = _logoShape == value;
    return GestureDetector(
      onTap: () {
        setState(() => _logoShape = value);
        onChanged?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget _buildBubbleSheet(QuestionBlock block) {
    final numQuestions = block.questions.length;
    final optionLabels = ['A', 'B', 'C', 'D'];
    final optionsPerQuestion = block.bubbleOptions;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("BUBBLE SHEET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          ),
          const Divider(thickness: 1, color: Colors.black),
          GestureDetector(
            onTap: () {
              final ctl = TextEditingController(text: block.bubbleOptions.toString());
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Bubble Sheet Options"),
                  content: TextField(
                    controller: ctl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Number of Options", border: OutlineInputBorder()),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () {
                        setState(() => block.bubbleOptions = int.tryParse(ctl.text) ?? block.bubbleOptions);
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              children: [
                const Icon(Icons.tune, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text("Options: ${block.bubbleOptions}", style: const TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.underline)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 30,
                child: Text("No.", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              ),
              const SizedBox(width: 8),
              ...optionLabels.take(optionsPerQuestion).map((label) {
                return Container(
                  width: 24,
                  alignment: Alignment.center,
                  child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                );
              }),
            ],
          ),
          const Divider(thickness: 0.5, color: Colors.grey),
          // Question rows with bubbles
          ...List.generate(numQuestions, (qIdx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(_getLocalizedNum(block.startNumber + qIdx), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(optionsPerQuestion, (optIdx) {
                    return Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _drawQuestionRow(QuestionBlock block, Question q, int index) {
    bool isMCQ = block.type == "MCQs";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${_getLocalizedNum(block.startNumber + index)}. ",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: _buildEditableField(q.text, (v) => setState(() => q.text = v),
                    style: const TextStyle(fontSize: 12),
                    hintText: block.type == "Long" ? "Leave empty for direct parts..." : "Question text..."),
              ),
              _rowActions(block, q, index),
            ],
          ),
          if (q.subParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 15),
              child: Wrap(
                spacing: 15,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                children: q.subParts.asMap().entries.map((entry) {
                  int spIndex = entry.key;
                  SubPart sp = entry.value;
                  double itemWidth = isMCQ ? (a4Width - 120) / 2 : (a4Width - 100);

                  String displayLabel = _getLocalizedOption(spIndex);

                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text("($displayLabel) ",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: _buildEditableField(sp.text, (v) => setState(() => sp.text = v),
                                style: const TextStyle(fontSize: 11)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 12, color: Colors.red),
                            onPressed: () => setState(() => q.subParts.remove(sp)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
        ],
      ),
    );
  }

  Widget _rowActions(QuestionBlock block, Question q, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.add_box, color: Colors.blue, size: 18), onPressed: () => _addSubPart(q, block.type)),
        IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 18), onPressed: () => setState(() => block.questions.insert(index + 1, _makeQuestion()))),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => _removeQuestion(block, index)),
      ],
    );
  }

  Widget _buildPublishFooter() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isGeneratingPdf ? null : _installAsPdf,
              icon: _isGeneratingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
              label: Text(_isGeneratingPdf ? "GENERATING..." : "PRINT PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveToVault,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("SAVE TO VAULT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultView() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _vaultSection("PENDING PAPERS", pendingVault),
        const SizedBox(height: 20),
        _vaultSection("ARCHITECTED VAULT", architectVault),
      ],
    );
  }

  Widget _vaultSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Text("No Papers Found", style: TextStyle(color: Colors.white70, fontSize: 10))
        else
          ...items.map((item) => Card(
            child: ListTile(
              title: Text(item['fileName'] ?? item['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Modified: ${item['timestamp'].toString().substring(0,16)}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _hydrateForEdit(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                    onPressed: () {
                      _hydrateForEdit(item);
                      _installAsPdf();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDeleteVaultItem(items, item),
                  ),
                ],
              ),
            ),
          )).toList(),
      ],
    );
  }

  void _confirmDeleteVaultItem(List<Map<String, dynamic>> items, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Paper"),
        content: Text("Delete '${item['fileName'] ?? item['subject']}' from vault?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => items.remove(item));
              _showStatus("Paper deleted", false);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}