import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/institution/notice_service.dart';
import '../services/api_service.dart';
import '../core/theme.dart';
import '../core/storage.dart';
import '../core/database_helper.dart';

class StarlightMailbox extends StatefulWidget {
  final ScrollController scrollController;

  const StarlightMailbox({super.key, required this.scrollController});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return StarlightMailbox(scrollController: scrollController);
        },
      ),
    );
  }

  @override
  State<StarlightMailbox> createState() => _StarlightMailboxState();
}

class _StarlightMailboxState extends State<StarlightMailbox> {
  String _activeCategory = "Institutional";
  final NoticeService _noticeService = NoticeService();
  
  List<dynamic> _institutionalNotices = [];
  bool _isLoadingNotices = false;

  List<dynamic> _formalEmails = [];
  bool _isLoadingFormals = false;
  String _myUserId = "";

  List<dynamic> _realAlerts = [];
  bool _isLoadingAlerts = false;

  List<dynamic> _realSecurityAlerts = [];
  bool _isLoadingSecurity = false;

  List<dynamic> _receivedGifts = [];
  List<dynamic> _sentGifts = [];
  bool _isLoadingGifts = false;

  @override
  void initState() {
    super.initState();
    _loadInstitutionalNotices();
    _loadMyUserId();
  }

  Future<void> _loadMyUserId() async {
    final Map<String, String> cached = await StarlightStorage.getIIdentity();
    if (mounted) {
      setState(() {
        _myUserId = cached['user_id'] ?? '';
      });
    }
  }

  Future<void> _loadGifts() async {
    setState(() => _isLoadingGifts = true);
    try {
      final receivedRes = await ApiService.get('/shop/gifts/received');
      final sentRes = await ApiService.get('/shop/gifts/sent');
      setState(() {
        _receivedGifts = receivedRes['received_gifts'] ?? [];
        _sentGifts = sentRes['sent_gifts'] ?? [];
        _isLoadingGifts = false;
      });
    } catch (e) {
      debugPrint('Mailbox: loadGifts error - $e');
      setState(() => _isLoadingGifts = false);
    }
  }

  Future<void> _loadInstitutionalNotices() async {
    setState(() => _isLoadingNotices = true);
    try {
      final notices = await _noticeService.getNoticeHistory();
      setState(() {
        _institutionalNotices = notices;
        _isLoadingNotices = false;
      });
    } catch (e) {
      setState(() => _isLoadingNotices = false);
    }
  }

  Future<void> _loadFormalEmails() async {
    setState(() => _isLoadingFormals = true);
    try {
      final res = await ApiService.get('/mailbox/inbox');
      if (res['emails'] is List) {
        setState(() {
          _formalEmails = res['emails'];
          _isLoadingFormals = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingFormals = false);
    }
  }

  Future<void> _loadRealAlerts() async {
    setState(() => _isLoadingAlerts = true);
    try {
      final res = await ApiService.get('/mailbox/alerts');
      if (res['alerts'] is List) {
        setState(() {
          _realAlerts = res['alerts'];
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading real alerts: $e");
      setState(() => _isLoadingAlerts = false);
    }
  }

  Future<void> _loadRealSecurityAlerts() async {
    setState(() => _isLoadingSecurity = true);
    try {
      final res = await ApiService.get('/mailbox/security');
      if (res['alerts'] is List) {
        setState(() {
          _realSecurityAlerts = res['alerts'];
          _isLoadingSecurity = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading real security alerts: $e");
      setState(() => _isLoadingSecurity = false);
    }
  }

  // --- Mock Data for other categories ---
  final Map<String, List<Map<String, String>>> _mailData = {
    "Alerts": [
      {
        "sender": "System Monitor",
        "title": "Server Maintenance",
        "desc": "The Institutional Pipe will be down for maintenance at 2:00 AM PST.",
        "time": "Just Now"
      },
      {
        "sender": "Admin Gate",
        "title": "Login Alert",
        "desc": "A new login was detected from a Chrome browser on Windows.",
        "time": "1 hr ago"
      },
    ],
    "Gifts": [
      {
        "sender": "Starlight Rewards",
        "title": "Efficiency Bonus",
        "desc": "Congratulations! You have earned a digital token for system uptime.",
        "time": "Jan 1"
      },
      {
        "sender": "Event Team",
        "title": "New Year Surprise",
        "desc": "Tap to reveal your institutional gift card for the tech-fair.",
        "time": "Dec 31"
      },
    ],
    "Security": [
      {
        "sender": "Vault Guard",
        "title": "MasterKey Rotation",
        "desc": "It's time to rotate your hardware keys for enhanced encryption.",
        "time": "Critical"
      },
      {
        "sender": "Firewall",
        "title": "IP Blocked",
        "desc": "A suspicious IP address from region US-East was automatically blocked.",
        "time": "12:00 PM"
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    List<dynamic> currentMails;
    if (_activeCategory == "Institutional") {
      currentMails = _institutionalNotices;
    } else if (_activeCategory == "Formals") {
      currentMails = _formalEmails;
    } else if (_activeCategory == "Gifts") {
      final List<dynamic> merged = [];
      for (final g in _receivedGifts) {
        merged.add({...g, 'isGiftReceived': true});
      }
      for (final g in _sentGifts) {
        merged.add({...g, 'isGiftReceived': false});
      }
      merged.sort((a, b) {
        final tA = DateTime.tryParse(a['activated_at'] ?? '') ?? DateTime(0);
        final tB = DateTime.tryParse(b['activated_at'] ?? '') ?? DateTime(0);
        return tB.compareTo(tA);
      });
      currentMails = merged;
    } else if (_activeCategory == "Alerts") {
      currentMails = _realAlerts.isNotEmpty ? _realAlerts : _mailData["Alerts"] ?? [];
    } else if (_activeCategory == "Security") {
      currentMails = _realSecurityAlerts.isNotEmpty ? _realSecurityAlerts : _mailData["Security"] ?? [];
    } else {
      currentMails = _mailData[_activeCategory] ?? [];
    }

    final isFormals = _activeCategory == "Formals";

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("STARLIGHT SECURE MAILBOX",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white60)),
              ],
            ),
          ),

          // Categories Navigation
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                _buildMailTab("Institutional", Icons.account_balance_rounded),
                _buildMailTab("Formals", Icons.mark_email_unread_rounded),
                _buildMailTab("Alerts", Icons.notifications_active_rounded),
                _buildMailTab("Gifts", Icons.card_giftcard_rounded),
                _buildMailTab("Security", Icons.shield_rounded),
              ],
            ),
          ),

          // Mail List Area
          Expanded(
            child: (isFormals && _isLoadingFormals) || 
                   (!isFormals && _isLoadingNotices && _activeCategory == "Institutional") ||
                   (_activeCategory == "Gifts" && _isLoadingGifts) ||
                   (_activeCategory == "Alerts" && _isLoadingAlerts) ||
                   (_activeCategory == "Security" && _isLoadingSecurity)
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : currentMails.isEmpty
                    ? Center(
                        child: Text(
                          "No ${_activeCategory.toLowerCase()} messages",
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: currentMails.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15, top: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_activeCategory.toUpperCase(),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                                  if (isFormals)
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: _myUserId));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("My User ID copied to clipboard")));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                        child: Text("My ID: $_myUserId 📋", style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                          final mail = currentMails[index - 1];
                          if (_activeCategory == "Gifts") {
                            return _buildGiftItemCard(mail);
                          }
                          return isFormals ? _buildFormalEmailCard(mail) : _buildMailItem(mail);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isFormals
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF38BDF8),
              icon: const Icon(Icons.edit_note, color: Colors.black87),
              label: const Text("Compose", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              onPressed: () => _openComposeDialog(),
            )
          : (_activeCategory == "Gifts"
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.purpleAccent,
                  icon: const Icon(Icons.card_giftcard, color: Colors.white),
                  label: const Text("Request Gift", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _openRequestGiftFromMailbox(),
                )
              : null),
    );
  }

  Widget _buildMailTab(String label, IconData icon) {
    bool isActive = _activeCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() => _activeCategory = label);
        if (label == "Formals") {
          _loadFormalEmails();
        } else if (label == "Gifts") {
          _loadGifts();
        } else if (label == "Alerts") {
          _loadRealAlerts();
        } else if (label == "Security") {
          _loadRealSecurityAlerts();
        }
      },
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: isActive ? Border.all(color: const Color(0xFF334155)) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF38BDF8) : Colors.white38, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftItemCard(dynamic gift) {
    final bool isReceived = gift['isGiftReceived'] == true;
    final bool isRequest = gift['status'] == 'pending_request';
    final bool isAlreadyFulfilled = gift['is_fulfilled'] == true;
    final String title = gift['title'] ?? 'Gift Pack';
    final String type = (gift['type'] ?? 'currency').toString().toUpperCase();
    final String dateString = gift['activated_at'] ?? '';
    
    String formattedTime = 'Just now';
    if (dateString.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateString);
        formattedTime = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedTime = dateString;
      }
    }

    // Determine card colors based on action type
    Color accentColor = isReceived ? Colors.purpleAccent : Colors.tealAccent;
    if (isRequest) {
      accentColor = isReceived ? Colors.amber : Colors.cyanAccent;
    }
    if (isAlreadyFulfilled) {
      accentColor = Colors.white24;
    }

    Widget card = Opacity(
      opacity: isAlreadyFulfilled ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accentColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isRequest 
                          ? (isReceived ? Icons.mark_email_unread_rounded : Icons.outbox_rounded)
                          : (isReceived ? Icons.card_giftcard_rounded : Icons.check_circle_outline_rounded),
                      color: accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRequest 
                          ? (isReceived ? "RECEIVED REQUEST" : "SENT REQUEST")
                          : (isReceived ? "RECEIVED GIFT" : "SENT GIFT"),
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                    ),
                  ],
                ),
                Text(
                  formattedTime,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              isReceived 
                  ? "From: ${gift['sender_name'] ?? 'Anonymous'}" 
                  : "To: ${gift['recipient_name'] ?? 'User'} (${gift['recipient_email'] ?? 'No email'})",
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Type: $type",
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isRequest && isReceived)
                  Row(
                    children: [
                      Text(
                        isAlreadyFulfilled ? "FULFILLED 🗸" : "Tap to Fulfill ", 
                        style: TextStyle(
                          color: isAlreadyFulfilled ? Colors.white30 : Colors.amber, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isAlreadyFulfilled)
                        const Icon(Icons.arrow_forward_ios, size: 8, color: Colors.amber),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isRequest) {
      return GestureDetector(
        onTap: () {
          // Deep-link to open formal email details
          _openEmailDetails(Map<String, dynamic>.from(gift));
        },
        child: card,
      );
    }
    return card;
  }

  Widget _buildMailItem(dynamic mail) {
    final isReal = mail is Map<String, dynamic>;
    final sender = isReal
        ? (mail['sender'] ?? mail['created_by'] ?? 'Institution').toString()
        : mail['sender']!;
    final title = isReal
        ? (mail['title'] ?? mail['subject'] ?? 'Notice').toString()
        : mail['title']!;
    final desc = isReal
        ? (mail['desc'] ?? mail['description'] ?? mail['content'] ?? 'No description').toString()
        : mail['desc']!;
    final time = isReal
        ? (mail['created_at'] ?? mail['time'] ?? 'Just now').toString()
        : mail['time']!;
    final isSigned = isReal && mail['is_signed'] == true;
    final signedByName = isReal ? (mail['signed_by_name'] ?? '').toString() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isSigned ? const Color(0xFF22C55E).withValues(alpha: 0.3) : const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(sender, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800, fontSize: 11)),
                  if (isSigned) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: Color(0xFF22C55E), size: 10),
                           const SizedBox(width: 3),
                          Text(
                            signedByName.isNotEmpty ? signedByName.toUpperCase() : "SIGNED",
                            style: const TextStyle(color: Color(0xFF22C55E), fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(_formatDate(time), style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFormalEmailCard(Map<String, dynamic> mail) {
    final sender = mail['sender_name'] ?? 'Formal sender';
    final title = mail['title'] ?? 'Subject';
    final body = mail['body'] ?? '';
    final time = mail['created_at'] ?? '';
    final hasPassword = mail['has_password'] == true;
    final oneTimeSeen = mail['one_time_seen'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: oneTimeSeen ? Colors.orange.withOpacity(0.3) : const Color(0xFF334155)),
      ),
      child: InkWell(
        onTap: () => _openEmailDetails(mail),
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sender, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800, fontSize: 11)),
                Row(
                  children: [
                    if (oneTimeSeen) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Text("VIEW ONCE", style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (hasPassword) ...[
                      const Icon(Icons.lock_rounded, color: Colors.orange, size: 12),
                      const SizedBox(width: 8),
                    ],
                    Text(_formatDate(time), style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _openEmailDetails(Map<String, dynamic> mail) {
    showDialog(
      context: context,
      builder: (ctx) => _FormalEmailDetailsDialog(
        mail: mail,
        onClose: () {
          if (mail['one_time_seen'] == true) {
            _loadFormalEmails();
          }
        },
      ),
    );
  }

  void _openComposeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ComposeEmailDialog(onSent: () => _loadFormalEmails()),
    );
  }

  Future<void> _openRequestGiftFromMailbox() async {
    // 1. Fetch available premium bundles from local SQLite cache
    List<Map<String, dynamic>> bundles = [];
    try {
      final db = await StarlightVault.instance.database;
      bundles = await db.query('shop_bundles');
    } catch (e) {
      debugPrint('Mailbox: failed to load bundles from SQLite - $e');
    }

    if (bundles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No shop bundles cached. Please open the Shop once to synchronize bundles!"), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final TextEditingController gifterCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedBundleId = bundles.first['id'];

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('REQUEST A GIFT', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select a bundle and enter the Gifter\'s identifier (User ID, Email, Public ID, or Name) to ask them to gift it to you.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 16),
                
                // Dropdown selector for Shop Bundles
                DropdownButtonFormField<String>(
                  value: selectedBundleId,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Select Bundle',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  items: bundles.map((b) => DropdownMenuItem<String>(
                    value: b['id'] as String,
                    child: Text(
                      "${b['title']} (${b['currency']} ${b['price'].toInt()})",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedBundleId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: gifterCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Gifter Identifier',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Gifter identifier is required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Send Request', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || selectedBundleId == null) return;

    final selectedBundle = bundles.firstWhere((b) => b['id'] == selectedBundleId);
    final gifter = gifterCtrl.text.trim();
    if (gifter.isEmpty) return;

    try {
      await ApiService.post('/mailbox/send', {
        'recipient_id': gifter,
        'title': '🎁 GIFT REQUEST: ${selectedBundle['title']}',
        'body': 'Hi! I would love to have the "${selectedBundle['title']}" premium pack as a gift from you if possible. You can fulfill this request directly from this message by clicking Fulfill!',
        'attachments': ['gift_request:${selectedBundle['id']}'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gift request sent successfully to $gifter!'),
            backgroundColor: Colors.purpleAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      // Reload gifts list to reflect sent requests
      _loadGifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }
}

class _ComposeEmailDialog extends StatefulWidget {
  final VoidCallback onSent;

  const _ComposeEmailDialog({required this.onSent});

  @override
  State<_ComposeEmailDialog> createState() => _ComposeEmailDialogState();
}

class _ComposeEmailDialogState extends State<_ComposeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _encryptEntireMessage = false;
  bool _oneTimeSeen = false;
  bool _submitting = false;

  XFile? _selectedImage;
  PlatformFile? _selectedFile;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedFile = null; // clear file
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single;
          _selectedImage = null; // clear image
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      // 🚀 Transform local file attachments to Base64
      final attachments = <String>[];
      if (_selectedImage != null) {
        final bytes = await File(_selectedImage!.path).readAsBytes();
        final base64Data = base64Encode(bytes);
        attachments.add("data:image/png;base64,$base64Data");
      } else if (_selectedFile != null && _selectedFile!.path != null) {
        final bytes = await File(_selectedFile!.path!).readAsBytes();
        final base64Data = base64Encode(bytes);
        attachments.add("data:application/pdf;base64,$base64Data");
      }

      final bodyText = _bodyCtrl.text.trim();
      final passwordText = _passwordCtrl.text.trim();

      // 🔐 Entire Encryption Logic
      final finalBody = _encryptEntireMessage ? "[LOCKED: Enter password to decrypt]" : bodyText;
      final finalEncryptedBody = _encryptEntireMessage ? bodyText : "";

      await ApiService.post('/mailbox/send', {
        'recipient_id': _recipientCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'body': finalBody,
        'attachments': attachments,
        'encrypted_body': finalEncryptedBody,
        'password': passwordText,
        'one_time_seen': _oneTimeSeen,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formal Email dispatched successfully!")));
        widget.onSent();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dispatch failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("COMPOSE SECURE FORMAL EMAIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _recipientCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Recipient User ID",
                  labelStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Recipient ID is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: "Subject / Title",
                  labelStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Subject is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bodyCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: _encryptEntireMessage ? "Confidential Encrypted Body" : "Message Body",
                  labelStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  isDense: true,
                ),
                maxLines: 3,
                validator: (val) => val == null || val.trim().isEmpty ? "Message content is required" : null,
              ),
              const SizedBox(height: 16),

              // 📎 ATTACHMENTS PICKING PANEL
              const Text("ATTACHMENTS FROM DEVICE:", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.photo, size: 14),
                      label: const Text("Image", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text("Document", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _pickDocument,
                    ),
                  ),
                ],
              ),
              if (_selectedImage != null || _selectedFile != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(_selectedImage != null ? Icons.image : Icons.picture_as_pdf, color: _selectedImage != null ? Colors.green : Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedImage != null ? _selectedImage!.name : _selectedFile!.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 🔐 ENCRYPTION SWITCH & CONFIG
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.orange,
                title: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.orange, size: 14),
                    SizedBox(width: 6),
                    Text("Encrypt Entire Message", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                subtitle: const Text("Requires recipient to input a master password to read.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                value: _encryptEntireMessage,
                onChanged: (val) => setState(() => _encryptEntireMessage = val),
              ),
              if (_encryptEntireMessage) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Message Decryption Password",
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    isDense: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Password is required for encryption";
                    }
                    if (val.trim().length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    if (val.trim().length > 100) {
                      return "Password cannot exceed 100 characters";
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),

              // One-Time Seen Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.orange,
                title: const Text("One-Time Seen (Self-Destruct)", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text("The recipient can only open and read this message once.", style: TextStyle(color: Colors.white38, fontSize: 9)),
                value: _oneTimeSeen,
                onChanged: (val) => setState(() => _oneTimeSeen = val),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                    onPressed: _submitting ? null : _send,
                    child: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Dispatch", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormalEmailDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> mail;
  final VoidCallback onClose;

  const _FormalEmailDetailsDialog({required this.mail, required this.onClose});

  @override
  State<_FormalEmailDetailsDialog> createState() => _FormalEmailDetailsDialogState();
}

class _FormalEmailDetailsDialogState extends State<_FormalEmailDetailsDialog> {
  final _passCtrl = TextEditingController();
  
  String? _decryptedBody;
  List<dynamic>? _decryptedAttachments;
  bool _unlocking = false;
  bool _viewOnceTriggered = false;
  bool _fulfilling = false;

  @override
  void initState() {
    super.initState();
    _triggerViewOnceIfApplicable();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _fulfillGift(String productId, String recipientId, String title) async {
    setState(() => _fulfilling = true);
    try {
      await ApiService.post('/shop/payment/initiate', {
        'product_id': productId,
        'amount': 0.0,
        'recipient_id': recipientId,
        'payment_method': 'google_pay',
        'request_id': widget.mail['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fulfillment of $title was successful!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fulfillment failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _fulfilling = false);
    }
  }

  Future<void> _triggerViewOnceIfApplicable() async {
    final hasPassword = widget.mail['has_password'] == true;
    if (widget.mail['one_time_seen'] == true && widget.mail['is_viewed'] == false && !_viewOnceTriggered && !hasPassword) {
      _viewOnceTriggered = true;
      try {
        await ApiService.post('/mailbox/${widget.mail['id']}/view', {});
      } catch (_) {}
    }
  }

  Future<void> _unlock() async {
    final pass = _passCtrl.text.trim();
    if (pass.isEmpty) return;

    setState(() => _unlocking = true);
    try {
      final res = await ApiService.post('/mailbox/${widget.mail['id']}/unlock', {'password': pass});
      setState(() {
        _decryptedBody = res['decrypted_body'];
        if (res['decrypted_attachments'] != null) {
          try {
            _decryptedAttachments = jsonDecode(res['decrypted_attachments'].toString());
          } catch (_) {
            if (res['decrypted_attachments'] is List) {
              _decryptedAttachments = res['decrypted_attachments'];
            }
          }
        }
        _unlocking = false;
      });
    } catch (e) {
      setState(() => _unlocking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Decryption failed. Invalid password.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mail = widget.mail;
    final sender = mail['sender_name'] ?? 'Formal Sender';
    final title = mail['title'] ?? 'Subject';
    final body = mail['body'] ?? '';
    final hasPassword = mail['has_password'] == true;
    final oneTimeSeen = mail['one_time_seen'] == true;
    
    // Parse attachments
    List<dynamic> attachments = [];
    if (_decryptedAttachments != null) {
      attachments = _decryptedAttachments!;
    } else {
      try {
        if (mail['attachments'] != null) {
          attachments = jsonDecode(mail['attachments'].toString());
        }
      } catch (_) {}
    }

    final String attachmentsString = (mail['attachments'] ?? '').toString();
    final bool isGiftRequest = attachmentsString.contains('gift_request:');
    String requestedProductId = '';
    if (isGiftRequest) {
      try {
        final matches = RegExp(r'gift_request:([a-zA-Z0-9_-]+)').firstMatch(attachmentsString);
        if (matches != null && matches.groupCount >= 1) {
          requestedProductId = matches.group(1) ?? '';
        }
      } catch (_) {}
    }

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sender.toUpperCase(), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                if (oneTimeSeen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text("VIEW ONCE", style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(color: Colors.white12, height: 24),
            
            // Decrypted Body vs Locked Indicator
            _decryptedBody != null
                ? Text(_decryptedBody!, style: const TextStyle(color: Colors.white70, fontSize: 13))
                : Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),

            // Attachments Section
            if (attachments.isNotEmpty) ...[
              const Text("ATTACHMENTS:", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...attachments.map((url) {
                final isImage = url.toString().endsWith(".png") || url.toString().endsWith(".jpg") || url.toString().startsWith("data:image");
                final isBase64 = url.toString().startsWith("data:");
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(isImage ? Icons.image : Icons.picture_as_pdf, color: isImage ? Colors.green : Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isBase64 ? "Secure Attachment (${isImage ? 'Image' : 'PDF'})" : url.toString().split('/').last,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (isBase64 && isImage) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(url.toString().split(',').last),
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],

            // Decryption Module
            if (hasPassword) ...[
              const Divider(color: Colors.white12, height: 24),
              if (_decryptedBody != null) ...[
                const Row(
                  children: [
                    Icon(Icons.lock_open_rounded, color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text("DECRYPTED SECURE TEXT:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text("Success: Entire email message is decrypted.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.orange, size: 14),
                    SizedBox(width: 6),
                    Text("CONFIDENTIAL PORTION IS ENCRYPTED", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: "Enter decryption password...",
                          hintStyle: TextStyle(color: Colors.white24),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: _unlocking
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.vpn_key, color: Colors.orange, size: 18),
                      onPressed: _unlock,
                    ),
                  ],
                ),
              ],
            ],

            if (isGiftRequest && requestedProductId.isNotEmpty) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: (mail['is_fulfilled'] == true || _fulfilling)
                    ? null
                    : () => _fulfillGift(requestedProductId, mail['sender_id'] ?? '', title),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: mail['is_fulfilled'] == true
                        ? const LinearGradient(colors: [Colors.grey, Colors.blueGrey])
                        : const LinearGradient(colors: [Colors.green, Colors.greenAccent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _fulfilling
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(mail['is_fulfilled'] == true ? Icons.check_circle : Icons.card_giftcard, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                mail['is_fulfilled'] == true ? "FULFILLED 🗸" : "🎁 FULFILL GIFT REQUEST",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  widget.onClose();
                  Navigator.pop(context);
                  if (oneTimeSeen && widget.mail['is_viewed'] == false) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Confidential View-Once email self-destructed.")));
                  }
                },
                child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
