import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../l10n/strings.dart';
import '../../../services/institution/dashboard_service.dart';
import 'database/dashboard_cache_service.dart';
import 'StudentListScreen.dart';
import 'TeachersBySubjectScreen.dart';

class SectionManagementScreen extends StatefulWidget {
  const SectionManagementScreen({super.key});

  @override
  State<SectionManagementScreen> createState() => _SectionManagementScreenState();
}

class _SectionManagementScreenState extends State<SectionManagementScreen> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final DashboardService _api = DashboardService();
  List<String> _allSections = [];
  List<String> _filteredSections = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<String> _selectedSections = {};

  @override
  void initState() {
    super.initState();
    _fetchSections();
    _searchController.addListener(_filterSections);
  }

  Future<void> _fetchSections() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getSections();
      setState(() {
        _allSections = data;
        _filteredSections = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadSectionsError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterSections() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSections = _allSections.where((s) => s.toLowerCase().contains(query)).toList();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedSections.clear();
    });
  }

  void _toggleSection(String section) {
    setState(() {
      if (_selectedSections.contains(section)) {
        _selectedSections.remove(section);
        if (_selectedSections.isEmpty) _isSelectionMode = false;
      } else {
        _selectedSections.add(section);
      }
    });
  }

  Future<void> _bulkDeleteSections() async {
    if (_selectedSections.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('deleteSectionsTitle', {'count': '${_selectedSections.length}'}), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          tr('deleteSectionsContent', {'count': '${_selectedSections.length}'}),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel'), style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('deleteAll'), style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    int deleted = 0;
    int pending = 0;
    for (var section in _selectedSections.toList()) {
      try {
        final result = await _cache.deleteSection(section);
        deleted++;
        if (result['pending'] == true) pending++;
      } catch (e) {
        debugPrint("Failed to delete section: $section - $e");
      }
    }

    setState(() {
      _selectedSections.clear();
      _isSelectionMode = false;
    });

    _fetchSections();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pending > 0
              ? tr('sectionsDeletedPending', {'deleted': '$deleted', 'pending': '$pending'})
              : tr('sectionsDeleted', {'deleted': '$deleted'})),
          backgroundColor: pending > 0 ? Colors.orange : (deleted > 0 ? Colors.green : Colors.red[700]),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                          color: StarlightTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded, color: StarlightTheme.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(tr('renameSection'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
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
                                  final result = await _cache.renameSection(oldName, newName);
                                  if (mounted) Navigator.pop(ctx);
                                  _fetchSections();
                                  if (mounted) {
                                    final isPending = result['pending'] == true;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isPending ? tr('sectionRenamedPending') : tr('sectionRenamed')),
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

  Future<void> _handleAssignTeacher(String sectionName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignTeacherSheet(
        sectionName: sectionName,
        cache: _cache,
        onOpenFullData: (teacherId) async {
          // Open full teacher record (reusing the teacher-list data sheet).
          try {
            final data = await _cache.getTeacherList(forceRefresh: true);
            final teachers = (data['teachers'] ?? data['rows'] ?? []) as List;
            final match = teachers.where((t) => (t['id'] ?? t['server_id'] ?? '').toString() == teacherId).toList();
            if (match.isNotEmpty && mounted) {
              Navigator.pop(ctx); // close assign sheet
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditTeacherSheet(
                  teacher: match.first,
                  onUpdate: () {},
                  dashboardService: _api,
                  cache: _cache,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('openTeacherRecordFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
              );
            }
          }
        },
      ),
    );
    _fetchSections(); // refresh in case anything changed
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
          _isSelectionMode
              ? tr('xSelected', {'count': '${_selectedSections.length}'})
              : tr('institutionSections'),
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode && _selectedSections.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red[400]),
              onPressed: _bulkDeleteSections,
            ),
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
                hintText: tr('searchSections'),
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

          if (!_isLoading && _filteredSections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    "${_filteredSections.length} ${_filteredSections.length == 1 ? tr('sectionSingular') : tr('sectionPlural')}",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredSections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.class_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noSectionsFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredSections.length,
                        itemBuilder: (context, index) {
                          String sectionName = _filteredSections[index];
                          final isSelected = _selectedSections.contains(sectionName);
                          final initials = sectionName.isNotEmpty ? sectionName[0].toUpperCase() : "?";

                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSection(sectionName);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => StudentListScreen(sectionName: sectionName)),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) _toggleSelectionMode();
                              _toggleSection(sectionName);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
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
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          StarlightTheme.primaryBlue.withOpacity(0.8),
                                          StarlightTheme.primaryBlue,
                                        ],
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
                                          sectionName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tr('tapToViewStudents'),
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isSelectionMode)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[200],
                                        shape: BoxShape.circle,
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                          : null,
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.grey[400]),
                                          tooltip: tr('assignTeacher'),
                                          onPressed: () => _handleAssignTeacher(sectionName),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.edit_rounded, size: 18, color: Colors.grey[400]),
                                          onPressed: () => _handleRename(sectionName),
                                        ),
                                      ],
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

class _AssignTeacherSheet extends StatefulWidget {
  final String sectionName;
  final DashboardCacheService cache;
  final Future<void> Function(String teacherId) onOpenFullData;

  const _AssignTeacherSheet({
    required this.sectionName,
    required this.cache,
    required this.onOpenFullData,
  });

  @override
  State<_AssignTeacherSheet> createState() => _AssignTeacherSheetState();
}

class _AssignTeacherSheetState extends State<_AssignTeacherSheet> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allTeachers = [];
  List<dynamic> _filteredTeachers = [];
  List<dynamic> _assigned = [];
  String? _selectedTeacherId;

  bool _loading = true;
  bool _assigning = false;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterTeachers);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await widget.cache.getTeacherList(forceRefresh: true);
      final teachers = (data['teachers'] ?? data['rows'] ?? []) as List;
      final assigned = await widget.cache.getSectionTeachers(widget.sectionName);
      if (mounted) {
        setState(() {
          _allTeachers = teachers;
          _filteredTeachers = List.from(teachers);
          _assigned = assigned;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _filterTeachers() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = _allTeachers.where((t) {
        final name = (t['name'] ?? '').toString().toLowerCase();
        final subj = (t['subject_name'] ?? t['designation'] ?? '').toString().toLowerCase();
        return name.contains(q) || subj.contains(q);
      }).toList();
    });
  }

  String _teacherId(dynamic t) => (t['id'] ?? t['server_id'] ?? '').toString();

  bool _isAlreadyAssigned(String id, String subject) {
    return _assigned.any((a) =>
        _teacherId(a) == id && (a['assigned_subject'] ?? '').toString().toLowerCase() == subject.toLowerCase());
  }

  Future<void> _assign() async {
    final subject = _subjectController.text.trim();
    final id = _selectedTeacherId;
    if (id == null || id.isEmpty || subject.isEmpty) return;

    if (_isAlreadyAssigned(id, subject)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('teacherAlreadyAssigned', {'subject': subject})), backgroundColor: Colors.orange[700], behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _assigning = true);
    try {
      await widget.cache.assignTeacherToSection(id, widget.sectionName, subject);
      final assigned = await widget.cache.getSectionTeachers(widget.sectionName);
      if (mounted) {
        setState(() {
          _assigned = assigned;
          _selectedTeacherId = null;
          _assigning = false;
          _subjectController.clear();
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('teacherAssignedTo', {'section': widget.sectionName})), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _assigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('assignmentFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _confirmRemove(dynamic teacher) async {
    final subject = (teacher['assigned_subject'] ?? '').toString();
    final name = (teacher['name'] ?? '').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('unassignTeacher'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        content: Text(
          tr('removeTeacherFrom', {'name': name, 'section': widget.sectionName, 'subject': subject}),
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

    if (confirm != true || !mounted) return;

    try {
      await widget.cache.removeTeacherFromSection(widget.sectionName, _teacherId(teacher), subject);
      final assigned = await widget.cache.getSectionTeachers(widget.sectionName);
      if (mounted) {
        setState(() => _assigned = assigned);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('removeFailed', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = _subjectController.text.trim();
    final canAssign = _selectedTeacherId != null && _selectedTeacherId!.isNotEmpty && subject.isNotEmpty && !_assigning;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: StarlightTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: StarlightTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('assignTeacher'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                        Text(tr('sectionPrefix', {'section': widget.sectionName}), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text(tr('couldNotLoadTeachers'), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: _loadData,
                                child: Text(tr('retry'), style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shrinkWrap: true,
                          children: [
                            if (_assigned.isNotEmpty) ...[
                              Text(tr('assignedTeachersCount', {'count': '${_assigned.length}'}), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              ..._assigned.map((t) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => widget.onOpenFullData(_teacherId(t)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(t['name'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                                if ((t['sync_status'] ?? 'done') == 'pending') ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                                                    child: Text(tr('pendingSync'), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.orange[700])),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(tr('subjectPrefix', {'subject': t['assigned_subject'] ?? ''}), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.red[400]),
                                      onPressed: () => _confirmRemove(t),
                                    ),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 8),
                            ],
                            TextField(
                              controller: _subjectController,
                              autofocus: true,
                              style: GoogleFonts.poppins(fontSize: 15),
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: tr('enterSubjectName'),
                                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _searchController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              onChanged: (_) => _filterTeachers(),
                              decoration: InputDecoration(
                                hintText: tr('searchTeachers'),
                                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_filteredTeachers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(tr('noTeachersFound'), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400])),
                              )
                            else
                              ..._filteredTeachers.map((t) {
                                final id = _teacherId(t);
                                final isSelected = _selectedTeacherId == id;
                                final dup = subject.isNotEmpty && _isAlreadyAssigned(id, subject);
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedTeacherId = id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? StarlightTheme.primaryBlue.withOpacity(0.08) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[200]!, width: isSelected ? 1.5 : 1),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.15),
                                          child: Text(
                                            ((t['name'] ?? '?').toString()).isNotEmpty ? (t['name']).toString()[0].toUpperCase() : "?",
                                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: StarlightTheme.primaryBlue),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(t['name'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                              Text(
                                                dup ? tr('alreadyAssignedFor', {'subject': subject}) : tr('subjectColon', {'subject': t['subject_name'] ?? t['designation'] ?? 'N/A'}),
                                                style: GoogleFonts.poppins(fontSize: 11, color: dup ? Colors.orange[700] : Colors.grey[500]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected) const Icon(Icons.check_circle_rounded, color: StarlightTheme.primaryBlue, size: 22),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 12),
                          ],
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAssign ? StarlightTheme.primaryBlue : Colors.grey[200],
                    disabledBackgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: canAssign ? _assign : null,
                  child: _assigning
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          tr('assignTeacher'),
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: canAssign ? Colors.white : Colors.grey[500]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
