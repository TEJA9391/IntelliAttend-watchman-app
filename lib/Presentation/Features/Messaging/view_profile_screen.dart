import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/call_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_appearance_sheet.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';

/// "View contact" profile for a chat peer with contact details, call buttons,
/// presence, mute/block/report and wallpaper settings.
class ViewProfileScreen extends StatefulWidget {
  final StudentContact peer;
  final String conversationId;

  const ViewProfileScreen({super.key, required this.peer, required this.conversationId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final MessageCacheService _cache = MessageCacheService.instance;
  final MessagingRepository _repository = MessagingRepository();
  late bool _muted;
  late bool _blocked;

  @override
  void initState() {
    super.initState();
    _muted = _cache.isMuted(widget.conversationId);
    _blocked = _cache.isBlocked(widget.conversationId);
  }

  StudentContact get _peer => widget.peer;

  bool get _isOnline {
    final snap = ChatRealtimeService.instance.presenceFor(_peer.id);
    return snap?.isOnline ?? _peer.isOnline;
  }

  String get _presenceText {
    final snap = ChatRealtimeService.instance.presenceFor(_peer.id);
    if (_isOnline) return 'Online';
    return ChatTimeFormat.lastSeen(snap?.lastSeen ?? _peer.lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    final peer = _peer;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: ChatRealtimeService.instance,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context), size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  tooltip: 'Voice call',
                  icon: Icon(Icons.call_rounded, color: AppTheme.text(context), size: 22),
                  onPressed: () => _startCall(context, CallType.audio),
                ),
                IconButton(
                  tooltip: 'Video call',
                  icon: Icon(Icons.videocam_rounded, color: AppTheme.text(context), size: 22),
                  onPressed: () => _startCall(context, CallType.video),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                          : [const Color(0xFFF0FDF4), const Color(0xFFF8FAFC)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Hero(
                          tag: 'avatar_${peer.id}',
                          child: PeerAvatar(
                            name: peer.name,
                            imageUrl: peer.avatarUrl,
                            radius: 52,
                            isOnline: _isOnline,
                            showOnlineDot: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          peer.displayTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppTheme.text(context),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            key: ValueKey(_presenceText),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? AppTheme.greenOnline.withValues(alpha: 0.12)
                                  : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isOnline)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.greenOnline,
                                    ),
                                  ),
                                Text(
                                  _presenceText,
                                  style: GoogleFonts.inter(
                                    color: _isOnline ? AppTheme.greenOnline : AppTheme.textSecondary(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(isDark),
                    const SizedBox(height: 16),
                    _buildContactActions(isDark),
                    const SizedBox(height: 16),
                    _buildSettingsSection(isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          if (_peer.rollNumber != null)
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'Roll Number',
              value: _peer.rollNumber!,
              copyable: true,
              onCopy: () => _copy(_peer.rollNumber!),
              isFirst: true,
              isDark: isDark,
            ),
          if (_peer.section != null)
            _InfoTile(
              icon: Icons.class_outlined,
              label: 'Section',
              value: _peer.section!,
              isDark: isDark,
            ),
          if (_peer.department != null)
            _InfoTile(
              icon: Icons.school_outlined,
              label: 'Department',
              value: _peer.department!,
              isDark: isDark,
            ),
          if (_peer.courseCode != null || _peer.courseName != null)
            _InfoTile(
              icon: Icons.menu_book_outlined,
              label: 'Course',
              value: [_peer.courseName, _peer.courseCode]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(' '),
              isDark: isDark,
            ),
          if (_peer.email != null)
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _peer.email!,
              copyable: true,
              onCopy: () => _copy(_peer.email!),
              isDark: isDark,
            ),
          if (_peer.phone != null)
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _peer.phone!,
              copyable: true,
              onCopy: () => _copy(_peer.phone!),
              isLast: true,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildContactActions(bool isDark) {
    if (_peer.phone == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _ContactButton(
            icon: Icons.call_outlined,
            label: 'Call',
            color: const Color(0xFF2DD4BF),
            onTap: () => launchUrl(Uri.parse('tel:${_peer.phone}'), mode: LaunchMode.externalApplication),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ContactButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF22C55E),
            onTap: () => launchUrl(
              Uri.parse('https://wa.me/${_peer.phone!.replaceAll('+', '').replaceAll(' ', '')}'),
              mode: LaunchMode.externalApplication,
            ),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          _SettingsRow(
            icon: _muted ? Icons.notifications_off_rounded : Icons.notifications_outlined,
            label: _muted ? 'Unmute notifications' : 'Mute notifications',
            trailing: Switch(
              value: _muted,
              onChanged: (val) async {
                HapticService.light();
                await _cache.setMuted(widget.conversationId, val);
                _repository.setMuted(widget.conversationId, val);
                setState(() => _muted = val);
              },
              activeColor: AppTheme.primary(context),
            ),
            isFirst: true,
            isDark: isDark,
          ),
          _SettingsRow(
            icon: Icons.wallpaper_outlined,
            label: 'Wallpaper & Theme',
            trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context), size: 20),
            onTap: () => showChatAppearanceSheet(
              context,
              conversationId: widget.conversationId,
            ),
            isDark: isDark,
          ),
          _SettingsRow(
            icon: Icons.block_rounded,
            label: _blocked ? 'Unblock contact' : 'Block contact',
            labelColor: AppTheme.errorRed,
            trailing: Switch(
              value: _blocked,
              onChanged: (val) async {
                HapticService.light();
                await _cache.setBlocked(widget.conversationId, val);
                _repository.setBlocked(widget.conversationId, val);
                setState(() => _blocked = val);
              },
              activeColor: AppTheme.errorRed,
            ),
            isDark: isDark,
          ),
          _SettingsRow(
            icon: Icons.flag_outlined,
            label: 'Report contact',
            labelColor: AppTheme.errorRed,
            onTap: () {
              _repository.reportConversation(widget.conversationId, 'Reported from contact profile');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thanks — your report was submitted')),
              );
            },
            isLast: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _startCall(BuildContext context, CallType type) {
    HapticService.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: _peer,
          type: type,
          direction: CallDirection.outgoing,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  final VoidCallback? onCopy;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.onCopy,
    this.isFirst = false,
    this.isLast = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: !isLast
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary(context), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary(context)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = labelColor ?? AppTheme.text(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: !isLast
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, color: labelColor ?? AppTheme.textSecondary(context), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: c,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
