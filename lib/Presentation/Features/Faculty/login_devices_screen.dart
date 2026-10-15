import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/auth_session_model.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'package:intelli_attend_faculty/Services/session_management_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Core/Models/device_data.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Auth/login_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/device_detail_screen.dart';

class LoginDevicesScreen extends StatefulWidget {
  const LoginDevicesScreen({super.key});

  @override
  State<LoginDevicesScreen> createState() => _LoginDevicesScreenState();
}

class _LoginDevicesScreenState extends State<LoginDevicesScreen> {
  DeviceData? _localDevice;
  List<AuthSession> _serverSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final localResult = await HardwareService.getDeviceSnapshot(forceRefresh: true);
    if (mounted) setState(() => _localDevice = localResult);

    try {
      final sessions = await SessionManagementService().getActiveSessions();
      if (mounted) setState(() => _serverSessions = sessions);
    } catch (_) {
      if (mounted) setState(() => _serverSessions = []);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _revokeSession(AuthSession session) async {
    final name = session.displayName;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Log Out Device?"),
        content: Text("End the session on $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("LOG OUT"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await SessionManagementService().revokeSession(session.sessionId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logged out from $name"), backgroundColor: AppTheme.accentTeal),
        );
        _loadAll();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to log out device")));
      }
    }
  }

  Future<void> _handleLogoutThisDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Log Out This Device?"),
        content: const Text("You will be signed out from this device."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("LOG OUT"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signOut();
      FacultyService.clear();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to log out.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherSessions = _serverSessions.where((s) => !s.isCurrentDevice).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text("Your devices", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading && _localDevice == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAll,
                    color: AppTheme.accentTeal,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        if (_localDevice != null)
                          _buildDeviceCard(
                            deviceName: _localDevice!.displayName,
                            subtitle: _localDevice!.osDisplay,
                            ipAddress: _localDevice!.localIpAddress,
                            isCurrentDevice: true,
                          ),

                        if (otherSessions.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            "OTHER DEVICES",
                            style: TextStyle(
                              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...otherSessions.map((s) => _buildDeviceCard(
                            deviceName: s.displayName,
                            subtitle: s.osDisplay,
                            ipAddress: s.ipAddress,
                            isCurrentDevice: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeviceDetailScreen(
                                  deviceName: s.displayName,
                                  ipAddress: s.ipAddress,
                                  isCurrentDevice: false,
                                ),
                              ),
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _buildActionBtn("Log Out This Device", Icons.logout_rounded, Colors.redAccent, _handleLogoutThisDevice),
                ),
              ],
            ),
    );
  }

  Widget _buildDeviceCard({
    required String deviceName,
    required String subtitle,
    required String ipAddress,
    required bool isCurrentDevice,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? (isCurrentDevice ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceDetailScreen(
              deviceName: _localDevice?.displayName ?? deviceName,
              ipAddress: ipAddress,
              isCurrentDevice: true,
            ),
          ),
        );
      } : null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: isCurrentDevice
              ? Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3), width: 1.5)
              : Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deviceName,
                          style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentDevice)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text("CURRENT DEVICE",
                              style: TextStyle(color: AppTheme.accentTeal, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ipAddress.isNotEmpty ? ipAddress : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context).withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}
