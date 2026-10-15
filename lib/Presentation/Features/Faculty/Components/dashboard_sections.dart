import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/History/history_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Analytics/analytics_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Support/help_center_page.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_list_screen.dart';

class StatsSection extends StatelessWidget {
  final DashboardController controller;

  const StatsSection({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Attendance Record",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.bar_chart_rounded, color: AppTheme.accentTeal, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<FacultyStats?>(
              valueListenable: FacultyService.stats,
              builder: (context, stats, _) {
                final present = stats?.livePresentCount ?? 0;
                final total = stats?.totalExpectedStrength ?? 0;
                final absent = total > present ? total - present : 0;
                final avg = stats?.departmentAverage ?? 0.0;

                return Row(
                  children: [
                    _buildStatItem(context, "Present", "$present", AppTheme.highlightLime),
                    const SizedBox(width: 12),
                    _buildStatItem(context, "Absent", "$absent", AppTheme.errorRed),
                    const SizedBox(width: 12),
                    _buildStatItem(context, "Dept Avg", "${avg.toStringAsFixed(1)}%", AppTheme.accentTeal),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "Quick Actions",
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              _buildActionButton(context, Icons.chat_bubble_rounded, "Chat", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
              }),
              const SizedBox(width: 12),
              _buildActionButton(context, Icons.history_rounded, "History", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              }),
              const SizedBox(width: 12),
              _buildActionButton(context, Icons.insights_rounded, "Insights", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              const SizedBox(width: 12),
              _buildActionButton(context, Icons.help_outline_rounded, "Support", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterPage()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.accentTeal, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
