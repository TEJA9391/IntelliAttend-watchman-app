import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class SendMessageScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const SendMessageScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _ChatMessage {
  final String id;
  final String sender;
  String text;
  final String time;
  final DateTime timestamp;
  String status;
  bool isDeleted;
  bool isStarred;

  _ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    required this.timestamp,
    this.status = 'sent',
    this.isDeleted = false,
    this.isStarred = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': sender,
        'text': text,
        'time': time,
        'timestamp': timestamp.toIso8601String(),
        'status': status,
        'isDeleted': isDeleted,
        'isStarred': isStarred,
      };

  factory _ChatMessage.fromMap(Map<dynamic, dynamic> map) => _ChatMessage(
        id: map['id'] ?? '',
        sender: map['sender'] ?? '',
        text: map['text'] ?? '',
        time: map['time'] ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
        status: map['status'] ?? 'sent',
        isDeleted: map['isDeleted'] ?? false,
        isStarred: map['isStarred'] ?? false,
      );
}

class _SendMessageScreenState extends State<SendMessageScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  late Box _chatBox;
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isTyping = false;
  bool _boxReady = false;

  String get _name => widget.student['name'] ?? 'Student';
  String get _roll => widget.student['roll_number'] ?? 'N/A';
  String get _id => widget.student['id']?.toString() ?? 'N/A';
  int get _attended => (widget.student['attended'] as num?)?.toInt() ?? 0;
  int get _total => (widget.student['total'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _chatBox = await Hive.openBox('chat_messages');
    final stored = _chatBox.get('messages_$_id');
    if (stored != null && stored is List) {
      for (final entry in stored) {
        if (entry is Map) {
          _messages.add(_ChatMessage.fromMap(entry));
        }
      }
    } else {
      // Start with empty chat - no seed messages
    }
    setState(() => _boxReady = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString() +
      (hashCode ^ _messages.length).toString();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    HapticService.selection();

    final now = DateTime.now();
    final msg = _ChatMessage(
      id: _generateId(),
      sender: 'faculty',
      text: text,
      time: _formatTime(now),
      timestamp: now,
      status: 'sent',
    );

    setState(() {
      _messages.add(msg);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();
    _persistMessages();

    // Sent -> Delivered after 1s
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => msg.status = 'delivered');
      _persistMessages();
    });

    // Delivered -> Read after 2s
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => msg.status = 'read');
      _persistMessages();
    });

    // Typing indicator disappears after 1.5s
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isTyping = false);
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  Future<void> _persistMessages() async {
    if (!_boxReady) return;
    final data = _messages.map((m) => m.toMap()).toList();
    await _chatBox.put('messages_$_id', data);
  }

  void _copyMessage(_ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message copied',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppTheme.card(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteMessage(int index) {
    setState(() => _messages.removeAt(index));
    _persistMessages();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message deleted',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showComingSoon(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action coming soon',
            style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppTheme.card(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMessageOptions(_ChatMessage msg, int index) {
    HapticService.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    msg.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _bottomSheetOption(
                  Icons.copy_rounded, 'Copy',
                  () { Navigator.pop(ctx); _copyMessage(msg); },
                  isDark,
                ),
                _bottomSheetOption(
                  Icons.delete_outline_rounded, 'Delete',
                  () { Navigator.pop(ctx); _deleteMessage(index); },
                  isDark,
                  isDestructive: true,
                ),
                _bottomSheetOption(
                  Icons.forward_rounded, 'Forward',
                  () { Navigator.pop(ctx); _showComingSoon('Forward'); },
                  isDark,
                ),
                _bottomSheetOption(
                  Icons.reply_rounded, 'Reply',
                  () { Navigator.pop(ctx); _showComingSoon('Reply'); },
                  isDark,
                ),
                _bottomSheetOption(
                  msg.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  msg.isStarred ? 'Unstar' : 'Star',
                  () {
                    Navigator.pop(ctx);
                    setState(() => msg.isStarred = !msg.isStarred);
                    _persistMessages();
                  },
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomSheetOption(
      IconData icon, String label, VoidCallback onTap, bool isDark,
      {bool isDestructive = false}) {
    final color = isDestructive
        ? AppTheme.errorRed
        : AppTheme.text(context);
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          )),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Share Attachment',
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _attachmentOption(Icons.picture_as_pdf_rounded, 'PDF',
                          AppTheme.errorRed, ctx),
                      _attachmentOption(Icons.image_rounded, 'Images',
                          AppTheme.accentPurple, ctx),
                      _attachmentOption(Icons.folder_rounded, 'Documents',
                          const Color(0xFFF59E0B), ctx),
                      _attachmentOption(Icons.slideshow_rounded, 'PPT',
                          AppTheme.accentTeal, ctx),
                      _attachmentOption(Icons.description_rounded, 'Word',
                          const Color(0xFF3B82F6), ctx),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentOption(
      IconData icon, String label, Color color, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _showComingSoon(label);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  List<_ChatMessage> get _filteredMessages {
    if (_searchQuery.isEmpty) return _messages;
    return _messages
        .where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('dd MMM yyyy').format(date);
  }

  bool _shouldShowDaySeparator(int index, List<_ChatMessage> msgs) {
    if (index == 0) return true;
    final prev = msgs[index - 1].timestamp;
    final curr = msgs[index].timestamp;
    return prev.year != curr.year ||
        prev.month != curr.month ||
        prev.day != curr.day;
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icon(Icons.done, size: 14, color: Colors.white.withOpacity(0.7));
      case 'delivered':
        return Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white.withOpacity(0.7));
      case 'read':
        return Icon(Icons.done_all_rounded, size: 14, color: AppTheme.accentTeal);
      default:
        return Icon(Icons.access_time_rounded,
            size: 12, color: Colors.white.withOpacity(0.5));
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 20),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppTheme.text(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Hero(
                  tag: 'student_avatar_$_id',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentTeal.withOpacity(0.3),
                          AppTheme.accentTeal.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initial,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentTeal)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _roll,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle,
                          size: 6, color: AppTheme.accentTeal),
                      const SizedBox(width: 4),
                      Text('Online',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentTeal)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showComingSoon('Voice call'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.call_rounded,
                        size: 16, color: AppTheme.accentTeal),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.more_vert_rounded,
                        size: 16, color: AppTheme.textSecondary(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          Expanded(
            child: !_boxReady
                ? Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accentTeal))
                : _filteredMessages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredMessages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredMessages.length) {
                            return _buildTypingIndicator();
                          }
                          final msg = _filteredMessages[index];
                          final realIndex = _messages.indexOf(msg);
                          final showDay = _shouldShowDaySeparator(
                              _filteredMessages.indexOf(msg),
                              _filteredMessages);
                          return Column(
                            children: [
                              if (showDay) _buildDaySeparator(msg.timestamp),
                              _buildMessageBubble(msg, realIndex),
                            ],
                          );
                        },
                      ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  // ─── SEARCH BAR ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: _isSearchActive
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                border: Border(
                  bottom: BorderSide(
                      color: AppTheme.border(context), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 18,
                              color: AppTheme.textSecondary(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: GoogleFonts.inter(
                                color: AppTheme.text(context),
                                fontSize: 14,
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search messages...',
                                hintStyle: GoogleFonts.inter(
                                  color: AppTheme.textSecondary(context)
                                      .withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.close_rounded,
                                  size: 16,
                                  color: AppTheme.textSecondary(context)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _isSearchActive = false;
                        _searchQuery = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.textSecondary(context)),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ─── DAY SEPARATOR ──────────────────────────────────────────────────────────

  Widget _buildDaySeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: AppTheme.border(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              _getDayLabel(date),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppTheme.border(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MESSAGE BUBBLE ─────────────────────────────────────────────────────────

  Widget _buildMessageBubble(_ChatMessage msg, int index) {
    if (msg.isDeleted) return const SizedBox.shrink();
    final isFaculty = msg.sender == 'faculty';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isFaculty ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(msg, index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: isFaculty
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFaculty
                        ? AppTheme.accentTeal
                        : isDark(context)
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isFaculty ? 16 : 4),
                      bottomRight: Radius.circular(isFaculty ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: GoogleFonts.inter(
                      color: isFaculty
                          ? Colors.white
                          : AppTheme.text(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.time,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppTheme.textSecondary(context)
                              .withOpacity(0.6),
                        ),
                      ),
                      if (isFaculty) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(msg.status),
                      ],
                      if (msg.isStarred) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.star_rounded,
                            size: 10, color: AppTheme.accentTeal.withOpacity(0.7)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ─── TYPING INDICATOR ───────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (i * 150)),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -3 * (value > 0.5 ? 2 - value * 2 : value * 2)),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary(context).withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  // ─── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.textSecondary(context).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No messages yet.\nStart a conversation!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  // ─── INPUT BAR ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.border(context), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _inputIcon(Icons.emoji_emotions_outlined, () {
            _showComingSoon('Emoji picker');
          }),
          const SizedBox(width: 4),
          _inputIcon(Icons.camera_alt_rounded, () {
            _showComingSoon('Camera');
          }),
          const SizedBox(width: 4),
          _inputIcon(Icons.attach_file_rounded, () {
            HapticService.light();
            _showAttachmentSheet();
          }),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: GoogleFonts.inter(
                    color: AppTheme.text(context), fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (_) => setState(() {}),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.inter(
                    color:
                        AppTheme.textSecondary(context).withOpacity(0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _messageController.text.trim().isEmpty
              ? _voiceButton()
              : _sendButton(),
        ],
      ),
    );
  }

  Widget _voiceButton() {
    return GestureDetector(
      onTap: () => _showComingSoon('Voice message'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic_rounded, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _sendButton() {
    return GestureDetector(
      onTap: _sendMessage,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.send_rounded, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _inputIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Icon(icon, size: 22, color: AppTheme.textSecondary(context)),
      ),
    );
  }
}
