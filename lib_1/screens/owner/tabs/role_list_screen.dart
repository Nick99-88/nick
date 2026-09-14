import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../l10n/strings.dart';
import 'database/dashboard_cache_service.dart';
import 'StaffByRoleScreen.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final DashboardCacheService _cache = DashboardCacheService.instance;
  List<String> _allRoles = [];
  List<String> _filteredRoles = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<String> _selectedRoles = {};

  @override
  void initState() {
    super.initState();
    _fetchRoles();
    _searchController.addListener(_filterRoles);
  }

  Future<void> _fetchRoles() async {
    setState(() => _isLoading = true);
    try {
      final data = await _cache.getRoles();
      setState(() {
        _allRoles = data;
        _filteredRoles = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('loadRolesError', {'error': '$e'})), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _filterRoles() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRoles = _allRoles.where((r) => r.toLowerCase().contains(query)).toList();
    });
  }

  void _enterSelectionMode(String initialRole) {
    setState(() {
      _isSelectionMode = true;
      _selectedRoles.add(initialRole);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedRoles.clear();
    });
  }

  void _toggleSelection(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
        if (_selectedRoles.isEmpty) _isSelectionMode = false;
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedRoles.length == _filteredRoles.length) {
        _selectedRoles.clear();
        _isSelectionMode = false;
      } else {
        _selectedRoles.clear();
        _selectedRoles.addAll(_filteredRoles);
      }
    });
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
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.edit_rounded, color: StarlightTheme.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(tr('renameRole'), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
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
                              onPressed: () { renameController.clear(); setModalState(() {}); },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
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
                                  final result = await _cache.renameRole(oldName, newName);
                                  if (mounted) Navigator.pop(ctx);
                                  _fetchRoles();
                                  if (mounted) {
                                    final isPending = result['pending'] == true;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isPending ? tr('roleRenamedPending') : tr('roleRenamed')),
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
                      child: Text(tr('updateName'), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: hasChange ? Colors.white : Colors.grey[500])),
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
    final bool allSelected = _filteredRoles.isNotEmpty && _selectedRoles.length == _filteredRoles.length;

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
            ? Text(tr('xSelected', {'count': '${_selectedRoles.length}'}), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))
            : Text(tr('staffRoles'), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue)),
        centerTitle: false,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, color: StarlightTheme.primaryBlue),
              tooltip: allSelected ? tr('deselectAll') : tr('selectAll'),
              onPressed: _selectAll,
            ),
            IconButton(
              icon: Icon(Icons.delete_rounded, color: Colors.red[600]),
              tooltip: tr('deleteSelected'),
              onPressed: _selectedRoles.isNotEmpty ? () async {
                final roleCount = _selectedRoles.length;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(tr('deleteRolesTitle', {'count': '$roleCount'}),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
                    content: Text(tr('deleteRolesContent'),
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'), style: GoogleFonts.poppins(color: Colors.grey[600]))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(tr('delete'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  try {
                    int pending = 0;
                    for (final role in _selectedRoles) {
                      final result = await _cache.deleteRole(role);
                      if (result['pending'] == true) pending++;
                    }
                    _exitSelectionMode();
                    _fetchRoles();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(pending > 0
                            ? tr('rolesDeletedPending', {'count': '$roleCount'})
                            : tr('rolesDeleted', {'count': '$roleCount'})),
                            backgroundColor: pending > 0 ? Colors.orange : Colors.green[700], behavior: SnackBarBehavior.floating),
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
              } : null,
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
                  hintText: tr('searchRoles'),
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

          if (!_isLoading && _filteredRoles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text("${_filteredRoles.length} ${_filteredRoles.length == 1 ? tr('roleSingular') : tr('rolePlural')}",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                : _filteredRoles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(tr('noRolesFound'), style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredRoles.length,
                        itemBuilder: (context, index) {
                          String roleName = _filteredRoles[index];
                          final initials = roleName.isNotEmpty ? roleName[0].toUpperCase() : "?";
                          final isSelected = _selectedRoles.contains(roleName);

                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(roleName);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => StaffByRoleScreen(roleName: roleName)));
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) _enterSelectionMode(roleName);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? StarlightTheme.primaryBlue.withOpacity(0.06) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected ? Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3), width: 1.5) : null,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
                                    width: 46, height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.teal[400]!, Colors.teal[600]!],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(initials, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(roleName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isSelectionMode
                                              ? (isSelected ? tr('tapToDeselect') : tr('tapToSelect'))
                                              : tr('tapToViewStaff'),
                                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isSelectionMode)
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded, size: 18, color: Colors.grey[400]),
                                      onPressed: () => _handleRename(roleName),
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
