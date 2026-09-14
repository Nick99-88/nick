import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/sign.dart';
import '../../core/constants.dart';
import '../../core/socket_vault.dart';
import '../../core/router_gateway.dart';
import '../../widgets/starlight_mailbox.dart';
import '../social/social_main_screen.dart'; // 🏛️ Added import
import 'profile_tabs/InstitutionDirectory.dart';
import 'profile_tabs/PersonalInformation.dart';
import 'profile_tabs/ProfessionalBio.dart';
import '../shared/settings_screen.dart';
import '../shared/portfolio_screen.dart';
import '../../l10n/strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String apiBase = "https://hub.institution.site";

  String name = tr('profileLoading');
  String email = "...";
  String role = "ADMIN";
  String? pfpBase64;
  String? publicId;

  @override
  void initState() {
    super.initState();
    name = tr('profileLoading');
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final token = await StarlightStorage.getUserToken();
      
      // Load user profile data
      final profileResponse = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/profile/identity"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        if (mounted) {
          setState(() {
            name = profileData['full_name'] ?? tr('profileDefaultName');
            email = profileData['email'] ?? tr('profileDefaultEmail');
            role = (profileData['role'] ?? tr('profileDefaultRole')).toUpperCase();
            publicId = profileData['public_id'];
          });
        }
      }

      // Load profile picture
      await _loadProfilePicture();
      
    } catch (e) {
      print('🏛️ Error loading profile data: $e');
      if (mounted) {
        setState(() {
          name = tr('profileDefaultName');
          email = tr('profileDefaultEmail');
          role = tr('profileDefaultRole').toUpperCase();
          pfpBase64 = null;
        });
      }
    }
  }

  Future<void> _loadProfilePicture() async {
    // 🏛️ Show cached photo immediately so it survives app restart
    try {
      final cached = await StarlightStorage.getUserPfp();
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() => pfpBase64 = "data:image/jpeg;base64,$cached");
      }
    } catch (_) {}

    try {
      final token = await StarlightStorage.getUserToken();
      final String baseUrl = StarlightConstants.apiBaseUrl;
      
      final response = await http.get(
        Uri.parse("$baseUrl/profile/pfp/current"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = "data:image/jpeg;base64,${base64Encode(bytes)}";
        await StarlightStorage.setUserPfp(base64Encode(bytes));
        if (mounted) {
          setState(() => pfpBase64 = base64String);
        }
      } else if (response.statusCode == 404) {
        print('🏛️ No profile picture found on server');
      } else {
        print('🏛️ Profile picture load failed: ${response.statusCode}');
      }
    } on TimeoutException {
      print('🏛️ Profile picture load timeout');
    } catch (e) {
      print('🏛️ Error loading profile picture: $e');
    }
  }

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final int sizeInBytes = await file.length();

    if (sizeInBytes > 5 * 1024 * 1024) {
      StarlightUtils.showErrorBox(context, tr('profileImageTooLarge'));
      return;
    }

    StarlightUtils.showSuccessBox(context, tr('profileUpdating'));

    try {
      final token = await StarlightStorage.getUserToken();
      
      // Use the correct API base URL from constants
      final String baseUrl = StarlightConstants.apiBaseUrl;
      
      // First test if server is reachable
      try {
        final testResponse = await http.get(
          Uri.parse("$baseUrl/"),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        
        if (testResponse.statusCode != 200) {
          throw Exception("Server not responding correctly");
        }
      } catch (e) {
        StarlightUtils.showErrorBox(context, tr('profileServerUnreachable'));
        return;
      }
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/profile/upload-pfp"),
      );
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add file as multipart data
      final bytes = await file.readAsBytes();
      
      // Determine content type from file extension
      String contentType = 'image/jpeg'; // default
      final fileName = pickedFile.name.toLowerCase();
      if (fileName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (fileName.endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.endsWith('.webp')) {
        contentType = 'image/webp';
      }
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: pickedFile.name,
          contentType: MediaType.parse(contentType),
        ),
      );

      // Debug: Print request details before sending
      print('🏛️ Upload request URL: ${request.url}');
      print('🏛️ Upload request method: ${request.method}');
      print('🏛️ Upload request headers: ${request.headers}');
      print('🏛️ Upload request files count: ${request.files.length}');
      if (request.files.isNotEmpty) {
        final file = request.files.first;
        print('🏛️ Upload file field: ${file.field}');
        print('🏛️ Upload file filename: ${file.filename}');
        print('🏛️ Upload file content-type: ${file.contentType}');
        print('🏛️ Upload file size: ${file.length} bytes');
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('🏛️ Profile upload response: ${response.statusCode}');
      print('🏛️ Profile upload headers: ${response.headers}');
      print('🏛️ Profile upload body: ${response.body}');

      if (response.statusCode == 200) {
        final base64String = "data:image/png;base64,${base64Encode(bytes)}";
        await StarlightStorage.setUserPfp(base64Encode(bytes));
        setState(() {
          pfpBase64 = base64String;
        });
        StarlightUtils.showSuccessBox(context, tr('profilePictureUpdated'));
      } else if (response.statusCode == 400) {
        // Handle 400 Bad Request with detailed error
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['detail'] ?? tr('profileUploadInvalidFormat');
          StarlightUtils.showErrorBox(context, tr('profileUploadFailed', {'error': errorMessage}));
        } catch (e) {
          StarlightUtils.showErrorBox(context, tr('profileUploadInvalid', {'body': response.body}));
        }
      } else if (response.statusCode == 502) {
        StarlightUtils.showErrorBox(context, tr('profileServerUnavailable'));
      } else {
        try {
          final errorData = jsonDecode(response.body);
          StarlightUtils.showErrorBox(context, tr('profileUploadFailed', {'error': errorData['detail'] ?? tr('profileUploadDefaultError')}));
        } catch (e) {
          StarlightUtils.showErrorBox(context, tr('profileUploadFailed', {'error': response.body}));
        }
      }
    } on TimeoutException {
      StarlightUtils.showErrorBox(context, tr('profileUploadTimeout'));
    } catch (e) {
      print('🏛️ Profile upload error: $e');
      StarlightUtils.showErrorBox(context, tr('profileUploadConnectionError', {'error': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildSettingsList(),
          ],
        ),
      ),
    );
  }

  void _handleLogout() async {
    StarlightSocket().close();
    await StarlightStorage.logout();
    if (mounted) {
      UniversalRouter.routeUser(context);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              children: [
                _buildSettingsIcon(),
                Expanded(
                  child: Center(
                    child: Text(tr('profile'),
                        style: const TextStyle(
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5)),
                  ),
                ),
                _buildMailIcon(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: pfpBase64 == null
                    ? const Color(0xFF0288D1)
                    : Colors.transparent,
                backgroundImage: pfpBase64 != null ? MemoryImage(
                    base64Decode(pfpBase64!.split(',').last)) : null,
                child: pfpBase64 == null
                    ? Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 35, color: Colors.white))
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _uploadPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFF263238),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(
                        Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          Text(name, style: const TextStyle(fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A237E))),
          Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          if (publicId != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPublicIdRow(),
            ),
        ],
      ),
    );
  }

  Widget _buildPublicIdRow() {
    return GestureDetector(
      onTap: () {
        if (publicId != null) {
          Clipboard.setData(ClipboardData(text: publicId!));
          StarlightUtils.showSuccessBox(context, tr('profileIdCopied', {'id': publicId!}));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0288D1).withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint, size: 16, color: Color(0xFF0288D1)),
            const SizedBox(width: 8),
            Text(
              publicId ?? '',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0288D1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsIcon() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Icon(Icons.settings_outlined, size: 22, color: Color(0xFF263238)),
      ),
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0288D1), Color(0xFF00BCD4)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.search, color: Colors.white),
              ),
              title: Text(tr('profileSearchPlatform'), style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(tr('profileSearchPlatformSub'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              onTap: () {
                // 🏛️ Navigation to Social Explore Hub
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SocialMainScreen(initialIndex: 0)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildMemberCard(),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 5),
            child: Text(tr('profilePublicIdentity'), style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1)),
          ),
          _buildListItem(Icons.person_outline, tr('profilePersonalInformation'), color: Colors.blue, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PersonalInformationScreen(onBack: () => Navigator.pop(context))),
            );
          }),
          _buildListItem(Icons.edit_note_rounded, tr('profileProfessionalBio'), color: Colors.deepPurple, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfessionalBioScreen(onBack: () => Navigator.pop(context))),
            );
          }),
          _buildListItem(Icons.work_outline_rounded, tr('profilePortfolio'), color: Colors.teal, onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PortfolioScreen(onBack: () => Navigator.pop(context))),
            );
          }),
          const SizedBox(height: 20),
          _buildListItem(
              Icons.logout, tr('profileLogoutAccount'), isRed: true, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildListItem(IconData icon, String title,
      {bool isRed = false, Color? color, VoidCallback? onTap}) {
    final Color accent = isRed ? Colors.red : (color ?? const Color(0xFF1A237E));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isRed ? Colors.red : const Color(0xFF1A237E))),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.black26),
      ),
    );
  }

  Widget _buildMailIcon() {
    return GestureDetector(
      onTap: () => StarlightMailbox.show(context),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const Icon(
                Icons.mail_outline, size: 22, color: Color(0xFF263238)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMemberCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstitutionDirectoryScreen(
                onBack: () => Navigator.pop(context),
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.groups, color: Colors.orange, size: 22),
        ),
        title: Text(tr('profileInstitutionDirectory'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A237E))),
        subtitle: Text(tr('profileInstitutionDirectorySub'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1A237E)),
      ),
    );
  }
}