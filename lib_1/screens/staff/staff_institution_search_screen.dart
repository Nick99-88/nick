import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../services/institution/institution_service.dart';
import '../../models/institution/institution_model.dart';
import '../../models/staff/staff_join_request.dart';

class StaffInstitutionSearchScreen extends StatefulWidget {
  const StaffInstitutionSearchScreen({super.key});

  @override
  State<StaffInstitutionSearchScreen> createState() => _StaffInstitutionSearchScreenState();
}

class _StaffInstitutionSearchScreenState extends State<StaffInstitutionSearchScreen> {
  final InstitutionService _institutionService = InstitutionService();
  final TextEditingController _searchController = TextEditingController();
  
  List<InstitutionModel> _institutions = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  
  // Pending join requests
  List<StaffJoinRequest> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchInstitutions();
    _loadPendingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 🏛️ Fetch up to 50 institutions from the database
  Future<void> _fetchInstitutions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired. Please login again.");

      final institutions = await _institutionService.getInstitutions(
        token: token,
        limit: 50,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _institutions = institutions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// 🔍 Search for specific institution by name or code
  Future<void> _searchInstitution(String query) async {
    if (query.trim().isEmpty) {
      _fetchInstitutions();
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired.");

      final institutions = await _institutionService.searchInstitutions(
        token: token,
        query: query.trim(),
      );

      if (mounted) {
        setState(() {
          _institutions = institutions;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  /// 📋 Load pending join requests for the current staff member
  Future<void> _loadPendingRequests() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final requests = await _institutionService.getStaffJoinRequests(token: token);
      
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    } catch (e) {
      debugPrint('🏛️ Error loading pending requests: $e');
    }
  }

  /// 📝 Send join request to an institution
  Future<void> _sendJoinRequest(InstitutionModel institution) async {
    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired.");

      await _institutionService.sendStaffJoinRequest(
        token: token,
        institutionId: institution.id,
        message: "I would like to join ${institution.name} as a staff member.",
      );

      if (mounted) {
        StarlightUtils.showSuccessBox(
          context, 
          "Join request sent to ${institution.name}!"
        );
        _loadPendingRequests(); // Refresh pending requests
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ❌ Cancel pending join request
  Future<void> _cancelJoinRequest(String requestId) async {
    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired.");

      await _institutionService.cancelStaffJoinRequest(
        token: token,
        requestId: requestId,
      );

      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Join request cancelled");
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Find Institution',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          // Refresh button
          IconButton(
            icon: _isLoading 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              : const Icon(Icons.refresh),
            color: StarlightTheme.primaryBlue,
            onPressed: _isLoading ? null : _fetchInstitutions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search institution by name or code...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: StarlightTheme.primaryBlue),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchInstitutions();
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: StarlightTheme.primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onSubmitted: _searchInstitution,
              textInputAction: TextInputAction.search,
            ),
          ),

          // Pending Requests Section (if any)
          if (_pendingRequests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_pendingRequests.length} pending join request${_pendingRequests.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPendingRequestsBottomSheet(),
                    child: Text(
                      'View',
                      style: GoogleFonts.poppins(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error Message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.poppins(color: Colors.red[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchInstitutions,
                    color: Colors.red[700],
                  ),
                ],
              ),
            ),

          // Institutions List
          Expanded(
            child: _isLoading && _institutions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _institutions.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchInstitutions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _institutions.length,
                        itemBuilder: (context, index) {
                          final institution = _institutions[index];
                          return _buildInstitutionCard(institution);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No institutions found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or pull to refresh',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionCard(InstitutionModel institution) {
    final hasPendingRequest = _pendingRequests.any(
      (r) => r.institutionId == institution.id && r.status == 'pending'
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: StarlightTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: StarlightTheme.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (institution.code != null)
                        Text(
                          'Code: ${institution.code}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                // Institution Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: institution.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    institution.isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (institution.address != null)
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      institution.address!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (institution.staffCount != null)
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${institution.staffCount} staff',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                // Join Request Button
                if (hasPendingRequest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isLoading 
                      ? null 
                      : () => _showJoinRequestDialog(institution),
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(
                      'Request to Join',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StarlightTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📝 Show dialog to send join request
  void _showJoinRequestDialog(InstitutionModel institution) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Join ${institution.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a request to join this institution as a staff member.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Message (Optional)',
                hintText: 'Introduce yourself...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendJoinRequest(institution);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
            ),
            child: Text(
              'Send Request',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 📋 Show pending requests bottom sheet
  void _showPendingRequestsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Join Requests',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your requests to join institutions',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _pendingRequests.length,
                itemBuilder: (context, index) {
                  final request = _pendingRequests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100],
                        child: Icon(Icons.pending, color: Colors.orange[700]),
                      ),
                      title: Text(
                        request.institutionName ?? 'Unknown Institution',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Sent: ${request.createdAt?.toString().split(' ')[0] ?? 'Unknown'}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => _cancelJoinRequest(request.id),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
