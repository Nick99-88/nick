import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../services/library_service.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  String _selectedPic = 'avatar_blue';
  final List<String> _pics = ['avatar_blue', 'avatar_green', 'avatar_orange', 'avatar_purple', 'avatar_teal'];
  bool _submitting = false;
  File? _profileImage;
  bool _useCustomImage = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
          _useCustomImage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await LibraryService.createChannel(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        profilePicPath: _useCustomImage ? _profileImage?.path : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Library created successfully!")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Library creation failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("CREATE LIBRARY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: StarlightTheme.primaryBlue.withOpacity(0.05),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: StarlightTheme.primaryBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Create your own Library to establish your brand profile, upload books, and build your student audience!",
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Channel Name input
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: "Library Name / Brand Name",
                  hintText: "e.g. Stanford Physics Notes",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Library name is required" : null,
              ),
              const SizedBox(height: 16),

              // Description input
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: "Library Description",
                  hintText: "e.g. Official physics study materials and reference guides.",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty ? "Description is required" : null,
              ),
              const SizedBox(height: 16),

              // Profile Picture Section
              const Text("Library Profile Picture:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              
              // Profile picture preview and picker
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                          border: Border.all(color: StarlightTheme.primaryBlue, width: 2),
                        ),
                        child: _useCustomImage && _profileImage != null
                            ? ClipOval(
                                child: Image.file(
                                  _profileImage!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _useCustomImage ? "Tap to change picture" : "Tap to upload picture",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Theme color selection (fallback if no custom image)
              const Text("Or choose a theme color:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _pics.map((pic) {
                  final selected = _selectedPic == pic;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedPic = pic;
                      _useCustomImage = false;
                      _profileImage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? StarlightTheme.primaryBlue : Colors.transparent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: _getPicColor(pic).withOpacity(0.2),
                        child: Icon(Icons.menu_book_rounded, color: _getPicColor(pic), size: 20),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Launch My Library", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPicColor(String pic) {
    switch (pic) {
      case 'avatar_blue': return Colors.blue;
      case 'avatar_green': return Colors.green;
      case 'avatar_orange': return Colors.orange;
      case 'avatar_purple': return Colors.purple;
      case 'avatar_teal': return Colors.teal;
      default: return Colors.blue;
    }
  }
}
