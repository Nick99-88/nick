import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../widgets/starlight_mailbox.dart';
import '../shared/settings_screen.dart';
import '../shared/role_identity_screen.dart';
import '../shared/portfolio_screen.dart';

class TeacherProfile extends StatefulWidget {
  const TeacherProfile({super.key});

  @override
  State<TeacherProfile> createState() => _TeacherProfileState();
}

class _TeacherProfileState extends State<TeacherProfile> {
  String _teacherName = "Teacher";
  String _teacherEmail = "";
  String? _teacherId;
  String _teacherPhone = "Not set";
  String _teacherSubject = "Not assigned";
  String _teacherDepartment = "Not assigned";
  String _teacherJoiningDate = "Not set";
  String _teacherDesignation = "";
  String? _pfpBase64;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await StarlightStorage.getUserName();
    final email = await StarlightStorage.getUserEmail();
    final roleId = await StarlightStorage.getUserPublicId();

    _teacherName = name ?? "Teacher";
    _teacherEmail = email ?? "";
    _teacherId = roleId;

    try {
      final token = await StarlightStorage.getUserToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse("${StarlightConstants.apiBaseUrl}/profile/identity"),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _teacherName = data['full_name'] ?? data['name'] ?? _teacherName;
              _teacherEmail = data['email'] ?? _teacherEmail;
              _teacherId = data['public_id'] ?? _teacherId;
              _teacherPhone = data['phone'] ?? data['phone_number'] ?? _teacherPhone;
              _teacherSubject = data['subject_name'] ?? _teacherSubject;
              _teacherDepartment = data['designation'] ?? data['department'] ?? _teacherDepartment;
              _teacherJoiningDate = data['joining_date'] ?? _teacherJoiningDate;
              _teacherDesignation = data['designation'] ?? data['position'] ?? '';
            });
          }
        }
      }
    } catch (_) {}

    await _loadProfilePicture();

    if (mounted) {
      setState(() {
        _teacherId ??= "TCH00000";
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked == null) return;

    final file = File(picked.path);
    final sizeInBytes = await file.length();

    if (sizeInBytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image too large! Max 5MB allowed.")),
        );
      }
      return;
    }

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final bytes = await file.readAsBytes();

      String contentType = 'image/jpeg';
      final fileName = picked.name.toLowerCase();
      if (fileName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (fileName.endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.endsWith('.webp')) {
        contentType = 'image/webp';
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/upload-pfp'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: picked.name,
          contentType: MediaType.parse(contentType),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final b64 = base64Encode(bytes);
        if (mounted) {
          setState(() => _pfpBase64 = "data:image/jpeg;base64,$b64");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated!"), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${response.statusCode}"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _loadProfilePicture() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/pfp/current'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final b64 = base64Encode(response.bodyBytes);
        if (mounted) setState(() => _pfpBase64 = "data:image/jpeg;base64,$b64");
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          _buildProfileInfoCard(),
          const SizedBox(height: 16),
          _buildSettingsCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      children: [
        Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [StarlightTheme.primaryBlue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: StarlightTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: _pfpBase64 != null
                    ? MemoryImage(base64Decode(_pfpBase64!.split(',').last))
                    : null,
                child: _pfpBase64 == null
                    ? Text(
                        _teacherName.isNotEmpty ? _teacherName[0].toUpperCase() : "T",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: StarlightTheme.primaryBlue,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploadPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 14, color: StarlightTheme.primaryBlue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _teacherName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _teacherEmail,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (_teacherId != null) {
                Clipboard.setData(ClipboardData(text: _teacherId!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User ID copied!"), duration: Duration(seconds: 1)),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 14, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    _teacherId ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: Row(
          children: [
            _headerIcon(Icons.mail_outline, () {
              StarlightMailbox.show(context);
            }),
            const SizedBox(width: 8),
            _headerIcon(Icons.settings, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(onBack: () => Navigator.pop(context))));
            }),
          ],
        ),
      ),
    ],
  );
}

Widget _headerIcon(IconData icon, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

  Widget _buildProfileInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Profile Information",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleIdentityScreen()));
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Edit"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.email, "Email", _teacherEmail.isNotEmpty ? _teacherEmail : "Not set"),
            _infoRow(Icons.phone, "Phone", _teacherPhone),
            _infoRow(Icons.subject, "Subject", _teacherSubject),
            _infoRow(Icons.business, "Department", _teacherDepartment),
            _infoRow(Icons.calendar_today, "Join Date", _teacherJoiningDate),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _menuTile(Icons.badge_outlined, "My Identity", "View & update your identity data", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleIdentityScreen()));
          }),
          const Divider(height: 1),
          _menuTile(Icons.work_outline_rounded, "Portfolio", "View your public portfolio", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioScreen(onBack: () => Navigator.pop(context))));
          }),
          const Divider(height: 1),
          _menuTile(Icons.logout, "Logout", "Sign out", color: Colors.red),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String subtitle, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? StarlightTheme.primaryBlue, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: color ?? Colors.black87,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
      onTap: onTap ?? (() {
        if (title == "Logout") _logout();
      }),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await StarlightStorage.clearAll();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
