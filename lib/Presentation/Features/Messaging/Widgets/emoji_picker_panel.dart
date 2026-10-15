import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/emoji_data.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/emoji_recents_service.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Fitzpatrick skin tone modifiers, light → dark.
const skinToneModifiers = ['\u{1F3FB}', '\u{1F3FC}', '\u{1F3FD}', '\u{1F3FE}', '\u{1F3FF}'];
const _rememberedToneKey = 'emoji_skin_tone';

/// Removes any skin tone modifier from [glyph].
String removeSkinTone(String glyph) {
  for (final tone in skinToneModifiers) {
    glyph = glyph.replaceAll(tone, '');
  }
  return glyph;
}

/// Applies [tone] to [glyph], stripping any existing modifier first.
String applySkinTone(String glyph, String tone) {
  final codeUnits = removeSkinTone(glyph).codeUnits;
  final result = <int>[...codeUnits.take(2), ...tone.codeUnits];
  if (codeUnits.length >= 2) {
    result.addAll(codeUnits.skip(2));
  }
  return String.fromCharCodes(result);
}

/// Custom emoji picker panel: category tabs, search, skin tones, locally
/// stored recents + frequently used, and a backspace key.
class EmojiPickerPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onBackspace;

  const EmojiPickerPanel({
    super.key,
    required this.onEmojiSelected,
    this.onBackspace,
  });

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tabScroll = ScrollController();
  final FocusNode _searchFocus = FocusNode();

  String _tab = 'Recent';
  String _query = '';
  String? _rememberedTone;
  OverlayEntry? _toneEntry;

  @override
  void initState() {
    super.initState();
    EmojiRecentsService.instance.load();
    _rememberedTone = PersistenceService.prefs.getString(_rememberedToneKey);
  }

  @override
  void dispose() {
    _closeToneOverlay();
    _searchController.dispose();
    _searchFocus.dispose();
    _tabScroll.dispose();
    super.dispose();
  }

  List<EmojiEntry> get _gridEntries {
    final recents = EmojiRecentsService.instance;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final seen = <String>{};
      final results = <EmojiEntry>[];
      for (final list in emojiCategories.values) {
        for (final entry in list) {
          if (!seen.add(entry.emoji)) continue;
          if (entry.name.toLowerCase().contains(q)) results.add(entry);
        }
      }
      return results;
    }
    if (_tab == 'Recent') {
      final seen = <String>{};
      final entries = <EmojiEntry>[];
      for (final glyph
          in [...recents.frequentlyUsed, ...recents.recent]) {
        if (!seen.add(glyph)) continue;
        entries.add(_entryForGlyph(glyph));
      }
      return entries;
    }
    return emojiCategories[_tab] ?? const [];
  }

  /// Looks up the dataset entry for a stored glyph. Toned variants (e.g.
  /// `👍🏽`) are not part of the dataset, so fall back to a plain entry.
  EmojiEntry _entryForGlyph(String glyph) {
    for (final list in emojiCategories.values) {
      for (final entry in list) {
        if (entry.emoji == glyph) return entry;
      }
    }
    return EmojiEntry(glyph, glyph, false);
  }

  String _displayGlyph(EmojiEntry entry) =>
      (entry.hasSkinTone && _rememberedTone != null)
          ? applySkinTone(entry.emoji, _rememberedTone!)
          : entry.emoji;

  void _handleSelected(String glyph) {
    HapticService.selection();
    EmojiRecentsService.instance.record(glyph);
    widget.onEmojiSelected(glyph);
  }

  void _handleBackspace() {
    HapticService.selection();
    widget.onBackspace?.call();
  }

  // ── Skin tone overlay ─────────────────────────────────────────────────

  void _closeToneOverlay() {
    _toneEntry?.remove();
    _toneEntry = null;
  }

  void _openSkinToneOverlay(EmojiEntry entry, Offset position, Size cellSize) {
    _closeToneOverlay();
    final overlay = Overlay.of(context);
    final screen = MediaQuery.sizeOf(context);
    const barHeight = 56.0;
    const hPad = 10.0;
    final toneBarWidth = cellSize.width * 6 + hPad * 2;

    var top = position.dy - barHeight - 10;
    if (top < 0) top = position.dy + cellSize.height + 10;
    final clampedTop = top.clamp(0.0, screen.height - barHeight);
    var left = position.dx - toneBarWidth / 2 + cellSize.width / 2;
    left = left.clamp(8.0, max(8.0, screen.width - toneBarWidth - 8));

    _toneEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeToneOverlay,
            ),
          ),
          Positioned(
            left: left,
            top: clampedTop,
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(14),
              color: AppTheme.card(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toneOption(entry.emoji, onSelect: () {
                      _selectTone(entry, null);
                    }),
                    for (final tone in skinToneModifiers)
                      _toneOption(applySkinTone(entry.emoji, tone), onSelect: () {
                        _selectTone(entry, tone);
                      }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_toneEntry!);
  }

  Widget _toneOption(String glyph, {required VoidCallback onSelect}) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 40,
        height: 44,
        child: Center(
          child: Text(glyph, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }

  void _selectTone(EmojiEntry entry, String? tone) {
    _closeToneOverlay();
    setState(() {
      _rememberedTone = tone;
      PersistenceService.prefs.setString(_rememberedToneKey, tone ?? '');
      if (tone == null) {
        PersistenceService.prefs.remove(_rememberedToneKey);
      }
    });
    final glyph = tone == null ? entry.emoji : applySkinTone(entry.emoji, tone);
    _handleSelected(glyph);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = ChatThemeScope.accentOf(context);
    final entries = _gridEntries;
    final isEmpty = entries.isEmpty;

    return Container(
      color: AppTheme.card(context),
      child: Column(
        children: [
          _buildSearch(context, accent),
          _buildTabBar(context, accent),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Text(
                        _query.isNotEmpty
                            ? 'No emoji found for “$_query”'
                            : 'No recent emoji yet',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    )
                  : Stack(
                      key: ValueKey('$_tab|$_query'),
                      children: [
                        GridView.builder(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 44),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _EmojiCell(
                              entry: entry,
                              glyph: _displayGlyph(entry),
                              onTap: () => _handleSelected(_displayGlyph(entry)),
                              onLongPress: entry.hasSkinTone
                                  ? (pos, size) => _openSkinToneOverlay(
                                      entry, pos, size)
                                  : null,
                            );
                          },
                        ),
                        Positioned(
                          right: 6,
                          bottom: 8,
                          child: _BackspaceButton(onTap: _handleBackspace),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _query = value.trim()),
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(
            color: AppTheme.text(context), fontSize: 13.5, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search emoji',
          hintStyle: GoogleFonts.inter(
              color: AppTheme.textSecondary(context), fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: AppTheme.textSecondary(context)),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textSecondary(context)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.surface(context),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, Color accent) {
    return SizedBox(
      height: 46,
      child: SingleChildScrollView(
        controller: _tabScroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (final tab in emojiCategoryOrder)
              _TabItem(
                label: tab,
                icon: tab == 'Recent' ? '🕘' : emojiCategories[tab]!.first.emoji,
                selected: _tab == tab,
                accent: accent,
                onTap: () {
                  HapticService.selection();
                  setState(() => _tab = tab);
                  _searchFocus.unfocus();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  final EmojiEntry entry;
  final String glyph;
  final VoidCallback onTap;
  final void Function(Offset, Size)? onLongPress;

  const _EmojiCell({
    required this.entry,
    required this.glyph,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticService.medium();
              final renderBox = context.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              onLongPress!(position, renderBox.size);
            },
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Center(
            child: Text(glyph, style: const TextStyle(fontSize: 22)),
          ),
          if (entry.hasSkinTone)
            Padding(
              padding: const EdgeInsets.all(1),
              child: Icon(Icons.arrow_drop_down_rounded,
                  size: 12, color: AppTheme.textSecondary(context).withValues(alpha: 0.55)),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dim = AppTheme.textSecondary(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2.5,
              color: selected ? accent : Colors.transparent,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon,
                style: TextStyle(
                    fontSize: 20,
                    color: selected ? accent : dim.withValues(alpha: 0.75))),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.backspace_outlined,
              size: 22, color: AppTheme.textSecondary(context)),
        ),
      ),
    );
  }
}
