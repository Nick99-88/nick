import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/sign.dart';
import '../../core/constants.dart';
import '../../core/platform_gate.dart';
import '../../services/api_service.dart';
import '../../services/auth/firebase_phone_service.dart';
import '../../screens/owner/profile_tabs/AdvancedSecurity.dart';

class QRProfileScreen extends StatefulWidget {
  const QRProfileScreen({super.key});

  @override
  State<QRProfileScreen> createState() => _QRProfileScreenState();
}

class _QRProfileScreenState extends State<QRProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? _pfpBase64;
  bool _isLoading = true;
  bool _isUploading = false;

  String _name = '';
  String _email = '';
  String _phone = '';
  String _bio = '';
  String _publicId = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/identity'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _name = data['full_name'] ?? data['name'] ?? '';
            _email = data['email'] ?? '';
            _phone = data['phone_number'] ?? '';
            _bio = data['bio'] ?? '';
            _publicId = data['public_id'] ?? '';
            _role = data['role'] ?? '';
          });
        }
      }

      await _loadPfp();
    } catch (e) {
      debugPrint('QR Profile load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPfp() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/pfp/current'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (mounted) {
          setState(() {
            _pfpBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadPfp() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      StarlightUtils.showErrorBox(context, 'Image too large! Max 5MB.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      final bytes = await file.readAsBytes();

      String contentType = 'image/jpeg';
      final name = picked.name.toLowerCase();
      if (name.endsWith('.png')) contentType = 'image/png';
      else if (name.endsWith('.gif')) contentType = 'image/gif';
      else if (name.endsWith('.webp')) contentType = 'image/webp';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/upload-pfp'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file', bytes,
        filename: picked.name,
        contentType: MediaType.parse(contentType),
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 && mounted) {
        setState(() { _pfpBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}'; });
        StarlightUtils.showSuccessBox(context, 'Profile picture updated!');
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateField(String field, String value) async {
    try {
      final token = await StarlightStorage.getUserToken();
      await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/profile/identity/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({field: value}),
      );
      if (mounted) {
        StarlightUtils.showSuccessBox(context, '${field == "full_name" ? "Name" : "About"} updated!');
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Update failed: $e');
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: field == 'bio' ? 3 : 1,
          decoration: InputDecoration(
            hintText: 'Enter $title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (field == 'full_name') _name = val;
                  else if (field == 'bio') _bio = val;
                });
                _updateField(field, val);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile', style: GoogleFonts.poppins(
          color: const Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 16),
                  _buildAboutSection(),
                  const SizedBox(height: 16),
                  _buildContactSection(),
                  const SizedBox(height: 16),
                  _buildSecuritySection(),
                  const SizedBox(height: 16),
                  _buildLogoutSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 30, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: _pfpBase64 == null
                    ? StarlightTheme.primaryBlue.withOpacity(0.15)
                    : Colors.transparent,
                backgroundImage: _pfpBase64 != null
                    ? MemoryImage(base64Decode(_pfpBase64!.split(',').last))
                    : null,
                child: _pfpBase64 == null
                    ? Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadPfp,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: StarlightTheme.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: _isUploading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showEditDialog('Name', 'full_name', _name),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _name.isNotEmpty ? _name : 'Your Name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _bio.isNotEmpty ? _bio : 'Hey there! I am using QR Portal',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return _sectionCard(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline, color: Colors.grey),
          title: const Text('About', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_bio.isNotEmpty ? _bio : 'Tap to add about yourself'),
          trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
          onTap: () => _showEditDialog('About', 'bio', _bio),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return _sectionCard(
      title: 'Contact Info',
      children: [
        ListTile(
          leading: const Icon(Icons.phone_outlined, color: Colors.grey),
          title: const Text('Phone', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_phone.isNotEmpty ? _phone : 'Not Linked'),
          trailing: TextButton(
            onPressed: _verifyPhoneNumber,
            child: Text(_phone.isEmpty ? 'Add' : 'Change', style: const TextStyle(fontSize: 12)),
          ),
        ),
        const Divider(height: 1, indent: 60),
        ListTile(
          leading: const Icon(Icons.email_outlined, color: Colors.grey),
          title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_email.isNotEmpty ? _email : 'Not Set'),
          trailing: TextButton(
            onPressed: _verifyEmail,
            child: Text(_email.isEmpty ? 'Add' : 'Change', style: const TextStyle(fontSize: 12)),
          ),
        ),
        if (_publicId.isNotEmpty) ...[
          const Divider(height: 1, indent: 60),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Colors.grey),
            title: const Text('Public ID', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_publicId, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
              onPressed: () => StarlightUtils.showSuccessBox(context, 'ID copied!'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecuritySection() {
    return _sectionCard(
      children: [
        ListTile(
          leading: const Icon(Icons.security_outlined, color: Colors.grey),
          title: const Text('Advanced Security', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Encryption keys & session logs'),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdvancedSecurityScreen(onClose: () => Navigator.pop(context)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: Colors.red, size: 18),
          label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({String? title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ...children,
        ],
      ),
    );
  }

  void _handleLogout() async {
    await StarlightStorage.logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
  }

  // --- Phone & Email Verification ---

  Future<void> _verifyPhoneNumber() async {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool isOTPSent = false;
    bool isVerifying = false;
    String errorMessage = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.phone_iphone_rounded, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                isOTPSent ? "ENTER OTP CODE" : "VERIFY PHONE NUMBER",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isOTPSent ? "We sent a 6-digit SMS to your phone." : "Enter your Pakistan phone number.",
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 16),
              if (!isOTPSent)
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    labelStyle: TextStyle(color: Colors.white38),
                    prefixText: "+92 ",
                    prefixStyle: TextStyle(color: Colors.white70, fontSize: 13),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                  ),
                )
              else
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.white24),
                    counterText: "",
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                  ),
                ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isVerifying ? null : () async {
                setDialogState(() { isVerifying = true; errorMessage = ""; });
                try {
                  if (!isOTPSent) {
                    final num = phoneCtrl.text.trim();
                    if (num.length != 10) throw Exception("Enter a valid 10-digit phone number");
                    await FirebasePhoneService.initialize();
                    final sent = await FirebasePhoneService.sendOTPToPakistan("+92$num");
                    if (sent) setDialogState(() { isOTPSent = true; });
                    else throw Exception("Failed to send OTP");
                  } else {
                    final otp = codeCtrl.text.trim();
                    if (otp.length != 6) throw Exception("Enter the full 6-digit OTP");
                    final verified = await FirebasePhoneService.verifyOTP(otp);
                    if (verified) {
                      final formatted = "+92${phoneCtrl.text.trim()}";
                      await ApiService.post('/firebase/verify-phone', {'phone_number': formatted});
                      await StarlightStorage.setUserPhoneNumber(formatted);
                      await StarlightStorage.setVerifiedPhone(formatted);
                      await StarlightStorage.setPhoneVerified(true);
                      if (mounted) {
                        setState(() { _phone = formatted; });
                        StarlightUtils.showSuccessBox(context, "Phone verified!");
                      }
                      Navigator.pop(ctx);
                    } else throw Exception("Invalid OTP");
                  }
                } catch (e) {
                  setDialogState(() { errorMessage = e.toString().replaceAll("Exception: ", ""); });
                } finally {
                  setDialogState(() { isVerifying = false; });
                }
              },
              child: isVerifying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : Text(isOTPSent ? "Verify Code" : "Send OTP",
                      style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyEmail() async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool isOTPSent = false;
    bool isVerifying = false;
    String errorMessage = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                isOTPSent ? "ENTER VERIFICATION OTP" : "VERIFY EMAIL",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isOTPSent ? "We sent a 6-digit code to ${emailCtrl.text.trim()}." : "Enter your email to receive an OTP.",
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 16),
              if (!isOTPSent)
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                  ),
                )
              else
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.white24),
                    counterText: "",
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                  ),
                ),
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isVerifying ? null : () async {
                setDialogState(() { isVerifying = true; errorMessage = ""; });
                try {
                  final targetEmail = emailCtrl.text.trim();
                  if (!isOTPSent) {
                    if (targetEmail.isEmpty || !targetEmail.contains("@")) throw Exception("Enter a valid email");
                    await ApiService.post('/profile/verify-email/send-otp', {'email': targetEmail});
                    setDialogState(() { isOTPSent = true; });
                  } else {
                    final otp = codeCtrl.text.trim();
                    if (otp.length != 6) throw Exception("Enter the full 6-digit OTP");
                    await ApiService.post('/profile/verify-email/verify-otp', {'email': targetEmail, 'otp': otp});
                    if (mounted) {
                      setState(() { _email = targetEmail; });
                      StarlightUtils.showSuccessBox(context, "Email verified!");
                    }
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  setDialogState(() { errorMessage = e.toString().replaceAll("Exception: ", ""); });
                } finally {
                  setDialogState(() { isVerifying = false; });
                }
              },
              child: isVerifying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : Text(isOTPSent ? "Verify Code" : "Send OTP",
                      style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}