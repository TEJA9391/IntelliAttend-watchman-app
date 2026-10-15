import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String deviceName;
  final String ipAddress;
  final bool isCurrentDevice;

  const DeviceDetailScreen({
    super.key,
    required this.deviceName,
    required this.ipAddress,
    required this.isCurrentDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text("Device Details", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 56),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              deviceName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.bold, fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          if (isCurrentDevice) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("CURRENT DEVICE",
                    style: TextStyle(color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              children: [
                _buildRow(context, Icons.android_rounded, "Device Name", deviceName),
                Divider(height: 1, color: AppTheme.border(context)),
                _buildRow(context, Icons.language_rounded, "IP Address", ipAddress.isNotEmpty ? ipAddress : "Not available"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
