import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Resources/resources_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({Key? key}) : super(key: key);

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  @override
  Widget build(BuildContext context) {
    final profile = FacultyService.profile.value;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: CustomAppBar(
        title: "Courses",
        subtitle: profile?.department ?? "Computer Science & Engineering",
        showBackButton: false,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: FacultyService.courses,
        builder: (context, courseList, _) {
          if (courseList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No courses assigned",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Courses will appear here once assigned",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: courseList.length,
            itemBuilder: (context, index) => _buildCourseCard(courseList[index]),
          );
        },
      ),
    );
  }

  String _getInitials(String subject, String code) {
    if (code.length <= 4 && !code.contains(RegExp(r'[0-9]'))) {
      return code.toUpperCase();
    }
    List<String> words = subject.trim().split(RegExp(r'\s+'));
    if (words.length >= 3) {
      return words.where((w) => w.toLowerCase() != 'and' && w.toLowerCase() != '&')
                  .take(3)
                  .map((w) => w[0])
                  .join()
                  .toUpperCase();
    } else if (words.length == 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return code.substring(0, min(code.length, 3)).toUpperCase();
  }

  Color _getCourseColor(String initials) {
    final colors = [
      const Color(0xFF2DD4BF),
      const Color(0xFFF472B6),
      const Color(0xFF60A5FA),
      const Color(0xFFFBBF24),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFF87171),
      const Color(0xFFFB923C),
    ];
    return colors[(initials.hashCode + initials.length) % colors.length];
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String subject = course['course'] ?? course['name'] ?? 'Unknown';
    final String code = course['code'] ?? course['id'] ?? '';
    final String initials = _getInitials(subject, code);
    final Color accentColor = _getCourseColor(initials);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          HapticService.medium();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResourcesScreen(courseCode: code, courseName: subject),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: AppTheme.jetBrainsMono(
                              color: AppTheme.accentTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "Resources",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary(context).withValues(alpha: 0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
