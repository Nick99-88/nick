import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../core/storage.dart';
import '../../services/socket/enhanced_socket_service.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isSaving = false;
  bool _isVerifying = false;
  bool _isNumberVerified = false;
  String _verificationMessage = '';
  
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    EnhancedSocketService.setPhoneValidationResultCallback(_handlePhoneValidationResult);
    EnhancedSocketService.connect(source: 'AddContactScreen');
    
    // Listen to phone number changes for verification
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    EnhancedSocketService.setPhoneValidationResultCallback(null);
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    // Debounce verification to avoid too many requests
    _debounceTimer?.cancel();
    
    final phoneNumber = _formatPhoneNumber(_phoneController.text);
    if (phoneNumber.length >= 10) {
      setState(() => _isVerifying = true);
      
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _verifyPhoneNumber(phoneNumber);
      });
    } else {
      setState(() {
        _isVerifying = false;
        _isNumberVerified = false;
        _verificationMessage = '';
      });
    }
  }

  void _verifyPhoneNumber(String phoneNumber) {
    EnhancedSocketService.validatePhone(phoneNumber);
  }

  Future<Map<String, String>> _getAllContactNumbers() async {
    final contactMap = <String, String>{};
    
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            final phoneNumber = _formatPhoneNumber(phone.number);
            if (phoneNumber.isNotEmpty) {
              final displayName = contact.displayName.isNotEmpty 
                  ? contact.displayName 
                  : (contact.name.first.isNotEmpty ? contact.name.first : 'Unknown');
              contactMap[phoneNumber] = displayName;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting contacts: $e');
    }
    
    return contactMap;
  }

  void _handlePhoneValidationResult(Map<String, dynamic> data) {
    final isVerified = data['found'] ?? false;
    final msg = data['message'] ?? '';
    setState(() {
      _isVerifying = false;
      _isNumberVerified = isVerified;
      _verificationMessage = msg;
    });
    if (msg.isNotEmpty) {
      if (isVerified) {
        _showSuccess(msg);
      } else {
        _showError(msg);
      }
    }
  }

  String _formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
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

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Request contacts permission
      final permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        _showError('Contacts permission is required to save contacts');
        setState(() => _isSaving = false);
        return;
      }

      final name = _nameController.text.trim();
      final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());

      // Check if number already exists in saved contacts
      final contactMap = await _getAllContactNumbers();
      if (contactMap.containsKey(phoneNumber)) {
        _showError('this number already exist in your contact with this ${contactMap[phoneNumber]}');
        setState(() => _isSaving = false);
        return;
      }

      // Create contact using flutter_contacts
      final contact = Contact()
        ..name = Name(first: name, last: '')
        ..phones = [Phone(phoneNumber)];

      await contact.insert();

      _showSuccess('Contact saved successfully');
      
      // Navigate back
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving contact: $e');
      _showError('Failed to save contact: $e');
    } finally {
      setState(() => _isSaving = false);
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
          'Add Contact',
          style: TextStyle(
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 64,
                  color: Colors.blue,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Add New Contact',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Enter contact details to save to your phone',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  hintText: 'Enter full name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '3XX XXXXXXX',
                  prefixText: '+92 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _isNumberVerified
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length != 10) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                  if (!value.startsWith('3')) {
                    return 'Please enter a valid Pakistan mobile number';
                  }
                  return null;
                },
              ),
              
              // Verification status message
              if (_isNumberVerified) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'This number is verified on the platform',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              
              const SizedBox(height: 40),
              
              // Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveContact,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF263238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
