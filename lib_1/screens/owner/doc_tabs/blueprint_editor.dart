import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';

class BlueprintEditor extends StatefulWidget {
  final String? blueprintId;
  final Map<String, dynamic>? existingBlueprint;
  final String? blueprintType;
  
  const BlueprintEditor({super.key, this.blueprintId, this.existingBlueprint, this.blueprintType});

  @override
  State<BlueprintEditor> createState() => _BlueprintEditorState();
}

class _BlueprintEditorState extends State<BlueprintEditor> {
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);

  double globalHeaderHeight = 60.0;
  bool showRowHeaders = true;
  bool isSaving = false;
  bool isLoading = false;

  List<Map<String, dynamic>> columns = [
    {'title': 'TOPIC NAME', 'width': 180.0, 'mapKey': 'topic_title'},
    {'title': 'OBJECTIVES', 'width': 220.0, 'mapKey': 'learning_goals'},
    {'title': 'STATUS', 'width': 100.0, 'mapKey': 'completion_status'},
  ];

  List<Map<String, dynamic>> rows = [
    {'title': 'Unit 1', 'height': 85.0},
    {'title': 'Unit 2', 'height': 85.0},
  ];

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingBlueprint();
  }

  Future<void> _loadExistingBlueprint() async {
    if (widget.blueprintId == null) return;
    
    // If existingBlueprint is passed directly, use it
    if (widget.existingBlueprint != null) {
      _populateFromBlueprint(widget.existingBlueprint!);
      return;
    }
    
    // Otherwise fetch from server
    setState(() => isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('$apiBase/document/blueprint/${widget.blueprintId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['blueprint'] != null) {
          _populateFromBlueprint(data['blueprint']);
        }
      }
    } catch (e) {
      debugPrint("Error loading blueprint: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _populateFromBlueprint(Map<String, dynamic> bp) {
    setState(() {
      globalHeaderHeight = (bp['global_header_height'] ?? 60.0).toDouble();
      showRowHeaders = bp['show_row_headers'] ?? true;
      
      if (bp['columns'] != null) {
        columns = List<Map<String, dynamic>>.from(bp['columns']);
      }
      
      if (bp['rows'] != null) {
        rows = List<Map<String, dynamic>>.from(bp['rows']);
      }
      
      _noteController.text = bp['footer_note'] ?? '';
    });
  }

  double get totalTableWidth {
    double base = showRowHeaders ? 100.0 : 0.0;
    double cols = columns.fold(0.0, (sum, item) => sum + (item['width'] as double));
    return base + cols + (columns.length * 4);
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> saveBlueprintToDB() async {
    setState(() => isSaving = true);
    
    final isEditing = widget.blueprintId != null;
    final String bpType = widget.blueprintType ?? widget.existingBlueprint?['type'] ?? "syllabus_blueprint";
    final payload = {
      "type": bpType,
      "title": isEditing 
          ? "$bpType (Updated)"
          : "$bpType ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      "global_header_height": globalHeaderHeight,
      "show_row_headers": showRowHeaders,
      "columns": columns,
      "rows": rows,
      "footer_note": _noteController.text,
      if (!isEditing) "created_at": DateTime.now().toIso8601String(),
    };

    try {
      final token = await StarlightStorage.getUserToken();
      
      http.Response res;
      if (isEditing) {
        // Update existing blueprint
        res = await http.put(
          Uri.parse('$apiBase/document/blueprint/${widget.blueprintId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(payload),
        );
      } else {
        // Create new blueprint
        res = await http.post(
          Uri.parse('$apiBase/document/blueprint/save'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showNotify(isEditing ? "Blueprint Updated" : "Blueprint Saved to Vault", true);
        } else {
          _showNotify("Error: ${data['message'] ?? 'Unknown error'}", false);
        }
      } else {
        _showNotify("Server Error: ${res.statusCode}", false);
      }
    } catch (e) {
      _showNotify("Network Error: $e", false);
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _showNotify(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("BLUEPRINT ARCHITECT", 
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF263238), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Quick toggle for the Vertical Parallel Header
          Row(
            children: [
              const Text("ROW HEADER", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
              Switch(
                value: showRowHeaders,
                onChanged: (v) => setState(() => showRowHeaders = v),
                activeColor: primaryColor,
              ),
            ],
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.white,
                child: Row(
                  children: [
                    _buildHeightSlider(),
                    const Spacer(),
                    _buildActionBtn("ADD COL", Icons.view_column_rounded, () {
                      setState(() => columns.add({'title': 'NEW COL', 'width': 120.0, 'mapKey': 'custom_field'}));
                    }),
                    const SizedBox(width: 8),
                    _buildActionBtn("ADD ROW", Icons.format_line_spacing_rounded, () {
                      setState(() => rows.add({'title': 'New Row', 'height': 80.0}));
                    }),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showRowHeaders) _buildCornerNode(),
                            ...columns.asMap().entries.map((e) => _buildColumnNode(e.key, e.value)),
                          ],
                        ),
                        ...rows.asMap().entries.map((r) => Row(
                          children: [
                            if (showRowHeaders) _buildRowHeader(r.key, r.value),
                            ...columns.map((c) => _buildDataCell(c['width'], r.value['height'], c['mapKey'])),
                          ],
                        )),
                        const SizedBox(height: 40),
                        _buildFooterNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Loading overlay when fetching existing blueprint
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Loading Blueprint...", style: TextStyle(color: Color(0xFF263238))),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
        ),
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : saveBlueprintToDB,
          icon: isSaving 
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(widget.blueprintId != null ? Icons.save : Icons.cloud_upload_rounded, size: 18),
          label: Text(
            isSaving 
              ? (widget.blueprintId != null ? "UPDATING..." : "SYNCING STRUCTURE...")
              : (widget.blueprintId != null ? "UPDATE BLUEPRINT" : "SAVE BLUEPRINT TO VAULT"), 
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }

  // --- REUSABLE UI NODES ---

  Widget _buildColumnNode(int index, Map<String, dynamic> col) {
    return Container(
      width: col['width'],
      height: globalHeaderHeight,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: secondaryColor, borderRadius: BorderRadius.circular(6)),
      child: Stack(
        children: [
          Positioned(
            top: 2, right: 2,
            child: InkWell(
              onTap: () => setState(() => columns.removeAt(index)),
              child: const Icon(Icons.cancel, color: Colors.redAccent, size: 14),
            ),
          ),
          Center(
            child: TextField(
              controller: TextEditingController(text: col['title']),
              onChanged: (v) => col['title'] = v,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => setState(() => col['width'] = (col['width'] + d.delta.dx).clamp(60.0, 400.0)),
              child: const Icon(Icons.unfold_more_rounded, color: Colors.white24, size: 14),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRowHeader(int index, Map<String, dynamic> row) {
    return Container(
      width: 100, height: row['height'],
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
      child: Stack(
        children: [
          Positioned(
            top: 4, left: 4,
            child: InkWell(
              onTap: () => setState(() => rows.removeAt(index)),
              child: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 14),
            ),
          ),
          Center(child: Text(row['title'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onVerticalDragUpdate: (d) => setState(() => row['height'] = (row['height'] + d.delta.dy).clamp(50.0, 300.0)),
              child: const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeightSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HEADER HEIGHT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
        SizedBox(
          width: 150,
          child: Slider(
            value: globalHeaderHeight, min: 40, max: 120,
            activeColor: primaryColor,
            onChanged: (v) => setState(() => globalHeaderHeight = v),
          ),
        ),
      ],
    );
  }

  Widget _buildDataCell(double w, double h, String key) {
    return Container(
      width: w, height: h,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(4)),
      child: Center(
        child: Text("{{$key}}", style: TextStyle(color: primaryColor.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      width: totalTableWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("INSTITUTIONAL NOTES / FOOTER", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Colors.grey)),
          const Divider(),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "Enter footer instructions...", border: InputBorder.none),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerNode() {
    return Container(
      width: 100, height: globalHeaderHeight,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(6)),
      child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: secondaryColor, foregroundColor: Colors.white),
    );
  }
}