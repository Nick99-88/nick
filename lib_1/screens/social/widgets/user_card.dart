import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../widgets/profile_avatar.dart';

class UserCard extends StatelessWidget {
  final String name;
  final String role;
  final String id;
  final Map<String, dynamic>? institution;
  final String? gender;
  final String? classSection;
  final String? shortId;
  final String? bio;
  final VoidCallback onTap;
  final VoidCallback? onChat;
  final VoidCallback? onAdd;

  const UserCard({
    super.key,
    required this.name,
    required this.role,
    required this.id,
    this.institution,
    this.gender,
    this.classSection,
    this.shortId,
    this.bio,
    required this.onTap,
    this.onChat,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final pfpUrl = "${StarlightConstants.apiBaseUrl}/explore/pfp/user/$id";

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProfileAvatar(
              userId: id,
              name: name,
              radius: 30,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _roleColor(role).withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(color: _roleColor(role), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ),
            if (bio != null && bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  bio!,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500, height: 1.3),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (gender != null && gender!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 9, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text(
                    gender!,
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
            if (classSection != null && classSection!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.class_rounded, size: 9, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text(
                    'Sec: $classSection',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
            if (institution != null) ...[
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_rounded, size: 9, color: const Color(0xFF1565C0).withOpacity(0.6)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        institution!['name'] ?? 'Institution',
                        style: TextStyle(fontSize: 9, color: const Color(0xFF1565C0).withOpacity(0.8), fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            if (shortId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint, size: 8, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(
                      shortId!,
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade400, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shortId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User ID $shortId copied'), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: Icon(Icons.copy_rounded, size: 9, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionIcon(Icons.chat_bubble_outline_rounded, Colors.blue, onChat ?? () {}),
                const SizedBox(width: 8),
                _actionIcon(Icons.person_add_alt_1_rounded, Colors.green, onAdd ?? () {}),
                const SizedBox(width: 8),
                _actionIcon(Icons.share_rounded, Colors.orange, () {
                  Share.share('Check out $name on Starlight Institution\nhttps://institution.site/u/$id');
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'teacher':
      case 'admin':
        return Colors.orange;
      case 'student':
        return const Color(0xFF1565C0);
      case 'staff':
        return Colors.purple;
      case 'owner':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
