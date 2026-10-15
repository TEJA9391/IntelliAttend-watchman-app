import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class SearchFilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final String activeFilterLabel;
  final VoidCallback onFilterTap;
  final String activeSortLabel;
  final VoidCallback onSortTap;
  final String? activeGenderLabel;
  final VoidCallback? onGenderTap;
  final String? activeSectionLabel;
  final VoidCallback? onSectionTap;
  final bool hasActiveFilters;
  final VoidCallback? onClearAllFilters;

  const SearchFilterBar({
    Key? key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClear,
    required this.activeFilterLabel,
    required this.onFilterTap,
    required this.activeSortLabel,
    required this.onSortTap,
    this.activeGenderLabel,
    this.onGenderTap,
    this.activeSectionLabel,
    this.onSectionTap,
    this.hasActiveFilters = false,
    this.onClearAllFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border(context), width: 0.5),
          ),
          child: TextField(
            onChanged: onSearchChanged,
            style: GoogleFonts.inter(color: textCol, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, roll no, or ID...',
              hintStyle: GoogleFonts.inter(color: textSec.withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: textSec, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close_rounded, color: textSec, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildFilterChip(context, 'Status: $activeFilterLabel', Icons.filter_list_rounded, onFilterTap, AppTheme.accentTeal),
              const SizedBox(width: 8),
              if (onGenderTap != null)
                _buildFilterChip(context, activeGenderLabel ?? 'Gender: All', Icons.person_outline_rounded, onGenderTap!, AppTheme.accentPurple),
              if (onGenderTap != null) const SizedBox(width: 8),
              if (onSectionTap != null)
                _buildFilterChip(context, activeSectionLabel ?? 'Section: All', Icons.class_outlined, onSectionTap!, const Color(0xFF60A5FA)),
              if (onSectionTap != null) const SizedBox(width: 8),
              _buildFilterChip(context, 'Sort: $activeSortLabel', Icons.sort_rounded, onSortTap, const Color(0xFFFBBF24)),
            ],
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticService.light();
                      onClearAllFilters?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.clear_all_rounded, color: AppTheme.errorRed, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Clear All Filters",
                            style: GoogleFonts.inter(
                              color: AppTheme.errorRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
        ],
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
