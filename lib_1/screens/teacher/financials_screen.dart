import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class TeacherFinancialsScreen extends StatefulWidget {
  const TeacherFinancialsScreen({super.key});

  @override
  State<TeacherFinancialsScreen> createState() => _TeacherFinancialsScreenState();
}

class _TeacherFinancialsScreenState extends State<TeacherFinancialsScreen> {
  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/finance/my-campaigns'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['campaigns'] != null) {
          final all = List<Map<String, dynamic>>.from(data['campaigns']);
          if (mounted) setState(() => _campaigns = all);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _campaigns;
    return _campaigns.where((c) {
      final status = (c['status'] ?? '').toString().toLowerCase();
      final remaining = (c['remaining_amount'] ?? 0);
      if (_filter == 'active') return status != 'closed' && remaining > 0;
      if (_filter == 'closed') return status == 'closed' || remaining <= 0;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('Financial Records', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold)),
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadCampaigns,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No campaign records found', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadCampaigns,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _buildCampaignCard(_filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _filterChip('All', 'all'),
          const SizedBox(width: 8),
          _filterChip('Active', 'active'),
          const SizedBox(width: 8),
          _filterChip('Closed', 'closed'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? StarlightTheme.primaryBlue : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final title = c['title'] ?? 'Untitled Campaign';
    final total = (c['total_amount'] ?? 0).toDouble();
    final paid = (c['paid_amount'] ?? 0).toDouble();
    final remaining = (c['remaining_amount'] ?? 0).toDouble();
    final type = c['campaign_type'] ?? 'student';
    final section = c['section'] ?? '';
    final status = (c['status'] ?? 'active').toString();
    final isClosed = status == 'closed' || remaining <= 0;
    final myStatus = c['my_status'] as Map<String, dynamic>?;
    final myAmount = (myStatus?['amount'] ?? 0).toDouble();
    final myPaid = myStatus?['paid'] == true;

    final progress = total > 0 ? (paid / total) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isClosed ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type == 'staff' ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  type == 'staff' ? Icons.work_outline : Icons.school_outlined,
                  color: type == 'staff' ? Colors.purple : Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (section.isNotEmpty)
                      Text('Section: $section', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isClosed ? 'Closed' : 'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isClosed ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(isClosed ? Colors.green : StarlightTheme.primaryBlue),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('Total', 'Rs ${total.toStringAsFixed(0)}', Colors.grey),
              _stat('Paid', 'Rs ${paid.toStringAsFixed(0)}', Colors.green),
              _stat('Remaining', 'Rs ${remaining.toStringAsFixed(0)}', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 8),
          if (myStatus != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(myPaid ? Icons.check_circle : Icons.pending, size: 14, color: myPaid ? Colors.green : Colors.orange),
                const SizedBox(width: 6),
                Text('Your ${type == 'staff' ? 'Salary' : 'Fee'}: ',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text('Rs ${myAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: myPaid ? Colors.green : Colors.orange)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: myPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    myPaid ? 'Paid' : 'Pending',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: myPaid ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          Text(
            'Type: ${type == 'staff' ? 'Staff Salary' : 'Student Fee'}',
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ],
    );
  }
}
