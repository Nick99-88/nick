import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme.dart';
import '../../../l10n/strings.dart';
import '../../../services/institution/dashboard_service.dart';
import 'StudentListScreen.dart';
import 'database/dashboard_cache_service.dart';

class TeachersBySubjectScreen extends StatefulWidget {
  final String subjectName;
  const TeachersBySubjectScreen({super.key, required this.subjectName});

  @override
  State<TeachersBySubjectScreen> createState() => _TeachersBySubjectScreenState();
}

class _TeachersBySubjectScreenState extends State<TeachersBySubjectScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allTeachers = [];
  List<dynamic> _filteredTeachers = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
    _searchController.addListener(_filterLogic);
  }

  Future<void> _fetchTeachers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getTeachersBySubject(widget.subjectName);
      setState(() {
        _allTeachers = data;
        _filteredTeachers = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadTeachersError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterLogic() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = _allTeachers.where((t) {
        final name = (t['name'] ?? "").toString().toLowerCase();
        final desig = (t['designation'] ?? "").toString().toLowerCase();
        return name.contains(query) || desig.contains(query);
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
      final allVisibleIds = _filteredTeachers.map((t) => t['id'].toString()).toSet();
      if (_selectedIds.length == allVisibleIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(allVisibleIds);
      }
    });
  }

  List<dynamic> get _selectedTeachers => _allTeachers.where((t) => _selectedIds.contains(t['id'].toString())).toList();

  Future<void> _handleBulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(count == 1 ? tr('removeTeacherTitle') : tr('removeTeachersTitle', {'count': '$count'}), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          count == 1 ? tr('removeTeacherContent') : tr('removeTeachersContent', {'count': '$count'}),
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
        debugPrint('🏛️ UI: TeachersBySubject delete teacher — id=$id');
        final result = await _cache.deleteTeacher(id);
        debugPrint('🏛️ UI: deleteTeacher result — $result');
        if (result['pending'] == true) pending++;
      }
      _exitSelectionMode();
      _fetchTeachers();
      debugPrint('🏛️ UI: TeachersBySubject _fetchTeachers done after delete');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pending > 0
                ? (count == 1 ? tr('teacherRemovedPending') : tr('teachersRemovedPending', {'count': '$count'}))
                : (count == 1 ? tr('teacherRemoved') : tr('teachersRemoved', {'count': '$count'}))),
            backgroundColor: pending > 0 ? Colors.orange : Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('teacherRemoveFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _handleSingleDelete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('removeTeacherTitle'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
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
            Text(tr('removeTeacherDetail', {'name': name}),
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], height: 1.5)),
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
        final result = await _cache.deleteTeacher(id);
        _fetchTeachers();
        if (mounted) {
          final isPending = result['pending'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPending ? tr('teacherRemovedPending') : tr('teacherRemoved')),
              backgroundColor: isPending ? Colors.orange : Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('teacherRemoveFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _confirmRegenerateKey(Map<String, dynamic> teacher) async {
    final id = '${teacher['server_id'] ?? teacher['local_id'] ?? ''}';
    if (id.isEmpty) return;
    final name = teacher['name'] ?? 'this teacher';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.autorenew_rounded, color: Colors.amber[700]),
            const SizedBox(width: 8),
            Flexible(child: Text(tr('regenerateAccessKey'), softWrap: true)),
          ],
        ),
        content: Text(
          tr('regenerateKeyConfirm', {'name': name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
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
      final newKey = await _cache.regenerateTeacherKey(id);
      _fetchTeachers();
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

  void _showPrintDialog() {
    final teachers = _isSelectionMode ? _selectedTeachers : _allTeachers;
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
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
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
              Text(tr('teacherCountSelected', {'count': '${teachers.length}'}), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 20),
              _printOption(
                icon: Icons.vpn_key_rounded,
                title: tr('keysOnly'),
                subtitle: tr('keysOnlySub'),
                color: Colors.amber,
                onTap: () { Navigator.pop(ctx); _generatePdf(teachers, keysOnly: true); },
              ),
              const SizedBox(height: 10),
              _printOption(
                icon: Icons.table_chart_rounded,
                title: tr('fullData'),
                subtitle: tr('fullDataSub'),
                color: Colors.blue,
                onTap: () { Navigator.pop(ctx); _generatePdf(teachers, keysOnly: false); },
              ),
              const SizedBox(height: 10),
              _printOption(
                icon: Icons.badge_rounded,
                title: tr('dataOnly'),
                subtitle: tr('dataOnlySub'),
                color: Colors.green,
                onTap: () { Navigator.pop(ctx); _generatePdf(teachers, keysOnly: false, hideKeys: true); },
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

  Future<void> _generatePdf(List<dynamic> teachers, {required bool keysOnly, bool hideKeys = false}) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#1A237E');
    final accentGreen = PdfColor.fromHex('#2E7D32');
    final lightGreen = PdfColor.fromHex('#E8F5E9');
    final darkText = PdfColor.fromHex('#1E293B');
    final greyText = PdfColor.fromHex('#64748B');
    final lightBlue = PdfColor.fromHex('#E8EAF6');

    final subjectName = widget.subjectName.toUpperCase();

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
                    pw.Text(subjectName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(keysOnly ? tr('printAccessKeys') : tr('printFacultyRecords'), style: pw.TextStyle(fontSize: 11, color: greyText, letterSpacing: 2)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(color: lightGreen, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(tr('printRecordCount', {'count': '${teachers.length}'}), style: pw.TextStyle(color: accentGreen, fontSize: 11, fontWeight: pw.FontWeight.bold)),
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
            _buildKeysOnlySection(teachers, primaryColor, accentGreen, darkText, greyText, lightBlue)
          else
            _buildFullDataTable(teachers, primaryColor, accentGreen, lightGreen, darkText, greyText, lightBlue, hideKeys: hideKeys),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${subjectName}_Records',
    );
  }

  pw.Widget _buildKeysOnlySection(List<dynamic> teachers, PdfColor primaryColor, PdfColor accentGreen, PdfColor darkText, PdfColor greyText, PdfColor lightBlue) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        ...teachers.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final name = (t['name'] ?? '').toString();
          final key = (t['access_key'] ?? '').toString();
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
                      pw.Text((t['designation'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, color: greyText)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF3E0'), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(key, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#E65100'))),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildFullDataTable(List<dynamic> teachers, PdfColor primaryColor, PdfColor accentGreen, PdfColor lightGreen, PdfColor darkText, PdfColor greyText, PdfColor lightBlue, {bool hideKeys = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(tr('printTeacherRecords'), style: pw.TextStyle(color: PdfColor.fromHex('#FFFFFF'), fontSize: 11, fontWeight: pw.FontWeight.bold)),
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
            3: pw.Alignment.centerRight,
            if (!hideKeys) 4: pw.Alignment.center,
          },
          headerAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerRight,
            if (!hideKeys) 4: pw.Alignment.center,
          },
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
          headers: [tr('printName'), tr('printDesignation'), tr('printPhone'), tr('printSalary'), if (!hideKeys) tr('printKey')],
          data: teachers.map((t) => [
            (t['name'] ?? '').toString(),
            (t['designation'] ?? '').toString(),
            (t['phone'] ?? '').toString(),
            '${t['salary'] ?? 0}',
            if (!hideKeys) (t['access_key'] ?? '').toString(),
          ]).toList(),
        ),
        if (!hideKeys) ...[
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF8E1'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(tr('printAccessKeysSummary'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#F57F17'))),
                pw.SizedBox(height: 8),
                ...teachers.map((t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(width: 4, height: 4, decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F57F17'), shape: pw.BoxShape.circle)),
                      pw.SizedBox(width: 8),
                      pw.Expanded(child: pw.Text((t['name'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, color: darkText))),
                      pw.Text((t['access_key'] ?? '').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkText)),
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

  void _openEditSheet(dynamic teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTeacherSheet(
        teacher: teacher,
        onUpdate: _fetchTeachers,
        dashboardService: _dashboardService,
        cache: _cache,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allVisibleSelected = _filteredTeachers.isNotEmpty && _filteredTeachers.every((t) => _selectedIds.contains(t['id'].toString()));

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
            : Text(tr('subjectFaculty', {'subject': widget.subjectName}), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue)),
        centerTitle: false,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(allVisibleSelected ? Icons.deselect_rounded : Icons.select_all_rounded, color: StarlightTheme.primaryBlue),
              tooltip: allVisibleSelected ? tr('deselectAll') : tr('selectAll'),
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
              onPressed: _allTeachers.isNotEmpty ? _showPrintDialog : null,
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
                  hintText: tr('searchNameDesignation'),
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

          if (!_isLoading && _filteredTeachers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text("${_filteredTeachers.length} ${_filteredTeachers.length == 1 ? tr('teacherSingular') : tr('teacherPlural')}",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredTeachers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noTeachersFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 10, mainAxisSpacing: 10,
                        ),
                        itemCount: _filteredTeachers.length,
                        itemBuilder: (context, index) => _teacherCard(_filteredTeachers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _teacherCard(dynamic teacher) {
    final id = teacher['id'].toString();
    final name = (teacher['name'] ?? '').toString();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final designation = (teacher['designation'] ?? 'Faculty').toString();
    final phone = (teacher['phone'] ?? 'N/A').toString();
    final salary = (teacher['salary'] ?? 0).toString();
    final accessKey = (teacher['access_key'] ?? '').toString();
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(id);
        } else {
          _openEditSheet(teacher);
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
                      gradient: LinearGradient(colors: [Colors.blue[400]!, Colors.blue[600]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
            Text(designation, style: GoogleFonts.poppins(fontSize: 10, color: Colors.green[600], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            _infoRow(Icons.phone_rounded, phone),
            const SizedBox(height: 2),
            _infoRow(Icons.payments_rounded, tr('salaryPkr', {'salary': salary})),
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
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 10, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr('keyLabel', {'key': accessKey}),
                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.amber[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _confirmRegenerateKey(teacher),
                        child: Icon(Icons.autorenew_rounded, size: 12, color: Colors.amber[800]),
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

class EditTeacherSheet extends StatefulWidget {
  final dynamic teacher;
  final VoidCallback onUpdate;
  final DashboardService dashboardService;
  final DashboardCacheService cache;

  const EditTeacherSheet({required this.teacher, required this.onUpdate, required this.dashboardService, required this.cache});

  @override
  State<EditTeacherSheet> createState() => EditTeacherSheetState();
}

class EditTeacherSheetState extends State<EditTeacherSheet> {
  late TextEditingController _name, _designation, _phone, _salary;
  List<Map<String, TextEditingController>> _extraFields = [];
  List<dynamic> _assignedSections = [];
  bool _loadingSections = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.teacher['name']?.toString());
    _designation = TextEditingController(text: widget.teacher['designation']?.toString());
    _phone = TextEditingController(text: widget.teacher['phone']?.toString());
    _salary = TextEditingController(text: widget.teacher['salary']?.toString());

    if (widget.teacher['extra_fields'] != null) {
      (widget.teacher['extra_fields'] as Map).forEach((k, v) {
        _extraFields.add({
          "key": TextEditingController(text: k.toString()),
          "val": TextEditingController(text: v.toString()),
        });
      });
    }

    _loadAssignedSections();
  }

  Future<void> _loadAssignedSections() async {
    try {
      final sections = await widget.cache.getTeacherSections(widget.teacher['id'].toString());
      if (mounted) {
        setState(() {
          _assignedSections = sections;
          _loadingSections = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    _phone.dispose();
    _salary.dispose();
    for (var f in _extraFields) {
      f['key']!.dispose();
      f['val']!.dispose();
    }
    super.dispose();
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
      if (mounted) Navigator.pop(context);
      widget.onUpdate();
      if (mounted) {
        final isPending = result['pending'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending ? tr('teacherUpdatedPending') : tr('teacherUpdated')),
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
                Text(tr('editTeacher'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 24),
            _buildField(_name, tr('fullName'), icon: Icons.person_rounded),
            const SizedBox(height: 12),
            _buildField(_designation, tr('designation'), icon: Icons.work_rounded),
            const SizedBox(height: 12),
            _buildField(_phone, tr('phone'), icon: Icons.phone_rounded),
            const SizedBox(height: 12),
            _buildField(_salary, tr('salaryLabel'), icon: Icons.payments_rounded, kb: TextInputType.number),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(tr('customFields'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            ..._extraFields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _buildField(f['key']!, tr('field'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField(f['val']!, tr('value'))),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _extraFields.remove(f)),
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
              onTap: () => setState(() => _extraFields.add({"key": TextEditingController(), "val": TextEditingController()})),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.class_rounded, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(tr('assignedSections'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),
            _loadingSections
                ? const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                : _assignedSections.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                        child: Center(child: Text(tr('notAssignedToSection'), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]))),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _assignedSections.map((s) {
                          final sectionName = (s['section_name'] ?? '').toString();
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => StudentListScreen(sectionName: sectionName)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: StarlightTheme.primaryBlue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2)),
                              ),
                              child: Text(
                                sectionName,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
                              ),
                            ),
                          );
                        }).toList(),
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
                onPressed: _saveChanges,
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
