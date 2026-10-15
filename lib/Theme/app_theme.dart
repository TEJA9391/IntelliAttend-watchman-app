import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Constant)
  static const Color accentTeal = Color(0xFF2DD4BF);
  static const Color highlightLime = Color(0xFFA3E635);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color greenOnline = Color(0xFF2DD4BF); 
  static const Color accentPurple = Color(0xFF6B4EFF);

  // Dark Theme Tokens (as defined in HTML)
  static const Color darkBackground = Color(0xFF050505);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkSurfaceSubtle = Color(0xFF121212);
  static const Color darkOnBackground = Color(0xFFF9FAFB);
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);
  static const Color darkOutlineVariant = Color(0xFF333333);

  // Light Theme Tokens (as defined in HTML)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF1F5F9);
  static const Color lightOnBackground = Color(0xFF0F172A);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightOutlineVariant = Color(0xFFE2E8F0);

  // Theme-aware color methods
  static Color bg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;
  static Color card(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;
  static Color surface(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkSurfaceSubtle : lightSurfaceSubtle;
  static Color text(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkOnBackground : lightOnBackground;
  static Color textSecondary(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF71717A) : const Color(0xFF64748B);
  static Color border(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0);
  static Color primary(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? accentTeal : const Color(0xFF14B8A6);
  static Color accent(BuildContext context) => accentTeal;
  
  static TextStyle jetBrainsMono({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // Pre-calculate font family for speed
  static final String? _interFontFamily = GoogleFonts.inter().fontFamily;

  static ThemeData getTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: isDark ? accentTeal : const Color(0xFF14B8A6),
      brightness: brightness,
      primary: isDark ? accentTeal : const Color(0xFF14B8A6),
      surface: isDark ? darkCard : lightCard,
      onSurface: isDark ? darkOnBackground : lightOnBackground,
      background: isDark ? darkBackground : lightBackground,
      onBackground: isDark ? darkOnBackground : lightOnBackground,
      outlineVariant: isDark ? darkOutlineVariant : lightOutlineVariant,
      surfaceVariant: isDark ? darkSurfaceVariant : lightSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: _interFontFamily,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      canvasColor: Colors.transparent,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
      ),
      cardColor: isDark ? darkCard : lightCard,
      dividerColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
      
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: isDark ? darkCard : lightCard,
        clipBehavior: Clip.antiAlias,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: -0.8),
        displaySmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: -0.3),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: -0.2),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: isDark ? darkOnBackground : lightOnBackground, height: 1.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: isDark ? darkOnBackground : lightOnBackground, height: 1.4),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? darkOnBackground : lightOnBackground, letterSpacing: 0.2),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBackground : Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? darkOnBackground : lightOnBackground),
        titleTextStyle: GoogleFonts.inter(
          color: isDark ? darkOnBackground : lightOnBackground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? darkBackground : lightBackground,
      ),
    );
  }

  static ThemeData getAuthTheme(BuildContext context) {
    final theme = getTheme(Theme.of(context).brightness);
    final isDark = theme.brightness == Brightness.dark;
    
    return theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
          fontSize: 14,
        ),
        prefixIconColor: accentTeal,
        suffixIconColor: isDark ? Colors.white70 : const Color(0xFF64748B),
      ),
      textTheme: theme.textTheme.copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          letterSpacing: -1,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
          height: 1.5,
        ),
      ),
    );
  }

  // Legacy/Helper support
  static Color get backgroundCustom => darkBackground;
  static Color get cardCustom => darkCard;
  static Color get surfaceSubtle => darkSurfaceSubtle;
  
  // Restored legacy color tokens to fix compilation errors in other screens
  static Color slate700(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFF475569);
  static Color slate500(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF64748B);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color cardDark = Color(0xFF18181B);
  static const Color green400 = Color(0xFF4ADE80);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color accentGold = Color(0xFFFACC15);
  static const Color accentPink = Color(0xFFF472B6);
}

/// Allows downward overscroll (pull-to-refresh bounce) but prevents any
/// upward overscroll at the bottom — the screen stays completely frozen
/// when the user tries to scroll past the last item.
class PullDownOnlyPhysics extends BouncingScrollPhysics {
  const PullDownOnlyPhysics({super.parent});

  @override
  PullDownOnlyPhysics applyTo(ScrollPhysics? ancestor) =>
      PullDownOnlyPhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Restored normal scrolling. Previously this was blocking all upward swipes (offset < 0).
    // offset < 0  →  finger swiped UP  →  pixels increase (toward end)
    // offset > 0  →  finger swiped DOWN →  pixels decrease (toward start / pull-to-refresh)
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // After an upward fling the ballistic velocity is positive (pixels increasing).
    // Suppress the simulation so the list doesn't slide past the end.
    if (velocity > 0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}


