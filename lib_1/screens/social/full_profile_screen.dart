import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../core/theme.dart';
import '../../services/social/explore_service.dart';
import '../owner/profile_tabs/institution_leaderboard_screen.dart';
import 'public_portfolio_screen.dart';

class FullProfileScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isUser;
  final bool? hasInstitution;

  const FullProfileScreen({super.key, required this.item, required this.isUser, this.hasInstitution});

  @override
  State<FullProfileScreen> createState() => _FullProfileScreenState();
}

class _FullProfileScreenState extends State<FullProfileScreen> {
  final ExploreService _exploreService = ExploreService();
  Map<String, dynamic>? _institutionDetails;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isUser) {
      _fetchInstitutionDetails();
    }
  }

  Future<void> _fetchInstitutionDetails() async {
    if (!widget.isUser && widget.item['id'] != null) {
      setState(() => _isLoadingDetails = true);
      try {
        final details = await _exploreService.getInstitutionDetails(widget.item['id']);
        if (mounted) {
          setState(() {
            _institutionDetails = details;
            _isLoadingDetails = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingDetails = false);
        }
      }
    }
  }

  void _handleJoinRequest() async {
    const roleToRequest = "student";
    try {
      await _exploreService.sendJoinRequest(widget.item['id'], roleToRequest);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Admission Request Sent!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    }
  }

  void _showAccessKeyInput() {
    final controller = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text("Join with Access Key"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Enter 16-character key",
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            textCapitalization: TextCapitalization.characters,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final key = controller.text.trim().toUpperCase();
                      if (key.isEmpty) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        final ref = widget.item['reference_id']?.toString() ?? widget.item['id'].toString();
                        final result = await _exploreService.joinWithAccessKey(ref, key);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          StarlightUtils.showSuccessBox(context, result['message'] ?? "Joined successfully");
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Join"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _institutionDetails ?? widget.item;
    final inst = widget.isUser
        ? (widget.item['institution'] as Map<String, dynamic>?)
        : details;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isUser ? "Profile" : "Institution",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: widget.isUser ? _buildUserBody(inst) : _buildInstitutionBody(details),
    );
  }

  Widget _buildUserBody(Map<String, dynamic>? inst) {
    final pfpUrl = "${StarlightConstants.apiBaseUrl}/explore/pfp/user/${widget.item['id']}";
    final role = widget.item['role']?.toString().toUpperCase() ?? 'USER';

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(pfpUrl, gradientColors: const [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildAvatar(pfpUrl, 65, isUser: true),
                const SizedBox(height: 14),
                Text(
                  widget.item['name'] ?? 'User',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1A237E).withOpacity(0.1), Color(0xFF283593).withOpacity(0.05)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A237E), letterSpacing: 1.5)),
                ),
                const SizedBox(height: 20),
                if (widget.item['bio'] != null && widget.item['bio'].toString().isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.08)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, color: const Color(0xFF1A237E).withOpacity(0.3), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item['bio'].toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildInfoCard([
                  if (widget.item['shortId'] != null)
                    _infoRow(Icons.fingerprint, 'ID', widget.item['shortId'].toString(), Colors.indigo,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: widget.item['shortId'].toString()));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID copied'), duration: Duration(seconds: 1)));
                      },
                      onShare: () => Share.share('Check out ${widget.item['name']} on Starlight Institution\nhttps://institution.site/u/${widget.item['id']}'),
                    ),
                  if (widget.item['gender'] != null)
                    _infoRow(Icons.people_outline, 'Gender', widget.item['gender'].toString(), Colors.purple),
                  if (widget.item['classSection'] != null && widget.item['classSection'].toString().isNotEmpty)
                    _infoRow(Icons.class_rounded, 'Section', widget.item['classSection'].toString(), Colors.teal),
                ]),
                const SizedBox(height: 16),
                _buildLocationButton(
                  city: widget.item['city']?.toString(),
                  country: widget.item['country']?.toString(),
                  latitude: widget.item['latitude'] != null ? double.tryParse(widget.item['latitude'].toString()) : null,
                  longitude: widget.item['longitude'] != null ? double.tryParse(widget.item['longitude'].toString()) : null,
                  name: widget.item['name']?.toString() ?? 'User',
                  color: const Color(0xFF1A237E),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicPortfolioView(userId: widget.item['id'].toString(), userName: widget.item['name'] ?? 'User'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.work_outline_rounded, size: 18),
                    label: const Text("View Portfolio"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A237E),
                      side: BorderSide(color: const Color(0xFF1A237E).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (inst != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1565C0).withOpacity(0.06), const Color(0xFF1565C0).withOpacity(0.02)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.12)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1565C0), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inst['name'] ?? 'Institution',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                  ),
                                  if (inst['reference_id'] != null) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1565C0).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'REF-${inst['reference_id'].toString().toUpperCase()}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1565C0), letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InstitutionLeaderboardScreen(
                                    onClose: () => Navigator.pop(context),
                                    institutionId: inst['id'].toString(),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.leaderboard_outlined, size: 18),
                            label: const Text("View Leaderboard"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1565C0),
                              side: BorderSide(color: const Color(0xFF1565C0).withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionBody(Map<String, dynamic> details) {
    final pfpUrl = "${StarlightConstants.apiBaseUrl}/explore/pfp/institution/${widget.item['id']}";
    final type = details['type']?.toString().toUpperCase() ?? 'INSTITUTION';
    final ref = details['ref'] ?? '';

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(pfpUrl, gradientColors: const [Color(0xFFE65100), Color(0xFFBF360C), Color(0xFF3E2723)]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildAvatar(pfpUrl, 65, isUser: false),
                const SizedBox(height: 14),
                Text(
                  details['name'] ?? widget.item['name'] ?? 'Institution',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFBF360C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFBF360C), letterSpacing: 1.2)),
                      ),
                    if (ref.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(ref, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (details['description'] != null && details['description'].toString().isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(details['description'].toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildInfoCard([
                  if (details['reference_id'] != null)
                    _infoRow(Icons.tag, 'Reference', details['reference_id'].toString().toUpperCase(), Colors.blueGrey,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: details['reference_id'].toString().toUpperCase()));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference ID copied'), duration: Duration(seconds: 1)));
                      },
                      onShare: () => Share.share('Check out ${details['name'] ?? widget.item['name']} on Starlight Institution\nhttps://institution.site/i/${widget.item['id']}'),
                    ),
                  if (details['owner_name'] != null)
                    _infoRow(Icons.person, 'Owner', details['owner_name'].toString(), Colors.brown),
                  if (details['address'] != null)
                    _infoRow(Icons.location_on_outlined, 'Address', details['address'].toString(), Colors.red.shade400),
                  if (details['email'] != null)
                    _infoRow(Icons.email_outlined, 'Email', details['email'].toString(), Colors.blue.shade400),
                ]),
                const SizedBox(height: 16),
                _buildLocationButton(
                  city: details['city']?.toString() ?? widget.item['city']?.toString(),
                  country: details['country']?.toString() ?? widget.item['country']?.toString(),
                  latitude: details['latitude'] != null ? double.tryParse(details['latitude'].toString()) : null,
                  longitude: details['longitude'] != null ? double.tryParse(details['longitude'].toString()) : null,
                  name: details['name']?.toString() ?? widget.item['name'] ?? 'Institution',
                  color: const Color(0xFFBF360C),
                ),
                const SizedBox(height: 16),
                if (_isLoadingDetails)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_institutionDetails != null)
                  _buildTypeSpecificDetails(details),
                if (details['owner_id'] != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicPortfolioView(userId: details['owner_id'].toString(), userName: details['owner_name'] ?? 'Owner'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.work_outline_rounded, size: 18),
                      label: const Text("View Owner Portfolio"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFBF360C),
                        side: BorderSide(color: const Color(0xFFBF360C).withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (widget.hasInstitution == true)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "You are already a member of an institution. Leave it first to join another.",
                            style: TextStyle(fontSize: 13, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleJoinRequest,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Send Admission Request"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBF360C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showAccessKeyInput,
                      icon: const Icon(Icons.key, size: 20),
                      label: const Text("Join with Access Key"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        foregroundColor: const Color(0xFFE65100),
                        side: BorderSide(color: const Color(0xFFE65100).withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                if (widget.item['id'] != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstitutionLeaderboardScreen(
                              onClose: () => Navigator.pop(context),
                              institutionId: widget.item['id'].toString(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.leaderboard_outlined, size: 20),
                      label: const Text("View Leaderboard"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        foregroundColor: Colors.blueGrey,
                        side: BorderSide(color: Colors.blueGrey.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String pfpUrl, {required List<Color> gradientColors}) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: -30, right: -30, child: _decoCircle(120, gradientColors.last.withOpacity(0.15))),
          Positioned(bottom: -20, left: -20, child: _decoCircle(80, gradientColors.first.withOpacity(0.12))),
          Positioned(top: 40, left: 30, child: _decoCircle(12, Colors.white.withOpacity(0.12))),
          Positioned(bottom: 50, right: 50, child: _decoCircle(18, Colors.white.withOpacity(0.08))),
        ],
      ),
    );
  }

  Widget _buildAvatar(String pfpUrl, double radius, {required bool isUser}) {
    return Transform.translate(
      offset: const Offset(0, -45),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: NetworkImage(pfpUrl),
          onBackgroundImageError: (_, __) {},
          child: Icon(
            isUser ? Icons.person : Icons.account_balance_rounded,
            size: radius * 0.7,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color, {VoidCallback? onCopy, VoidCallback? onShare}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
          if (onCopy != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCopy,
              child: Container(padding: const EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey.shade400)),
            ),
          ],
          if (onShare != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onShare,
              child: Container(padding: const EdgeInsets.all(4), child: Icon(Icons.share_rounded, size: 15, color: Colors.orange.shade400)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSpecificDetails(Map<String, dynamic> details) {
    final type = details['type'];

    Widget buildCard(String title, List<Widget> rows) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.school, color: const Color(0xFFBF360C), size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212121))),
              ],
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      );
    }

    if (type == 'school' && details['principal_name'] != null) {
      return buildCard('School Details', [
        if (details['principal_name'] != null) _detailRow('Principal', details['principal_name']),
        if (details['campus'] != null) _detailRow('Campus', details['campus']),
        if (details['website'] != null) _detailRow('Website', details['website']),
      ]);
    } else if (type == 'academy' && details['edu_type'] != null) {
      return buildCard('Academy Details', [
        if (details['edu_type'] != null) _detailRow('Education Type', details['edu_type']),
        if (details['campus_name'] != null) _detailRow('Campus Name', details['campus_name']),
        if (details['contact'] != null) _detailRow('Contact', details['contact']),
      ]);
    } else if (type == 'college' && details['dean_name'] != null) {
      return buildCard('College Details', [
        if (details['dean_name'] != null) _detailRow('Dean', details['dean_name']),
        if (details['university'] != null) _detailRow('University', details['university']),
        if (details['code'] != null) _detailRow('Code', details['code']),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _decoCircle(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF212121)))),
        ],
      ),
    );
  }

  Widget _buildLocationButton({String? city, String? country, double? latitude, double? longitude, required String name, required Color color}) {
    final hasLocation = latitude != null && longitude != null;
    final locationText = (city != null && city.isNotEmpty) || (country != null && country.isNotEmpty)
        ? "${city != null && city.isNotEmpty ? city : ''}${city != null && city.isNotEmpty && country != null && country.isNotEmpty ? ', ' : ''}${country != null && country.isNotEmpty ? country : ''}"
        : null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: hasLocation
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LocationMapView(
                      latitude: latitude,
                      longitude: longitude,
                      city: city ?? '',
                      country: country ?? '',
                      name: name,
                    ),
                  ),
                );
              }
            : null,
        icon: Icon(Icons.location_on_outlined, size: 18, color: hasLocation ? color : Colors.grey),
        label: Text(
          hasLocation ? (locationText ?? 'View Location') : 'Location unavailable',
          style: TextStyle(color: hasLocation ? color : Colors.grey, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: hasLocation ? color : Colors.grey,
          side: BorderSide(color: hasLocation ? color.withOpacity(0.3) : Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _LocationMapView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String name;

  const _LocationMapView({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(latitude, longitude),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.starlight.console',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(latitude, longitude),
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A237E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        "${city.isNotEmpty ? city : ''}${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}${country.isNotEmpty ? country : ''}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}",
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
