import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intelli_attend_faculty/Theme/theme_controller.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/change_password_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/login_devices_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/support/about_app_page.dart';
import 'package:intelli_attend_faculty/Presentation/Features/support/help_center_page.dart';
import 'package:intelli_attend_faculty/Presentation/Features/support/report_issue_page.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Profile/qr_scanner_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _defaultAvatar = "https://ui-avatars.com/api/?name=Faculty+User&background=2DD4BF&color=000";

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    await FacultyService.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: const CustomAppBar(
        title: "Profile",
        showBackButton: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Profile Header
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final p = FacultyService.profile.value;
                  if (p != null) {
                    _showFullImage(context, p.profileImage);
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface(context),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: AppTheme.primary(context), width: 2)
                      ),
                      child: ValueListenableBuilder<FacultyProfile?>(
                        valueListenable: FacultyService.profile,
                        builder: (context, p, _) {
                          final imageUrl = p?.profileImage ?? _defaultAvatar;
                          return CircleAvatar(
                            backgroundImage: imageUrl.startsWith('http')
                                ? CachedNetworkImageProvider(imageUrl)
                                : FileImage(File(imageUrl)) as ImageProvider,
                          );
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: _showProfileHeaderOptions,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary(context),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.bg(context), width: 2)
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 12)
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ValueListenableBuilder<FacultyProfile?>(
                  valueListenable: FacultyService.profile,
                  builder: (context, p, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p?.name ?? 'Faculty User',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.text(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5
                        )
                      ),
                      const SizedBox(height: 2),
                      Text(p?.department ?? 'Department',
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p?.designation ?? 'DESIGNATION',
                          style: TextStyle(
                            color: AppTheme.primary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w800
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 32),
          Text("Registration Identity",
            style: TextStyle(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<FacultyProfile?>(
            valueListenable: FacultyService.profile,
            builder: (context, p, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPlainRow("Faculty Name", p?.name ?? 'N/A'),
                _buildPlainRow("Designation", p?.designation ?? 'N/A'),
                _buildPlainRow("Department", p?.department ?? 'N/A'),
                _buildPlainRow("Official Email", p?.email ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text("Appearance Settings",
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 16),
          _buildThemeToggle(),
          const SizedBox(height: 32),
          Text("Security & Access",
            style: TextStyle(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 16),
          _buildInteractiveTile(Icons.lock_reset, "Change Password", "Update credentials", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
          }),
          _buildInteractiveTile(Icons.devices_other_rounded, "Login Devices", "Manage sessions", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginDevicesScreen()));
          }),
          const SizedBox(height: 32),
          Text("Identification",
            style: TextStyle(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 16),
          _buildInteractiveTile(Icons.badge_outlined, "Digital ID Card", "View Virtual Faculty ID", onTap: _showDigitalIdCard),
          const SizedBox(height: 32),
          Text("Help & Support",
            style: TextStyle(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.2
            )
          ),
          const SizedBox(height: 16),
          _buildInteractiveTile(Icons.info_outline_rounded, "About IntelliAttend", "App version & information", onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AboutAppPage()))),
          _buildInteractiveTile(Icons.help_outline_rounded, "Help Center", "FAQs & Tutorials", onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HelpCenterPage()))),
          _buildInteractiveTile(Icons.mail_outline_rounded, "Report an Issue", "Submit feedback", onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportIssuePage()))),
          const SizedBox(height: 64),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("INTELLIATTEND WATCHMAN",
                  style: TextStyle(
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2
                  )
                ),
                const SizedBox(height: 8),
                Text("© 2026 IntelliAttend Technologies.\nAll Rights Reserved.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.2),
                    fontSize: 9,
                    height: 1.5
                  )
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPlainRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(":", style: TextStyle(color: AppTheme.textSecondary(context).withValues(alpha: 0.4), fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
              style: TextStyle(
                color: AppTheme.text(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary(context), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value,
                  style: TextStyle(
                    color: AppTheme.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCompact({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary(context), size: 18),
          const SizedBox(height: 10),
          Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              color: AppTheme.text(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary(context).withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 16),
          Flexible(
            child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.text(context),
                fontSize: 13,
                fontWeight: FontWeight.w500
              )
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(value,
              style: TextStyle(
                color: AppTheme.primary(context),
                fontSize: 13,
                fontWeight: FontWeight.bold
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary(context), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w500
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.primary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.bold
                    )
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        bool isDark = mode == ThemeMode.dark;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.primary(context).withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
              color: isDark ? AppTheme.primary(context) : Colors.amber,
            ),
          ),
          title: Text("Appearance",
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(isDark ? "Dark Theme" : "Light Theme",
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 12,
            ),
          ),
          trailing: Switch.adaptive(
            value: isDark,
            activeThumbColor: AppTheme.primary(context),
            onChanged: (v) => ThemeController.toggle(),
          ),
        );
      },
    );
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result == null || !mounted) return;

    final value = result['value'] ?? '';
    final format = result['format'] ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Scanned ($format): $value"),
        backgroundColor: AppTheme.accentTeal,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "COPY",
          textColor: Colors.white,
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      ),
    );
  }

  void _showQRCodeID() {
    final p = FacultyService.profile.value;
    if (p == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_2_rounded, color: AppTheme.primary(context), size: 32),
              ),
              const SizedBox(height: 20),
              Text("Verification ID", 
                style: TextStyle(
                  color: AppTheme.text(context), 
                  fontSize: 20, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5
                )
              ),
              const SizedBox(height: 8),
              Text("Scan this code to verify your identity", 
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13)
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
                  ]
                ),
                child: QrImageView(
                  data: p.email,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF131B2E)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF131B2E)),
                ),
              ),
              const SizedBox(height: 32),
              Text(p.email.split('@')[0].toUpperCase(), 
                style: AppTheme.jetBrainsMono(
                  color: AppTheme.primary(context), 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2
                )
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("DISMISS", style: TextStyle(color: AppTheme.textSecondary(context), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDigitalIdCard() {
    final p = FacultyService.profile.value;
    if (p == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.88,
          height: MediaQuery.sizeOf(context).height * 0.32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary(context),
                const Color(0xFF004D40),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppTheme.primary(context).withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Stack(
            children: [
              // Subtle Pattern Overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/logo_square.png'),
                        repeat: ImageRepeat.repeat,
                        scale: 8,
                      ),
                    ),
                  ),
                ),
              ),
              // Card Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("INTELLIATTEND", 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 14,
                                letterSpacing: 1.5
                              )
                            ),
                            Text("FACULTY PORTAL", 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.6), 
                                fontWeight: FontWeight.bold, 
                                fontSize: 8,
                                letterSpacing: 1.2
                              )
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text("OFFICIAL", 
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            backgroundImage: (p.profileImage ?? _defaultAvatar).startsWith('http')
                                ? CachedNetworkImageProvider(p.profileImage ?? _defaultAvatar)
                                : FileImage(File(p.profileImage!)) as ImageProvider,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name.toUpperCase(), 
                                style: GoogleFonts.inter(
                                  color: Colors.white, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.1
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(p.email.split('@')[0].toUpperCase(), 
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.jetBrainsMono(
                                  color: AppTheme.accentTeal, 
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1
                                )
                              ),
                              const SizedBox(height: 4),
                              Text("${p.designation} • ${p.department}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.7), 
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600
                                )
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("STATUS", 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.4), fontSize: 8, fontWeight: FontWeight.bold)
                            ),
                            const Text("ACTIVE", 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)
                            ),
                          ],
                        ),
                        Image.asset('assets/images/logo_square.png', height: 24, color: Colors.white.withValues(alpha: 0.3)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: url.startsWith('http') 
              ? CachedNetworkImage(
                  imageUrl: url, 
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                ) 
              : Image.file(File(url)),
        ),
      ),
    );
  }

  void _showProfileHeaderOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showImagePicker();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_a_photo_outlined,
                        color: AppTheme.primary(context), size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Change Photo",
                    style: TextStyle(
                      color: AppTheme.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "This photo is used solely for your in-app display and does not update your official institutional records or database profile.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMediaOption(Icons.camera_alt_outlined, "Camera", () => _pickImage(ImageSource.camera)),
                _buildMediaOption(Icons.photo_library_outlined, "From Device", () => _pickImage(ImageSource.gallery)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.primary(context).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primary(context), size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;
    await FacultyService.updateProfileImage(image.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Profile photo updated"),
          backgroundColor: AppTheme.primary(context),
        ),
      );
    }
  }
}
