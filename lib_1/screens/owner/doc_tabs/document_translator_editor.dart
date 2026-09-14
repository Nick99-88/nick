import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../services/institution/document_service.dart';

class DocumentTranslatorEditor extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const DocumentTranslatorEditor({
    super.key,
    required this.initialData,
  });

  @override
  State<DocumentTranslatorEditor> createState() => _DocumentTranslatorEditorState();
}

class _DocumentTranslatorEditorState extends State<DocumentTranslatorEditor> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DocumentService _docService = DocumentService();

  late String docId;
  late String docTitle;
  List<Map<String, dynamic>> segments = [];

  int? _selectedSegmentIndex;
  final TextEditingController _consoleController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    docId = widget.initialData['id']?.toString() ?? '';
    docTitle = widget.initialData['name']?.toString() ?? 'Untitled Document';
    _titleController.text = docTitle;

    // Parse bilingual content list of maps
    final rawContent = widget.initialData['content'];
    if (rawContent is List) {
      segments = rawContent.map((item) {
        if (item is Map) {
          return {
            'title': item['title']?.toString() ?? '',
            'translated_text': item['translated_text']?.toString() ?? '',
          };
        }
        return {'title': item.toString(), 'translated_text': ''};
      }).toList();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _consoleController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _selectSegment(int index, bool isOriginalTab) {
    setState(() {
      _selectedSegmentIndex = index;
      _consoleController.text = isOriginalTab 
          ? segments[index]['title'] 
          : segments[index]['translated_text'];
    });
    
    // Log selected text to print console
    print("🎯 [CONSOLE SELECTED] Index: $index | Tab: ${isOriginalTab ? 'Original' : 'Translated'} | Text: ${_consoleController.text}");
  }

  void _updateSegmentText(bool isOriginalTab) {
    if (_selectedSegmentIndex == null) return;
    setState(() {
      if (isOriginalTab) {
        segments[_selectedSegmentIndex!]['title'] = _consoleController.text;
      } else {
        segments[_selectedSegmentIndex!]['translated_text'] = _consoleController.text;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Segment updated in local workspace.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.indigo),
    );
  }

  Future<void> _saveAllChanges() async {
    setState(() => _isSaving = true);
    try {
      await _docService.updateDocument(docId, _titleController.text, segments);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Translation changes saved to Starlight Vault Database!", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving changes: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Tech Midnight
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("TRANSLATOR CODES EDITOR", 
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isSaving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
              : const Icon(Icons.cloud_done_rounded, color: Colors.cyanAccent),
            onPressed: _isSaving ? null : _saveAllChanges,
          ),
        ],
      ),
      body: Column(
        children: [
          // Title Editor Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              decoration: const InputDecoration(
                labelText: "Document Title",
                labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ),

          // Custom Tabs Header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.cyanAccent,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(child: Text("ORIGINAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1))),
                Tab(child: Text("TRANSLATED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1))),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSegmentsList(isOriginalTab: true),
                _buildSegmentsList(isOriginalTab: false),
              ],
            ),
          ),

          // Bottom Console Editor Panel
          _buildConsoleEditorPanel(),
        ],
      ),
    );
  }

  Widget _buildSegmentsList({required bool isOriginalTab}) {
    if (segments.isEmpty) {
      return const Center(child: Text("No segments found in this document.", style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final bool isSelected = _selectedSegmentIndex == index;
        final String text = isOriginalTab 
            ? segments[index]['title'] 
            : segments[index]['translated_text'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyanAccent.withOpacity(0.08) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white10, width: 1.5),
          ),
          child: ListTile(
            dense: true,
            title: Text(text.isNotEmpty ? text : "[Empty segment]", 
              style: TextStyle(
                color: text.isNotEmpty ? Colors.white : Colors.white24, 
                fontSize: isOriginalTab ? 13 : 14,
                fontFamily: isOriginalTab ? null : 'NotoNastaliqUrdu',
                height: isOriginalTab ? 1.3 : 1.6,
              ),
            ),
            trailing: isSelected 
              ? const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.cyanAccent) 
              : const Icon(Icons.gesture, color: Colors.white24, size: 16),
            onTap: () => _selectSegment(index, isOriginalTab),
          ),
        );
      },
    );
  }

  Widget _buildConsoleEditorPanel() {
    final bool hasSelection = _selectedSegmentIndex != null;
    final bool isOriginalTab = _tabController.index == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasSelection 
                  ? "EDITING WORKSPACE: SEGMENT #${_selectedSegmentIndex! + 1}" 
                  : "SELECT A SEGMENT ABOVE TO EDIT",
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              if (hasSelection)
                TextButton.icon(
                  onPressed: () => _updateSegmentText(isOriginalTab),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.cyanAccent),
                  label: const Text("APPLY TO LIST", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _consoleController,
            enabled: hasSelection,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Terminal editor console...",
              hintStyle: const TextStyle(color: Colors.white10),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}
