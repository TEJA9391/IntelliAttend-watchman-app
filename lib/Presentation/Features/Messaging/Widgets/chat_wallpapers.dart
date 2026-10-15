import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The kind of paint a [ChatWallpaper] produces.
enum ChatWallpaperKind {
  /// A smooth diagonal multi-stop gradient.
  gradient,

  /// A gradient base plus a subtle repeating motif.
  pattern,
}

/// The decorative motif layered over gradient wallpapers.
enum ChatWallpaperMotif { none, circles, confetti, waves, dots }

/// A built-in premium chat wallpaper. Wallpapers are painted procedurally so
/// no asset download is required and they look sharp at any resolution.
class ChatWallpaper {
  final String id;
  final String name;
  final ChatWallpaperKind kind;
  final ChatWallpaperMotif motif;
  final List<Color> colors;

  /// Whether this wallpaper reads better under light or dark bubble themes.
  final bool prefersDark;

  const ChatWallpaper({
    required this.id,
    required this.name,
    required this.colors,
    this.kind = ChatWallpaperKind.gradient,
    this.motif = ChatWallpaperMotif.none,
    this.prefersDark = false,
  });

  static const String defaultId = 'default';

  static final List<ChatWallpaper> presets = [
    ChatWallpaper(
      id: 'aurora',
      name: 'Aurora',
      colors: [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)],
      motif: ChatWallpaperMotif.confetti,
    ),
    ChatWallpaper(
      id: 'sunset',
      name: 'Sunset',
      colors: [const Color(0xFFFF512F), const Color(0xFFF09819), const Color(0xFFFFD26F)],
      motif: ChatWallpaperMotif.waves,
    ),
    ChatWallpaper(
      id: 'ocean',
      name: 'Ocean',
      colors: [const Color(0xFF000428), const Color(0xFF004E92)],
      motif: ChatWallpaperMotif.waves,
    ),
    ChatWallpaper(
      id: 'royal',
      name: 'Royal',
      colors: [const Color(0xFF5B247A), const Color(0xFF1BCEDF)],
      motif: ChatWallpaperMotif.circles,
    ),
    ChatWallpaper(
      id: 'midnight',
      name: 'Midnight',
      colors: [const Color(0xFF232526), const Color(0xFF414345)],
      motif: ChatWallpaperMotif.dots,
      prefersDark: true,
    ),
    ChatWallpaper(
      id: 'emerald',
      name: 'Emerald',
      colors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    ),
    ChatWallpaper(
      id: 'rose',
      name: 'Rose',
      colors: [const Color(0xFFF953C6), const Color(0xFFB91D73)],
      motif: ChatWallpaperMotif.circles,
    ),
    ChatWallpaper(
      id: 'graphite',
      name: 'Graphite',
      colors: [const Color(0xFF2B2B2B), const Color(0xFF1F1F1F)],
      motif: ChatWallpaperMotif.dots,
      prefersDark: true,
    ),
    ChatWallpaper(
      id: 'clouds',
      name: 'Clouds',
      colors: [const Color(0xFFDEEBFF), const Color(0xFFF4F9FF), const Color(0xFFCFE0FF)],
      motif: ChatWallpaperMotif.circles,
    ),
    ChatWallpaper(
      id: 'mint',
      name: 'Mint',
      colors: [const Color(0xFFE0F7F2), const Color(0xFFB7F0E1)],
      motif: ChatWallpaperMotif.waves,
    ),
    ChatWallpaper(
      id: 'matrix',
      name: 'Matrix',
      colors: [const Color(0xFF001A00), const Color(0xFF003300)],
      motif: ChatWallpaperMotif.dots,
      prefersDark: true,
    ),
    ChatWallpaper(
      id: 'berry',
      name: 'Berry',
      colors: [const Color(0xFF4E0062), const Color(0xFFB4007C), const Color(0xFF2B0034)],
      motif: ChatWallpaperMotif.confetti,
      prefersDark: true,
    ),
  ];

  static ChatWallpaper? byId(String? id) {
    if (id == null || id.isEmpty || id == defaultId) return null;
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Paints a [ChatWallpaper] across the full canvas. Cheap enough to run in a
/// [CustomPaint] behind the scrolling message list without caching.
class ChatWallpaperPainter extends CustomPainter {
  final ChatWallpaper wallpaper;

  const ChatWallpaperPainter({required this.wallpaper});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = wallpaper.colors;
    final gradient = colors.length == 1
        ? LinearGradient(colors: [colors.first, colors.first])
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    switch (wallpaper.motif) {
      case ChatWallpaperMotif.none:
        break;
      case ChatWallpaperMotif.circles:
        _paintCircles(canvas, size);
      case ChatWallpaperMotif.confetti:
        _paintConfetti(canvas, size);
      case ChatWallpaperMotif.waves:
        _paintWaves(canvas, size);
      case ChatWallpaperMotif.dots:
        _paintDots(canvas, size);
    }
  }

  void _paintCircles(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final rnd = math.Random(wallpaper.id.hashCode);
    final cell = 140.0;
    for (var x = -cell; x < size.width + cell; x += cell) {
      for (var y = -cell; y < size.height + cell; y += cell) {
        final r = 24.0 + rnd.nextDouble() * 48;
        canvas.drawCircle(Offset(x + rnd.nextDouble() * cell, y + rnd.nextDouble() * cell),
            r, paint);
      }
    }
  }

  void _paintConfetti(Canvas canvas, Size size) {
    final rnd = math.Random(wallpaper.id.hashCode ^ 0x1A2B3C);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < 90; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final w = 6.0 + rnd.nextDouble() * 16;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, y),
              width: w,
              height: w * (0.4 + rnd.nextDouble() * 0.8)),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  void _paintWaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.10);
    final path = Path();
    final w = size.width;
    var y = 40.0;
    while (y < size.height) {
      path.moveTo(0, y);
      for (var x = 0.0; x <= w; x += 40) {
        path.quadraticBezierTo(
          x + 20,
          y + (20 * math.sin((x + y) * 0.02)),
          x + 40,
          y,
        );
      }
      canvas.drawPath(path, paint);
      path.reset();
      y += 92;
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    final rnd = math.Random(wallpaper.id.hashCode ^ 0x99E1A2);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final step = 46.0;
    for (var x = step / 2; x < size.width; x += step) {
      for (var y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 2.5 + rnd.nextDouble() * 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ChatWallpaperPainter oldDelegate) =>
      oldDelegate.wallpaper != wallpaper;
}

/// Draws a live preview of a [ChatWallpaper] inside the appearance picker.
class ChatWallpaperPreview extends StatelessWidget {
  final ChatWallpaper wallpaper;
  final double height;

  const ChatWallpaperPreview({
    super.key,
    required this.wallpaper,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: ChatWallpaperPainter(wallpaper: wallpaper),
        child: SizedBox(height: height, width: double.infinity),
      ),
    );
  }
}
