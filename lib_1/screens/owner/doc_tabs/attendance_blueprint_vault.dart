import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/storage.dart';
import '../../../core/database_helper.dart';

class TableColumnDef {
  String id;
  String header;
  double width; 

  TableColumnDef({required this.id, required this.header, this.width = 100.0});
}

class AttendanceBlueprintVault extends StatefulWidget {
  final Map<String, dynamic>? existingBlueprint;
  const AttendanceBlueprintVault({super.key, this.existingBlueprint});

  @override
  State<AttendanceBlueprintVault> createState() => _AttendanceBlueprintVaultState();
}

class _AttendanceBlueprintVaultState extends State<AttendanceBlueprintVault> {
  // --- Branding & Paper State ---
  String instName = "STARLIGHT INSTITUTION";
  String sheetTitle = "Daily Attendance Architecture";
  String selectedDay = "Monday";
  int rowCount = 20;
  bool showLogo = true;
  bool _isSaving = false;

  Future<void> _saveBlueprint() async {
    setState(() => _isSaving = true);
    final isEditing = widget.existingBlueprint != null;

    final payload = {
      "type": "attendance_blueprint",
      "title": sheetTitle.isEmpty ? "Daily Attendance Architecture" : sheetTitle,
      "global_header_height": 60.0,
      "show_row_headers": false,
      "columns": columns.map((col) => {
        "title": col.header,
        "width": col.width,
        "mapKey": col.id,
      }).toList(),
      "rows": List.generate(rowCount, (index) => {
        "title": "Slot ${index + 1}",
        "height": 35.0,
      }),
      "footer_note": "Day: $selectedDay | Institution: $instName | Logo: $showLogo",
    };

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        _showSignBox("Authentication failed. Token not found.", false);
        setState(() => _isSaving = false);
        return;
      }

      final response = isEditing
          ? await http.put(
              Uri.parse('https://api.institution.site/document/blueprint/${widget.existingBlueprint!['id']}'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse('https://api.institution.site/document/blueprint/save'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Robust Local SQLite Backup Sync
          final db = await StarlightVault.instance.database;
          
          if (isEditing) {
            await db.update(
              'universal_blueprints',
              {
                'blueprint_name': sheetTitle.isEmpty ? "Daily Attendance Architecture" : sheetTitle,
                'columns_config': jsonEncode(payload['columns']),
                'rows_config': jsonEncode(payload['rows']),
                'footer_note': payload['footer_note'],
                'sync_status': 'done',
              },
              where: 'server_id = ?',
              whereArgs: [widget.existingBlueprint!['id'].toString()],
            );
          } else {
            await db.insert(
              'universal_blueprints',
              {
                'server_id': data['id']?.toString(),
                'blueprint_name': sheetTitle.isEmpty ? "Daily Attendance Architecture" : sheetTitle,
                'columns_config': jsonEncode(payload['columns']),
                'rows_config': jsonEncode(payload['rows']),
                'footer_note': payload['footer_note'],
                'sync_status': 'done',
              },
            );
          }

          _showSignBox(isEditing ? "Architecture Blueprint Updated" : "Architecture Blueprint Saved to Institution Vault", true);
        } else {
          _showSignBox("Failed to save: ${data['message'] ?? 'Unknown error'}", false);
        }
      } else {
        _showSignBox("Server Error: ${response.statusCode}", false);
      }
    } catch (e) {
      _showSignBox("Network Error: $e", false);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- Table Architecture State ---
  List<TableColumnDef> columns = [
    TableColumnDef(id: '1', header: "Sr#", width: 50),
    TableColumnDef(id: '2', header: "Staff Name", width: 200),
    TableColumnDef(id: '3', header: "Signature", width: 120),
    TableColumnDef(id: '4', header: "Remarks", width: 150),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingBlueprint != null) {
      final bp = widget.existingBlueprint!;
      sheetTitle = bp['title'] ?? sheetTitle;
      
      final String footer = bp['footer_note'] ?? '';
      if (footer.isNotEmpty) {
        final parts = footer.split('|');
        for (var part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('Day:')) {
            selectedDay = trimmed.substring(4).trim();
          } else if (trimmed.startsWith('Institution:')) {
            instName = trimmed.substring(12).trim();
          } else if (trimmed.startsWith('Logo:')) {
            showLogo = trimmed.substring(5).trim().toLowerCase() == 'true';
          }
        }
      }

      if (bp['columns'] != null) {
        final List<dynamic> colsRaw = bp['columns'] is String 
            ? jsonDecode(bp['columns']) 
            : bp['columns'];
        columns = colsRaw.map((c) => TableColumnDef(
          id: c['mapKey']?.toString() ?? DateTime.now().toString(),
          header: c['title'] ?? 'New Col',
          width: (c['width'] ?? 100.0).toDouble(),
        )).toList();
      }

      if (bp['rows'] != null) {
        final List<dynamic> rowsRaw = bp['rows'] is String 
            ? jsonDecode(bp['rows']) 
            : bp['rows'];
        rowCount = rowsRaw.length;
      }
    }
  }

  final List<String> weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  // Precision Width Logic
  double get totalSheetWidth => columns.fold(0.0, (sum, col) => sum + col.width) + 80;

  void _addColumn() {
    setState(() => columns.add(TableColumnDef(id: DateTime.now().toString(), header: "New Col", width: 100)));
  }

  void _showSignBox(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: success ? Colors.green : Colors.red, 
        behavior: SnackBarBehavior.floating
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("SHEET ARCHITECT CONSOLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // LEFT SIDE: MANAGEMENT CONSOLE
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02), 
                      border: const Border(right: BorderSide(color: Colors.white10))
                    ),
                    child: _buildManagementConsole(),
                  ),
                ),
                // RIGHT SIDE: DYNAMIC CANVAS PREVIEW
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black26, 
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: _buildPaperPreview(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionFooter(),
        ],
      ),
    );
  }

  Widget _buildManagementConsole() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), // Gain horizontal space
      children: [
        _sectionHeader("HEADER & LOGO ARCHITECT"),
        _consoleInput("Institution Name", (v) => setState(() => instName = v), instName),
        _consoleInput("Sheet Title", (v) => setState(() => sheetTitle = v), sheetTitle),
        
        const SizedBox(height: 15),
        // Compact Logo Toggle Row to prevent overflow
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text("Include Institution Logo", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: showLogo,
                activeColor: Colors.cyanAccent,
                onChanged: (v) => setState(() => showLogo = v),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Text("Select Day", style: TextStyle(color: Colors.white38, fontSize: 10)),
        DropdownButton<String>(
          value: selectedDay,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
          items: weekDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => selectedDay = v!),
        ),

        const SizedBox(height: 30),
        _sectionHeader("COLUMN ARCHITECTURE"),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text("ADD NEW COLUMN", style: TextStyle(color: Colors.white38, fontSize: 10)),
            ),
            IconButton(onPressed: _addColumn, icon: const Icon(Icons.add_circle, color: Colors.cyanAccent, size: 22)),
          ],
        ),
        ...columns.map((col) => _buildColumnSizer(col)).toList(),
        
        const SizedBox(height: 30),
        _sectionHeader("ROW CONFIGURATION"),
        Slider(
          value: rowCount.toDouble(),
          min: 5, max: 60,
          divisions: 55,
          activeColor: Colors.cyanAccent,
          onChanged: (v) => setState(() => rowCount = v.toInt()),
        ),
        Center(child: Text("Slots: $rowCount", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _consoleInput(String label, Function(String) onChanged, String initialValue) {
    return TextField(
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
      ),
    );
  }

  Widget _buildColumnSizer(TableColumnDef col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => col.header = v),
                  controller: TextEditingController(text: col.header),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              IconButton(onPressed: () => setState(() => columns.remove(col)), icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 16)),
            ],
          ),
          Slider(
            value: col.width,
            min: 40, max: 400,
            activeColor: Colors.white24,
            onChanged: (v) => setState(() => col.width = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperPreview() {
    return Container(
      width: totalSheetWidth,
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Day: $selectedDay", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
              const Text("Date: ____ / ____ / 20__", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.black, thickness: 1),
          const SizedBox(height: 15),
          
          // HEADER WITH LOGO
          Row(
            children: [
              if (showLogo) 
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.school, size: 30, color: Colors.black),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(instName.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                    Text(sheetTitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // THE ARCHITECTED TABLE
          Table(
            columnWidths: {
              for (int i = 0; i < columns.length; i++) i: FixedColumnWidth(columns[i].width)
            },
            border: TableBorder.all(color: Colors.black, width: 1.0),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: columns.map((col) => Container(
                  height: 35,
                  alignment: Alignment.center,
                  child: Text(col.header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black)),
                )).toList(),
              ),
              ...List.generate(rowCount, (index) => TableRow(
                children: columns.map((col) => Container(height: 35)).toList(),
              )),
            ],
          ),
          const SizedBox(height: 40),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("In-charge Signature: ________________", style: TextStyle(fontSize: 9, color: Colors.black)),
              Text("Institution Stamp: ________________", style: TextStyle(fontSize: 9, color: Colors.black)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), 
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveBlueprint,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text("FINALIZE & SAVE BLUEPRINT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
    );
  }
}