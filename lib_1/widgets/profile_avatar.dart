import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage.dart';
import '../core/theme.dart';

class ProfileAvatar extends StatefulWidget {
  final String userId;
  final String name;
  final double radius;
  final bool showInitial;
  final String? externalImageBase64;
  final String? localImagePath;

  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.radius = 30,
    this.showInitial = true,
    this.externalImageBase64,
    this.localImagePath,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageError = false;
  bool _isLoading = true;
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.userId.isEmpty && widget.externalImageBase64 == null && widget.localImagePath == null) {
      if (mounted) setState(() { _imageError = true; _isLoading = false; });
      return;
    }

    try {
      // Use local file path if provided
      if (widget.localImagePath != null) {
        final file = File(widget.localImagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (mounted) setState(() { _cachedBytes = bytes; _isLoading = false; });
          return;
        }
      }

      // Use external base64 if provided
      if (widget.externalImageBase64 != null) {
        final bytes = base64Decode(widget.externalImageBase64!);
        if (mounted) setState(() { _cachedBytes = bytes; _isLoading = false; });
        return;
      }

      // Fetch from server if no external image
      final res = await http.get(Uri.parse(
        "${StarlightConstants.apiBaseUrl}/explore/pfp/user/${widget.userId}",
      ));
      if (res.statusCode == 200 && mounted) {
        final bytes = res.bodyBytes;
        // Cache locally for current user
        final b64 = base64Encode(bytes);
        await StarlightStorage.setUserPfp(b64);
        if (mounted) setState(() { _cachedBytes = bytes; _isLoading = false; });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() { _imageError = true; _isLoading = false; });
  }

  String get _initial {
    if (widget.name.isEmpty) return '?';
    final words = widget.name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return widget.name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(StarlightTheme.primaryBlue),
        ),
      );
    }

    if (_imageError || widget.userId.isEmpty || _cachedBytes == null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
        child: widget.showInitial
            ? Text(
                _initial,
                style: TextStyle(
                  color: StarlightTheme.primaryBlue,
                  fontSize: widget.radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Icon(Icons.person, color: StarlightTheme.primaryBlue, size: 30),
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
      backgroundImage: MemoryImage(_cachedBytes!),
    );
  }
}
