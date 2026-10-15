import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_wallpapers.dart';

/// The full per-chat appearance configuration.
class ChatAppearanceConfig {
  final String themeMode; // 'auto' | 'light' | 'dark'
  final int accentIndex;
  final String? wallpaperId;
  final String? customWallpaperPath;
  final bool glass;

  const ChatAppearanceConfig({
    required this.themeMode,
    required this.accentIndex,
    this.wallpaperId,
    this.customWallpaperPath,
    required this.glass,
  });
}

/// Opens the premium chat appearance picker (theme mode, accent, wallpaper
/// presets + custom gallery image, glass effect). Changes are persisted to the
/// [MessageCacheService] immediately and the current config is returned on
/// close so the chat screen can rebuild its surface.
Future<ChatAppearanceConfig?> showChatAppearanceSheet(
  BuildContext context, {
  required String conversationId,
}) {
  return showModalBottomSheet<ChatAppearanceConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChatAppearanceSheet(conversationId: conversationId),
  );
}

class _ChatAppearanceSheet extends StatefulWidget {
  final String conversationId;

  const _ChatAppearanceSheet({required this.conversationId});

  @override
  State<_ChatAppearanceSheet> createState() => _ChatAppearanceSheetState();
}

class _ChatAppearanceSheetState extends State<_ChatAppearanceSheet> {
  final _cache = MessageCacheService.instance;
  late String _mode;
  late int _accentIndex;
  late String? _wallpaperId;
  late String? _customPath;
  late bool _glass;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final id = widget.conversationId;
    _mode = _cache.getChatThemeMode(id);
    _accentIndex = _cache.getChatAccent(id) ?? 0;
    _wallpaperId = _cache.getWallpaperId(id);
    _customPath = _cache.getCustomWallpaperPath(id);
    _glass = _cache.getGlassEnabled(id);
  }

  ChatAppearanceConfig get _config => ChatAppearanceConfig(
        themeMode: _mode,
        accentIndex: _accentIndex,
        wallpaperId: _wallpaperId,
        customWallpaperPath: _customPath,
        glass: _glass,
      );

  Future<void> _persist() async {
    final id = widget.conversationId;
    await _cache.setChatThemeMode(id, _mode);
    await _cache.setChatAccent(id, _accentIndex);
    await _cache.setWallpaperId(id, _wallpaperId);
    await _cache.setCustomWallpaperPath(id, _customPath);
    await _cache.setGlassEnabled(id, _glass);
  }

  void _update(VoidCallback change) {
    setState(change);
    _persist();
  }

  Future<void> _pickCustom() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final wallDir = Directory('${dir.path}/wallpapers');
      if (!wallDir.existsSync()) wallDir.createSync(recursive: true);
      final dot = picked.path.lastIndexOf('.');
      final ext = dot >= 0 ? picked.path.substring(dot) : '.jpg';
      final target = '${wallDir.path}/wall_${widget.conversationId}_'
          '${DateTime.now().millisecondsSinceEpoch}$ext';
      final copied = await File(picked.path).copy(target);
      if (!mounted) return;
      setState(() {
        _customPath = copied.path;
        _wallpaperId = null;
      });
      await _persist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set wallpaper: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _mode == 'dark' ||
        (_mode == 'auto' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return SafeArea(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          decoration: BoxDecoration(color: AppTheme.card(context)),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary(context).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Chat appearance',
                    style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                _WallpaperPreviewCard(config: _config, isDark: isDark),
                const SizedBox(height: 20),
                _sectionLabel('Theme mode'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'auto', label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded, size: 16)),
                    ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded, size: 16)),
                    ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded, size: 16)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _update(() => _mode = s.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(AppTheme.primary(context)),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppTheme.primary(context).withValues(alpha: 0.14)
                          : Colors.transparent,
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? AppTheme.primary(context)
                            : AppTheme.textSecondary(context).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Accent color'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < ChatAccents.colors.length; i++)
                      _AccentDot(
                        color: ChatAccents.colors[i],
                        selected: _accentIndex == i,
                        onTap: () => _update(() => _accentIndex = i),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel('Wallpaper'),
                const SizedBox(height: 10),
                _WallpaperGrid(
                  conversationId: widget.conversationId,
                  selectedId: _wallpaperId,
                  customPath: _customPath,
                  picking: _picking,
                  onSelect: (id) => _update(() {
                    _wallpaperId = id;
                    _customPath = null;
                  }),
                  onGallery: _pickCustom,
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Glass effect',
                      style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text('Frosted blur over the wallpaper for the header, composer and bubbles',
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context), fontSize: 12)),
                  value: _glass,
                  onChanged: (v) => _update(() => _glass = v),
                  activeTrackColor: AppTheme.primary(context),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context, _config),
                    child: Text('Done',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          color: AppTheme.textSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6));
}

/// Renders a live miniature of how the chat will look with the current config.
class _WallpaperPreviewCard extends StatelessWidget {
  final ChatAppearanceConfig config;
  final bool isDark;

  const _WallpaperPreviewCard({required this.config, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = ChatAccents.resolve(config.accentIndex);
    final wallpaper = ChatWallpaper.byId(config.wallpaperId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (config.customWallpaperPath != null &&
                File(config.customWallpaperPath!).existsSync())
              Image.file(File(config.customWallpaperPath!), fit: BoxFit.cover)
            else if (wallpaper != null)
              CustomPaint(
                painter: ChatWallpaperPainter(wallpaper: wallpaper),
              )
            else
              CustomPaint(
                painter: _DefaultPreviewPainter(dark: isDark, accent: accent),
              ),
            const Positioned(
              right: 10,
              top: 10,
              child: _MiniBubble(outgoing: true),
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: _MiniBubble(outgoing: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBubble extends StatelessWidget {
  final bool outgoing;

  const _MiniBubble({required this.outgoing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: outgoing
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(outgoing ? 'Looks great ✨' : 'Hello!',
          style: GoogleFonts.inter(
              color: Colors.black.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _DefaultPreviewPainter extends CustomPainter {
  final bool dark;
  final Color accent;

  const _DefaultPreviewPainter({required this.dark, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF0C1218), Color(0xFF142028), Color(0xFF10161C)]
          : [
              const Color(0xFFF4FCF9),
              accent.withValues(alpha: 0.10),
              const Color(0xFFEAF8F3),
            ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_DefaultPreviewPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.accent != accent;
}

class _AccentDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: AppTheme.text(context), width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _WallpaperGrid extends StatelessWidget {
  final String conversationId;
  final String? selectedId;
  final String? customPath;
  final bool picking;
  final ValueChanged<String> onSelect;
  final VoidCallback onGallery;

  const _WallpaperGrid({
    required this.conversationId,
    required this.selectedId,
    required this.customPath,
    required this.picking,
    required this.onSelect,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _WallpaperTile(
        label: 'Default',
        selected: (selectedId == null || selectedId == ChatWallpaper.defaultId) &&
            customPath == null,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF4FCF9), Color(0xFFEAF8F3)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.black45),
          ),
        ),
        onTap: () => onSelect(ChatWallpaper.defaultId),
      ),
      for (final preset in ChatWallpaper.presets)
        _WallpaperTile(
          label: preset.name,
          selected: selectedId == preset.id && customPath == null,
          child: ChatWallpaperPreview(wallpaper: preset, height: 56),
          onTap: () => onSelect(preset.id),
        ),
      _WallpaperTile(
        label: picking ? 'Loading…' : 'From gallery',
        selected: customPath != null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.4)),
          ),
          child: customPath != null && File(customPath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(customPath!), fit: BoxFit.cover),
                )
              : Center(
                  child: picking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Icon(Icons.add_photo_alternate_rounded,
                          color: AppTheme.textSecondary(context), size: 26),
                ),
        ),
        onTap: onGallery,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: tiles,
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  const _WallpaperTile({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.primary(context)
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: child,
          ),
          const SizedBox(height: 5),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: selected
                      ? AppTheme.primary(context)
                      : AppTheme.textSecondary(context),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
