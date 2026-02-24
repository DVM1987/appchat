import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/deep_link_service.dart';

/// QR Code Scanner screen for scanning group invite QR codes.
/// Scans for `appchat://join?token=XXX` links and auto-joins the group.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;

      AppConfig.log('[QR] Scanned: $value');

      final uri = Uri.tryParse(value);
      if (uri != null && uri.scheme == 'appchat') {
        setState(() => _hasScanned = true);
        _controller.stop();

        Navigator.pop(context);
        DeepLinkService.handleDeepLink(context, uri);
        return;
      }

      _showInvalidQr();
    }
  }

  void _showInvalidQr() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'QR code không hợp lệ. Vui lòng quét mã mời nhóm MChat.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Overlay
          _buildScanOverlay(),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Quét mã QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleTorch,
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: _torchOn ? Colors.amber : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Đưa camera vào mã QR mời nhóm',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () => _controller.switchCamera(),
                      icon: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cameraswitch,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final left = (constraints.maxWidth - scanAreaSize) / 2;
        final top = (constraints.maxHeight - scanAreaSize) / 2 - 40;

        return Stack(
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black54,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Corners
            Positioned(left: left - 2, top: top - 2, child: _corner(tl: true)),
            Positioned(right: left - 2, top: top - 2, child: _corner(tr: true)),
            Positioned(
              left: left - 2,
              bottom: constraints.maxHeight - top - scanAreaSize - 2,
              child: _corner(bl: true),
            ),
            Positioned(
              right: left - 2,
              bottom: constraints.maxHeight - top - scanAreaSize - 2,
              child: _corner(br: true),
            ),
          ],
        );
      },
    );
  }

  Widget _corner({
    bool tl = false,
    bool tr = false,
    bool bl = false,
    bool br = false,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          top: (tl || tr)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          bottom: (bl || br)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          left: (tl || bl)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          right: (tr || br)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}
