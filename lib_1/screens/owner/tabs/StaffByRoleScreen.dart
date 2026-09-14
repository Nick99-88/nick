import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme.dart';
import '../../../l10n/strings.dart';
import '../../../services/institution/dashboard_service.dart';
import 'database/dashboard_cache_service.dart';

class StaffByRoleScreen extends StatefulWidget {
  final String roleName;
  const StaffByRoleScreen({super.key, required this.roleName});

  @override
  State<StaffByRoleScreen> createState() => _StaffByRoleScreenState();
}

class _StaffByRoleScreenState extends State<StaffByRoleScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allStaff = [];
  List<dynamic> _filteredStaff = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchStaff();
    _searchController.addListener(_filterLogic);
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getStaffByRole(widget.roleName);
      setState(() {
        _allStaff = data;
        _filteredStaff = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadStaffError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterLogic() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStaff = _allStaff.where((s) {
        final name = (s['name'] ?? "").toString().toLowerCase();
        final pos = (s['position'] ?? "").toString().toLowerCase();
        return name.contains(query) || pos.contains(query);
      }).toList();
    });
  }

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final allIds = _filteredStaff.map((s) => s['id'].toString()).toSet();
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _handleSingleDelete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('removeStaffTitle'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.person_off_rounded, color: Colors.red[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red[700]))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(tr('removeStaffDetail', {'name': name}), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], height: 1.5)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('keep'), style: GoogleFonts.poppins(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('remove'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final result = await _cache.deleteStaff(id);
        _fetchStaff();
        if (mounted) {
          final isPending = result['pending'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(isPending ? 'staffRemovedPending' : 'staffRemoved')),
              backgroundColor: isPending ? Colors.orange : Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('staffRemoveFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _confirmRegenerateKey(Map<String, dynamic> staff) async {
    final id = '${staff['server_id'] ?? staff['local_id'] ?? ''}';
    if (id.isEmpty) return;
    final name = staff['name'] ?? tr('staffSingular');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.autorenew_rounded, color: Colors.purple[700]),
            const SizedBox(width: 8),
            Flexible(child: Text(tr('regenerateAccessKey'), softWrap: true)),
          ],
        ),
        content: Text(
          tr('regenerateKeyConfirm', {'name': '$name'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('regenerate')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final newKey = await _cache.regenerateStaffKey(id);
      _fetchStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('newKey', {'key': newKey}),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: tr('copy'),
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: newKey)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('regenerateFailed', {'error': '$e'})),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(count == 1 ? 'removeStaffTitle' : 'removeStaffsTitle', {'count': '$count'}), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          tr(count == 1 ? 'removeStaffContent' : 'removeStaffsContent', {'count': '$count'}),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'), style: GoogleFonts.poppins(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('remove'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      int pending = 0;
      for (final id in _selectedIds) {
        final result = await _cache.deleteStaff(id);
        if (result['pending'] == true) pending++;
      }
      _exitSelectionMode();
      _fetchStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pending > 0
                ? tr(count == 1 ? 'staffRemovedPending' : 'staffPluralRemovedPending', {'count': '$count'})
                : tr(count == 1 ? 'staffRemoved' : 'staffPluralRemoved', {'count': '$count'})),
            backgroundColor: pending > 0 ? Colors.orange : Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('deleteFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _openEditSheet(dynamic staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditStaffSheet(
        staff: staff,
        onUpdate: _fetchStaff,
        service: _dashboardService,
        cache: _cache,
      ),
    );
  }

  void _showPrintDialog() {
    final staff = _isSelectionMode ? _allStaff.where((s) => _selectedIds.contains(s['id'].toString())).toList() : _allStaff;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.print_rounded, color: StarlightTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(tr('printOptions'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                ],
              ),
              const SizedBox(height: 6),
              Text(tr('staffCount', {'count': '${staff.length}'}), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 20),
              _printOption(
                icon: Icons.vpn_key_rounded,
                title: tr('keysOnly'),
                subtitle: tr('keysOnlySub'),
                color: Colors.purple,
                onTap: () { Navigator.pop(ctx); _generatePdf(staff, keysOnly: true); },
              ),
              const SizedBox(height: 10),
              _printOption(
                icon: Icons.table_chart_rounded,
                title: tr('fullData'),
                subtitle: tr('staffFullDataSub'),
                color: Colors.blue,
                onTap: () { Navigator.pop(ctx); _generatePdf(staff, keysOnly: false); },
              ),
              const SizedBox(height: 10),
              _printOption(
                icon: Icons.badge_rounded,
                title: tr('dataOnly'),
                subtitle: tr('staffDataOnlySub'),
                color: Colors.green,
                onTap: () { Navigator.pop(ctx); _generatePdf(staff, keysOnly: false, hideKeys: true); },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _printOption({required IconData icon, required String title, required String subtitle, required MaterialColor color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color[50], borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color[600], size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(List<dynamic> staff, {required bool keysOnly, bool hideKeys = false}) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#00695C');
    final accentGreen = PdfColor.fromHex('#2E7D32');
    final lightGreen = PdfColor.fromHex('#E8F5E9');
    final darkText = PdfColor.fromHex('#1E293B');
    final greyText = PdfColor.fromHex('#64748B');
    final lightBlue = PdfColor.fromHex('#E0F2F1');
    final roleName = widget.roleName.toUpperCase();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(roleName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(keysOnly ? tr('printAccessKeys') : tr('printStaffRecords'), style: pw.TextStyle(fontSize: 11, color: greyText, letterSpacing: 2)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(color: lightGreen, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(tr('printRecordCount', {'count': '${staff.length}'}), style: pw.TextStyle(color: accentGreen, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1.5),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          if (keysOnly)
            _buildKeysOnlySection(staff, primaryColor, darkText, greyText, lightBlue)
          else
            _buildFullDataTable(staff, primaryColor, accentGreen, lightGreen, darkText, greyText, lightBlue, hideKeys: hideKeys),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${roleName}_Staff_Records',
    );
  }

  pw.Widget _buildKeysOnlySection(List<dynamic> staff, PdfColor primaryColor, PdfColor darkText, PdfColor greyText, PdfColor lightBlue) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...staff.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final name = (s['name'] ?? '').toString();
          final key = (s['access_key'] ?? '').toString();
          final pos = (s['position'] ?? '').toString();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: i % 2 == 0 ? lightBlue : PdfColor.fromHex('#FFFFFF'),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkText)),
                      pw.SizedBox(height: 3),
                      pw.Text(pos, style: pw.TextStyle(fontSize: 10, color: greyText)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3E5F5'), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(key, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7B1FA2'))),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildFullDataTable(List<dynamic> staff, PdfColor primaryColor, PdfColor accentGreen, PdfColor lightGreen, PdfColor darkText, PdfColor greyText, PdfColor lightBlue, {bool hideKeys = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(tr('printStaffRecords'), style: pw.TextStyle(color: PdfColor.fromHex('#FFFFFF'), fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: primaryColor),
          cellStyle: pw.TextStyle(fontSize: 9, color: darkText),
          headerDecoration: pw.BoxDecoration(color: lightBlue),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
          cellHeight: 28,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            if (!hideKeys) 4: pw.Alignment.center,
          },
          headerAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            if (!hideKeys) 4: pw.Alignment.center,
          },
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
          headers: [tr('printName'), tr('printPosition'), tr('printContact'), tr('printCnic'), if (!hideKeys) tr('printKey')],
          data: staff.map((s) => [
            (s['name'] ?? '').toString(),
            (s['position'] ?? '').toString(),
            (s['contact'] ?? '').toString(),
            (s['cnic'] ?? '').toString(),
            if (!hideKeys) (s['access_key'] ?? '').toString(),
          ]).toList(),
        ),
        if (!hideKeys) ...[
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3E5F5'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tr('printAccessKeysSummary'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7B1FA2'))),
                pw.SizedBox(height: 8),
                ...staff.map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(width: 4, height: 4, decoration: pw.BoxDecoration(color: PdfColor.fromHex('#7B1FA2'), shape: pw.BoxShape.circle)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: pw.Text((s['name'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, color: darkText))),
                      pw.Text((s['access_key'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkText)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allVisibleSelected = _filteredStaff.isNotEmpty && _filteredStaff.every((s) => _selectedIds.contains(s['id'].toString()));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: _exitSelectionMode)
            : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: _isSelectionMode
            ? Text(tr('xSelected', {'count': '${_selectedIds.length}'}), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))
            : Text(tr('roleStaffTitle', {'role': widget.roleName}), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue)),
        centerTitle: false,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(allVisibleSelected ? Icons.deselect_rounded : Icons.select_all_rounded, color: StarlightTheme.primaryBlue),
              tooltip: tr(allVisibleSelected ? 'deselectAll' : 'selectAll'),
              onPressed: _selectAll,
            ),
            IconButton(
              icon: Icon(Icons.print_rounded, color: Colors.blue[600]),
              tooltip: tr('printSelected'),
              onPressed: _selectedIds.isNotEmpty ? _showPrintDialog : null,
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, color: Colors.red[600]),
              tooltip: tr('deleteSelected'),
              onPressed: _selectedIds.isNotEmpty ? _handleBulkDelete : null,
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.print_rounded, color: Colors.grey[600]),
              tooltip: tr('printAll'),
              onPressed: _allStaff.isNotEmpty ? _showPrintDialog : null,
            ),
          ],
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey[100], height: 1)),
      ),
      body: Column(
        children: [
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: tr('searchNamePosition'),
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
                ),
              ),
            ),

          if (!_isLoading && _filteredStaff.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text("${_filteredStaff.length} ${_filteredStaff.length == 1 ? tr('staffSingular') : tr('staffPlural')}",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredStaff.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noStaffFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 10, mainAxisSpacing: 10,
                        ),
                        itemCount: _filteredStaff.length,
                        itemBuilder: (context, index) => _staffCard(_filteredStaff[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _staffCard(dynamic staff) {
    final id = staff['id'].toString();
    final name = (staff['name'] ?? '').toString();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final position = (staff['position'] ?? 'Staff').toString();
    final contact = (staff['contact'] ?? 'N/A').toString();
    final cnic = (staff['cnic'] ?? 'N/A').toString();
    final accessKey = (staff['access_key'] ?? '').toString();
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(id);
        } else {
          _openEditSheet(staff);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) _enterSelectionMode(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? StarlightTheme.primaryBlue.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[350],
                    size: 20,
                  )
                else
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.teal[400]!, Colors.teal[600]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(initials, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                  ),
                if (!_isSelectionMode)
                  GestureDetector(
                    onTap: () => _handleSingleDelete(id, name),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(7)),
                      child: Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red[400]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(position, style: GoogleFonts.poppins(fontSize: 10, color: Colors.teal[600], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            _infoRow(Icons.phone_rounded, contact),
            const SizedBox(height: 2),
            _infoRow(Icons.subtitles_rounded, cnic),
            if (accessKey.isNotEmpty) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: accessKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('keyCopied', {'key': accessKey})), backgroundColor: Colors.green[700], behavior: SnackBarBehavior.floating),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 10, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr('keyLabel', {'key': accessKey}),
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.purple[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _confirmRegenerateKey(staff),
                        child: Icon(Icons.autorenew_rounded, size: 12, color: Colors.purple[800]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 11, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
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
  final DashboardService service;
  final DashboardCacheService cache;

  const _EditStaffSheet({required this.staff, required this.onUpdate, required this.service, required this.cache});

  @override
  State<_EditStaffSheet> createState() => _EditStaffSheetState();
}

class _EditStaffSheetState extends State<_EditStaffSheet> {
  late TextEditingController _name, _pos, _cnic, _contact;
  List<Map<String, TextEditingController>> _extras = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.staff['name']?.toString());
    _pos = TextEditingController(text: widget.staff['position']?.toString());
    _cnic = TextEditingController(text: widget.staff['cnic']?.toString());
    _contact = TextEditingController(text: widget.staff['contact']?.toString());

    if (widget.staff['extra_fields'] != null) {
      (widget.staff['extra_fields'] as Map).forEach((k, v) {
        _extras.add({"k": TextEditingController(text: k.toString()), "v": TextEditingController(text: v.toString())});
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pos.dispose();
    _cnic.dispose();
    _contact.dispose();
    for (var f in _extras) {
      f['k']!.dispose();
      f['v']!.dispose();
    }
    super.dispose();
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
      if (mounted) Navigator.pop(context);
      widget.onUpdate();
      if (mounted) {
        final isPending = result['pending'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(isPending ? 'staffUpdatedPending' : 'staffUpdated')),
            backgroundColor: isPending ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('updateFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_rounded, color: StarlightTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(tr('editStaff'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 24),
            _buildField(_name, tr('fullName'), icon: Icons.person_rounded),
            const SizedBox(height: 12),
            _buildField(_pos, tr('position'), icon: Icons.badge_rounded),
            const SizedBox(height: 12),
            _buildField(_contact, tr('contact'), icon: Icons.phone_rounded),
            const SizedBox(height: 12),
            _buildField(_cnic, tr('cnic'), icon: Icons.subtitles_rounded),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(tr('customFields'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            ..._extras.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _buildField(e['k']!, tr('field'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField(e['v']!, tr('value'))),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _extras.remove(e)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.red[400]),
                    ),
                  ),
                ],
              ),
            )),
            GestureDetector(
              onTap: () => setState(() => _extras.add({"k": TextEditingController(), "v": TextEditingController()})),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: StarlightTheme.primaryBlue),
                    const SizedBox(width: 6),
                    Text(tr('addField'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _update,
                child: Text(tr('saveChanges'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label, {IconData? icon, TextInputType kb = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: kb,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey[400]) : null,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
      ),
    );
  }
}
