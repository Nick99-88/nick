import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import '../../core/router_gateway.dart';

class ParentChildConnectionScreen extends StatefulWidget {
  const ParentChildConnectionScreen({super.key});

  @override
  State<ParentChildConnectionScreen> createState() => _ParentChildConnectionScreenState();
}

class _ParentChildConnectionScreenState extends State<ParentChildConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _childNameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _connectedChildren = [];

  @override
  void initState() {
    super.initState();
    _loadConnectedChildren();
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectedChildren() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      // TODO: Replace with actual API call to fetch linked children
      // For now, use placeholder data
      if (mounted) {
        setState(() {
          _connectedChildren = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading connected children: $e');
    }
  }

  Future<void> _linkChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired.");

      final accessKey = _accessKeyController.text.trim();

      // TODO: Replace with actual API call to link child via access key
      // For now, simulate the linking process
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Child linked successfully!");
        _accessKeyController.clear();
        _childNameController.clear();
        _loadConnectedChildren();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkChild(String childId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired.");

      // TODO: Replace with actual API call to unlink child
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Child unlinked successfully");
        _loadConnectedChildren();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Connect Your Child',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.family_restroom, size: 60, color: StarlightTheme.primaryBlue),
                  const SizedBox(height: 12),
                  Text(
                    'Link Your Child\'s Account',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: StarlightTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the access key provided by your child\'s institution to monitor their academic progress.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Link Child Form
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Child',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _childNameController,
                        decoration: InputDecoration(
                          labelText: 'Child\'s Name (for your reference)',
                          hintText: 'e.g., Ahmed Ali',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accessKeyController,
                        decoration: InputDecoration(
                          labelText: 'Child\'s Access Key',
                          hintText: 'Enter the access key from institution',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter the access key'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _linkChild,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StarlightTheme.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'LINK CHILD',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Connected Children List
            if (_connectedChildren.isNotEmpty) ...[
              Text(
                'Connected Children',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              ..._connectedChildren.map((child) => _buildChildCard(child)),
              const SizedBox(height: 16),
            ],

            // Skip Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  await UniversalRouter.routeUser(context);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: StarlightTheme.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'SKIP FOR NOW',
                  style: GoogleFonts.poppins(
                    color: StarlightTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
          child: Icon(Icons.school, color: StarlightTheme.primaryBlue),
        ),
        title: Text(
          child['name'] ?? 'Unknown',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          child['institution'] ?? 'No institution linked',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.link_off, color: Colors.red),
          onPressed: () => _showUnlinkDialog(child),
        ),
      ),
    );
  }

  void _showUnlinkDialog(Map<String, dynamic> child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Unlink Child',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unlink ${child['name']}? You will no longer be able to monitor their progress.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _unlinkChild(child['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Unlink',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
