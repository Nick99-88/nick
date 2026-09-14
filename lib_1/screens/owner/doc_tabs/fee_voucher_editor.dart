import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';

class FeeVoucherEditor extends StatefulWidget {
  final String? blueprintId;
  final Map<String, dynamic>? existingBlueprint;

  const FeeVoucherEditor({super.key, this.blueprintId, this.existingBlueprint});

  @override
  State<FeeVoucherEditor> createState() => _FeeVoucherEditorState();
}

class _FeeVoucherEditorState extends State<FeeVoucherEditor> {
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);

  @override
  void initState() {
    super.initState();
    if (widget.existingBlueprint != null) {
      final bp = widget.existingBlueprint!;
      headerHeight = bp['global_header_height'] != null 
          ? double.tryParse(bp['global_header_height'].toString()) ?? 70.0 
          : 70.0;
      
      if (bp['columns'] != null && bp['columns'] is List) {
        feeHeads = (bp['columns'] as List).map((col) {
          if (col is Map) {
            return {
              'label': (col['title'] ?? 'Fee Head').toString(),
              'key': (col['mapKey'] ?? 'fee_custom').toString(),
            };
          }
          return <String, String>{};
        }).where((e) => e.isNotEmpty).cast<Map<String, String>>().toList();
      }
      
      if (bp['rows'] != null && bp['rows'] is List) {
        studentFields = (bp['rows'] as List).map((row) {
          if (row is Map) {
            final String label = (row['title'] ?? 'Field').toString();
            return {
              'label': label,
              'key': label.toLowerCase().replaceAll(' ', '_'),
            };
          }
          return <String, String>{};
        }).where((e) => e.isNotEmpty).cast<Map<String, String>>().toList();
      }
    }
  }

  // 🏛️ Global Architectural Management
  String orientation = "Vertical"; 
  int copyCount = 3; 
  double copyWidth = 420.0;

  // 📐 Individual Section Height Management (The "Squeezing" Engine)
  double headerHeight = 70.0;
  double studentInfoHeight = 100.0;
  double feePartHeight = 180.0; // Adjustable for long fee lists
  double footerHeight = 60.0;

  // 🏛️ Dynamic Content Nodes
  List<Map<String, String>> studentFields = [
    {'label': 'CHALLAN NO', 'key': 'challan_no'},
    {'label': 'STUDENT NAME', 'key': 'student_name'},
    {'label': 'FATHER NAME', 'key': 'father_name'},
    {'label': 'CLASS / SEC', 'key': 'class_sec'},
    {'label': 'ROLL NO', 'key': 'roll_no'},
    {'label': 'FEE MONTH', 'key': 'fee_month'},
  ];

  List<Map<String, String>> feeHeads = [
    {'label': 'Tuition Fee', 'key': 'fee_tuition'},
    {'label': 'Admission Fee', 'key': 'fee_adm'},
    {'label': 'Late Fine', 'key': 'fee_fine'},
  ];

  bool isSaving = false;
  final String apiBase = "https://api.institution.site";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDE1E4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("VOUCHER ARCHITECT PRO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
        actions: [
          _topAction(isSaving ? "SYNCING..." : "SYNC TO VAULT", Icons.cloud_done_rounded, isSaving ? () {} : () => _saveToVault()),
        ],
      ),
      body: Column(
        children: [
          _buildSqueezeConsole(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: _buildCanvas(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 🏛️ SERVER SYNC LOGIC ---
  Future<void> _saveToVault() async {
    setState(() => isSaving = true);
    
    // Convert fee voucher data to blueprint format
    final payload = {
      "type": "fee_voucher_blueprint",
      "title": "Fee Voucher Blueprint ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
      "global_header_height": headerHeight,
      "show_row_headers": false, // Fee vouchers don't use row headers
      "columns": feeHeads.map((fee) => {
        'title': fee['label'],
        'width': 120.0,
        'mapKey': fee['key']
      }).toList(),
      "rows": studentFields.map((field) => {
        'title': field['label'],
        'height': 60.0
      }).toList(),
      "footer_note": "Fee voucher blueprint - Orientation: $orientation, Copies: $copyCount, Width: ${copyWidth}px, Student Height: ${studentInfoHeight}px, Fee Height: ${feePartHeight}px, Footer Height: ${footerHeight}px",
      "created_at": DateTime.now().toIso8601String(),
    };

    try {
      final token = await StarlightStorage.getUserToken();
      
      final res = await http.post(
        Uri.parse('$apiBase/document/blueprint/save'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showNotify("Fee Voucher Blueprint Saved to Vault", true);
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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- 🛠️ THE SQUEEZE CONSOLE (Multi-Section Control) ---
  Widget _buildSqueezeConsole() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _configDrop("COPIES", ["1", "2", "3"], (v) => setState(() => copyCount = int.parse(v!))),
              _configDrop("ALIGN", ["Vertical", "Horizontal"], (v) => setState(() => orientation = v!)),
              _buildActionBtn("ADD FIELD", Icons.person_add_alt_1, () {
                setState(() => studentFields.add({'label': 'NEW FIELD', 'key': 'custom_key'}));
              }),
              _buildActionBtn("ADD FEE", Icons.add_chart_rounded, () {
                setState(() => feeHeads.add({'label': 'New Fee', 'key': 'new_fee'}));
              }),
            ],
          ),
          const Divider(),
          // Section Height Sliders
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _squeezeSlider("HEADER", headerHeight, 50, 120, (v) => setState(() => headerHeight = v)),
                _squeezeSlider("STUDENT", studentInfoHeight, 60, 200, (v) => setState(() => studentInfoHeight = v)),
                _squeezeSlider("FEES", feePartHeight, 100, 400, (v) => setState(() => feePartHeight = v)),
                _squeezeSlider("FOOTER", footerHeight, 40, 120, (v) => setState(() => footerHeight = v)),
                _squeezeSlider("WIDTH", copyWidth, 300, 600, (v) => setState(() => copyWidth = v)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- 🏛️ THE DYNAMIC CANVAS ---
  Widget _buildCanvas() {
    List<Widget> copies = [];
    List<String> labels = ["BANK COPY", "INSTITUTION COPY", "STUDENT COPY"];

    for (int i = 0; i < copyCount; i++) {
      copies.add(_buildVoucherComponent(labels[i]));
      if (i < copyCount - 1) {
        copies.add(orientation == "Vertical" ? _buildVDivider() : _buildHDivider());
      }
    }

    return orientation == "Vertical" ? Column(children: copies) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: copies);
  }

  Widget _buildVoucherComponent(String type) {
    return Container(
      width: copyWidth,
      // Total height is the sum of all squeezed parts
      height: headerHeight + studentInfoHeight + feePartHeight + footerHeight + 40, 
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 1.2)),
      child: Column(
        children: [
          // 1. HEADER PART
          SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                Container(width: 40, height: 40, color: Colors.grey.shade100, child: const Icon(Icons.account_balance_rounded, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("STARLIGHT INSTITUTION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const Text("Official Fee Challan | Branch: Gaggoo Mandi", style: TextStyle(fontSize: 7)),
                      Text("BANK: ALLIED BANK LTD | A/C: 01-2345-6789", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),
                Text(type, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black),

          // 2. STUDENT DETAIL PART
          SizedBox(
            height: studentInfoHeight,
            child: Center(
              child: Wrap(
                runSpacing: 4,
                children: studentFields.asMap().entries.map((e) => _buildStudentFieldNode(e.key, e.value)).toList(),
              ),
            ),
          ),

          // 3. FEE TABLE PART
          SizedBox(
            height: feePartHeight,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
              child: Column(
                children: [
                  _tableHeader(),
                  Expanded(child: ListView(
                    physics: const NeverScrollableScrollPhysics(), // Print view behavior
                    children: feeHeads.asMap().entries.map((e) => _buildFeeRow(e.key, e.value)).toList(),
                  )),
                  _totalRow(),
                ],
              ),
            ),
          ),

          // 4. FOOTER PART
          SizedBox(
            height: footerHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("NOTE: Fees are non-refundable. Paid via Starlight Wallet or Bank.", style: TextStyle(fontSize: 7, fontStyle: FontStyle.italic)),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Issue Date: {{now}}", style: TextStyle(fontSize: 7)),
                    const Text("Authorized Signature: ____________", style: TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _squeezeSlider(String label, double val, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
          SizedBox(
            width: 100,
            child: Slider(value: val, min: min, max: max, activeColor: primaryColor, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentFieldNode(int index, Map<String, String> data) {
    return SizedBox(
      width: (copyWidth / 2) - 25,
      child: Row(
        children: [
          GestureDetector(onTap: () => setState(() => studentFields.removeAt(index)), child: const Icon(Icons.remove_circle, size: 8, color: Colors.red)),
          const SizedBox(width: 4),
          Text("${data['label']}: ", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          Expanded(child: Text("{{${data['key']}}}", style: const TextStyle(fontSize: 8), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildFeeRow(int index, Map<String, String> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            GestureDetector(onTap: () => setState(() => feeHeads.removeAt(index)), child: const Icon(Icons.remove_circle, size: 9, color: Colors.red)),
            const SizedBox(width: 5),
            Text(data['label']!, style: const TextStyle(fontSize: 9)),
          ]),
          Text("PKR {{${data['key']}}}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("DESCRIPTION", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          Text("AMOUNT", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _totalRow() {
    return Container(
      padding: const EdgeInsets.all(6),
      color: Colors.grey.shade100,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("TOTAL PAYABLE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          Text("PKR {{total_payable}}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // --- DIVIDERS ---
  Widget _buildVDivider() => Container(height: 40, child: Center(child: Text("- " * 30, style: const TextStyle(color: Colors.grey, fontSize: 10))));
  Widget _buildHDivider() => Container(width: 40, height: headerHeight + studentInfoHeight + feePartHeight + footerHeight, child: const VerticalDivider(color: Colors.grey, thickness: 1, indent: 20, endIndent: 20));

  // --- HELPERS ---
  Widget _configDrop(String label, List<String> opts, Function(String?) onChange) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
      DropdownButton<String>(value: opts.firstWhere((e) => e == (label == "COPIES" ? copyCount.toString() : orientation), orElse: () => opts.first), items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 10)))).toList(), onChanged: onChange, underline: const SizedBox()),
    ]);
  }

  Widget _buildActionBtn(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 12), label: Text(label, style: const TextStyle(fontSize: 8)), style: ElevatedButton.styleFrom(backgroundColor: secondaryColor, foregroundColor: Colors.white));
  }

  Widget _topAction(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(onPressed: onTap, icon: Icon(icon, color: primaryColor, size: 16), label: Text(label, style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}