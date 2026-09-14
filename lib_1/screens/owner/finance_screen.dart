import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../services/api_service.dart';
import '../../services/campaign_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _campaignType = 'staff';
  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoading = true;
  bool _isCreating = false;
  bool _showHistory = false;
  Set<String> _selectedCampaigns = {};

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/finance/campaigns?campaign_type=$_campaignType');
      if (response is Map && response['campaigns'] != null) {
        setState(() {
          _campaigns = List<Map<String, dynamic>>.from(response['campaigns']);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(localizedReason: reason);
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteCampaign(String campaignId) async {
    final authed = await _authenticate("Authenticate to delete campaign");
    if (!authed) return;
    try {
      await ApiService.delete('/finance/campaigns/$campaignId');
      await _loadCampaigns();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Campaign deleted")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _bulkDeleteCampaigns() async {
    final authed = await _authenticate("Authenticate to delete selected campaigns");
    if (!authed) return;
    
    setState(() => _isLoading = true);
    for (final id in _selectedCampaigns) {
      await ApiService.delete('/finance/campaigns/$id');
    }
    setState(() {
      _selectedCampaigns.clear();
      _isLoading = false;
    });
    await _loadCampaigns();
  }

  Future<void> _createCampaign() async {
    if (_campaignType == 'staff') {
      // Logic for staff campaign...
    } else {
      // Logic for student campaign...
    }
    await _loadCampaigns();
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finance Manager"),
        actions: [
          if (_selectedCampaigns.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _bulkDeleteCampaigns),
          IconButton(
            icon: Icon(_showHistory ? Icons.list : Icons.history, color: StarlightTheme.primaryBlue),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: 'Toggle History/Active',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: StarlightTheme.primaryBlue),
            onPressed: _isCreating ? null : _createCampaign,
            tooltip: 'Create Campaign',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _showHistory ? _buildHistoryList() : _buildCampaignsList(),
    );
  }

  Widget _buildCampaignsList() {
    final active = _campaigns.where((c) => c['status'] == 'active').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ... (campaign creation tiles) ...
        const Text("ACTIVE CAMPAIGNS", style: TextStyle(fontWeight: FontWeight.bold)),
        ...active.map((c) => _buildCampaignCard(c)),
      ],
    );
  }

  Widget _buildHistoryList() {
    final completed = _campaigns.where((c) => c['status'] != 'active').toList();
    return ListView(
      children: completed.map((c) => _buildHistoryCard(c)).toList(),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final total = (c['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (c['paid_amount'] as num?)?.toDouble() ?? 0;
    return Card(
      child: CheckboxListTile(
        value: _selectedCampaigns.contains(id),
        onChanged: (val) => setState(() => val == true ? _selectedCampaigns.add(id) : _selectedCampaigns.remove(id)),
        title: Text(c['title'] ?? ''),
        subtitle: Text('Paid: ${paid.toStringAsFixed(0)} / Total: ${total.toStringAsFixed(0)}'),
        secondary: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCampaign(id)),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> c) => Card(child: ListTile(title: Text(c['title'] ?? ''), trailing: const Icon(Icons.history)));
}