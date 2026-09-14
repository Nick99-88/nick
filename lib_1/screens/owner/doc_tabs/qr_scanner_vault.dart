import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Add this to pubspec.yaml
import 'package:qr_flutter/qr_flutter.dart'; // Add this to pubspec.yaml

class QrScannerVault extends StatefulWidget {
  const QrScannerVault({super.key});

  @override
  State<QrScannerVault> createState() => _QrScannerVaultState();
}

class _QrScannerVaultState extends State<QrScannerVault> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // --- STATE ---
  String? generatedQrData;
  String selectedPaper = "Mid-Term Physics 2026";
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showSignBox(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("QR SCANNER VAULT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          tabs: const [
            Tab(text: "CREATE QR KEY", icon: Icon(Icons.qr_code, size: 20)),
            Tab(text: "SCAN SOLUTION", icon: Icon(Icons.qr_code_scanner, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreationTab(),
          _buildScannerTab(),
        ],
      ),
    );
  }

  // --- TAB 1: CREATION (TEACHER CONSOLE) ---
  Widget _buildCreationTab() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SELECT TARGET PAPER", style: TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: selectedPaper,
                  dropdownColor: const Color(0xFF1A1A2E),
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  items: ["Mid-Term Physics 2026", "Final Math Exam", "Chemistry Quiz B"]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => selectedPaper = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (generatedQrData != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: QrImageView(
                data: generatedQrData!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text("QR KEY GENERATED FOR VAULT", style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              setState(() => generatedQrData = "starlight_vault_paper_id_789");
              _showSignBox("Solution Linked to QR Code", true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("GENERATE & ATTACH QR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: SCANNER (USER CONSOLE) ---
  Widget _buildScannerTab() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.cyanAccent, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _processScannedResult(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, color: Colors.cyanAccent, size: 40),
                const SizedBox(height: 10),
                const Text("ALIGN QR CODE WITHIN FRAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                Text("App will auto-hydrate the solution from the Starlight Vault", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _processScannedResult(String data) {
    if (isScanning) return;
    setState(() => isScanning = true);
    
    _showSignBox("Paper Detected: $data", true);
    
    // Future logic: Navigate to the Paper Generator Hydration page with this ID
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => isScanning = false);
    });
  }
}