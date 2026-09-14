import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../l10n/strings.dart';
import 'database/dashboard_cache_service.dart';
import 'TeachersBySubjectScreen.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() => _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  List<String> _allSubjects = [];
  List<String> _filteredSubjects = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<String> _selectedSubjects = {};

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _searchController.addListener(_filterSubjects);
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getSubjects();
      setState(() {
        _allSubjects = data;
        _filteredSubjects = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadSubjectsError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterSubjects() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects = _allSubjects.where((s) => s.toLowerCase().contains(query)).toList();
    });
  }

  void _enterSelectionMode(String initialSubject) {
    setState(() {
      _isSelectionMode = true;
      _selectedSubjects.add(initialSubject);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSubjects.clear();
    });
  }

  void _toggleSelection(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
        if (_selectedSubjects.isEmpty) _isSelectionMode = false;
      } else {
        _selectedSubjects.add(subject);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedSubjects.length == _filteredSubjects.length) {
        _selectedSubjects.clear();
        _isSelectionMode = false;
      } else {
        _selectedSubjects.clear();
        _selectedSubjects.addAll(_filteredSubjects);
      }
    });
  }

  Future<void> _handleDelete() async {
    final count = _selectedSubjects.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          count == 1 ? tr('deleteSubjectTitle') : tr('deleteSubjectsTitle', {'count': '$count'}),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        content: Text(
          count == 1
              ? tr('deleteSubjectContent')
              : tr('deleteSubjectsContent', {'count': '$count'}),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _cache.deleteSubjects(_selectedSubjects.toList());
      _exitSelectionMode();
      _fetchSubjects();
      if (mounted) {
        final isPending = result['pending'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending
                ? (count == 1 ? tr('subjectDeletedPending') : tr('subjectsDeletedPending', {'count': '$count'}))
                : (count == 1 ? tr('subjectDeleted') : tr('subjectsDeleted', {'count': '$count'}))),
            backgroundColor: isPending ? Colors.orange : Colors.green[700],
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

  Future<void> _handleRename(String oldName) async {
    TextEditingController renameController = TextEditingController(text: oldName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final newName = renameController.text.trim();
            final hasChange = newName.isNotEmpty && newName != oldName;
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_rounded, color: Colors.green[600], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(tr('renameSubject'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(oldName, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: renameController,
                    autofocus: true,
                    style: GoogleFonts.poppins(fontSize: 15),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: tr('enterNewName'),
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: renameController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                              onPressed: () {
                                renameController.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasChange ? StarlightTheme.primaryBlue : Colors.grey[200],
                        disabledBackgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: hasChange
                          ? () async {
                              String newName = renameController.text.trim();
                              if (newName.isNotEmpty && newName != oldName) {
                                try {
                                  final result = await _cache.renameSubject(oldName, newName);
                                  if (mounted) Navigator.pop(ctx);
                                  _fetchSubjects();
                                  if (mounted) {
                                    final isPending = result['pending'] == true;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isPending ? tr('subjectRenamedPending') : tr('subjectRenamed')),
                                        backgroundColor: isPending ? Colors.orange : Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(tr('renameFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
                                    );
                                  }
                                }
                              }
                            }
                          : null,
                      child: Text(
                        tr('updateName'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasChange ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allSelected = _filteredSubjects.isNotEmpty && _selectedSubjects.length == _filteredSubjects.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelectionMode
            ? Text(
                tr('xSelected', {'count': '${_selectedSubjects.length}'}),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              )
            : Text(
                tr('teacherSubjects'),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
              ),
        centerTitle: false,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                color: StarlightTheme.primaryBlue,
              ),
              tooltip: allSelected ? tr('deselectAll') : tr('selectAll'),
              onPressed: _selectAll,
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, color: Colors.red[600]),
              tooltip: tr('deleteSelected'),
              onPressed: _selectedSubjects.isNotEmpty ? _handleDelete : null,
            ),
          ],
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
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
                  hintText: tr('searchSubjects'),
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

          if (!_isLoading && _filteredSubjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${_filteredSubjects.length} ${_filteredSubjects.length == 1 ? tr('subjectSingular') : tr('subjectPlural')}",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredSubjects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.book_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noSubjectsFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          String subjectName = _filteredSubjects[index];
                          final initials = subjectName.isNotEmpty ? subjectName[0].toUpperCase() : "?";
                          final isSelected = _selectedSubjects.contains(subjectName);

                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(subjectName);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TeachersBySubjectScreen(subjectName: subjectName)),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                _enterSelectionMode(subjectName);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? StarlightTheme.primaryBlue.withOpacity(0.06) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3), width: 1.5)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (_isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[350],
                                        size: 22,
                                      ),
                                    ),
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green[400]!, Colors.green[600]!],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subjectName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isSelectionMode
                                              ? (isSelected ? tr('tapToDeselect') : tr('tapToSelect'))
                                              : tr('tapToViewTeachers'),
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isSelectionMode)
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded, size: 18, color: Colors.grey[400]),
                                      onPressed: () => _handleRename(subjectName),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
