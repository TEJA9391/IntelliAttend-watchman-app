import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? _cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
        BarcodeFormat.code93,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
        BarcodeFormat.pdf417,
      ],
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    debugPrint('📸 [SCANNER] Scanned: format=${barcode.format.name}, value="$rawValue"');
    HapticService.medium();
    _cameraController?.stop();

    if (!mounted) return;
    Navigator.pop(context, {'value': rawValue, 'format': barcode.format.name});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Square viewfinder matching user's image exactly
    final double scannerSize = size.width * 0.74;
    final double topOffset = (size.height - scannerSize) / 2.3;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Camera Feed ──
          Positioned.fill(
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_rounded, color: Colors.white38, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        "Camera access required",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Grant camera permission in settings\nto scan student & faculty cards.",
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── 2. Dark Overlay with Cutout ──
          CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(
              scannerSize: scannerSize,
              topOffset: topOffset,
              cornerRadius: 26.0,
            ),
          ),

          // ── 3. Square Viewfinder Frame with 4 Rounded Teal Corners ──
          Positioned(
            top: topOffset,
            left: (size.width - scannerSize) / 2,
            width: scannerSize,
            height: scannerSize,
            child: _buildScanFrame(scannerSize),
          ),

          // ── 4. Top Bar: Back Button, Title ("Scan QR Code"), Flashlight ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back arrow
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.centerLeft,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // Centered title exactly like image
                    Text(
                      "Scan QR Code",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),

                    // Circular Flashlight Toggle
                    ValueListenableBuilder(
                      valueListenable: _cameraController!.torchState,
                      builder: (context, state, _) {
                        final isOn = state == TorchState.on;
                        return GestureDetector(
                          onTap: () => _cameraController?.toggleTorch(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isOn
                                  ? const Color(0xFF2DD4BF).withOpacity(0.25)
                                  : Colors.white.withOpacity(0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: isOn ? const Color(0xFF2DD4BF) : Colors.white,
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 5. Processing Indicator ──
          if (_isProcessing)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2DD4BF).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2DD4BF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Verifying ID...",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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

  Widget _buildScanFrame(double size) {
    const double cornerLen = 46.0;
    const double cornerWidth = 4.0;
    const double radius = 26.0;
    const Color cornerColor = Color(0xFF2DD4BF);

    return Stack(
      children: [
        // Top Left
        Positioned(
          top: 0,
          left: 0,
          child: SizedBox(
            width: cornerLen,
            height: cornerLen,
            child: CustomPaint(
              painter: _TopLeftCornerPainter(
                color: cornerColor,
                strokeWidth: cornerWidth,
                radius: radius,
                len: cornerLen,
              ),
            ),
          ),
        ),
        // Top Right
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: cornerLen,
            height: cornerLen,
            child: CustomPaint(
              painter: _TopRightCornerPainter(
                color: cornerColor,
                strokeWidth: cornerWidth,
                radius: radius,
                len: cornerLen,
              ),
            ),
          ),
        ),
        // Bottom Left
        Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
            width: cornerLen,
            height: cornerLen,
            child: CustomPaint(
              painter: _BottomLeftCornerPainter(
                color: cornerColor,
                strokeWidth: cornerWidth,
                radius: radius,
                len: cornerLen,
              ),
            ),
          ),
        ),
        // Bottom Right
        Positioned(
          bottom: 0,
          right: 0,
          child: SizedBox(
            width: cornerLen,
            height: cornerLen,
            child: CustomPaint(
              painter: _BottomRightCornerPainter(
                color: cornerColor,
                strokeWidth: cornerWidth,
                radius: radius,
                len: cornerLen,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scannerSize;
  final double topOffset;
  final double cornerRadius;

  _ScannerOverlayPainter({
    required this.scannerSize,
    required this.topOffset,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final scanLeft = (size.width - scannerSize) / 2;
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(scanLeft, topOffset, scannerSize, scannerSize),
      Radius.circular(cornerRadius),
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => false;
}

class _TopLeftCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double len;

  _TopLeftCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.len,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, len)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(len, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopRightCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double len;

  _TopRightCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.len,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(len - radius, 0)
      ..arcToPoint(Offset(len, radius), radius: Radius.circular(radius))
      ..lineTo(len, len);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomLeftCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double len;

  _BottomLeftCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.len,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(len, len)
      ..lineTo(radius, len)
      ..arcToPoint(Offset(0, len - radius), radius: Radius.circular(radius))
      ..lineTo(0, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomRightCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double len;

  _BottomRightCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.len,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(len, 0)
      ..lineTo(len, len - radius)
      ..arcToPoint(Offset(len - radius, len), radius: Radius.circular(radius))
      ..lineTo(0, len);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
