import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/services/api_service.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_content_display_screen.dart';
import 'package:image_picker/image_picker.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with WidgetsBindingObserver {
  // Stable controller setup for Android device compatibility
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool isScanning = true;
  String? scannedResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startCamera();
  }

  void _startCamera() {
    try {
      controller.start();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void _handleQRScanned(String qrData) {
    if (mounted) {
      debugPrint('🏛️ QR Scanner: Scanned - $qrData');
      _fetchContentFromQR(qrData);
    }
  }

  Future<void> _fetchContentFromQR(String qrData) async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.post('/api/link-search', {
        'query': qrData,
      });

      print('🏛️ QR Scanner: Response - $result');
      
      if (result['success'] == true && result['content'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content loaded successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRContentDisplayScreen(
              link: qrData,
              data: result,
            ),
          ),
        );
      } else {
        _processResult(qrData, false, result['message'] ?? 'Content not found');
      }
    } catch (e) {
      _processResult(qrData, false, 'Error loading content: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processResult(String data, bool isSuccess, [String? message]) {
    // UI Feedback using sign boxes instead of alerts
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? (isSuccess ? 'QR Code Processed Successfully' : 'QR Code Scanned'),
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scanFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      setState(() => _isLoading = true);
      
      final BarcodeCapture? capture = await controller.analyzeImage(image.path) as BarcodeCapture?;
      
      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          _handleQRScanned(barcode.rawValue!);
          return;
        }
      }
      
      _processResult('', false, 'No QR code found in image');
    } catch (e) {
      _processResult('', false, 'Error scanning image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), //[cite: 2]
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'QR Scanner',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          // Torch toggle using stable torchState listenable
          ValueListenableBuilder(
            valueListenable: controller.torchState,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: StarlightTheme.primaryBlue,
                ),
                onPressed: () => controller.toggleTorch(),
              );
            },
          ),
          // Camera switch using stable cameraFacingState listenable
          ValueListenableBuilder(
            valueListenable: controller.cameraFacingState,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state == CameraFacing.front ? Icons.camera_front : Icons.camera_rear,
                  color: StarlightTheme.primaryBlue,
                ),
                onPressed: () => controller.switchCamera(),
              );
            },
          ),
          // Gallery scan button
          IconButton(
            icon: const Icon(Icons.photo_library, color: StarlightTheme.primaryBlue),
            onPressed: _isLoading ? null : _scanFromGallery,
            tooltip: 'Scan from gallery',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null && isScanning) {
                        setState(() {
                          scannedResult = barcode.rawValue;
                          isScanning = false;
                        });
                        _handleQRScanned(barcode.rawValue!);
                        controller.stop();
                        break;
                      }
                    }
                  },
                ),
                // Optimized interactive overlay for all screen sizes
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: StarlightTheme.primaryBlue,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StarlightTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: StarlightTheme.primaryBlue),
                    ),
                    child: Row(
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: StarlightTheme.primaryBlue,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            'Loading content...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: StarlightTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (scannedResult != null) ...[
                  // Green sign box for the result
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'QR Code Scanned',
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                Text(
                  'Position QR code within the frame to scan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                if (!_isLoading)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          scannedResult = null;
                          isScanning = true;
                        });
                        controller.start();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Scan Again',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}