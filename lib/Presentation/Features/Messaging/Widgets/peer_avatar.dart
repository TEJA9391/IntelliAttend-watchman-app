import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Circular avatar showing the peer's profile image (when available) or their
/// initials, with an optional online ring and presence dot.
class PeerAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final Color? backgroundColor;
  final double radius;
  final bool isOnline;
  final bool showOnlineDot;

  const PeerAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.backgroundColor,
    this.radius = 24,
    this.isOnline = false,
    this.showOnlineDot = false,
  });

  /// Deterministic pastel backdrop derived from the name so a given peer
  /// always gets the same color in both themes.
  static Color colorFor(String name, BuildContext context) {
    const palette = [
      Color(0xFF14B8A6),
      Color(0xFF6B4EFF),
      Color(0xFF3B82F6),
      Color(0xFFF472B6),
      Color(0xFFF59E0B),
      Color(0xFF22C55E),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF0EA5E9),
      Color(0xFF84CC16),
    ];
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final onlineRing = isOnline && showOnlineDot;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? Colors.transparent : const Color(0xFFDFE5E7),
        border: onlineRing
            ? Border.all(color: AppTheme.greenOnline, width: 2.5)
            : null,
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorWidget: (_, __, ___) => _defaultIcon(),
                placeholder: (_, __) => _defaultIcon(),
              )
            : _defaultIcon(),
      ),
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDFE5E7),
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: radius * 0.9,
        ),
      ),
    );
  }
}

/// Small green dot indicating the peer is online, overlaid on an avatar.
class OnlineDot extends StatelessWidget {
  final double size;

  const OnlineDot({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.greenOnline,
        border: Border.all(color: AppTheme.bg(context), width: 2),
      ),
    );
  }
}
