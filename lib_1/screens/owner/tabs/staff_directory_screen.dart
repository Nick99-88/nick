import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import 'database/dashboard_cache_service.dart';

class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  List<dynamic> _allStaff = [];
  List<dynamic> _filteredStaff = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStaff();
    _searchController.addListener(_filterStaff);
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getStaffList();
      setState(() {
        _allStaff = data['staff'] ?? data['rows'] ?? [];
        _filteredStaff = _allStaff;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showStatusBox(context, "Connection Lost: Vault Offline", false);
    }
  }

  void _filterStaff() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStaff = _allStaff.where((s) {
        final name = s['name'].toString().toLowerCase();
        final position = (s['position'] ?? '').toString().toLowerCase();
        final cnic = (s['cnic'] ?? '').toString().toLowerCase();
        return name.contains(query) || position.contains(query) || cnic.contains(query);
      }).toList();
    });
  }

  Future<void> _handleDelete(String id, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Removal", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Permanently remove $name from institution staff records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _cache.deleteStaff(id);
        StarlightUtils.showStatusBox(context, result['pending'] == true ? "Staff Record Erased (pending sync)" : "Staff Record Erased", true);
        _fetchStaff();
      } catch (e) {
        StarlightUtils.showStatusBox(context, "Removal Failed", false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("STAFF DIRECTORY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStaff.isEmpty
                ? const Center(child: Text("No staff records found."))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: _filteredStaff.length,
              itemBuilder: (context, index) => _staffCard(_filteredStaff[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search name, role, or CNIC...",
          prefixIcon: const Icon(Icons.badge_outlined, color: StarlightTheme.primaryBlue),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _staffCard(dynamic staff) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
                  child: const Icon(Icons.engineering_outlined, color: StarlightTheme.primaryBlue),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(staff['position'] ?? 'Support Staff', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blueGrey),
                  onPressed: () => _openEditSheet(staff),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: () => _handleDelete(staff['id'], staff['name']),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo(Icons.contact_phone_outlined, staff['contact'] ?? 'N/A'),
                _miniInfo(Icons.fingerprint_rounded, staff['cnic'] ?? 'No CNIC'),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Text(
                "KEY: ${staff['access_key'] ?? 'N/A'}",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.purple, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  void _openEditSheet(dynamic staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _EditStaffSheet(
        staff: staff,
        onUpdate: _fetchStaff,
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

class _EditStaffSheet extends StatefulWidget {
  final dynamic staff;
  final VoidCallback onUpdate;
  final DashboardCacheService cache;

  const _EditStaffSheet({required this.staff, required this.onUpdate, required this.cache});

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  late TextEditingController _name, _pos, _cnic, _contact;
  List<Map<String, TextEditingController>> _extras = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.staff['name']);
    _pos = TextEditingController(text: widget.staff['position']);
    _cnic = TextEditingController(text: widget.staff['cnic']);
    _contact = TextEditingController(text: widget.staff['contact']);

    if (widget.staff['extra_details'] != null) {
      (widget.staff['extra_details'] as Map).forEach((k, v) {
        _extras.add({"k": TextEditingController(text: k), "v": TextEditingController(text: v.toString())});
      });
    }
  }

  Future<void> _update() async {
    Map<String, dynamic> extrasMap = {};
    for (var f in _extras) {
      if (f['k']!.text.isNotEmpty) extrasMap[f['k']!.text] = f['v']!.text;
    }

    final data = {
      "name": _name.text,
      "position": _pos.text,
      "cnic": _cnic.text,
      "contact": _contact.text,
      "extra_details": extrasMap,
    };

    try {
      final result = await widget.cache.updateStaff(widget.staff['id'], data);
      Navigator.pop(context);
      widget.onUpdate();
      StarlightUtils.showStatusBox(context, result['pending'] == true ? "Updated (pending sync)" : "Institution Records Updated", true);
    } catch (e) {
      StarlightUtils.showStatusBox(context, "Update Failed", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("EDIT STAFF PROFILE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 20),
            _input(_name, "Full Name"),
            _input(_pos, "Position"),
            _input(_cnic, "CNIC"),
            _input(_contact, "Contact"),
            const Divider(),
            ..._extras.map((e) => Row(children: [
              Expanded(child: _input(e['k']!, "Key")),
              const SizedBox(width: 10),
              Expanded(child: _input(e['v']!, "Value")),
              IconButton(onPressed: () => setState(() => _extras.remove(e)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red))
            ])),
            TextButton(onPressed: () => setState(() => _extras.add({"k": TextEditingController(), "v": TextEditingController()})), child: const Text("ADD FIELD")),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _update, child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
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