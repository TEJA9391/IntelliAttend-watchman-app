import 'dart:math';
import 'package:flutter/material.dart';

/// A custom vector icon widget representing the stylized QR scanner logo
/// with 4 corner viewfinder brackets, 3 hollow finder pattern squares,
/// and a QR dot matrix pattern.
class QrScanLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const QrScanLogo({
    Key? key,
    this.size = 26.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color iconColor = color ?? Theme.of(context).colorScheme.primary;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(size, size),
        painter: QrScanLogoPainter(color: iconColor),
      ),
    );
  }
}

class QrScanLogoPainter extends CustomPainter {
  final Color color;

  const QrScanLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = min(size.width, size.height);
    if (s <= 0) return;

    // Line thickness & metrics proportionally scaled to size
    final double bracketThick = s * 0.095;
    final double armLength = s * 0.22;
    final double cornerR = s * 0.06;
    final double halfThick = bracketThick / 2;

    final Paint bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = bracketThick
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // ── 1. Four Corner Viewfinder Brackets ──
    // Top-Left
    final Path tlPath = Path()
      ..moveTo(halfThick, armLength)
      ..lineTo(halfThick, halfThick + cornerR)
      ..quadraticBezierTo(halfThick, halfThick, halfThick + cornerR, halfThick)
      ..lineTo(armLength, halfThick);
    canvas.drawPath(tlPath, bracketPaint);

    // Top-Right
    final Path trPath = Path()
      ..moveTo(s - armLength, halfThick)
      ..lineTo(s - halfThick - cornerR, halfThick)
      ..quadraticBezierTo(s - halfThick, halfThick, s - halfThick, halfThick + cornerR)
      ..lineTo(s - halfThick, armLength);
    canvas.drawPath(trPath, bracketPaint);

    // Bottom-Left
    final Path blPath = Path()
      ..moveTo(halfThick, s - armLength)
      ..lineTo(halfThick, s - halfThick - cornerR)
      ..quadraticBezierTo(halfThick, s - halfThick, halfThick + cornerR, s - halfThick)
      ..lineTo(armLength, s - halfThick);
    canvas.drawPath(blPath, bracketPaint);

    // Bottom-Right
    final Path brPath = Path()
      ..moveTo(s - armLength, s - halfThick)
      ..lineTo(s - halfThick - cornerR, s - halfThick)
      ..quadraticBezierTo(s - halfThick, s - halfThick, s - halfThick, s - halfThick - cornerR)
      ..lineTo(s - halfThick, s - armLength);
    canvas.drawPath(brPath, bracketPaint);

    // ── 2. Three Finder Squares (Top-Left, Top-Right, Bottom-Left) ──
    final double pos1 = s * 0.17;
    final double pos2 = s * 0.55;
    final double finderSize = s * 0.28;
    final double finderThick = s * 0.078;
    final double finderRadius = s * 0.055;

    final Paint finderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = finderThick
      ..isAntiAlias = true;

    for (final Offset pos in [
      Offset(pos1, pos1), // Top-Left
      Offset(pos2, pos1), // Top-Right
      Offset(pos1, pos2), // Bottom-Left
    ]) {
      final Rect outerRect = Rect.fromLTWH(
        pos.dx + finderThick / 2,
        pos.dy + finderThick / 2,
        finderSize - finderThick,
        finderSize - finderThick,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(outerRect, Radius.circular(finderRadius)),
        finderPaint,
      );
    }

    // ── 3. Bottom-Right QR Data Modules (Dots Matrix) ──
    final double dotSize = finderSize / 3.4;
    final double dotGap = (finderSize - (3 * dotSize)) / 2;
    final double dotRadius = dotSize * 0.24;

    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const List<List<int>> pattern = [
      [1, 0, 1],
      [0, 1, 1],
      [1, 1, 1],
    ];

    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (pattern[r][c] == 1) {
          final double dx = pos2 + c * (dotSize + dotGap);
          final double dy = pos2 + r * (dotSize + dotGap);
          final Rect dotRect = Rect.fromLTWH(dx, dy, dotSize, dotSize);
          canvas.drawRRect(
            RRect.fromRectAndRadius(dotRect, Radius.circular(dotRadius)),
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrScanLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
