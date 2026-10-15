import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "About IntelliAttend",
          style: TextStyle(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo Placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary(context).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.school_rounded,
                size: 64,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "IntelliAttend Watchman",
              style: TextStyle(
                color: AppTheme.text(context),
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Version 2.4.0 (Build 108)",
              style: TextStyle(
                color: AppTheme.slate500(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            _buildSection(
              context,
              "Our Mission",
              "IntelliAttend is dedicated to revolutionizing academic attendance through intelligent automation and real-time analytics. We empower educators with seamless tools to focus on what matters most: teaching.",
            ),
            const SizedBox(height: 32),
            _buildInfoCard(context),
            const SizedBox(height: 48),
            Text(
              "© 2026 IntelliAttend Technologies",
              style: TextStyle(
                color: AppTheme.slate500(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Made with ❤️ for Educators Worldwide",
              style: TextStyle(
                color: AppTheme.slate500(context).withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.primary(context),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context), width: 1),
      ),
      child: Column(
        children: [
          _buildInfoRow(context, Icons.language_rounded, "Official Website",
              "www.intelliattend.com", () => _launchUrl(context, "https://www.intelliattend.app/")),
          const Divider(height: 32),
          _buildInfoRow(context, Icons.privacy_tip_outlined, "Privacy Policy",
              "View Document", () => _launchUrl(context, "https://www.intelliattend.app/privacy/")),
          const Divider(height: 32),
          _buildInfoRow(context, Icons.description_outlined, "Terms of Service",
              "View Document", () => _launchUrl(context, "https://www.intelliattend.app/terms/")),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open link")),
        );
      }
    }
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String title, String value, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary(context), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.primary(context),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.slate500(context), size: 16),
          ],
        ),
      ),
    );
  }
}
