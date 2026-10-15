import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/notifications/notifications_screen.dart';

class DashboardHeader extends StatefulWidget {
  final VoidCallback onProfileTap;

  const DashboardHeader({
    Key? key, 
    required this.onProfileTap,
  }) : super(key: key);

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  StreamSubscription? _connectivitySub;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isConnected = results.any((r) => r != ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = results.any((r) => r != ConnectivityResult.none);
      });
    }
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning,";
    if (hour < 17) return "Good Afternoon,";
    return "Good Evening,";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<FacultyProfile?>(
      valueListenable: FacultyService.profile,
      builder: (context, profile, _) {
        return Container(
          height: 72,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onProfileTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: _getProfileImage(profile),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          color: _isConnected ? const Color(0xFFA3E635) : Colors.amber, 
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF050505) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? const Color(0xFFA3E635) : Colors.amber).withValues(alpha: 0.4),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getTimeGreeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      profile?.name ?? '',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<List<AppNotification>>(
                valueListenable: NotificationService.history,
                builder: (context, history, _) {
                  final unread = history.where((n) => !n.isRead).length;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            size: 22,
                          ),
                          if (unread > 0)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                   unread > 9 ? '9+' : '$unread',
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                   style: const TextStyle(
                                     color: Colors.white,
                                     fontSize: 9,
                                     fontWeight: FontWeight.bold,
                                     height: 1,
                                   ),
                                 ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider _getProfileImage(FacultyProfile? profile) {
    if (profile?.profileImage != null) {
      if (profile!.profileImage!.startsWith('http')) {
        return NetworkImage(profile.profileImage!);
      } else {
        return FileImage(File(profile.profileImage!));
      }
    }
    return const AssetImage('assets/images/logo_square.png');
  }
}
