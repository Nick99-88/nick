import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../core/utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _profileImage;
  bool _isEditing = false;
  bool _isLoading = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  String _userRole = '';
  String _institutionName = '';
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    
    try {
      final role = await StarlightStorage.getUserRole() ?? '';
      final token = await StarlightStorage.getUserToken();
      
      if (token != null) {
        // Load profile data based on role
        final profileData = await _getProfileDataByRole(role, token);
        setState(() {
          _userRole = role;
          _profileData = profileData;
          _nameController.text = profileData['name'] ?? '';
          _emailController.text = profileData['email'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _bioController.text = profileData['bio'] ?? '';
          _institutionName = profileData['institution_name'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showErrorBox(context, 'Failed to load profile data');
    }
  }

  Future<Map<String, dynamic>> _getProfileDataByRole(String role, String token) async {
    // Mock profile data based on role
    switch (role.toLowerCase()) {
      case 'owner':
        return {
          'name': 'John Owner',
          'email': 'owner@institution.com',
          'phone': '+1234567890',
          'bio': 'Institution owner and administrator',
          'institution_name': 'Starlight Academy',
          'position': 'Owner',
          'department': 'Administration',
        };
      case 'teacher':
        return {
          'name': 'Ms. Sarah Williams',
          'email': 'teacher@institution.com',
          'phone': '+1234567891',
          'bio': 'Mathematics teacher with 10 years of experience',
          'institution_name': 'Starlight Academy',
          'position': 'Mathematics Teacher',
          'department': 'Academics',
          'subject': 'Mathematics',
          'grade': 'Grade 10',
        };
      case 'student':
        return {
          'name': 'Alice Johnson',
          'email': 'student@institution.com',
          'phone': '+1234567892',
          'bio': 'Grade 10 student interested in science and technology',
          'institution_name': 'Starlight Academy',
          'grade': 'Grade 10',
          'section': 'Section A',
          'rollNumber': 'STU001',
        };
      case 'staff':
        return {
          'name': 'John Doe',
          'email': 'staff@institution.com',
          'phone': '+1234567893',
          'bio': 'Administrative staff member',
          'institution_name': 'Starlight Academy',
          'position': 'Administrative Staff',
          'department': 'Administration',
          'staffType': 'Administrative',
          'employeeId': 'EMP001',
        };
      default:
        return {
          'name': 'User',
          'email': 'user@example.com',
          'phone': '+1234567890',
          'bio': 'User profile',
          'institution_name': 'Starlight Academy',
        };
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Failed to pick image');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception('Not authenticated');
      
      // Update profile data
      final updatedData = {
        ..._profileData,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
      };
      
      // Mock API call to update profile
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _profileData = updatedData;
        _isEditing = false;
        _isLoading = false;
      });
      
      StarlightUtils.showSuccessBox(context, 'Profile updated successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showErrorBox(context, 'Failed to update profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  
                  // Role Information
                  _buildRoleInfo(),
                  const SizedBox(height: 24),
                  
                  // Personal Information
                  _buildPersonalInfo(),
                  const SizedBox(height: 24),
                  
                  // Additional Information
                  _buildAdditionalInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              _profileImage != null
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: FileImage(_profileImage!),
                    )
                  : ProfileAvatar(
                      userId: _profileData['id'] ?? '',
                      name: _nameController.text,
                      radius: 50,
                    ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: StarlightTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _getRoleDisplayName(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Role', _getRoleDisplayName()),
          _buildInfoRow('Institution', _institutionName),
          if (_profileData['position'] != null)
            _buildInfoRow('Position', _profileData['position']),
          if (_profileData['department'] != null)
            _buildInfoRow('Department', _profileData['department']),
          if (_profileData['subject'] != null)
            _buildInfoRow('Subject', _profileData['subject']),
          if (_profileData['grade'] != null)
            _buildInfoRow('Grade', _profileData['grade']),
          if (_profileData['section'] != null)
            _buildInfoRow('Section', _profileData['section']),
          if (_profileData['rollNumber'] != null)
            _buildInfoRow('Roll Number', _profileData['rollNumber']),
          if (_profileData['employeeId'] != null)
            _buildInfoRow('Employee ID', _profileData['employeeId']),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildEditableField('Name', _nameController),
          _buildEditableField('Email', _emailController),
          _buildEditableField('Phone', _phoneController),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildEditableField('Bio', _bioController, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            enabled: _isEditing,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName() {
    switch (_userRole.toLowerCase()) {
      case 'owner':
        return 'Institution Owner';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'staff':
        return 'Staff Member';
      default:
        return 'User';
    }
  }
}