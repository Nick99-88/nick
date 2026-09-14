import 'package:flutter/material.dart';
import '../models/rtc_room_model.dart';
import '../services/rtc_room_service.dart';
import 'rtc_active_room_screen.dart';
import 'rtc_moderator_room_screen.dart';

class RtcCreateRoomScreen extends StatefulWidget {
  const RtcCreateRoomScreen({super.key});

  @override
  State<RtcCreateRoomScreen> createState() => _RtcCreateRoomScreenState();
}

class _RtcCreateRoomScreenState extends State<RtcCreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomService = RtcRoomService();

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedType = 'all_speakers_all_videos';
  String _selectedAccess = 'open';
  String _selectedControl = 'all_access';
  String _selectedVisibility = 'public';

  bool _isLoading = false;

  final List<Map<String, String>> _roomTypes = [
    {
      'value': 'one_speaker',
      'label': 'One Speaker Only',
      'desc': 'Only the host speaks; all other participants are muted.'
    },
    {
      'value': 'one_video',
      'label': 'Teacher / One Video',
      'desc': 'Only the host streams video; others can speak/listen.'
    },
    {
      'value': 'all_speakers_one_video',
      'label': 'All Speakers, One Video',
      'desc': 'All can speak; only host streams video.'
    },
    {
      'value': 'all_speakers_all_videos',
      'label': 'Group Video Call',
      'desc': 'All participants can stream video and audio.'
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final room = await _roomService.createRoom(
        name: _nameController.text.trim(),
        type: _selectedType,
        accessType: _selectedAccess,
        password: _selectedAccess == 'password' ? _passwordController.text : null,
        controlType: _selectedControl,
        visibility: _selectedVisibility,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room "${room.name}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate directly into the room — creator screen for creator_only, moderator screen for all_access
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _selectedControl == 'creator_only'
                ? RtcActiveRoomScreen(
                    roomId: room.roomId,
                    roomPassword: _selectedAccess == 'password' ? _passwordController.text : null,
                  )
                : RtcModeratorRoomScreen(
                    roomId: room.roomId,
                    roomPassword: _selectedAccess == 'password' ? _passwordController.text : null,
                  ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Chat Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F0C20), const Color(0xFF15102A)]
                : [Colors.grey[100]!, Colors.grey[200]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glassmorphic Card for Form Fields
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: isDark ? const Color(0xFF1E1B3A).withOpacity(0.8) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Room Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Room Name',
                            prefixIcon: const Icon(Icons.meeting_room),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a room name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Room Type Dropdown
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Call Mode / Type',
                            prefixIcon: const Icon(Icons.video_call),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _roomTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type['value'],
                              child: Text(type['label']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedType = val);
                          },
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            _roomTypes.firstWhere((t) => t['value'] == _selectedType)['desc']!,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Access Level
                        Text('Access Type', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'open', label: Text('Open'), icon: Icon(Icons.lock_open)),
                            ButtonSegment(value: 'password', label: Text('Password'), icon: Icon(Icons.lock)),
                          ],
                          selected: {_selectedAccess},
                          onSelectionChanged: (val) {
                            setState(() => _selectedAccess = val.first);
                          },
                        ),
                        if (_selectedAccess == 'password') ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Room Password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (_selectedAccess == 'password' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please enter a password';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Advanced Permissions Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: isDark ? const Color(0xFF1E1B3A).withOpacity(0.8) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host & Control Privileges',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Control Type Switch (All Access vs Host Only)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedControl,
                          decoration: InputDecoration(
                            labelText: 'Control Access',
                            prefixIcon: const Icon(Icons.admin_panel_settings),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all_access',
                              child: Text('All participants can moderate'),
                            ),
                            DropdownMenuItem(
                              value: 'creator_only',
                              child: Text('Only Host/Creator has complete control'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedControl = val);
                          },
                        ),
                        const SizedBox(height: 20),
                        // Visibility Switch
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedVisibility,
                          decoration: InputDecoration(
                            labelText: 'Room Visibility',
                            prefixIcon: const Icon(Icons.visibility),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public (Visible to everyone randomly)'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Private (Only accessible via Room ID)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedVisibility = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Create Room Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'LAUNCH ROOM',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
