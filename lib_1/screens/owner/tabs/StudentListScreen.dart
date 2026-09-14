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

class StudentListScreen extends StatefulWidget {
  final String sectionName;
  const StudentListScreen({super.key, required this.sectionName});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterLogic);
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getStudentsBySection(widget.sectionName);
      setState(() {
        _allStudents = data;
        _filteredStudents = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadRecordsError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterLogic() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name'] ?? "").toString().toLowerCase();
        final fName = (s['father_name'] ?? "").toString().toLowerCase();
        return name.contains(query) || fName.contains(query);
      }).toList();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIndices.clear();
    });
  }

  void _toggleStudent(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == _filteredStudents.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(_filteredStudents.length, (i) => i));
      }
    });
  }

  void _showPrintOptions() {
    if (_selectedIndices.isEmpty) return;
    String selectedOption = 'access_keys';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('printOptions'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('xStudentsSelected', {'count': '${_selectedIndices.length}'}),
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 16),
              RadioListTile<String>(
                value: 'access_keys', groupValue: selectedOption, dense: true, contentPadding: EdgeInsets.zero,
                activeColor: StarlightTheme.primaryBlue,
                onChanged: (v) => setDialogState(() => selectedOption = v!),
                title: Text(tr('accessKeysOnly'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(tr('nameFatherAccessKey'), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
              ),
              RadioListTile<String>(
                value: 'full_data', groupValue: selectedOption, dense: true, contentPadding: EdgeInsets.zero,
                activeColor: StarlightTheme.primaryBlue,
                onChanged: (v) => setDialogState(() => selectedOption = v!),
                title: Text(tr('dataPlusKeys'), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(tr('fullRecordsWithKeys'), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _generatePrint(selectedOption);
              },
              child: Text(tr('confirm'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _generatePrint(String option) {
    final students = _selectedIndices.map((i) => _filteredStudents[i]).toList();
    _printPdf(students, option);
  }

  Future<void> _printPdf(List<dynamic> students, String option) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#1A237E');
    final lightBlue = PdfColor.fromHex('#E8EAF6');
    final accentGreen = PdfColor.fromHex('#2E7D32');
    final lightGreen = PdfColor.fromHex('#E8F5E9');
    final darkText = PdfColor.fromHex('#1E293B');
    final greyText = PdfColor.fromHex('#64748B');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [primaryColor, PdfColor.fromHex('#0D1B5E')],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    tr('printStudentRecords'),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    tr('sectionPrefix', {'section': widget.sectionName}),
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  tr('pdfGenerated', {'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'}),
                  style: pw.TextStyle(color: greyText, fontSize: 9),
                ),
                pw.Text(
                  tr('pdfTotalStudents', {'count': '${students.length}'}),
                  style: pw.TextStyle(color: greyText, fontSize: 9),
                ),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            tr('pdfFooter', {'page': '${context.pageNumber}'}),
            style: pw.TextStyle(color: greyText, fontSize: 8),
          ),
        ),
        build: (context) => [
          if (option == 'access_keys') ...[
            _buildAccessKeysTable(students, primaryColor, lightBlue, greyText, darkText),
          ] else ...[
            _buildDataTable(students, primaryColor, accentGreen, lightGreen, darkText, greyText, lightBlue),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Student_Records_${widget.sectionName}',
    );
  }

  pw.Widget _buildAccessKeysTable(List<dynamic> students, PdfColor primaryColor, PdfColor lightBlue, PdfColor greyText, PdfColor darkText) {
    if (students.isEmpty) return pw.SizedBox();
    pw.Padding cell(String text, PdfColor color, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: lightBlue,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            tr('printAccessKeys'),
            style: pw.TextStyle(color: primaryColor, fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2.6),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: lightBlue),
              children: [
                cell('#', primaryColor, bold: true),
                cell(tr('printStudentName'), primaryColor, bold: true),
                cell(tr('printFatherName'), primaryColor, bold: true),
                cell(tr('printAccessKey'), primaryColor, bold: true),
              ],
            ),
            ...students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return pw.TableRow(
                children: [
                  cell('${i + 1}', greyText),
                  cell(s['name'] ?? 'N/A', darkText),
                  cell(s['father_name'] ?? 'N/A', darkText),
                  cell((s['access_key'] ?? 'N/A').toString(), PdfColor.fromHex('#1A237E'), bold: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDataTable(List<dynamic> students, PdfColor primaryColor, PdfColor accentGreen, PdfColor lightGreen, PdfColor darkText, PdfColor greyText, PdfColor lightBlue) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: lightBlue,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            tr('printStudentData'),
            style: pw.TextStyle(color: primaryColor, fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
        ...students.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final extras = s['extra_fields'];
          final hasExtras = extras != null && extras is Map && extras.isNotEmpty;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 24,
                      height: 24,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${i + 1}',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Text(
                        s['name'] ?? 'N/A',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkText),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: lightGreen,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        tr('rupeesPrefix', {'amount': '${s['fee'] ?? '0'}'}),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentGreen),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                _buildInfoRow(tr('labelFather'), s['father_name'] ?? 'N/A', greyText, darkText),
                _buildInfoRow(tr('labelSection'), s['section'] ?? 'N/A', greyText, darkText),
                _buildInfoRow(tr('labelAccessKey'), s['access_key'] ?? 'N/A', greyText, PdfColor.fromHex('#1A237E')),
                if (hasExtras) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FFF8E1'),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          tr('extraFields'),
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#F57F17')),
                        ),
                        pw.SizedBox(height: 4),
                        ...extras.entries.map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 2),
                          child: pw.Row(
                            children: [
                              pw.Text('${e.key}: ', style: pw.TextStyle(fontSize: 9, color: greyText)),
                              pw.Text('${e.value}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkText)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value, PdfColor labelColor, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: labelColor)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: valueColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(String? id) async {
    if (id == null || id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('deleteRecord'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(tr('actionCannotBeUndone'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'), style: GoogleFonts.poppins())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _cache.deleteStudent(id);
      _fetchStudents();
      if (mounted) {
        final isPending = result['pending'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending ? tr('recordRemovedPending') : tr('recordRemoved')),
            backgroundColor: isPending ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('deletionFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _toggleSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isSelectionMode ? tr('xSelected', {'count': '${_selectedIndices.length}'}) : widget.sectionName,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedIndices.length == _filteredStudents.length && _filteredStudents.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                color: StarlightTheme.primaryBlue,
              ),
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded, color: StarlightTheme.primaryBlue),
              onPressed: _selectedIndices.isNotEmpty ? _showPrintOptions : null,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.grey),
              onPressed: _allStudents.isNotEmpty ? _toggleSelectionMode : null,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('searchByName'),
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),

          if (!_isLoading && _filteredStudents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${_filteredStudents.length} ${_filteredStudents.length == 1 ? tr('studentSingular') : tr('studentPlural')}",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noStudentsFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) => _buildStudentCard(_filteredStudents[index], index),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerateKey(Map<String, dynamic> student) async {
    final id = '${student['server_id'] ?? student['local_id'] ?? ''}';
    if (id.isEmpty) return;
    final name = student['name'] ?? 'this student';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.autorenew_rounded, color: StarlightTheme.primaryBlue),
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
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('regenerate')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final newKey = await _cache.regenerateStudentKey(id);
      await _fetchStudents();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final isSelected = _selectedIndices.contains(index);
    final name = (student['name'] ?? "N/A").toString();
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleStudent(index);
        } else {
          _openProfile(student);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) _toggleSelectionMode();
        _toggleStudent(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? StarlightTheme.primaryBlue : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? StarlightTheme.primaryBlue.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StarlightTheme.primaryBlue.withOpacity(0.8),
                              StarlightTheme.primaryBlue,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            initials.isNotEmpty ? initials : "?",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!_isSelectionMode)
                        GestureDetector(
                          onTap: () => _handleDelete(student['id']?.toString()),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[400]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr('fatherPrefix', {'father': student['father_name'] ?? 'N/A'}),
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GestureDetector(
                    onTap: () {
                      final key = student['access_key'] ?? "";
                      if (key.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: key));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tr('copiedKey', {'key': key}),
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.vpn_key_rounded, size: 11, color: StarlightTheme.primaryBlue),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              student['access_key'] ?? "N/A",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: StarlightTheme.primaryBlue,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_rounded, size: 10, color: StarlightTheme.primaryBlue.withOpacity(0.6)),
                        ],
                      ),
                    ),
                  ),
                ),
                      IconButton(
                        icon: const Icon(Icons.autorenew_rounded, size: 16),
                        tooltip: tr('regenerateAccessKey'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        onPressed: () => _confirmRegenerateKey(student),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[50]!, Colors.green[100]!],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_rounded, size: 13, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          tr('rupeesPrefix', {'amount': '${student['fee'] ?? '0'}'}),
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    isSelected ? Icons.check_rounded : null,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openProfile(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileEditSheet(student: student, onUpdate: _fetchStudents),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onUpdate;
  const _ProfileEditSheet({required this.student, required this.onUpdate});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  late TextEditingController _name, _father, _fee;
  List<Map<String, TextEditingController>> _extraFields = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.student['name']);
    _father = TextEditingController(text: widget.student['father_name']);
    _fee = TextEditingController(text: widget.student['fee'].toString());
    Map<String, dynamic> extras = widget.student['extra_fields'] ?? {};
    extras.forEach((k, v) {
      _extraFields.add({"key": TextEditingController(text: k), "val": TextEditingController(text: v.toString())});
    });
  }

  Future<void> _saveToVault() async {
    Map<String, String> extrasMap = {};
    for (var f in _extraFields) {
      if (f['key']!.text.isNotEmpty) extrasMap[f['key']!.text] = f['val']!.text;
    }
    final data = {
      "name": _name.text,
      "father_name": _father.text,
      "fee": double.tryParse(_fee.text) ?? 0.0,
      "section": widget.student['section'],
      "extra_fields": extrasMap,
    };
    try {
      final result = await _cache.editStudent(widget.student['id'], data);
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdate();
        final isPending = result['pending'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending ? tr('profileUpdatedPending') : tr('profileUpdated')),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              tr('editProfile'),
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: StarlightTheme.primaryBlue),
            ),
            const SizedBox(height: 6),
            Text(
              widget.student['name'] ?? '',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            _buildField(_name, tr('studentName'), Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _buildField(_father, tr('fatherName'), Icons.person_pin_outlined),
            const SizedBox(height: 14),
            _buildField(_fee, tr('admissionFee'), Icons.payments_outlined, kbType: TextInputType.number),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  tr('additionalFields'),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._extraFields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: _buildCompactField(f['key']!, tr('field'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCompactField(f['val']!, tr('value'))),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red[300], size: 22),
                    onPressed: () => setState(() => _extraFields.remove(f)),
                  ),
                ],
              ),
            )),
            GestureDetector(
              onTap: () => setState(() => _extraFields.add({"key": TextEditingController(), "val": TextEditingController()})),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(tr('addField'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500])),
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
                onPressed: _saveToVault,
                child: Text(tr('saveChanges'), style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label, IconData icon, {TextInputType kbType = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: kbType,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
      ),
    );
  }

  Widget _buildCompactField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
        isDense: true,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _father.dispose();
    _fee.dispose();
    for (var f in _extraFields) {
      f['key']?.dispose();
      f['val']?.dispose();
    }
    super.dispose();
  }
}
