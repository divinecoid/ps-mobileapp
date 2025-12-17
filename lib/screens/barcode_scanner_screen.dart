import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScanType {
  barcode,
  qrCode,
}

class BarcodeScannerScreen extends StatefulWidget {
  final String title;
  final String instruction;
  final ScanType scanType;
  final Function(String) onScanResult;

  const BarcodeScannerScreen({
    super.key,
    required this.title,
    required this.instruction,
    required this.scanType,
    required this.onScanResult,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController controller;
  bool isScanning = true;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
      controller = MobileScannerController(
        cameraResolution: const Size(1920, 1080),
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: false,
        formats: const [
          BarcodeFormat.code128,
          BarcodeFormat.pdf417,
        ],
    );
    
    // Start scanner setelah widget siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });
  }

  Future<void> _startScanner() async {
    try {
      await controller.start();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('Error starting scanner: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Tidak dapat mengakses kamera. Pastikan izin kamera sudah diberikan.';
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.stop();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      // Coba semua barcode yang terdeteksi, ambil yang paling panjang/valid
      Barcode? bestBarcode;
      String? bestCode;
      
      for (final barcode in barcodes) {
        final code = barcode.rawValue;
        if (code != null && code.isNotEmpty) {
          // Prioritaskan barcode yang lebih panjang (untuk barcode panjang)
          if (bestCode == null || code.length > bestCode.length) {
            bestBarcode = barcode;
            bestCode = code;
          }
        }
      }

      if (bestCode != null && bestBarcode != null) {
        // Debug: print barcode yang terdeteksi
        print('Scanner detected barcode: $bestCode');
        print('Barcode length: ${bestCode.length}');
        print('Barcode type: ${bestBarcode.type}');
        print('Barcode format: ${bestBarcode.format}');
        
        // Validasi minimal panjang untuk barcode kita (LPK-MERAH-L-RAK01-001-PCS = ~30 chars)
        if (bestCode.length < 10) {
          print('Barcode terlalu pendek, mungkin tidak valid. Panjang: ${bestCode.length}');
          return; // Skip jika terlalu pendek
        }
        
        setState(() {
          isScanning = false;
        });

        // Vibrate feedback
        // HapticFeedback.lightImpact();

        // Show result and return
        widget.onScanResult(bestCode);
        Navigator.pop(context, bestCode);
      } else {
        print('Barcode detected but code is null or empty');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Auto-focus button untuk membantu scan barcode blur
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: () {
              // Restart scanner untuk trigger auto-focus
              controller.stop();
              Future.delayed(const Duration(milliseconds: 100), () {
                controller.start();
              });
            },
            tooltip: 'Refresh Scanner',
          ),
          IconButton(
            icon: const Icon(Icons.flash_off, color: Colors.white),
            onPressed: () => controller.toggleTorch(),
            tooltip: 'Flash',
          ),
          IconButton(
            icon: const Icon(Icons.camera_rear, color: Colors.white),
            onPressed: () => controller.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _startScanner();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                // Scanner
                _isInitialized
                    ? MobileScanner(
                        controller: controller,
                        onDetect: _onDetect,
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.white,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Memuat kamera...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                // Overlay dengan instruksi (hanya tampil jika sudah initialized)
                if (_isInitialized)
                  Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: Column(
              children: [
                // Top instruction
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          widget.scanType == ScanType.barcode
                              ? Icons.qr_code_scanner
                              : Icons.qr_code,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.instruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Center scanning area - Lebih besar untuk barcode panjang
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: widget.scanType == ScanType.qrCode ? 300 : 150, // Lebih tinggi untuk barcode panjang
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Corner indicators
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 3),
                              left: BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white, width: 3),
                              right: BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white, width: 3),
                              left: BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white, width: 3),
                              right: BorderSide(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Scan type indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.scanType == ScanType.qrCode
                        ? const Color(0xFF3B82F6).withOpacity(0.2)
                        : const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.scanType == ScanType.qrCode
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF10B981),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.scanType == ScanType.qrCode
                            ? Icons.qr_code
                            : Icons.qr_code_scanner,
                        color: widget.scanType == ScanType.qrCode
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF10B981),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.scanType == ScanType.qrCode
                            ? 'QR CODE SCANNER'
                            : 'BARCODE SCANNER',
                        style: TextStyle(
                          color: widget.scanType == ScanType.qrCode
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom instruction
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.scanType == ScanType.barcode
                              ? 'Arahkan kamera ke barcode produk'
                              : 'Arahkan kamera ke QR code lokasi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.scanType == ScanType.barcode
                              ? 'Scanner akan mendeteksi barcode secara otomatis'
                              : 'Scanner akan mendeteksi QR code secara otomatis',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
