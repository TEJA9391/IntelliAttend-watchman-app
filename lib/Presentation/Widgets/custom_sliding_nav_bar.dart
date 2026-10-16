import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'qr_scan_logo.dart';

class CustomSlidingNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomSlidingNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CustomSlidingNavBar> createState() => _CustomSlidingNavBarState();
}

class _CustomSlidingNavBarState extends State<CustomSlidingNavBar> {
  bool _isScanPressed = false;
  bool _isHomePressed = false;
  bool _isProfilePressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF94A3B8);
    const Color activeColor = AppTheme.accentTeal;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final Color navBgColor = isDark ? const Color(0xFF16161A) : Colors.white;

    // Determine selection state (support 0 for Home, 1 or 2 for Profile)
    final bool isHomeSelected = widget.currentIndex == 0;
    final bool isProfileSelected = widget.currentIndex == 1 || widget.currentIndex == 2;

    const double dockHeight = 66.0;
    const double overflowHeight = 16.0;
    final double totalHeight = dockHeight + overflowHeight + bottomInset;

    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: navBgColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // ── 1. Sleek Professional Dock Container ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: dockHeight + bottomInset,
                child: Container(
                  decoration: BoxDecoration(
                    color: navBgColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: navBgColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Tab: Home
                          Expanded(
                            child: _buildSideTab(
                              context: context,
                              label: 'Home',
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home_rounded,
                              isSelected: isHomeSelected,
                              isPressed: _isHomePressed,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTapDown: () => setState(() => _isHomePressed = true),
                              onTapCancel: () => setState(() => _isHomePressed = false),
                              onTapUp: () {
                                setState(() => _isHomePressed = false);
                                HapticService.selection();
                                widget.onTap(0);
                              },
                            ),
                          ),

                          // Center Space Reserved for the Floating Scan Pod
                          const SizedBox(width: 86),

                          // Right Tab: Profile
                          Expanded(
                            child: _buildSideTab(
                              context: context,
                              label: 'Profile',
                              icon: Icons.person_outline_rounded,
                              activeIcon: Icons.person_rounded,
                              isSelected: isProfileSelected,
                              isPressed: _isProfilePressed,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTapDown: () => setState(() => _isProfilePressed = true),
                              onTapCancel: () => setState(() => _isProfilePressed = false),
                              onTapUp: () {
                                setState(() => _isProfilePressed = false);
                                HapticService.selection();
                                widget.onTap(2);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. Floating Hero Center Action Button (Scan) - Professional Sleek Style ──
              Positioned(
                bottom: bottomInset + 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _isScanPressed = true),
                  onTapCancel: () => setState(() => _isScanPressed = false),
                  onTapUp: (_) {
                    setState(() => _isScanPressed = false);
                    HapticService.medium();
                    widget.onTap(1);
                  },
                  child: AnimatedScale(
                    scale: _isScanPressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 130),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Professional Non-Glowing Tactile Pod
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: navBgColor,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: QrScanLogo(
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Scan',
                          style: GoogleFonts.inter(
                            color: activeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildSideTab({
    required BuildContext context,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isSelected,
    required bool isPressed,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTapDown,
    required VoidCallback onTapCancel,
    required VoidCallback onTapUp,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      onTapCancel: onTapCancel,
      onTapUp: (_) => onTapUp(),
      child: AnimatedScale(
        scale: isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Pill Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: isDark ? 0.15 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
