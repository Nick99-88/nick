import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import 'database/dashboard_cache_service.dart';

class FacultyDirectoryScreen extends StatefulWidget {
  const FacultyDirectoryScreen({super.key});

  @override
  State<FacultyDirectoryScreen> createState() => _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState extends State<FacultyDirectoryScreen> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  List<dynamic> _allFaculty = [];
  List<dynamic> _filteredFaculty = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
    _searchController.addListener(_filterFaculty);
  }

  Future<void> _fetchFaculty() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getTeacherList();
      setState(() {
        _allFaculty = data['teachers'] ?? data['rows'] ?? [];
        _filteredFaculty = _allFaculty;
        _isLoading = false;
      });
      debugPrint('🏛️ UI: _fetchFaculty loaded ${_allFaculty.length} teachers');
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showStatusBox(context, "Sync Error: Institution Offline", false);
    }
  }

  void _filterFaculty() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFaculty = _allFaculty.where((t) {
        final name = t['name'].toString().toLowerCase();
        final designation = (t['designation'] ?? '').toString().toLowerCase();
        return name.contains(query) || designation.contains(query);
      }).toList();
    });
  }

  /// 🏛️ Delete Logic (Permanent Removal)
  Future<void> _handleDelete(String id, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Removal", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Permanently remove $name from institution records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("KEEP")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("REMOVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      debugPrint('🏛️ UI: delete teacher — id=$id, name=$name');
      try {
        final result = await _cache.deleteTeacher(id);
        debugPrint('🏛️ UI: deleteTeacher result — $result');
        StarlightUtils.showStatusBox(context, result['pending'] == true ? "Record Erased (pending sync)" : "Record Erased", true);
        _fetchFaculty();
        debugPrint('🏛️ UI: _fetchFaculty done after teacher delete');
      } catch (e) {
        debugPrint('🏛️ UI: deleteTeacher threw — $e');
        StarlightUtils.showStatusBox(context, "Delete Failed", false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("FACULTY DIRECTORY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFaculty.isEmpty
                ? const Center(child: Text("No faculty records found."))
                : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _filteredFaculty.length,
              itemBuilder: (context, index) => _teacherCard(_filteredFaculty[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Real-time management for the institution", style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 15),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search name, subject, or phone...",
              prefixIcon: const Icon(Icons.search, color: StarlightTheme.primaryBlue),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teacherCard(dynamic teacher) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: StarlightTheme.primaryBlue, width: 4)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(teacher['designation']?.toUpperCase() ?? 'FACULTY',
                    style: const TextStyle(color: StarlightTheme.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                      onPressed: () => _openEditSheet(teacher),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      onPressed: () => _handleDelete(teacher['id'], teacher['name']),
                    ),
                  ],
                ),
              ],
            ),
            Text(teacher['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _detailRow("Contact", teacher['phone'] ?? 'N/A'),
            _detailRow("Monthly Salary", "${teacher['salary']} PKR"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                "KEY: ${teacher['access_key'] ?? 'N/A'}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 🏛️ EDIT MODAL (BottomSheet)
  void _openEditSheet(dynamic teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _EditTeacherSheet(
        teacher: teacher,
        onUpdate: _fetchFaculty,
        cache: _cache,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _EditTeacherSheet extends StatefulWidget {
  final dynamic teacher;
  final VoidCallback onUpdate;
  final DashboardCacheService cache;

  const _EditTeacherSheet({required this.teacher, required this.onUpdate, required this.cache});

  @override
  State<_EditTeacherSheet> createState() => _EditTeacherSheetState();
}

class _EditTeacherSheetState extends State<_EditTeacherSheet> {
  late TextEditingController _name, _designation, _phone, _salary;
  List<Map<String, TextEditingController>> _extraFields = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.teacher['name']);
    _designation = TextEditingController(text: widget.teacher['designation']);
    _phone = TextEditingController(text: widget.teacher['phone']);
    _salary = TextEditingController(text: widget.teacher['salary'].toString());

    if (widget.teacher['extra_details'] != null) {
      (widget.teacher['extra_details'] as Map).forEach((k, v) {
        _extraFields.add({"key": TextEditingController(text: k), "val": TextEditingController(text: v.toString())});
      });
    }
  }

  Future<void> _saveChanges() async {
    Map<String, dynamic> extras = {};
    for (var f in _extraFields) {
      if (f['key']!.text.isNotEmpty) extras[f['key']!.text] = f['val']!.text;
    }

    final data = {
      "name": _name.text,
      "designation": _designation.text,
      "phone": _phone.text,
      "salary": double.tryParse(_salary.text) ?? 0.0,
      "extra_details": extras,
    };

    try {
      final result = await widget.cache.updateTeacher(widget.teacher['id'], data);
      Navigator.pop(context);
      widget.onUpdate();
      StarlightUtils.showStatusBox(context, result['pending'] == true ? "Updated (pending sync)" : "Institution Vault Updated", true);
    } catch (e) {
      StarlightUtils.showStatusBox(context, "Update Denied", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("UPDATE FACULTY", style: TextStyle(fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue)),
            const SizedBox(height: 20),
            _field(_name, "Full Name"),
            _field(_designation, "Designation"),
            _field(_phone, "Contact Number"),
            _field(_salary, "Salary (PKR)", kb: TextInputType.number),
            const Divider(),
            const Text("CUSTOM INFORMATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ..._extraFields.map((f) => Row(children: [
              Expanded(child: _field(f['key']!, "Field")),
              const SizedBox(width: 10),
              Expanded(child: _field(f['val']!, "Value")),
              IconButton(onPressed: () => setState(() => _extraFields.remove(f)), icon: const Icon(Icons.remove_circle, color: Colors.red))
            ])),
            TextButton(onPressed: () => setState(() => _extraFields.add({"key": TextEditingController(), "val": TextEditingController()})), child: const Text("+ ADD FIELD")),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saveChanges, child: const Text("UPDATE", style: TextStyle(color: Colors.white)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String l, {TextInputType kb = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: kb,
        style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: l,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}