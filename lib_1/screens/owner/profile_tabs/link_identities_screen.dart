import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/sign.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';
import '../../../l10n/strings.dart';

class LinkIdentitiesScreen extends StatefulWidget {
  final VoidCallback onClose;
  const LinkIdentitiesScreen({super.key, required this.onClose});

  @override
  State<LinkIdentitiesScreen> createState() => _LinkIdentitiesScreenState();
}

class _LinkIdentitiesScreenState extends State<LinkIdentitiesScreen> {
  final String _baseUrl =
      "${StarlightConstants.apiBaseUrl}/institution/directory";

  List<dynamic> _unlinkedUsers = [];
  List<dynamic> _availableIdentities = [];
  bool _isLoading = true;

  // Node connection mappings: userId -> identityId (Strictly 1 wire per node)
  final Map<String, String> _activeConnections = {};

  // Active dragging state for drawing wires
  String? _draggingUserId;
  Offset? _dragCurrentPosition;

  // Track node global positions for CustomPainter wire rendering
  final Map<String, Offset> _userNodePositions = {};
  final Map<String, Offset> _identityNodePositions = {};
  final GlobalKey _canvasKey = GlobalKey();

  String _selectedRole = 'all';
  String _selectedSection = '';
  String _selectedDepartment = '';

  List<String> _sections = [];
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchUnlinkedUsers(), _fetchAvailableIdentities()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUnlinkedUsers() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse("$_baseUrl/unlinked-identities"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() => _unlinkedUsers = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching unlinked users: $e");
    }
  }

  Future<void> _fetchAvailableIdentities() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final params = <String, String>{};
      if (_selectedRole != 'all') params['role'] = _selectedRole;
      if (_selectedSection.isNotEmpty) params['section'] = _selectedSection;
      if (_selectedDepartment.isNotEmpty)
        params['department'] = _selectedDepartment;

      final uri = Uri.parse("$_baseUrl/available-identities")
          .replace(queryParameters: params);
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _availableIdentities = data;
          _extractSections(data);
          _extractDepartments(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching identities: $e");
    }
  }

  void _extractSections(List<dynamic> data) {
    final sections = <String>{};
    for (var item in data) {
      if (item['section'] != null && item['section'].toString().isNotEmpty) {
        sections.add(item['section']);
      }
    }
    if (mounted) setState(() => _sections = sections.toList()..sort());
  }

  void _extractDepartments(List<dynamic> data) {
    final depts = <String>{};
    for (var item in data) {
      final dept = item['department'] ?? item['subject'];
      if (dept != null && dept.toString().isNotEmpty) {
        depts.add(dept);
      }
    }
    if (mounted) setState(() => _departments = depts.toList()..sort());
  }

  Future<void> _linkIdentity(String userId, String identityId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/link-identity"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'user_id': userId, 'identity_id': identityId}),
      );

      if (response.statusCode == 200 && mounted) {
        StarlightUtils.showSuccessBox(
            context, tr('linkIdentitiesConnected'));
        setState(() {
          _activeConnections[userId] = identityId;
        });
        await _fetchData();
      } else if (mounted) {
        final error = jsonDecode(response.body);
        StarlightUtils.showErrorBox(
            context, error['detail'] ?? tr('linkIdentitiesFailed'));
      }
    } catch (e) {
      if (mounted) StarlightUtils.showErrorBox(context, e.toString());
    }
  }

  Future<void> _unlinkIdentity(String userId, String identityId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/unlink-identity"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'user_id': userId, 'identity_id': identityId}),
      );

      if (response.statusCode == 200 && mounted) {
        StarlightUtils.showSuccessBox(
            context, tr('linkIdentitiesDisconnected'));
        setState(() {
          _activeConnections.remove(userId);
        });
        await _fetchData();
      } else {
        setState(() {
          _activeConnections.remove(userId);
        });
        StarlightUtils.showSuccessBox(context, tr('linkIdentitiesDisconnected'));
        await _fetchData();
      }
    } catch (e) {
      setState(() {
        _activeConnections.remove(userId);
      });
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Color(0xFF1E293B)),
            onPressed: widget.onClose,
          ),
        ),
        title: Text(
          tr('linkIdentitiesTitle'),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB))))
          : Column(
              children: [
                _buildFilters(),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: Stack(
                    key: _canvasKey,
                    children: [
                      // Canvas Wire Painter Layer
                      CustomPaint(
                        painter: WirePainter(
                          userPositions: _userNodePositions,
                          identityPositions: _identityNodePositions,
                          activeConnections: _activeConnections,
                          draggingUserId: _draggingUserId,
                          dragCurrentPosition: _dragCurrentPosition,
                        ),
                        size: Size.infinite,
                      ),
                      // Interactive Node Columns Layout
                      Row(
                        children: [
                          // Left Node Panel: Unlinked Users
                          Expanded(child: _buildUsersCanvasPanel()),
                          // Center Divider / Indicator
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6),
                                ],
                              ),
                              child: const Icon(Icons.bolt_rounded,
                                  size: 18, color: Color(0xFF2563EB)),
                            ),
                          ),
                          // Right Node Panel: Available Identities
                          Expanded(child: _buildIdentitiesCanvasPanel()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('linkIdentitiesFilter'),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedRole,
                  items: const ['all', 'student', 'teacher', 'staff'],
                  itemLabels: {
                    'all': tr('roleLblAll'),
                    'student': tr('roleLblStudent'),
                    'teacher': tr('roleLblTeacher'),
                    'staff': tr('roleLblStaff'),
                  },
                  onChanged: (v) {
                    setState(() {
                      _selectedRole = v ?? 'all';
                      _selectedSection = '';
                      _selectedDepartment = '';
                    });
                    _fetchAvailableIdentities();
                  },
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedRole == 'student' && _sections.isNotEmpty)
                Expanded(
                  child: _buildDropdown(
                    value: _selectedSection.isEmpty ? null : _selectedSection,
                    items: ['all', ..._sections],
                    label: tr('labelSection'),
                    onChanged: (v) {
                      setState(
                          () => _selectedSection = v == 'all' ? '' : (v ?? ''));
                      _fetchAvailableIdentities();
                    },
                  ),
                ),
              if (_selectedRole == 'teacher' && _departments.isNotEmpty)
                Expanded(
                  child: _buildDropdown(
                    value: _selectedDepartment.isEmpty
                        ? null
                        : _selectedDepartment,
                    items: ['all', ..._departments],
                    label: tr('labelDepartment'),
                    onChanged: (v) {
                      setState(() =>
                          _selectedDepartment = v == 'all' ? '' : (v ?? ''));
                      _fetchAvailableIdentities();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
      {required String? value,
      required List<String> items,
      String? label,
      Map<String, String>? itemLabels,
      void Function(String?)? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label ?? tr('roleLabel'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(itemLabels != null ? (itemLabels[e] ?? e) : e,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUsersCanvasPanel() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFEFF6FF),
          child: Text("${tr('linkIdentitiesUnlinkedUsers')} (${_unlinkedUsers.length})",
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFF2563EB))),
        ),
        Expanded(
          child: _unlinkedUsers.isEmpty
              ? Center(
                  child: Text(tr('linkIdentitiesAllLinked'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _unlinkedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _unlinkedUsers[index];
                    final userId = user['user_id']?.toString() ?? '';
                    final hasWire = _activeConnections.containsKey(userId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: hasWire
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                            width: hasWire ? 2 : 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (hasWire) {
                            _unlinkIdentity(userId, _activeConnections[userId]!);
                          }
                        },
                        child: Draggable<String>(
                          data: userId,
                          onDragStarted: () =>
                              setState(() => _draggingUserId = userId),
                          onDragUpdate: (details) {
                            final RenderBox? box = _canvasKey.currentContext
                                ?.findRenderObject() as RenderBox?;
                            if (box != null) {
                              setState(() => _dragCurrentPosition =
                                  box.globalToLocal(details.globalPosition));
                            }
                          },
                          onDragEnd: (_) => setState(() {
                            _draggingUserId = null;
                            _dragCurrentPosition = null;
                          }),
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 10)
                                ],
                              ),
                              child: Text(user['name'] ?? tr('profileDefaultName'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(user['name'] ?? tr('linkIdentitiesUnknown'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF1E293B))),
                                    Text(
                                        hasWire
                                            ? tr('linkIdentitiesConnected')
                                            : tr('linkIdentitiesDrag'),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: hasWire
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Icon(
                                  hasWire
                                      ? Icons.link_rounded
                                      : Icons.drag_indicator_rounded,
                                  size: 18,
                                  color: hasWire
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIdentitiesPanel() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF0FDF4),
          child: Text("${tr('linkIdentitiesRecords')} (${_availableIdentities.length})",
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Color(0xFF10B981))),
        ),
        Expanded(
          child: _availableIdentities.isEmpty
              ? Center(
                  child: Text(tr('linkIdentitiesNoRecords'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _availableIdentities.length,
                  itemBuilder: (context, index) {
                    final identity = _availableIdentities[index];
                    final identityId = identity['id']?.toString() ?? '';
                    final type = identity['type'] ?? '';
                    final isLinked =
                        _activeConnections.containsValue(identityId);

                    return DragTarget<String>(
                      onWillAccept: (userId) =>
                          userId != null &&
                          !_activeConnections.containsKey(userId),
                      onAccept: (userId) {
                        _linkIdentity(userId, identityId);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? const Color(0xFFF0FDF4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isHovered || isLinked
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                              width: isHovered || isLinked ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  type == 'student'
                                      ? Icons.school_rounded
                                      : Icons.badge_rounded,
                                  color: const Color(0xFF10B981),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(identity['name'] ?? tr('linkIdentitiesRecord'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF1E293B))),
                                    Text(_buildIdentitySubtitle(identity),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              if (isLinked)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF10B981), size: 18)
                              else
                                const Icon(Icons.input_rounded,
                                    size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIdentitiesCanvasPanel() => _buildIdentitiesPanel();

  String _buildIdentitySubtitle(dynamic identity) {
    final type = identity['type'] ?? '';
    if (type == 'student') {
      final parts = <String>[];
      if (identity['section']?.toString().isNotEmpty == true)
        parts.add('${tr('labelSection')}: ${identity['section']}');
      if (identity['roll_number']?.toString().isNotEmpty == true)
        parts.add('${tr('linkIdentitiesRoll')}: ${identity['roll_number']}');
      return parts.join(' • ');
    }
    return identity['department'] ??
        identity['designation'] ??
        tr('linkIdentitiesMember');
  }
}

// Custom Painter to draw connecting wires between active node selections
class WirePainter extends CustomPainter {
  final Map<String, Offset> userPositions;
  final Map<String, Offset> identityPositions;
  final Map<String, String> activeConnections;
  final String? draggingUserId;
  final Offset? dragCurrentPosition;

  WirePainter({
    required this.userPositions,
    required this.identityPositions,
    required this.activeConnections,
    required this.draggingUserId,
    required this.dragCurrentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw active wire connections if coordinates are registered
    activeConnections.forEach((userId, identityId) {
      final uPos = userPositions[userId];
      final iPos = identityPositions[identityId];
      if (uPos != null && iPos != null) {
        final path = Path()
          ..moveTo(uPos.dx, uPos.dy)
          ..cubicTo(
              uPos.dx + 50, uPos.dy, iPos.dx - 50, iPos.dy, iPos.dx, iPos.dy);
        canvas.drawPath(path, paint..color = const Color(0xFF10B981));
      }
    });

    // Draw live drag wire
    if (draggingUserId != null && dragCurrentPosition != null) {
      final uPos = userPositions[draggingUserId!] ?? const Offset(100, 100);
      final path = Path()
        ..moveTo(uPos.dx, uPos.dy)
        ..lineTo(dragCurrentPosition!.dx, dragCurrentPosition!.dy);
      canvas.drawPath(path, paint..color = const Color(0xFF2563EB));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
