import 'package:flutter/material.dart';
import 'database/dashboard_cache_service.dart';
import 'database/dashboard_sync_service.dart';

class DashboardHomeTab extends StatefulWidget {
  const DashboardHomeTab({super.key});

  @override
  State<DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<DashboardHomeTab> {
  bool _isSyncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final pending = await DashboardCacheService.instance.getPendingOpCount();
    final failed = await DashboardCacheService.instance.getFailedOpCount();
    if (mounted) setState(() { _pendingCount = pending; _failedCount = failed; });
  }

  Future<void> _storeLocally() async {
    setState(() => _isSyncing = true);
    try {
      await DashboardSyncService.instance.syncPendingOps();
      await DashboardCacheService.instance.syncAll(forceRefresh: true);
      await _loadCounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All data stored locally"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed: $e"), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _clearFailedOps() async {
    await DashboardCacheService.instance.clearFailedOps();
    await _loadCounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed operations cleared"), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_failedCount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_failedCount operation${_failedCount == 1 ? '' : 's'} failed permanently',
                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFailedOps,
                    child: Text("Clear", style: TextStyle(color: Colors.red[700])),
                  ),
                ],
              ),
            ),
          ],
          const Text("Live Statistics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statCard("Students", "1,240", Icons.people, Colors.blue),
              _statCard("Revenue", "450k", Icons.account_balance_wallet, Colors.green),
            ],
          ),
          const SizedBox(height: 30),
          const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
                    : const Icon(Icons.cloud_download_outlined, color: Colors.teal),
              ),
              title: const Text("Store Locally", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: _pendingCount > 0
                  ? Text("$_pendingCount pending sync", style: const TextStyle(fontSize: 12, color: Colors.orange))
                  : const Text("Cache all data offline", style: TextStyle(fontSize: 12, color: Colors.grey)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : _storeLocally,
            ),
          ),
          _actionTile(context, "Admit New Student", Icons.person_add_alt_1, Colors.orange),
          _actionTile(context, "Generate Fee Slips", Icons.receipt_long, Colors.purple),
          _actionTile(context, "Broadcast Notice", Icons.campaign, Colors.red),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(5),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext context, String title, IconData icon, Color color) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
