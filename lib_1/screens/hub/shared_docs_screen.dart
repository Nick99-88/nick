import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class SharedDocsScreen extends StatefulWidget {
  const SharedDocsScreen({super.key});

  @override
  State<SharedDocsScreen> createState() => _SharedDocsScreenState();
}

class _SharedDocsScreenState extends State<SharedDocsScreen> {
  int _activeTab = 0;

  List<Map<String, dynamic>> _receivedDocs = [];
  List<Map<String, dynamic>> _sentDocs = [];

  bool _isLoadingReceived = true;
  bool _isLoadingSent = true;

  @override
  void initState() {
    super.initState();
    _loadReceived();
    _loadSent();
  }

  Future<void> _loadReceived() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/share/my-received'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _receivedDocs = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingReceived = false);
  }

  Future<void> _loadSent() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/share/my-sent'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _sentDocs = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSent = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Shared Documents", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _activeTab == 0 ? _buildReceivedView() : _buildSentView()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab(0, "Received", _receivedDocs.length),
          _buildTab(1, "Sent", _sentDocs.length),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, int count) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? StarlightTheme.primaryBlue : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Center(
            child: Text(
              "$label${count > 0 ? ' ($count)' : ''}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? StarlightTheme.primaryBlue : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedView() {
    if (_isLoadingReceived) return const Center(child: CircularProgressIndicator());
    if (_receivedDocs.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: () async { await _loadReceived(); await _loadSent(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedDocs.length,
        itemBuilder: (_, i) => _buildDocCard(_receivedDocs[i], isReceived: true),
      ),
    );
  }

  Widget _buildSentView() {
    if (_isLoadingSent) return const Center(child: CircularProgressIndicator());
    if (_sentDocs.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: () async { await _loadSent(); await _loadReceived(); },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentDocs.length,
        itemBuilder: (_, i) => _buildDocCard(_sentDocs[i], isReceived: false),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_shared, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _activeTab == 0 ? "No received documents" : "No sent documents",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc, {required bool isReceived}) {
    final name = doc['title'] ?? 'Untitled';
    final category = doc['category'] ?? '';
    final date = doc['created_at'] ?? '';
    final personName = isReceived ? (doc['sender_name'] ?? 'Unknown') : (doc['receiver_name'] ?? 'Unknown');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceived ? Icons.download : Icons.upload,
                  color: Colors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (category.isNotEmpty)
                      Text(category, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                isReceived ? "From: $personName" : "To: $personName",
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(_formatDate(date), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}