import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class BulkActionsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectRemaining;
  final VoidCallback onSelectPresent;
  final VoidCallback onSelectAbsent;
  final VoidCallback onSelectLate;
  final VoidCallback onSelectLeave;
  final VoidCallback onInvertSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onMarkPresent;
  final VoidCallback onMarkAbsent;
  final VoidCallback onMarkLate;
  final VoidCallback onMarkLeave;
  final VoidCallback? onUndo;
  final bool canUndo;
  final VoidCallback? onExport;
  final VoidCallback? onSendParents;

  const BulkActionsBar({
    Key? key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onSelectRemaining,
    required this.onSelectPresent,
    required this.onSelectAbsent,
    required this.onSelectLate,
    required this.onSelectLeave,
    required this.onInvertSelection,
    required this.onClearSelection,
    required this.onMarkPresent,
    required this.onMarkAbsent,
    required this.onMarkLate,
    required this.onMarkLeave,
    this.onUndo,
    this.canUndo = false,
    this.onExport,
    this.onSendParents,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                "$selectedCount selected",
                style: GoogleFonts.inter(
                  color: textCol,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (canUndo && onUndo != null)
                GestureDetector(
                  onTap: () {
                    HapticService.light();
                    onUndo!.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.undo_rounded, color: AppTheme.accentPurple, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "Undo",
                          style: GoogleFonts.inter(
                            color: AppTheme.accentPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  onClearSelection();
                },
                child: Text(
                  "Cancel",
                  style: GoogleFonts.inter(
                    color: AppTheme.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildActionChip(context, "Select All", Icons.select_all_rounded, onSelectAll),
              _buildActionChip(context, "Remaining", Icons.how_to_reg_rounded, onSelectRemaining),
              _buildActionChip(context, "Present", Icons.check_circle_rounded, onSelectPresent, const Color(0xFF22C55E)),
              _buildActionChip(context, "Absent", Icons.cancel_rounded, onSelectAbsent, AppTheme.errorRed),
              _buildActionChip(context, "Late", Icons.schedule_rounded, onSelectLate, const Color(0xFFFBBF24)),
              _buildActionChip(context, "Leave", Icons.event_busy_rounded, onSelectLeave, const Color(0xFF60A5FA)),
              _buildActionChip(context, "Invert", Icons.flip_rounded, onInvertSelection, AppTheme.accentPurple),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMarkButton(context, "Mark Present", const Color(0xFF22C55E), onMarkPresent)),
              const SizedBox(width: 6),
              Expanded(child: _buildMarkButton(context, "Mark Absent", AppTheme.errorRed, onMarkAbsent)),
              const SizedBox(width: 6),
              Expanded(child: _buildMarkButton(context, "Mark Late", const Color(0xFFFBBF24), onMarkLate)),
              const SizedBox(width: 6),
              Expanded(child: _buildMarkButton(context, "Mark Leave", const Color(0xFF60A5FA), onMarkLeave)),
            ],
          ),
          if (onExport != null || onSendParents != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onExport != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.light();
                        onExport!.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_download_rounded, color: AppTheme.accentTeal, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "Export",
                              style: GoogleFonts.inter(
                                color: AppTheme.accentTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onExport != null && onSendParents != null) const SizedBox(width: 6),
                if (onSendParents != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticService.light();
                        onSendParents!.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, color: AppTheme.accentPurple, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "Send to Parents",
                              style: GoogleFonts.inter(
                                color: AppTheme.accentPurple,
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
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, String label, IconData icon, VoidCallback onTap, [Color? color]) {
    final chipColor = color ?? AppTheme.textSecondary(context);
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: chipColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chipColor, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: chipColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkButton(BuildContext context, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticService.medium();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
