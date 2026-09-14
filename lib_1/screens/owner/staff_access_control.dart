import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/offline/offline_service.dart';
import '../../core/utils.dart';

class StaffAccessControlScreen extends StatefulWidget {
  const StaffAccessControlScreen({super.key});

  @override
  State<StaffAccessControlScreen> createState() => _StaffAccessControlScreenState();
}

class _StaffAccessControlScreenState extends State<StaffAccessControlScreen> {
  final OfflineService _offlineService = OfflineService.instance;
  List<Map<String, dynamic>> _staffMembers = [];
  bool _isLoading = true;

  // Available permissions for staff members
  final Map<String, bool> _availablePermissions = {
    'view_students': true,
    'manage_attendance': false,
    'view_grades': false,
    'upload_documents': false,
    'view_reports': false,
    'send_notices': false,
    'manage_library': false,
    'view_finances': false,
    'manage_events': false,
    'access_chat': true,
  };

  @override
  void initState() {
    super.initState();
    _loadStaffMembers();
  }

  Future<void> _loadStaffMembers() async {
    setState(() => _isLoading = true);
    
    try {
      // Mock staff members data
      final staffMembers = [
        {
          'id': '1',
          'name': 'John Doe',
          'email': 'john@institution.com',
          'position': 'Administrative Staff',
          'department': 'Administration',
          'staffType': 'Administrative',
          'employeeId': 'EMP001',
          'isActive': true,
          'permissions': Map<String, bool>.from(_availablePermissions),
          'lastLogin': '2024-01-15 10:30 AM',
        },
        {
          'id': '2',
          'name': 'Jane Smith',
          'email': 'jane@institution.com',
          'position': 'Librarian',
          'department': 'Library',
          'staffType': 'Support Staff',
          'employeeId': 'EMP002',
          'isActive': true,
          'permissions': {
            'view_students': true,
            'manage_attendance': false,
            'view_grades': false,
            'upload_documents': true,
            'view_reports': false,
            'send_notices': false,
            'manage_library': true,
            'view_finances': false,
            'manage_events': false,
            'access_chat': true,
          },
          'lastLogin': '2024-01-15 09:15 AM',
        },
        {
          'id': '3',
          'name': 'Mike Johnson',
          'email': 'mike@institution.com',
          'position': 'Security Officer',
          'department': 'Security',
          'staffType': 'Security',
          'employeeId': 'EMP003',
          'isActive': false,
          'permissions': {
            'view_students': true,
            'manage_attendance': true,
            'view_grades': false,
            'upload_documents': false,
            'view_reports': false,
            'send_notices': false,
            'manage_library': false,
            'view_finances': false,
            'manage_events': false,
            'access_chat': true,
          },
          'lastLogin': '2024-01-10 03:45 PM',
        },
      ];

      setState(() {
        _staffMembers = staffMembers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showErrorBox(context, 'Failed to load staff members');
    }
  }

  Future<void> _updateStaffPermissions(String staffId, Map<String, bool> permissions) async {
    try {
      // Find and update staff member permissions
      final staffIndex = _staffMembers.indexWhere((staff) => staff['id'] == staffId);
      if (staffIndex != -1) {
        setState(() {
          _staffMembers[staffIndex]['permissions'] = permissions;
        });
        
        StarlightUtils.showSuccessBox(context, 'Permissions updated successfully!');
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Failed to update permissions');
    }
  }

  Future<void> _toggleStaffStatus(String staffId) async {
    try {
      final staffIndex = _staffMembers.indexWhere((staff) => staff['id'] == staffId);
      if (staffIndex != -1) {
        setState(() {
          _staffMembers[staffIndex]['isActive'] = !_staffMembers[staffIndex]['isActive'];
        });
        
        final status = _staffMembers[staffIndex]['isActive'] ? 'activated' : 'deactivated';
        StarlightUtils.showSuccessBox(context, 'Staff member $status successfully!');
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Failed to update staff status');
    }
  }

  void _showPermissionDialog(Map<String, dynamic> staffMember) {
    final permissions = Map<String, bool>.from(staffMember['permissions']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Permissions - ${staffMember['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select permissions to grant:'),
                  const SizedBox(height: 16),
                  ...permissions.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(_getPermissionDisplayName(entry.key)),
                      subtitle: Text(_getPermissionDescription(entry.key)),
                      value: entry.value,
                      onChanged: (value) {
                        setState(() {
                          permissions[entry.key] = value!;
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStaffPermissions(staffMember['id'], permissions);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getPermissionDisplayName(String permissionKey) {
    switch (permissionKey) {
      case 'view_students':
        return 'View Students';
      case 'manage_attendance':
        return 'Manage Attendance';
      case 'view_grades':
        return 'View Grades';
      case 'upload_documents':
        return 'Upload Documents';
      case 'view_reports':
        return 'View Reports';
      case 'send_notices':
        return 'Send Notices';
      case 'manage_library':
        return 'Manage Library';
      case 'view_finances':
        return 'View Finances';
      case 'manage_events':
        return 'Manage Events';
      case 'access_chat':
        return 'Access Chat';
      default:
        return permissionKey;
    }
  }

  String _getPermissionDescription(String permissionKey) {
    switch (permissionKey) {
      case 'view_students':
        return 'Can view student information and records';
      case 'manage_attendance':
        return 'Can mark and manage student attendance';
      case 'view_grades':
        return 'Can view student grades and results';
      case 'upload_documents':
        return 'Can upload and manage documents';
      case 'view_reports':
        return 'Can view institutional reports';
      case 'send_notices':
        return 'Can send notices and announcements';
      case 'manage_library':
        return 'Can manage library resources';
      case 'view_finances':
        return 'Can view financial information';
      case 'manage_events':
        return 'Can create and manage events';
      case 'access_chat':
        return 'Can access chat system';
      default:
        return 'Permission description';
    }
  }

  String _getStaffTypeDisplayName(String staffType) {
    switch (staffType) {
      case 'Administrative':
        return 'Administrative';
      case 'Support Staff':
        return 'Support Staff';
      case 'Security':
        return 'Security';
      case 'Maintenance':
        return 'Maintenance';
      case 'Librarian':
        return 'Librarian';
      case 'Lab Assistant':
        return 'Lab Assistant';
      case 'IT Support':
        return 'IT Support';
      case 'Accountant':
        return 'Accountant';
      case 'Counselor':
        return 'Counselor';
      default:
        return staffType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Staff Access Control'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with summary
                _buildHeader(),
                const SizedBox(height: 16),
                
                // Staff members list
                Expanded(
                  child: _buildStaffList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final activeStaff = _staffMembers.where((staff) => staff['isActive']).length;
    final totalPermissions = _availablePermissions.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
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
            'Access Control Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Staff', _staffMembers.length.toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Active Staff', activeStaff.toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Permissions', totalPermissions.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StarlightTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: StarlightTheme.primaryBlue,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: StarlightTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _staffMembers.length,
      itemBuilder: (context, index) {
        final staffMember = _staffMembers[index];
        return _buildStaffCard(staffMember);
      },
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staffMember) {
    final permissions = staffMember['permissions'] as Map<String, bool>;
    final grantedPermissions = permissions.values.where((p) => p).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: staffMember['isActive'] 
                      ? Colors.green.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: staffMember['isActive'] ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffMember['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${staffMember['position']} • ${staffMember['department']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status toggle
                Switch(
                  value: staffMember['isActive'],
                  onChanged: (value) => _toggleStaffStatus(staffMember['id']),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Staff details
            Row(
              children: [
                _buildDetailChip('ID', staffMember['employeeId']),
                const SizedBox(width: 8),
                _buildDetailChip('Type', _getStaffTypeDisplayName(staffMember['staffType'])),
                const SizedBox(width: 8),
                _buildDetailChip('Permissions', '$grantedPermissions/${permissions.length}'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Permission summary and actions
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: permissions.entries
                        .where((entry) => entry.value)
                        .take(3)
                        .map((entry) => _buildPermissionChip(entry.key))
                        .toList(),
                  ),
                ),
                if (permissions.values.where((p) => p).length > 3)
                  Text(
                    '+${permissions.values.where((p) => p).length - 3} more',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showPermissionDialog(staffMember),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                  ),
                  child: const Text('Manage'),
                ),
              ],
            ),
            
            if (staffMember['lastLogin'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last login: ${staffMember['lastLogin']}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPermissionChip(String permissionKey) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: StarlightTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getPermissionDisplayName(permissionKey).split(' ')[0],
        style: TextStyle(
          fontSize: 10,
          color: StarlightTheme.primaryBlue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
