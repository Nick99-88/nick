import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../services/auth/user_roles_service.dart';
import '../../../core/sign.dart';

class UserRolesScreen extends StatefulWidget {
  const UserRolesScreen({super.key});

  @override
  State<UserRolesScreen> createState() => _UserRolesScreenState();
}

class _UserRolesScreenState extends State<UserRolesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserRole> _userRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // owner, teacher, student, staff
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    setState(() => _isLoading = true);
    
    try {
      final roles = await UserRolesService.getActiveRoles();
      setState(() {
        _userRoles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Failed to load user roles: $e");
      }
    }
  }

  Future<void> _switchToPrimaryRole(UserRole role) async {
    if (role.isPrimary) return;

    try {
      bool success = await UserRolesService.switchPrimaryRole(role.id);
      
      if (success) {
        await _loadUserRoles(); // Refresh roles
        if (mounted) {
          StarlightUtils.showSuccessBox(context, "Switched to ${role.role} at ${role.institutionName}");
        }
      } else {
        if (mounted) {
          StarlightUtils.showErrorBox(context, "Failed to switch primary role");
        }
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Error switching role: $e");
      }
    }
  }

  Future<void> _removeRole(UserRole role) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove Role"),
        content: Text("Are you sure you want to remove your ${role.role} role at ${role.institutionName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      bool success = await UserRolesService.removeRole(role.id);
      
      if (success) {
        await _loadUserRoles(); // Refresh roles
        if (mounted) {
          StarlightUtils.showSuccessBox(context, "Role removed successfully");
        }
      } else {
        if (mounted) {
          StarlightUtils.showErrorBox(context, "Failed to remove role");
        }
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Error removing role: $e");
      }
    }
  }

  List<UserRole> _getRolesByTab(String roleType) {
    return _userRoles.where((role) => role.role == roleType).toList();
  }

  Widget _buildRoleCard(UserRole role) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: role.isPrimary ? 4 : 2,
      color: role.isPrimary ? StarlightTheme.primaryBlue.withOpacity(0.1) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.institutionName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: StarlightTheme.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        role.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: role.isPrimary ? StarlightTheme.primaryBlue : Colors.grey.shade600,
                        ),
                      ),
                      if (role.department != null) ...[
                        SizedBox(height: 4),
                        Text(
                          "Department: ${role.department}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (role.gradeLevel != null) ...[
                        SizedBox(height: 4),
                        Text(
                          "Grade: ${role.gradeLevel}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      if (role.employeeId != null) ...[
                        SizedBox(height: 4),
                        Text(
                          "Employee ID: ${role.employeeId}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (role.isPrimary)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StarlightTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "PRIMARY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                if (!role.isPrimary)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _switchToPrimaryRole(role),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text("Make Primary"),
                    ),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _removeRole(role),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text("Remove"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesList(String roleType, String title) {
    final roles = _getRolesByTab(roleType);
    
    if (roles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getRoleIcon(roleType),
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              "No $title roles",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Join institutions to add $title roles",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: roles.length,
      itemBuilder: (context, index) => _buildRoleCard(roles[index]),
    );
  }

  IconData _getRoleIcon(String roleType) {
    switch (roleType) {
      case 'owner':
        return Icons.business;
      case 'teacher':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'staff':
        return Icons.work;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "My Roles",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: StarlightTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: StarlightTheme.primaryBlue,
          tabs: [
            Tab(text: "OWNER"),
            Tab(text: "TEACHER"),
            Tab(text: "STUDENT"),
            Tab(text: "STAFF"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRolesList('owner', 'Owner'),
                _buildRolesList('teacher', 'Teacher'),
                _buildRolesList('student', 'Student'),
                _buildRolesList('staff', 'Staff'),
              ],
            ),
    );
  }
}
