import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';
import '../../../services/institution/notice_service.dart';

class NoticeArchitect extends StatefulWidget {
  const NoticeArchitect({super.key});

  @override
  State<NoticeArchitect> createState() => _NoticeArchitectState();
}

class _NoticeArchitectState extends State<NoticeArchitect> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final NoticeService _noticeService = NoticeService();

  String currentLang = 'en';
  String title = "";
  String desc = "";
  String instName = "STARLIGHT INSTITUTION";
  bool isSigned = false;
  String signedByName = "";
  Uint8List? _signatureImageBytes;
  String? noticeId;
  bool _isSigning = false;

  final Map<String, Map<String, String>> languages = {
    'en': {
      'header': "Notice Architect",
      'lblTitle': "Notice Title",
      'lblMsg': "Detailed Message",
      'lblPre': "Live Preview",
      'phTitle': "Enter Title...",
      'phMsg': "Type message...",
      'btn': "BROADCAST NOTICE",
      'signed': "SIGNED",
      'auth': "SIGN NOTICE",
      'dir': "ltr"
    },
    'ur': {
      'header': "نوٹس آرکیٹیکٹ",
      'lblTitle': "نوٹس کا عنوان",
      'lblMsg': "تفصیلی پیغام",
      'lblPre': "لائیو پریویو",
      'phTitle': "عنوان درج کریں...",
      'phMsg': "پیغام لکھیں...",
      'btn': "نوٹس جاری کریں",
      'signed': "دستخط شدہ",
      'auth': "دستخط کریں",
      'dir': "rtl"
    }
  };

  void _showMsg(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signNotice() async {
    if (_isSigning) return;

    bool authenticated = false;
    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: "Authenticate to sign this notice",
      );
    } catch (e) {
      _showMsg("Authentication not available on this device", false);
      return;
    }

    if (!authenticated) {
      _showMsg("Authentication failed", false);
      return;
    }

    if (title.trim().isEmpty || desc.trim().isEmpty) {
      _showMsg("Please fill in title and message first", false);
      return;
    }

    setState(() => _isSigning = true);

    try {
      // Broadcast notice first
      final token = await StarlightStorage.getUserToken();
      final broadcastRes = await http.post(
        Uri.parse("${StarlightConstants.apiBaseUrl}/document/notice/broadcast"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "title": title.trim(),
          "description": desc.trim(),
          "language": currentLang,
        }),
      );

      if (broadcastRes.statusCode != 200) {
        _showMsg("Failed to create notice", false);
        setState(() => _isSigning = false);
        return;
      }

      final broadcastData = jsonDecode(broadcastRes.body);
      final newNoticeId = broadcastData['notice_id'];

      // Sign the notice on the server
      final sigResult = await _noticeService.signNotice(newNoticeId);

      if (mounted) {
        Uint8List? imgBytes;
        final sigImg = sigResult['signature_image'] as String?;
        if (sigImg != null && sigImg.startsWith('data:image/png;base64,')) {
          imgBytes = base64Decode(sigImg.split(',').last);
        }
        setState(() {
          isSigned = true;
          noticeId = newNoticeId;
          signedByName = sigResult['signed_by_name'] ?? '';
          _signatureImageBytes = imgBytes;
          _isSigning = false;
        });
        _showMsg("Notice signed successfully", true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSigning = false);
        _showMsg("Signing failed: ${e.toString().replaceAll("Exception: ", "")}", false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var lang = languages[currentLang] ?? languages['en']!;
    bool isRtl = lang['dir'] == 'rtl';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text(lang['header']!, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [_buildLanguageSwitcher()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInputSection(lang, isRtl),
                const SizedBox(height: 30),
                _buildLivePreview(lang, isRtl),
              ],
            ),
          ),
          _buildActionFooter(lang),
        ],
      ),
    );
  }

  Widget _buildInputSection(Map<String, String> lang, bool isRtl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(lang['lblTitle']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          TextField(
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            onChanged: (v) => setState(() => title = v),
            decoration: InputDecoration(hintText: lang['phTitle'], border: InputBorder.none),
          ),
          const Divider(),
          Text(lang['lblMsg']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          TextField(
            maxLines: 4,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            onChanged: (v) => setState(() => desc = v),
            decoration: InputDecoration(hintText: lang['phMsg'], border: InputBorder.none),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(Map<String, String> lang, bool isRtl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
        border: const Border(top: BorderSide(color: Colors.blue, width: 8)),
      ),
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.school, color: Colors.blue),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(instName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const Text("OFFICIAL CORRESPONDENCE", style: TextStyle(fontSize: 8, color: Colors.grey, letterSpacing: 1.2)),
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          Text(title.isEmpty ? "NOTICE TITLE" : title, textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 25),
          Text(desc.isEmpty ? "Notice body text will appear here..." : desc, textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(fontSize: 13, height: 1.6)),
          const SizedBox(height: 50),
          _buildSignatureArea(lang, isRtl),
        ],
      ),
    );
  }

  Widget _buildSignatureArea(Map<String, String> lang, bool isRtl) {
    if (_isSigning) {
      return Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: 120, height: 40,
            decoration: BoxDecoration(border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          const SizedBox(height: 5),
          Container(width: 150, height: 1, color: Colors.black),
          Text("SIGNING...", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      );
    }

    if (isSigned && _signatureImageBytes != null) {
      return Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: 200,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.memory(
                _signatureImageBytes!,
                width: 200,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 12),
              const SizedBox(width: 4),
              Text("SIGNED BY: ${signedByName.toUpperCase()}", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
        ],
      );
    }

    return InkWell(
      onLongPress: _signNotice,
      child: Column(
        crossAxisAlignment: isRtl ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            width: 100, height: 40,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), border: Border.all(color: Colors.black12)),
            child: const Center(child: Icon(Icons.touch_app, size: 16, color: Colors.black26)),
          ),
          const SizedBox(height: 5),
          Container(width: 150, height: 1, color: Colors.black),
          Text("HOLD TO SIGN", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLanguageSwitcher() {
    return Row(
      children: languages.keys.map((k) => TextButton(
        onPressed: () => setState(() => currentLang = k),
        child: Text(k.toUpperCase(), style: TextStyle(fontSize: 10, color: currentLang == k ? Colors.blue : Colors.grey)),
      )).toList(),
    );
  }

  Widget _buildActionFooter(Map<String, String> lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: isSigned
            ? () {
                setState(() {
                  title = "";
                  desc = "";
                  isSigned = false;
                  signedByName = "";
                  _signatureImageBytes = null;
                  noticeId = null;
                });
                _showMsg("Notice already broadcasted and signed", true);
              }
            : title.trim().isEmpty || desc.trim().isEmpty
                ? () => _showMsg("Fill in title and message", false)
                : () => _showMsg("Long-press the signature area to sign", false),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSigned ? Colors.green : Colors.grey,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSigned) ...[
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text("SIGNED & BROADCASTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ] else
              Text(lang['btn']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
