import 'package:flutter/material.dart';
import '../../../core/sign.dart';
import '../../../services/institution/directory_service.dart';

class VerifyIdentitiesScreen extends StatefulWidget {
  final VoidCallback onClose;
  const VerifyIdentitiesScreen({super.key, required this.onClose});

  @override
  State<VerifyIdentitiesScreen> createState() => _VerifyIdentitiesScreenState();
}

class _VerifyIdentitiesScreenState extends State<VerifyIdentitiesScreen> {
  // Helper method to resolve text direction consistency
  TextDirection getTextDirection() {
    return TextDirection.ltr;
  }

  final DirectoryService _directoryService = DirectoryService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _processingId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await _directoryService.getJoinRequests();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Enforce user rule: Don't use alerts; use a red or green sign box instead.
        StarlightUtils.showErrorBox(context, "Could not sync requests.");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApproval(String reqId) async {
    setState(() => _processingId = reqId);
    try {
      await _directoryService.approveRequest(reqId);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Identity Verified & Approved!");
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _handleRejection(String reqId) async {
    setState(() => _processingId = reqId);
    try {
      await _directoryService.rejectRequest(reqId);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Request Rejected.");
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  List<dynamic> get _filteredRequests {
    if (_searchQuery.isEmpty) return _requests;
    return _requests.where((req) {
      final name = (req['user_name'] ?? '').toString().toLowerCase();
      final role = (req['role_requested'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1E293B)),
            onPressed: widget.onClose,
          ),
        ),
        title: Text(
          "VERIFY IDENTITIES",
          textDirection: getTextDirection(),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Banner Container matching previous management consoles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "PENDING APPROVALS",
                            textDirection: getTextDirection(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Identity Verification Console",
                          textDirection: getTextDirection(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Review and authorize membership requests securely.",
                          textDirection: getTextDirection(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search requests by name or role...",
                  hintTextDirection: getTextDirection(),
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Main List Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0).withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.done_all_rounded,
                                  size: 40, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No pending requests",
                              textDirection: getTextDirection(),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "All verification requests have been processed.",
                              textDirection: getTextDirection(),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          final reqId = req['id']?.toString() ?? '';
                          final userName = req['user_name'] ?? 'Unknown User';
                          final roleRequested =
                              req['role_requested'] ?? 'Member';
                          final profilePhoto =
                              req['profile_photo'] ?? req['pfp'];
                          final isProcessing = _processingId == reqId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    image: profilePhoto != null
                                        ? DecorationImage(
                                            image: NetworkImage(profilePhoto),
                                            fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: profilePhoto == null
                                      ? const Icon(Icons.person_outline_rounded,
                                          color: Color(0xFF2563EB), size: 22)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        textDirection: getTextDirection(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "WANTS TO JOIN AS: ${roleRequested.toUpperCase()}",
                                          textDirection: getTextDirection(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Approve Button
                                    InkWell(
                                      onTap: _processingId == null
                                          ? () => _handleApproval(reqId)
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: isProcessing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFF10B981)),
                                                ),
                                              )
                                            : const Icon(Icons.check_rounded,
                                                color: Color(0xFF10B981),
                                                size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Reject Button
                                    InkWell(
                                      onTap: _processingId == null
                                          ? () => _handleRejection(reqId)
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            color: Color(0xFFEF4444), size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
