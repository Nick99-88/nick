import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'blueprint_editor.dart'; // Your Universal Template Editor
import '../../../core/storage.dart';

class DatesheetArchitect extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const DatesheetArchitect({super.key, this.initialData});

  @override
  State<DatesheetArchitect> createState() => _DatesheetArchitectState();
}

class _DatesheetArchitectState extends State<DatesheetArchitect> {
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);

  // Controller for the main title
  final TextEditingController _titleController = TextEditingController();
  
  // Data State
  String? selectedSection;
  List<String> availableSections = [];
  List<Map<String, dynamic>> examEntries = [];
  bool isLoadingSections = true;
  bool isDeploying = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchSections();
    
    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _titleController.text = data['title'] ?? data['name'] ?? '';
        
        // Populate target section
        final List<dynamic> targets = data['targets'] ?? [];
        if (targets.isNotEmpty) {
          selectedSection = targets.first.toString();
        }

        // Populate exam entries with their required TextControllers safely
        final List<dynamic> content = data['content'] ?? [];
        examEntries = content.map((entry) {
          if (entry is Map) {
            final String subjectName = entry['subject_name']?.toString() ?? '';
            final String venue = entry['venue']?.toString() ?? '';
            
            return {
              'subject_name': subjectName,
              'date': entry['date']?.toString() ?? '',
              'day': entry['day']?.toString() ?? 'Pick Date',
              'time': entry['time']?.toString() ?? '09:00 AM',
              'duration_mins': entry['duration_mins'] ?? 180,
              'venue': venue,
              'controller': TextEditingController(text: subjectName),
              'venue_controller': TextEditingController(text: venue),
            };
          }
          return <String, dynamic>{};
        }).where((e) => e.isNotEmpty).toList();
      });
    } else {
      _addNewEntry(); // Initialize with one empty slot only if not hydrating
    }
  }

  // --- LOGIC: FETCH SECTIONS ---
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

  // --- LOGIC: SMART CLONING ---
  void _addNewEntry() {
    String lastTime = "09:00";
    String lastDuration = "180";
    String lastVenue = "";

    if (examEntries.isNotEmpty) {
      final last = examEntries.last;
      lastTime = last['time'] ?? "09:00";
      lastDuration = last['duration_mins'].toString();
      lastVenue = last['venue'] ?? "";
    }

    setState(() {
      examEntries.add({
        'subject_name': '',
        'date': '',
        'day': 'Pick Date',
        'time': lastTime,
        'duration_mins': int.parse(lastDuration),
        'venue': lastVenue,
        'controller': TextEditingController(), // Specific for subject name
        'venue_controller': TextEditingController(text: lastVenue),
      });
    });
  }

  // --- UI: NOTIFICATION ---
  void _showNotify(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
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
        leading: IconButton(
          icon: Icon(Icons.close, color: secondaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("DATESHEET ARCHITECT", 
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
        actions: [
          // 🏛️ The Universal Blueprint Button
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BlueprintEditor())),
            icon: Icon(Icons.account_tree_rounded, color: primaryColor, size: 18),
            label: Text("TEMPLATE", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMainConfigCard(),
                  const SizedBox(height: 20),
                  ...examEntries.asMap().entries.map((e) => _buildExamEntryCard(e.key, e.value)),
                  const SizedBox(height: 15),
                  _buildAddButton(),
                ],
              ),
            ),
          ),
          _buildPublishFooter(),
        ],
      ),
    );
  }

  Widget _buildMainConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD1D9E0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Datesheet Title"),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: "e.g. Mid-Term March 2026", border: InputBorder.none),
            style: const TextStyle(fontSize: 14),
          ),
          const Divider(),
          _label("Select Institution Section"),
          isLoadingSections 
            ? const LinearProgressIndicator()
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedSection,
                  isExpanded: true,
                  hint: const Text("Choose Section", style: TextStyle(fontSize: 14)),
                  items: availableSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => selectedSection = v),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExamEntryCard(int index, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: const Color(0xFFE0E6ED))
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label("Subject Details", color: secondaryColor),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: data['date'] == '' ? secondaryColor : primaryColor, borderRadius: BorderRadius.circular(5)),
                    child: Text(data['day'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => examEntries.removeAt(index)),
                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                  )
                ],
              )
            ],
          ),
          TextField(
            controller: data['controller'],
            onChanged: (v) => data['subject_name'] = v,
            decoration: const InputDecoration(hintText: "Subject Name", border: InputBorder.none),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Paper Date"),
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) {
                          setState(() {
                            data['date'] = DateFormat('yyyy-MM-dd').format(picked);
                            data['day'] = DateFormat('EEEE').format(picked).toUpperCase();
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(data['date'] == '' ? "Select Date" : data['date'], style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Paper Time"),
                    InkWell(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) {
                          setState(() => data['time'] = picked.format(context));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(data['time'], style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Duration (Mins)"),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => data['duration_mins'] = int.tryParse(v) ?? 0,
                      decoration: InputDecoration(hintText: data['duration_mins'].toString(), border: InputBorder.none),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Venue/Room"),
                    TextField(
                      controller: data['venue_controller'],
                      onChanged: (v) => data['venue'] = v,
                      decoration: const InputDecoration(hintText: "Room...", border: InputBorder.none),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _addNewEntry,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5FE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor, style: BorderStyle.none), // Simplified
        ),
        child: Text("+ Add Next Subject (Clone Details)", 
          textAlign: TextAlign.center, 
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  Widget _buildPublishFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isDeploying ? null : _deployDatesheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
          ),
          child: Text(isDeploying ? "DEPLOYING TO VAULT..." : "DEPLOY TO INSTITUTION", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Future<void> _deployDatesheet() async {
    // Validation
    if (_titleController.text.trim().isEmpty) {
      _showNotify("Please enter a datesheet title", false);
      return;
    }
    
    if (selectedSection == null || selectedSection!.isEmpty) {
      _showNotify("Please select a section", false);
      return;
    }
    
    if (examEntries.isEmpty || examEntries.every((entry) => entry['subject_name'].toString().trim().isEmpty)) {
      _showNotify("Please add at least one subject", false);
      return;
    }

    setState(() => isDeploying = true);

    // Prepare payload
    final payload = {
      "name": _titleController.text.trim(),
      "targets": [selectedSection!],
      "subject": "Datesheet",
      "date": "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      "is_final": true,
      "content": examEntries.map((entry) => {
        "subject_name": entry['subject_name']?.toString().trim() ?? '',
        "date": entry['date']?.toString() ?? '',
        "day": entry['day']?.toString() ?? '',
        "time": entry['time']?.toString() ?? '',
        "duration_mins": entry['duration_mins'] ?? 0,
        "venue": entry['venue']?.toString() ?? '',
      }).toList(),
    };

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.post(
        Uri.parse('$apiBase/document/vault/upload'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        _showNotify("Datesheet deployed successfully", true);
        Navigator.pop(context);
      } else {
        _showNotify("Server Error: ${res.statusCode}", false);
      }
    } catch (e) {
      _showNotify("Network Error: Failed to deploy", false);
    } finally {
      setState(() => isDeploying = false);
    }
  }

  Widget _label(String text, {Color? color}) {
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color ?? primaryColor, letterSpacing: 0.5));
  }
}