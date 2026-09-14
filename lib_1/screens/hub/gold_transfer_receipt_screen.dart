import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GoldTransferReceiptScreen extends StatefulWidget {
  final String transactionId;
  final String senderName;
  final String senderPublicId;
  final String recipientName;
  final String recipientPublicId;
  final int goldAmount;
  final String timestamp;

  const GoldTransferReceiptScreen({
    super.key,
    required this.transactionId,
    required this.senderName,
    required this.senderPublicId,
    required this.recipientName,
    required this.recipientPublicId,
    required this.goldAmount,
    required this.timestamp,
  });

  @override
  State<GoldTransferReceiptScreen> createState() => _GoldTransferReceiptScreenState();
}

class _GoldTransferReceiptScreenState extends State<GoldTransferReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();

  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/starlight_receipt_${widget.transactionId}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: 'Starlight Gold Transfer Receipt');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1A),
      appBar: AppBar(
        title: const Text('Transfer Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _shareReceipt(context),
            icon: const Icon(Icons.share_rounded, color: Colors.amber),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A3E), Color(0xFF0B0E1A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.amber.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFB8860B)],
                          stops: [0.3, 0.7, 1.0],
                        ),
                        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.black87, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Transfer Successful',
                      style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\u{1F947} ${widget.goldAmount} Gold',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _receiptRow('FROM', '${widget.senderName}  (${widget.senderPublicId})', Icons.arrow_upward_rounded, Colors.redAccent),
                          const SizedBox(height: 16),
                          _receiptRow('TO', '${widget.recipientName}  (${widget.recipientPublicId})', Icons.arrow_downward_rounded, Colors.green),
                          const Divider(color: Colors.white12, height: 32),
                          _receiptRow('TX ID', widget.transactionId, Icons.receipt_long_rounded, Colors.amber),
                          const SizedBox(height: 12),
                          _receiptRow('DATE', _formatDate(widget.timestamp), Icons.schedule_rounded, Colors.white54),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'STARLIGHT',
                            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _shareReceipt(context),
                icon: const Icon(Icons.screenshot_rounded, size: 20),
                label: const Text('Screenshot & Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
