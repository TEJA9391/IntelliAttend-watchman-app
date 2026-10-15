import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';

class SubjectClassTopicsSection extends StatelessWidget {
  final List<CourseTopic> topics;
  final ScheduledClass scheduledClass;
  final VoidCallback? onSeeAll;
  final ValueChanged<int>? onTopicTap;

  const SubjectClassTopicsSection({
    Key? key,
    required this.topics,
    required this.scheduledClass,
    this.onSeeAll,
    this.onTopicTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int completedCount = topics.where((t) => t.isCompleted).length;
    final double progressPct = topics.isNotEmpty ? completedCount / topics.length : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppTheme.accentTeal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Subject Class Topics",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$completedCount of ${topics.length} completed",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSec,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onSeeAll != null && topics.length > 3)
                GestureDetector(
                  onTap: () {
                    HapticService.light();
                    onSeeAll!();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      "See All",
                      style: GoogleFonts.inter(
                        color: AppTheme.accentTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressPct,
                  backgroundColor: textSec.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (topics.isEmpty)
            _buildEmptyState(context, textCol, textSec)
          else
            NotificationListener<ScrollNotification>(
              onNotification: (notification) => true,
              child: SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: topics.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _buildTopicCard(context, topics[index], index, textCol, textSec, isDark);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, CourseTopic topic, int index, Color textCol, Color textSec, bool isDark) {
    final bool isCompleted = topic.isCompleted;
    final bool isInProgress = !isCompleted && topic.completedCount > 0;
    final double topicProgress = topic.totalCount > 0 ? topic.completedCount / topic.totalCount : 0.0;

    final Color statusColor;
    final String statusLabel;
    if (isCompleted) {
      statusColor = const Color(0xFF22C55E);
      statusLabel = "Completed";
    } else if (isInProgress) {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = "In Progress";
    } else {
      statusColor = textSec;
      statusLabel = "Pending";
    }

    return GestureDetector(
      onTap: () {
        HapticService.light();
        onTopicTap?.call(index);
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.only(right: index < topics.length - 1 ? 10 : 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                : AppTheme.border(context),
            width: isCompleted ? 1 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                topic.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: textCol,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (topic.totalCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 11, color: textSec),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      "${topic.completedCount}/${topic.totalCount}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textSec,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: topicProgress,
                    backgroundColor: textSec.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textCol, Color textSec) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 36, color: textSec.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            "No topics added yet",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: textSec,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
