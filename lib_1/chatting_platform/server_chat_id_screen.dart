import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../chat_local_db/chat_local_db.dart';
import '../../screens/social/chat_screen.dart';
import 'add_contact_screen.dart';

class ServerChatIdScreen extends StatefulWidget {
  const ServerChatIdScreen({super.key});

  @override
  State<ServerChatIdScreen> createState() => _ServerChatIdScreenState();
}

class _ServerChatIdScreenState extends State<ServerChatIdScreen> {
  bool _isLoading = true;
  bool _isFetchingContacts = false;
  bool _isSyncingWithServer = false;
  bool _isFetchingProfilePictures = false;
  
  List<LocalChat> _localContacts = [];
  List<LocalChat> _verifiedContacts = [];
  String _statusMessage = '';

  // Get current user's phone number to detect self contacts
  String _userPhoneNumber = '';
  
  // Alphabetical index
  final ScrollController _scrollController = ScrollController();
  final List<String> _alphabet = ['#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
  Map<String, int> _sectionOffsets = {};
  double _indexHeight = 0;
  
  @override
  void initState() {
    super.initState();
    _loadAndSyncContacts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAndSyncContacts() async {
    // Get current user's phone number
    _userPhoneNumber = await StarlightStorage.getVerifiedPhone() ?? '';
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading contacts...';
    });

    try {
      // Step 1: Request contacts permission
      final permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Contacts permission denied';
        });
        _showError('Contacts permission is required to find verified users');
        return;
      }

      // Step 2: Fetch all contacts from phone
      setState(() {
        _isFetchingContacts = true;
        _statusMessage = 'Fetching contacts from phone...';
      });

      final phoneContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Extract phone numbers and names (unique by phone number)
      List<Map<String, String>> contactData = [];
      final seenPhones = <String>{};
      for (final contact in phoneContacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            final phoneNumber = _formatPhoneNumber(phone.number);
            if (phoneNumber.isEmpty || seenPhones.contains(phoneNumber)) continue;
            seenPhones.add(phoneNumber);
            final contactName = contact.displayName.isNotEmpty 
                ? contact.displayName 
                : (contact.name.first.isNotEmpty ? contact.name.first : 'Unknown');
            contactData.add({
              'phone_number': phoneNumber,
              'contact_name': contactName,
            });
          }
        }
      }

      setState(() {
        _isFetchingContacts = false;
      });

      // Step 3: Check which contacts exist in local DB
      setState(() {
        _statusMessage = 'Checking local database...';
      });

      final chatRepository = ChatRepository();
      final localChats = await chatRepository.getAllChats();
      
      // Create a map of existing local contacts by phone number
      final localPhoneMap = <String, LocalChat>{};
      for (final chat in localChats) {
        localPhoneMap[chat.phoneNumber] = chat;
      }

      List<Map<String, String>> contactsToCheckServer = [];
      List<LocalChat> existingLocalContacts = [];

      for (final contact in contactData) {
        final phone = contact['phone_number']!;
        if (localPhoneMap.containsKey(phone)) {
          existingLocalContacts.add(localPhoneMap[phone]!);
        } else {
          contactsToCheckServer.add(contact);
        }
      }

      // Display local contacts immediately
      final unLockedExisting = existingLocalContacts.where((c) => !c.isLocked).toList();
      setState(() {
        _localContacts = unLockedExisting;
        _verifiedContacts = unLockedExisting;
        _isLoading = false;
      });

      // Step 4: Send remaining contacts to server for verification (background)
      if (contactsToCheckServer.isNotEmpty) {
        setState(() {
          _isSyncingWithServer = true;
          _statusMessage = 'Verifying contacts with server...';
        });

        final verifiedFromServer = await _verifyContactsOnServer(contactsToCheckServer);
        
        // Step 5: Save verified contacts to local DB with empty profile picture
        for (final verifiedContact in verifiedFromServer) {
          final newChat = LocalChat(
            phoneNumber: verifiedContact['phone_number']!,
            contactName: verifiedContact['contact_name']!,
            profileImageUrl: '', // Empty initially
            peerUserId: verifiedContact['peer_user_id'] ?? '',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          
          await chatRepository.insertChat(newChat);
          existingLocalContacts.add(newChat);
        }

        final unLockedNew = existingLocalContacts.where((c) => !c.isLocked).toList();
        setState(() {
          _isSyncingWithServer = false;
          _localContacts = unLockedNew;
          _verifiedContacts = unLockedNew;
        });
      }

      // Step 6: Fetch profile pictures for ALL contacts without them (single fetch)
      final contactsWithoutPictures = existingLocalContacts
          .where((chat) => chat.profileImageUrl.isEmpty)
          .toList();

      if (contactsWithoutPictures.isNotEmpty) {
        setState(() {
          _isFetchingProfilePictures = true;
          _statusMessage = 'Fetching profile pictures...';
        });

        await _fetchProfilePictures(contactsWithoutPictures);

        // Reload contacts to get updated profile pictures
        final updatedChats = await chatRepository.getAllChats();
        final updatedPhoneMap = <String, LocalChat>{};
        for (final chat in updatedChats) {
          updatedPhoneMap[chat.phoneNumber] = chat;
        }

        final finalContacts = existingLocalContacts.map((chat) {
          return updatedPhoneMap[chat.phoneNumber] ?? chat;
        }).toList();

        final unLockedFinal = finalContacts.where((c) => !c.isLocked).toList();
        setState(() {
          _localContacts = unLockedFinal;
          _verifiedContacts = unLockedFinal;
          _isFetchingProfilePictures = false;
          _statusMessage = '';
        });
      } else {
        setState(() {
          _statusMessage = '';
        });
      }

    } catch (e) {
      debugPrint("Error loading contacts: $e");
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading contacts';
      });
      _showError('Failed to load contacts: $e');
    }
  }

  List<String> get _sortedAlphabet {
    final usedLetters = <String>{};
    for (final contact in _verifiedContacts) {
      final name = contact.contactName.isNotEmpty ? contact.contactName : '';
      if (name.isNotEmpty) {
        usedLetters.add(name[0].toUpperCase());
      }
    }
    final result = <String>['#'];
    for (final letter in _alphabet.skip(1)) {
      if (usedLetters.contains(letter)) {
        result.add(letter);
      }
    }
    return result;
  }

  Map<String, List<LocalChat>> get _groupedContacts {
    final map = <String, List<LocalChat>>{};
    final noNameContacts = <LocalChat>[];
    
    for (final contact in _verifiedContacts) {
      final name = contact.contactName;
      if (name.isEmpty) {
        noNameContacts.add(contact);
      } else {
        final letter = name[0].toUpperCase();
        map.putIfAbsent(letter, () => []).add(contact);
      }
    }
    
    if (noNameContacts.isNotEmpty) {
      map['#'] = noNameContacts;
    }
    
    for (final letter in map.keys) {
      map[letter]!.sort((a, b) => a.contactName.compareTo(b.contactName));
    }
    
    return map;
  }

  void _scrollToSection(String letter) {
    final grouped = _groupedContacts;
    if (!grouped.containsKey(letter)) return;
    
    final sectionIndex = _sortedAlphabet.indexOf(letter);
    if (sectionIndex < 0) return;
    
    double offset = 0;
    for (int i = 0; i < sectionIndex; i++) {
      final prevLetter = _sortedAlphabet[i];
      if (grouped.containsKey(prevLetter)) {
        offset += 30 + (grouped[prevLetter]!.length * 72.0);
      }
    }
    
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Convert to Pakistan format if needed
    if (cleaned.startsWith('+92') && cleaned.length == 13) {
      return cleaned;
    } else if (cleaned.startsWith('92') && cleaned.length == 12) {
      return '+$cleaned';
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '+92${cleaned.substring(1)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('3')) {
      return '+92$cleaned';
    }
    
    return cleaned;
  }

  Future<List<Map<String, String>>> _verifyContactsOnServer(
    List<Map<String, String>> contacts
  ) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/verify-contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'contacts': contacts}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final verifiedContacts = data['verified_contacts'] as List<dynamic>;
        
        return verifiedContacts.map((contact) {
          return {
            'phone_number': contact['phone_number'] as String,
            'contact_name': contact['contact_name'] as String,
            'peer_user_id': contact['peer_user_id'] as String? ?? '',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Error verifying contacts with server: $e");
    }
    
    return [];
  }

  Future<String?> _downloadAndSaveProfilePicture(String serverUrl, String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final fullUrl = '${StarlightConstants.apiBaseUrl}$serverUrl';
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Get the application documents directory
        final directory = await getApplicationDocumentsDirectory();
        final profileDir = Directory('${directory.path}/profile_pictures');
        
        // Create directory if it doesn't exist
        if (!await profileDir.exists()) {
          await profileDir.create(recursive: true);
        }
        
        // Create a unique filename based on phone number
        final filename = '${phoneNumber.replaceAll("+", "")}.jpg';
        final filePath = '${profileDir.path}/$filename';
        
        // Save the image file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        debugPrint("Profile picture saved locally for $phoneNumber: $filePath");
        return filePath;
      } else {
        debugPrint("Failed to download profile picture: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error downloading profile picture: $e");
      return null;
    }
  }

  Future<void> _fetchProfilePictures(List<LocalChat> contacts) async {
    final chatRepository = ChatRepository();
    
    for (final contact in contacts) {
      try {
        // Fetch profile picture URL from server
        final token = await StarlightStorage.getUserToken();
        final response = await http.get(
          Uri.parse('${StarlightConstants.apiBaseUrl}/chat/profile-picture/${contact.phoneNumber}'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        debugPrint("Profile picture response for ${contact.phoneNumber}: ${response.statusCode}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final profileUrl = data['profile_picture_url'] as String?;
          
          debugPrint("Profile URL for ${contact.phoneNumber}: $profileUrl");
          
          if (profileUrl != null && profileUrl.isNotEmpty) {
            // Download and save the profile picture locally
            final localPath = await _downloadAndSaveProfilePicture(profileUrl, contact.phoneNumber);
            
            if (localPath != null) {
              // Update local chat with local file path
              final updatedChat = contact.copyWith(
                profileImageUrl: localPath,
                updatedAt: DateTime.now().toIso8601String(),
              );
              final result = await chatRepository.updateChat(updatedChat);
              debugPrint("Updated chat ${contact.phoneNumber} with local profile picture, rows affected: $result");
            }
          } else {
            debugPrint("Profile URL is null or empty for ${contact.phoneNumber}");
          }
        }
      } catch (e) {
        debugPrint("Error fetching profile picture for ${contact.phoneNumber}: $e");
      }
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

  void _navigateToAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF263238),
        ),
        title: const Text(
          'Verified Contacts',
          style: TextStyle(
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            onPressed: _loadAndSyncContacts,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Status bar
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.withOpacity(0.1),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contacts list with alphabetical index
                Expanded(
                  child: _verifiedContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No verified contacts found',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sync your contacts to find verified users',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _verifiedContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _verifiedContacts[index];
                                return _contactTile(contact);
                              },
                            ),
                            Positioned(
                              right: 4,
                              top: 0,
                              bottom: 0,
                              child: _buildAlphabetIndex(),
                            ),
                          ],
                        ),
                ),

                // Add contact button
                SafeArea(
                  top: false,
                  child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToAddContact,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF263238),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ],
            ),
    );
  }

  Widget _contactTile(LocalChat contact) {
    // Number is compulsory, name and picture are optional
    // Show "you" for self contacts (when the contact is the current user)
    final displayName = contact.phoneNumber == _userPhoneNumber
        ? 'You'
        : (contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber);
    final hasPicture = contact.profileImageUrl.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: hasPicture ? () => _showFullImage(contact.profileImageUrl) : null,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[200],
            backgroundImage: hasPicture ? FileImage(File(contact.profileImageUrl)) : null,
            child: !hasPicture
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF263238),
                    ),
                  )
                : null,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF263238),
          ),
        ),
        subtitle: Text(
          _formatPhoneNumberForDisplay(contact.phoneNumber),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified,
                size: 14,
                color: Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(contact.phoneNumber);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                friendId: contact.peerUserId.isNotEmpty ? contact.peerUserId : contact.phoneNumber,
                friendName: contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber,
                friendRole: 'User',
                friendPhone: isUuid ? null : contact.phoneNumber,
                friendProfilePicture: contact.profileImageUrl.isNotEmpty ? contact.profileImageUrl : null,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatPhoneNumberForDisplay(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+92') && cleaned.length == 13) {
      return '+92 ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }
    return phoneNumber;
  }

  Widget _buildAlphabetIndex() {
    final sortedAlphabet = _sortedAlphabet;
    
    return GestureDetector(
      onVerticalDragStart: (details) {
        _handleAlphabetTouch(details.localPosition);
      },
      onVerticalDragUpdate: (details) {
        _handleAlphabetTouch(details.localPosition);
      },
      child: Container(
        width: 24,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: sortedAlphabet.map((letter) {
            return GestureDetector(
              onTap: () => _scrollToSection(letter),
              child: Container(
                height: 20,
                width: 20,
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _handleAlphabetTouch(Offset position) {
    final sortedAlphabet = _sortedAlphabet;
    final itemHeight = 20.0;
    final index = (position.dy / itemHeight).floor();
    if (index >= 0 && index < sortedAlphabet.length) {
      _scrollToSection(sortedAlphabet[index]);
    }
  }

  void _showFullImage(String imagePath) {
    if (imagePath.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: FileImage(File(imagePath)) is ImageProvider
                  ? Image.file(File(imagePath), fit: BoxFit.contain)
                  : Container(),
            ),
          ),
        ),
      ),
    );
  }
}
