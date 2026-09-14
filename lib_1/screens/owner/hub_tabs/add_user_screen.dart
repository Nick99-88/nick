import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../l10n/strings.dart';
import '../../../services/chat/chat_service.dart';
import '../../../core/theme.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  
  String _searchType = 'phone'; // 'phone' or 'id'
  bool _isLoading = false;
  bool _userFound = false;
  Map<String, dynamic>? _foundUser;
  XFile? _profileImage;

  @override
  void dispose() {
    _searchController.dispose();
    _displayNameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    if (_searchController.text.isEmpty) {
      _showError(tr('enterPhoneOrUserId'));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await _chatService.searchUser(_searchType, _searchController.text);
      
      if (result['status'] == 'found') {
        setState(() {
          _userFound = true;
          _foundUser = result['user'];
          _displayNameController.text = _foundUser!['name'];
        });
      } else if (result['status'] == 'exists') {
        _showSuccess(tr('chatAlreadyExists'));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createChatRequest() async {
    if (_foundUser == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _chatService.createChatRequest(
        _foundUser!['id'],
        displayName: _displayNameController.text.isNotEmpty ? _displayNameController.text : null,
      );
      
      _showSuccess(tr('chatRequestSentSuccess'));
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _profileImage = image);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('addUserToChat')),
        backgroundColor: StarlightTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Type Selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
Text(
                    tr('findUser'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text(tr('phoneNumber')),
                          value: 'phone',
                          groupValue: _searchType,
                          onChanged: (value) => setState(() => _searchType = value!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text(tr('userId')),
                          value: 'id',
                          groupValue: _searchType,
                          onChanged: (value) => setState(() => _searchType = value!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: _searchType == 'phone' ? tr('phoneNumber') : tr('userId'),
                prefixIcon: Icon(_searchType == 'phone' ? Icons.phone : Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: _searchType == 'phone' ? TextInputType.phone : TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            // Search Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _searchUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('searchUserBtn'), style: const TextStyle(color: Colors.white)),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // User Found Section
            if (_userFound && _foundUser != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('userFound'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: StarlightTheme.primaryBlue,
                          child: Text(
                            _foundUser!['name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundUser!['name'],
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                tr('roleColon', {'role': '${_foundUser!['role']}'}),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Profile Setup (WhatsApp-like)
              Text(
                tr('setupChatProfile'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Profile Picture
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: StarlightTheme.primaryBlue, width: 2),
                    ),
                    child: _profileImage != null
                        ? ClipOval(
                            child: Image.network(
                              _profileImage!.path,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Display Name
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: tr('displayNameOptional'),
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // About
              TextField(
                controller: _aboutController,
                decoration: InputDecoration(
                  labelText: tr('aboutOptional'),
                  prefixIcon: const Icon(Icons.info),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 20),
              
              // Create Chat Request Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createChatRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(tr('sendChatRequest'), style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
