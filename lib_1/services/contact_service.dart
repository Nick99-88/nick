import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// 🏛️ Contact Service for managing phone contacts
/// Handles creating contacts in user's phone after successful add user
class ContactService {
  /// 🏛️ Create a new contact in user's phone
  /// Returns true if successful, false otherwise
  /// NOTE: Contact creation is disabled on cloud-only devices to prevent crashes
  static Future<bool> createContact({
    required String name,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      print('🏛️ Contact Service: Skipping contact creation for $name at $phoneNumber');
      print('🏛️ Contact Service: Contact creation disabled to prevent crashes on cloud-only devices');
      
      // Contact creation is disabled to prevent crashes on devices with cloud-only contact accounts
      // The user connection is still created successfully in the backend
      return false;
      
    } catch (e) {
      print('🏛️ Contact Service: Error in contact creation (disabled) - $e');
      return false;
    }
  }
  
    
    
  /// 🏛️ Check if contact with phone number already exists
  /// Returns true if contact exists, false otherwise
  static Future<bool> contactExists(String phoneNumber) async {
    try {
      print('🏛️ Contact Service: Checking if contact exists for $phoneNumber');
      
      // Request contacts permission
      final permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        print('🏛️ Contact Service: Contacts permission denied');
        return false;
      }
      
      // Get all contacts
      final contacts = await FlutterContacts.getContacts();
      
      // Check if any contact has the same phone number
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            if (phone.number.replaceAll(RegExp(r'[^0-9+]'), '') == phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '')) {
              print('🏛️ Contact Service: Contact already exists - ${contact.name.first} ($phoneNumber)');
              return true;
            }
          }
        }
      }
      
      print('🏛️ Contact Service: Contact does not exist for $phoneNumber');
      return false;
      
    } catch (e) {
      print('🏛️ Contact Service: Error checking contact existence - $e');
      return false;
    }
  }
  
  /// 🏛️ Get contact name by phone number
  /// Returns contact name if found, null otherwise
  static Future<String?> getContactName(String phoneNumber) async {
    try {
      print('🏛️ Contact Service: Getting contact name for $phoneNumber');
      
      // Request contacts permission
      final permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        print('🏛️ Contact Service: Contacts permission denied');
        return null;
      }
      
      // Get all contacts
      final contacts = await FlutterContacts.getContacts();
      
      // Find contact by phone number
      for (final contact in contacts) {
        if (contact.phones.isNotEmpty) {
          for (final phone in contact.phones) {
            if (phone.number.replaceAll(RegExp(r'[^0-9+]'), '') == phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '')) {
              final name = contact.name.first.isNotEmpty ? contact.name.first : 'Unknown';
              print('🏛️ Contact Service: Found contact - $name ($phoneNumber)');
              return name;
            }
          }
        }
      }
      
      print('🏛️ Contact Service: No contact found for $phoneNumber');
      return null;
      
    } catch (e) {
      print('🏛️ Contact Service: Error getting contact name - $e');
      return null;
    }
  }
}
