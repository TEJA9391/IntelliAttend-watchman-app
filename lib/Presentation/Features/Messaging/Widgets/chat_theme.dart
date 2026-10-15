import 'package:flutter/material.dart';

import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_wallpapers.dart';

/// WhatsApp-style accent palette used by the per-chat theme picker.
class ChatAccents {
  static const List<Color> colors = [
    Color(0xFF2DD4BF), // teal (default)
    Color(0xFF0EA5E9), // sky
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFFACC15), // amber
    Color(0xFF22C55E), // green
    Color(0xFF14B8A6), // teal-dark
    Color(0xFF6366F1), // indigo
    Color(0xFF94A3B8), // slate
  ];

  static const List<String> names = [
    'Teal', 'Sky', 'Blue', 'Violet', 'Pink', 'Red',
    'Orange', 'Amber', 'Green', 'Teal Dark', 'Indigo', 'Slate',
  ];

  static Color resolve(int? index) =>
      (index != null && index >= 0 && index < colors.length)
          ? colors[index]
          : AppTheme.accentTeal;

  static int indexOf(Color color) {
    for (var i = 0; i < colors.length; i++) {
      if (colors[i].toARGB32() == color.toARGB32()) return i;
    }
    return 0;
  }
}

/// Exposes the per-chat accent color and dark-mode flag down the widget tree,
/// so bubbles/input/header all react to the conversation theme.
class ChatThemeScope extends InheritedWidget {
  final Color accent;
  final bool isDark;

  const ChatThemeScope({
    super.key,
    required this.accent,
    required this.isDark,
    required super.child,
  });

  static ChatThemeScope? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChatThemeScope>();
    if (scope != null) return scope;
    // A ChatAppearanceScope is also a ChatThemeScope from the callers' view.
    return context.dependOnInheritedWidgetOfExactType<ChatAppearanceScope>();
  }

  /// Accent color for this chat, falling back to the app theme primary.
  static Color accentOf(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) return scope.accent;
    return AppTheme.primary(context);
  }

  static bool isDarkOf(BuildContext context) => maybeOf(context)?.isDark ?? false;

  /// Glass/blur effect for the chat surface, resolved from [ChatAppearanceScope].
  static bool glassOf(BuildContext context) {
    final scope = ChatAppearanceScope.maybeOf(context);
    return scope?.glass ?? false;
  }

  @override
  bool updateShouldNotify(ChatThemeScope oldWidget) =>
      oldWidget.accent != accent || oldWidget.isDark != isDark;
}

/// Extends [ChatThemeScope] with the premium per-chat appearance: wallpaper
/// preset / custom image and the glass blur toggle. Widgets that only need the
/// accent or dark flag keep using [ChatThemeScope], which resolves both.
class ChatAppearanceScope extends ChatThemeScope {
  final ChatWallpaper? wallpaper;
  final String? wallpaperPath;
  final bool glass;

  const ChatAppearanceScope({
    super.key,
    required super.accent,
    required super.isDark,
    required super.child,
    this.wallpaper,
    this.wallpaperPath,
    this.glass = false,
  });

  static ChatAppearanceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatAppearanceScope>();

  static ChatWallpaper? wallpaperOf(BuildContext context) =>
      maybeOf(context)?.wallpaper;

  static String? wallpaperPathOf(BuildContext context) =>
      maybeOf(context)?.wallpaperPath;

  static bool glassOf(BuildContext context) =>
      maybeOf(context)?.glass ?? false;

  @override
  bool updateShouldNotify(ChatThemeScope oldWidget) {
    if (super.updateShouldNotify(oldWidget)) return true;
    if (oldWidget is ChatAppearanceScope) {
      return oldWidget.wallpaper != wallpaper ||
          oldWidget.wallpaperPath != wallpaperPath ||
          oldWidget.glass != glass;
    }
    return wallpaper != null || wallpaperPath != null || glass;
  }
}
