import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';

/// In-conversation search.
///
/// Filters by category (Messages / Date / PDF / Media / Assignments /
/// Attendance / Links / Replies), free-text matching across text, sender,
/// attachment names, captions and reply previews, live match highlighting,
/// a live result count and realtime re-filtering as messages arrive.
class MessageSearchScreen extends StatefulWidget {
  final ChatScreenController controller;

  const MessageSearchScreen({super.key, required this.controller});

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  static final List<ChatSearchCategory> _categories = [
    ChatSearchCategory.all,
    ChatSearchCategory.messages,
    ChatSearchCategory.date,
    ChatSearchCategory.pdf,
    ChatSearchCategory.media,
    ChatSearchCategory.assignments,
    ChatSearchCategory.attendance,
    ChatSearchCategory.links,
    ChatSearchCategory.replies,
  ];

  final TextEditingController _search = TextEditingController();
  final FocusNode _focus = FocusNode();
  ChatSearchCategory _category = ChatSearchCategory.all;
  DateTime? _selectedDate;
  Timer? _debounce;

  static IconData _categoryIcon(ChatSearchCategory category) {
    switch (category) {
      case ChatSearchCategory.all:
        return Icons.search_rounded;
      case ChatSearchCategory.messages:
        return Icons.chat_bubble_rounded;
      case ChatSearchCategory.date:
        return Icons.calendar_month_rounded;
      case ChatSearchCategory.pdf:
        return Icons.picture_as_pdf_rounded;
      case ChatSearchCategory.media:
        return Icons.perm_media_rounded;
      case ChatSearchCategory.assignments:
        return Icons.assignment_rounded;
      case ChatSearchCategory.attendance:
        return Icons.assessment_rounded;
      case ChatSearchCategory.links:
        return Icons.link_rounded;
      case ChatSearchCategory.replies:
        return Icons.reply_rounded;
    }
  }

  ChatSearchFilter get _filter => ChatSearchFilter(
        query: _search.text,
        category: _category,
        date: _category == ChatSearchCategory.date ? _selectedDate : null,
      );

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _runSearch() {
    _debounce?.cancel();
    widget.controller.searchMessages(_filter);
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  void _selectCategory(ChatSearchCategory category) {
    if (category == ChatSearchCategory.date) {
      _pickDate();
      return;
    }
    setState(() => _category = category);
    _runSearch();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: 'SEARCH BY DATE',
      cancelText: 'Cancel',
      confirmText: 'Search',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary(context),
            surface: AppTheme.surface(context),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _category = ChatSearchCategory.date;
      _selectedDate = picked;
    });
    _runSearch();
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
      if (_category == ChatSearchCategory.date) _category = ChatSearchCategory.all;
    });
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _search,
          focusNode: _focus,
          autofocus: true,
          onChanged: _onChanged,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search this chat…',
            hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _search.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: AppTheme.textSecondary(context)),
                    onPressed: () {
                      _search.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => Column(
          children: [
            _buildFilterChips(context),
            if (widget.controller.isSearching)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppTheme.accentGold,
                backgroundColor: Colors.transparent,
              ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final category in _categories) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(context, category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, ChatSearchCategory category) {
    final isDate = category == ChatSearchCategory.date;
    final selected = _category == category ||
        (isDate && _selectedDate != null && _category == ChatSearchCategory.date);

    Widget label;
    if (isDate && _selectedDate != null) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded,
              size: 15, color: selected ? Colors.white : AppTheme.primary(context)),
          const SizedBox(width: 4),
          Text(DateFormat('dd MMM').format(_selectedDate!),
              style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      );
    } else {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(category),
              size: 15, color: selected ? Colors.white : AppTheme.textSecondary(context)),
          const SizedBox(width: 4),
          Text(category.label,
              style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      );
    }

    return FilterChip(
      label: label,
      selected: selected,
      selectedColor: AppTheme.primary(context),
      backgroundColor: AppTheme.surface(context),
      side: BorderSide(color: selected ? AppTheme.primary(context) : AppTheme.border(context)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => _selectCategory(category),
      onDeleted: isDate && _selectedDate != null ? _clearDate : null,
      deleteIcon: const Icon(Icons.close_rounded, size: 15),
    );
  }

  Widget _buildBody(BuildContext context) {
    final results = widget.controller.searchResults;
    final filter = _filter;
    final active = filter.isActive;

    if (!active) {
      return const _EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Search this chat',
        subtitle:
            'Find messages, PDFs, media, assignments, attendance, links and replies.',
      );
    }
    if (widget.controller.isSearching && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: _noResultsSubtitle(filter),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} result${results.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text('Tap to jump to message',
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context).withValues(alpha: 0.8),
                        fontSize: 11)),
              ],
            ),
          );
        }
        final m = results[index - 1];
        return _ResultTile(
          message: m,
          query: filter.query,
          onTap: () {
            Navigator.pop(
              context,
              ChatSearchJump(
                messageIds: [for (final r in results) r.id],
                index: index - 1,
              ),
            );
          },
        );
      },
    );
  }

  String _noResultsSubtitle(ChatSearchFilter filter) {
    final parts = <String>[];
    if (filter.category != ChatSearchCategory.all && filter.category != ChatSearchCategory.date) {
      parts.add(filter.category.label.toLowerCase());
    }
    if (filter.hasDate) parts.add(DateFormat('dd MMM yyyy').format(filter.date!));
    if (filter.hasQuery) parts.add('“${filter.query.trim()}”');
    if (parts.isEmpty) return 'Nothing matched your search.';
    return 'Nothing matched ${parts.join(' · ')}.';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppTheme.primary(context)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.inter(
                    color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context), fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final ChatMessage message;
  final String query;
  final VoidCallback onTap;

  const _ResultTile({required this.message, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.direction == MessageDirection.outgoing;
    final snippet = _snippetFor(message, query);
    final badge = _badgeFor(context, message);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(badge.icon, size: 19, color: badge.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isOutgoing ? 'You' : message.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: isOutgoing ? AppTheme.primary(context) : AppTheme.text(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(ChatTimeFormat.bubbleTime(message.timestamp),
                          style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    _highlight(context, snippet, query),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prefers the field that actually contains the query so the highlight is
  /// visible; otherwise falls back to the message text / content summary.
  String _snippetFor(ChatMessage m, String query) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      if (m.text.toLowerCase().contains(q)) return m.text;
      for (final a in m.attachments) {
        if (a.name.toLowerCase().contains(q)) return a.name;
        if ((a.caption ?? '').toLowerCase().contains(q)) return a.caption!;
      }
      if ((m.replyTo?.text.toLowerCase().contains(q) ?? false)) return m.replyTo!.text;
      if ((m.replyTo?.senderName.toLowerCase().contains(q) ?? false)) {
        return '↩ ${m.replyTo!.senderName}';
      }
      if (m.senderName.toLowerCase().contains(q)) return m.senderName;
    }
    return m.text.isNotEmpty ? m.text : m.contentSummary;
  }

  ({IconData icon, Color color}) _badgeFor(BuildContext context, ChatMessage m) {
    const gold = Color(0xFFFACC15);
    const teal = Color(0xFF14B8A6);
    const blue = Color(0xFF3B82F6);
    const green = Color(0xFF22C55E);
    const red = Color(0xFFEF4444);
    const purple = Color(0xFFA855F7);
    const orange = Color(0xFFF97316);

    if (m.replyTo != null) return (icon: Icons.reply_rounded, color: blue);
    switch (m.type) {
      case MessageContentType.image:
        return (icon: Icons.photo_rounded, color: purple);
      case MessageContentType.gif:
        return (icon: Icons.gif_box_rounded, color: purple);
      case MessageContentType.video:
        return (icon: Icons.movie_rounded, color: purple);
      case MessageContentType.pdf:
        return (icon: Icons.picture_as_pdf_rounded, color: red);
      case MessageContentType.document:
      case MessageContentType.word:
      case MessageContentType.excel:
      case MessageContentType.powerpoint:
      case MessageContentType.zip:
        return (icon: Icons.insert_drive_file_rounded, color: blue);
      case MessageContentType.voice:
      case MessageContentType.audio:
        return (icon: Icons.graphic_eq_rounded, color: green);
      case MessageContentType.location:
        return (icon: Icons.location_on_rounded, color: red);
      case MessageContentType.contact:
        return (icon: Icons.person_rounded, color: green);
      case MessageContentType.attendanceReport:
        return (icon: Icons.assessment_rounded, color: teal);
      case MessageContentType.assignment:
        return (icon: Icons.assignment_rounded, color: blue);
      case MessageContentType.announcement:
        return (icon: Icons.campaign_rounded, color: orange);
      case MessageContentType.system:
      case MessageContentType.emoji:
      case MessageContentType.text:
        if (m.text.contains(RegExp(r'https?://', caseSensitive: false))) {
          return (icon: Icons.link_rounded, color: gold);
        }
        return (icon: Icons.chat_bubble_rounded, color: AppTheme.textSecondary(context));
    }
  }

  TextSpan _highlight(BuildContext context, String text, String query) {
    final q = query.trim().toLowerCase();
    final baseStyle = GoogleFonts.inter(
      color: AppTheme.textSecondary(context),
      fontSize: 13,
      height: 1.3,
    );
    if (q.isEmpty) return TextSpan(text: text, style: baseStyle);

    final lowerText = text.toLowerCase();
    final spans = <InlineSpan>[];
    var start = 0;
    while (true) {
      final idx = lowerText.indexOf(q, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: const TextStyle(
          color: AppTheme.accentGold,
          fontWeight: FontWeight.w800,
          backgroundColor: Color(0x33FACC15),
        ),
      ));
      start = idx + q.length;
    }
    return TextSpan(children: spans, style: baseStyle);
  }
}
