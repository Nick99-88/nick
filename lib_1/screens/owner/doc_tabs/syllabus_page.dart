import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import 'blueprint_overlay.dart';


class SyllabusPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const SyllabusPage({super.key, this.initialData});

  @override
  State<SyllabusPage> createState() => _SyllabusPageState();
}

class _SyllabusPageState extends State<SyllabusPage> {
  // Constants & Styles
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);
  final Color bgColor = const Color(0xFFF0F2F5);

  // State Variables
  String activeTab = 'architect'; // 'architect' or 'pending'
  String institutionName = "INSTITUTION";
  List<String> availableSections = [];
  Set<String> selectedSections = {};
  List<String> subjectTags = [];
  List<Map<String, dynamic>> syllabusContent = [];
  List<dynamic> pendingVaultList = [];
  bool isLoadingSections = true;

  // Controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _docNameController = TextEditingController();
  bool isFinalized = false;
  bool isSyncing = false;
  String? currentSyllabusId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchSections();
    await fetchPendingVault();

    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _docNameController.text = data['title'] ?? data['name'] ?? '';
        currentSyllabusId = data['id']?.toString();
        isFinalized = data['is_final'] == true;

        // Populate subject tags
        final String rawSubject = data['subject'] ?? '';
        if (rawSubject.isNotEmpty) {
          subjectTags = rawSubject.split(', ').map((e) => e.trim()).toList();
        }

        // Populate targets (sections)
        final rawTargets = data['targets'] ?? data['details']?['Targets'];
        if (rawTargets != null) {
          if (rawTargets is List) {
            selectedSections = Set<String>.from(rawTargets.map((e) => e.toString()));
          } else if (rawTargets is String) {
            try {
              final decoded = jsonDecode(rawTargets);
              if (decoded is List) {
                selectedSections = Set<String>.from(decoded.map((e) => e.toString()));
              }
            } catch (_) {}
          }
        }

        // Populate content (chapters/topics) with safe nested map casting
        final rawContent = data['content'];
        if (rawContent != null) {
          if (rawContent is List) {
            syllabusContent = rawContent.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          } else if (rawContent is String) {
            try {
              final decoded = jsonDecode(rawContent);
              if (decoded is List) {
                syllabusContent = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
              }
            } catch (_) {}
          }
        }
      });
    }
  }

  // --- API LOGIC ---

  Future<void> fetchSections() async {
    setState(() => isLoadingSections = true);
    try {

      final token = await StarlightStorage.getUserToken();

      final res = await http.get(
        Uri.parse('$apiBase/dashboard/sections'),
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
        _showNotify("Institutional error: ${res.statusCode}", false);
      }
    } catch (e) {
      setState(() => isLoadingSections = false);
      _showNotify("Network Link Failed", false);
    }
  }

  Future<void> fetchPendingVault() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('$apiBase/document/pending/list'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => pendingVaultList = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Pending Load Fail: $e");
    }
  }

  Future<void> handleDeployment() async {
    setState(() => isSyncing = true);

    final payload = {
      "id": currentSyllabusId,
      "name": _docNameController.text,
      "targets": selectedSections.toList(),
      "subject": subjectTags.join(', '),
      "date": "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      "is_final": isFinalized,
      "content": syllabusContent,
    };

    String endpoint = isFinalized
        ? '$apiBase/document/vault/upload'
        : '$apiBase/document/pending/sync';

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        if (isFinalized) {
          _showNotify("Deployed Officially", true);
        } else {
          _showNotify("Synced to Institutional Vault", true);
          setState(() {
            activeTab = 'pending';
            currentSyllabusId = null;
            syllabusContent.clear();
          });
          fetchPendingVault();
        }
        Navigator.pop(context);
      } else {
        _showNotify("Server Error", false);
      }
    } catch (e) {
      _showNotify("Network Error", false);
    } finally {
      setState(() => isSyncing = false);
    }
  }

  // --- UI BUILDERS ---

  void _showNotify(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool isBlueprintOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.white,
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(institutionName,
                    style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                centerTitle: true,
              ),
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    _buildTab("ARCHITECT", 'architect'),
                    _buildTab("PENDING VAULT", 'pending'),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: activeTab == 'architect'
                      ? _buildArchitectView()
                      : _buildPendingView(),
                ),
              ),
            ],
          ),
          BlueprintOverlay(
            isOpen: isBlueprintOpen,
            onClose: () => setState(() => isBlueprintOpen = false),
          ),
        ],
      ),
      floatingActionButton: activeTab == 'architect'
          ? FloatingActionButton.extended(
        onPressed: () => setState(() => isBlueprintOpen = !isBlueprintOpen),
        backgroundColor: secondaryColor,
        icon: const Icon(Icons.account_tree_rounded, color: Colors.white),
        label: const Text("Blueprints",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      )
          : null,
      bottomNavigationBar: activeTab == 'architect'
          ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: ElevatedButton(
          onPressed: () => _showDeploymentModal(),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: 10,
          ),
          child: const Text("Deploy Official Syllabus",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      )
          : null,
    );
  }

  Widget _buildTab(String label, String key) {
    bool isActive = activeTab == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => activeTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
                color: isActive ? primaryColor : Colors.transparent, width: 3)),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: isActive ? primaryColor : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildArchitectView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("1. SELECT CLASS SECTIONS",
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.5)),
              const SizedBox(height: 15),
              isLoadingSections
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : availableSections.isEmpty
                  ? Text("No active sections found in DB",
                  style: TextStyle(color: Colors.grey.shade400,
                      fontSize: 12,
                      fontStyle: FontStyle.italic))
                  : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableSections
                    .map((s) => _buildSectionPill(s))
                    .toList(),
              ),
              const SizedBox(height: 25),
              Text("2. ADD SUBJECT AREAS",
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200)
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subjectController,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter subject (e.g. Physics)...",
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey)
                        ),
                        onSubmitted: (val) => _addSubjectTag(),
                      ),
                    ),
                    TextButton(
                      onPressed: _addSubjectTag,
                      child: Text("ADD", style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.w900)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subjectTags.map((tag) => _buildTag(tag)).toList(),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _generateCollaboratorWorkspace,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0
                  ),
                  child: const Text("Initialize Collaborator Workspace",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 30),
        ...syllabusContent
            .asMap()
            .entries
            .map((entry) => _buildBookSection(entry.key, entry.value)),
        const SizedBox(height: 10),

        // 🏛️ Manual Dotted Border Implementation (Replacing DottedBorder package)
        CustomPaint(
          painter: _DashedRectPainter(color: const Color(0xFFBDBDBD), strokeWidth: 1, gap: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _addBook(""),
              child: Container(
                width: double.infinity,
                height: 55,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                ),
                child: const Text(
                  "+ Add Custom Subject Area",
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionPill(String s) {
    bool isSel = selectedSections.contains(s);
    return InkWell(
      onTap: () => setState(() => isSel ? selectedSections.remove(s) : selectedSections.add(s)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? primaryColor : Colors.grey.shade300),
        ),
        child: Text(s, style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Chip(
      label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: secondaryColor,
      deleteIcon: const Icon(Icons.close, color: Colors.white, size: 14),
      onDeleted: () => setState(() => subjectTags.remove(tag)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildBookSection(int index, Map<String, dynamic> book) {
    if (book['chapters'] == null) {
      book['chapters'] = [];
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            color: const Color(0xFFF8F9FA),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: book['title']),
                    onChanged: (v) => book['title'] = v,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => syllabusContent.removeAt(index))),
              ],
            ),
          ),
          ...book['chapters'].asMap().entries.map<Widget>((chEntry) => _buildChapterRow(book, chEntry.key, chEntry.value as Map<String, dynamic>)),
          InkWell(
            onTap: () => _addChapter(book),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFE1F5FE),
              child: Text("+ Add Chapter", textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChapterRow(Map<String, dynamic> book, int chIndex, Map<String, dynamic> chapter) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: TextEditingController(text: chapter['name']),
            onChanged: (v) => chapter['name'] = v,
            decoration: const InputDecoration(hintText: "Chapter Name", isDense: true),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...chapter['topics'].asMap().entries.map((tEntry) => TextField(
            controller: TextEditingController(text: tEntry.value),
            onChanged: (v) => chapter['topics'][tEntry.key] = v,
            decoration: const InputDecoration(hintText: "• Topic detail", border: InputBorder.none),
            style: const TextStyle(fontSize: 13),
          )),
          TextButton(
            onPressed: () => setState(() => chapter['topics'].add("")),
            child: Text("+ Add Topic", style: TextStyle(color: primaryColor, fontSize: 11)),
          )
        ],
      ),
    );
  }

  void _addSubjectTag() {
    if (_subjectController.text.trim().isNotEmpty) {
      setState(() {
        subjectTags.add(_subjectController.text.trim());
        _subjectController.clear();
      });
    }
  }

  void _generateCollaboratorWorkspace() {
    if (selectedSections.isEmpty || subjectTags.isEmpty) {
      _showNotify("Select Section & Subject first", false);
      return;
    }
    for (var sec in selectedSections) {
      for (var sub in subjectTags) {
        _addBook("$sec - $sub");
      }
    }
  }

  void _addBook(String title) {
    setState(() {
      syllabusContent.add({
        "title": title,
        "chapters": [
          {"name": "", "topics": [""]}
        ]
      });
    });
  }

  void _addChapter(Map<String, dynamic> book) {
    setState(() {
      book['chapters'].add({"name": "", "topics": [""]});
    });
  }

  Widget _buildPendingView() {
    return Column(
      children: pendingVaultList.map((d) => Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(d['subject'], style: TextStyle(color: primaryColor, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _resumeFromDB(d),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text("EDIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _deleteDraft(d['id']),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFEBEE), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            )
          ],
        ),
      )).toList(),
    );
  }

  void _resumeFromDB(Map<String, dynamic> d) {
    setState(() {
      currentSyllabusId = d['id'];
      _docNameController.text = d['name'];
      syllabusContent = List<Map<String, dynamic>>.from(d['content']);
      activeTab = 'architect';
    });
    _showNotify("Collaborative Draft Loaded", true);
  }

  Future<void> _deleteDraft(dynamic id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Remove this draft from the vault?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.delete(Uri.parse('$apiBase/document/pending/delete/$id'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        _showNotify("Draft Removed", true);
        fetchPendingVault();
      }
    } catch (e) {
      _showNotify("Delete failed", false);
    }
  }

  void _showDeploymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Collaborative Sync", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _docNameController,
                decoration: InputDecoration(
                  hintText: "Document Name (e.g. Mid-Term 2026)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Finalized for Printing?", style: TextStyle(fontWeight: FontWeight.bold)),
                  Switch(value: isFinalized, onChanged: (v) => setModalState(() => isFinalized = v)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200), child: const Text("Cancel"))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isSyncing ? null : () async {
                        setModalState(() => isSyncing = true);
                        await handleDeployment();
                        setModalState(() => isSyncing = false);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(isSyncing ? "Syncing..." : "Sync with DB", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// 🏛️ Custom Dash/Dotted Border Painter
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedRectPainter({required this.color, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rRect = RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(12));
    final Path path = Path()..addRRect(rRect);

    // Create a dashed effect
    final Path dashedPath = Path();
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(_DashedRectPainter oldDelegate) => false;
}