import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../widgets/profile_avatar.dart';

class FriendRequest {
  final String id;
  final String name;
  final String role;
  DateTime timestamp;
  String status; // 'pending' | 'accepted' | 'rejected'

  FriendRequest({
    required this.id,
    required this.name,
    required this.role,
    DateTime? timestamp,
    this.status = 'pending',
  }) : timestamp = timestamp ?? DateTime.now();
}

class RequestBox extends StatefulWidget {
  final List<FriendRequest> requests;
  final Function(String requestId, bool accepted) onRespond;
  final VoidCallback onClose;

  const RequestBox({
    super.key,
    required this.requests,
    required this.onRespond,
    required this.onClose,
  });

  @override
  State<RequestBox> createState() => _RequestBoxState();
}

class _RequestBoxState extends State<RequestBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _controller.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.requests.where((r) => r.status == 'pending').toList();

    return GestureDetector(
      onTap: () {},
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          alignment: Alignment.bottomRight,
          child: Container(
            width: 320,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(pending.length),
                const Divider(height: 1),
                if (pending.isEmpty)
                  _buildEmptyState()
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: pending.length,
                      itemBuilder: (context, index) {
                        return _buildRequestItem(pending[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1, color: StarlightTheme.primaryBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Friend Requests',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: StarlightTheme.primaryBlue,
                  ),
                ),
                Text(
                  '$count pending',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _close,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'No pending requests',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(FriendRequest request) {
    final isAccepted = request.status == 'accepted';
    final isRejected = request.status == 'rejected';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAccepted
            ? Colors.green.withOpacity(0.05)
            : isRejected
                ? Colors.red.withOpacity(0.05)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAccepted
              ? Colors.green.withOpacity(0.3)
              : isRejected
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ProfileAvatar(userId: request.id, name: request.name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  request.role.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          if (isAccepted)
            _buildStatusChip('Accepted', Colors.green)
          else if (isRejected)
            _buildStatusChip('Rejected', Colors.red)
          else ...[
            _buildActionBtn(Icons.close, Colors.red, () => widget.onRespond(request.id, false)),
            const SizedBox(width: 6),
            _buildActionBtn(Icons.check, Colors.green, () => widget.onRespond(request.id, true)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
