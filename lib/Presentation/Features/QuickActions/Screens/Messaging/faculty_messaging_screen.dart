import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/dummy_data.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/faculty_message.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/messaging_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:provider/provider.dart';

double _fontSize(Responsive r, double base) {
  final w = r.screenWidth;
  if (w >= 410) return base;
  if (w >= 360) return base * 0.95;
  return base * 0.9;
}

class FacultyMessagingScreen extends StatefulWidget {
  const FacultyMessagingScreen({super.key});

  @override
  State<FacultyMessagingScreen> createState() => _FacultyMessagingScreenState();
}

class _FacultyMessagingScreenState extends State<FacultyMessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _inboxScrollController = ScrollController();
  final ScrollController _sentScrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inboxScrollController.addListener(_onInboxScroll);
    _sentScrollController.addListener(_onSentScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<MessagingController>();
      controller.loadMessages();
      controller.loadThreads();
      controller.loadTemplates();
    });
  }

  void _onInboxScroll() {
    if (_inboxScrollController.position.pixels >=
        _inboxScrollController.position.maxScrollExtent - 200) {
      context.read<MessagingController>().loadMoreMessages();
    }
  }

  void _onSentScroll() {
    if (_sentScrollController.position.pixels >=
        _sentScrollController.position.maxScrollExtent - 200) {
      context.read<MessagingController>().loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _inboxScrollController.dispose();
    _sentScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final controller = context.read<MessagingController>();
      controller.search(query);
      controller.loadMessages(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(r),
            _buildTabBar(r),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInboxTab(r),
                  _buildSentTab(r),
                  _buildComposeTab(r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(4),
        vertical: r.hp(1),
      ),
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
          SizedBox(width: r.spacingM),
          Expanded(
            child: Text(
              'Messaging',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: _fontSize(r, 20),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Consumer<MessagingController>(
            builder: (context, controller, _) {
              final unread = controller.unreadCount;
              if (unread == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread unread',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.accentTeal,
                    fontSize: _fontSize(r, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Responsive r) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.wp(4)),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.accentTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary(context),
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: _fontSize(r, 13),
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: _fontSize(r, 13),
        ),
        labelPadding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.all(r.wp(0.8)),
        tabs: const [
          Tab(text: 'Inbox'),
          Tab(text: 'Sent'),
          Tab(text: 'Compose'),
        ],
      ),
    );
  }

  Widget _buildInboxTab(Responsive r) {
    return Consumer<MessagingController>(
      builder: (context, controller, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(r, controller),
            _buildFilterChips(r, controller),
            Expanded(
              child: _buildMessageList(
                controller: controller,
                messages: controller.messages,
                isSent: false,
                scrollController: _inboxScrollController,
                isLoading: controller.isLoading,
                isLoadingMore: controller.isLoadingMore,
                error: controller.error,
                hasMore: controller.hasMore,
                onRefresh: () => controller.refresh(),
                onRetry: () => controller.loadMessages(),
                r: r,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSentTab(Responsive r) {
    return Consumer<MessagingController>(
      builder: (context, controller, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(r, controller),
            Expanded(
              child: _buildMessageList(
                controller: controller,
                messages: controller.messages,
                isSent: true,
                scrollController: _sentScrollController,
                isLoading: controller.isLoading,
                isLoadingMore: controller.isLoadingMore,
                error: controller.error,
                hasMore: controller.hasMore,
                onRefresh: () => controller.refresh(),
                onRetry: () => controller.loadMessages(),
                r: r,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(Responsive r, MessagingController controller) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.wp(4),
        r.hp(1.5),
        r.wp(4),
        r.hp(1),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.inter(
          color: AppTheme.text(context),
          fontSize: r.fontSizeS,
        ),
        maxLines: 1,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: GoogleFonts.inter(
            color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
            fontSize: r.fontSizeS,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.textSecondary(context),
              size: r.iconM),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary(context),
                      size: r.iconM),
                )
              : null,
          filled: true,
          fillColor: AppTheme.card(context),
          contentPadding: EdgeInsets.symmetric(
              horizontal: r.spacingM, vertical: r.spacingS),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(Responsive r, MessagingController controller) {
    final filters = <(MessageType?, String)>[
      (null, 'All'),
      (MessageType.announcement, 'Announcements'),
      (MessageType.classMessage, 'Class'),
      (MessageType.individual, 'Individual'),
      (MessageType.parent, 'Parents'),
    ];

    return SizedBox(
      height: r.hp(5.5),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(4),
          vertical: r.hp(0.8),
        ),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: r.spacingS),
        itemBuilder: (context, index) {
          final (type, label) = filters[index];
          final isSelected = controller.selectedType == type;

          return GestureDetector(
            onTap: () {
              controller.setTypeFilter(type);
              controller.loadMessages(type: type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: r.wp(3),
                vertical: r.hp(0.6),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentTeal
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentTeal
                      : AppTheme.border(context),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textSecondary(context),
                    fontSize: _fontSize(r, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList({
    required MessagingController controller,
    required List<FacultyMessage> messages,
    required bool isSent,
    required ScrollController scrollController,
    required bool isLoading,
    required bool isLoadingMore,
    required String? error,
    required bool hasMore,
    required VoidCallback onRefresh,
    required VoidCallback onRetry,
    required Responsive r,
  }) {
    if (isLoading && messages.isEmpty) {
      return _buildShimmerLoading(r);
    }

    if (error != null && messages.isEmpty) {
      return _buildErrorState(error, onRetry, r);
    }

    if (messages.isEmpty) {
      return _buildEmptyState(isSent, r);
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accentTeal,
      backgroundColor: AppTheme.card(context),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(4),
          vertical: r.hp(1),
        ),
        itemCount: messages.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return _buildLoadingMoreIndicator(r);
          }
          final message = messages[index];
          return _buildMessageCard(
            message: message,
            isSent: isSent,
            r: r,
            onTap: () => _navigateToDetail(message, isSent),
          );
        },
      ),
    );
  }

  Widget _buildMessageCard({
    required FacultyMessage message,
    required bool isSent,
    required Responsive r,
    required VoidCallback onTap,
  }) {
    final isUnread = !message.isRead && !isSent;
    final initials = message.senderName.isNotEmpty
        ? message.senderName[0].toUpperCase()
        : '?';
    final displayTime = _formatRelativeTime(message.createdAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showMessageOptions(message, isSent, r),
      child: Container(
        margin: EdgeInsets.only(bottom: r.hp(0.8)),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isUnread ? AppTheme.accentTeal : AppTheme.border(context),
              width: isUnread ? 3 : 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(r.wp(3)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.wp(10),
                height: r.wp(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getTypeColor(message.type).withValues(alpha: 0.3),
                      _getTypeColor(message.type).withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _getTypeColor(message.type),
                      fontSize: _fontSize(r, 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.spacingM),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isSent
                                ? (message.recipientName ?? 'Unknown')
                                : message.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.text(context),
                              fontSize: _fontSize(r, 14),
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: r.spacingS),
                        _buildTypeBadge(message.type, r),
                      ],
                    ),
                    SizedBox(height: r.hp(0.3)),
                    Text(
                      message.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: _fontSize(r, 13),
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: r.hp(0.2)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context),
                              fontSize: _fontSize(r, 12),
                            ),
                          ),
                        ),
                        SizedBox(width: r.spacingS),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary(context),
                                fontSize: _fontSize(r, 10),
                              ),
                            ),
                            if (!isSent) ...[
                              SizedBox(width: r.spacingXS),
                              _buildReadIndicator(message.isRead, r),
                            ],
                            if (isSent) ...[
                              SizedBox(width: r.spacingXS),
                              _buildStatusIcon(message.status, r),
                            ],
                          ],
                        ),
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

  Widget _buildTypeBadge(MessageType type, Responsive r) {
    final (label, color) = switch (type) {
      MessageType.announcement => ('Announce', const Color(0xFF3B82F6)),
      MessageType.classMessage => ('Class', const Color(0xFF22C55E)),
      MessageType.individual => ('Direct', AppTheme.accentTeal),
      MessageType.parent => ('Parent', AppTheme.accentPurple),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(1.8),
        vertical: r.hp(0.3),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: _fontSize(r, 9),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildReadIndicator(bool isRead, Responsive r) {
    return Container(
      width: r.wp(2),
      height: r.wp(2),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : AppTheme.accentTeal,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status, Responsive r) {
    final (icon, color) = switch (status) {
      MessageStatus.sending => (
          Icons.access_time_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.sent => (
          Icons.check_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.delivered => (
          Icons.done_all_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.read => (
          Icons.done_all_rounded,
          AppTheme.accentTeal,
        ),
      MessageStatus.failed => (
          Icons.error_outline_rounded,
          AppTheme.errorRed,
        ),
    };

    return Icon(icon, size: r.wp(3.2), color: color);
  }

  Widget _buildShimmerLoading(Responsive r) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(4),
        vertical: r.hp(1),
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: r.hp(0.8)),
          padding: EdgeInsets.all(r.wp(3)),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.wp(10),
                height: r.wp(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.spacingM),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: r.hp(1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        SizedBox(width: r.spacingS),
                        Container(
                          width: r.wp(14),
                          height: r.hp(1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.hp(0.6)),
                    Container(
                      height: r.hp(1.5),
                      width: r.wp(55),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    SizedBox(height: r.hp(0.5)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: r.hp(1.2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(width: r.spacingS),
                        Container(
                          width: r.wp(12),
                          height: r.hp(1.2),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isSent, Responsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.wp(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(r.wp(6)),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSent ? Icons.send_rounded : Icons.inbox_rounded,
                size: r.wp(12),
                color: AppTheme.accentTeal.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: r.spacingL),
            Text(
              isSent ? 'No sent messages' : 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: _fontSize(r, 18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.spacingS),
            Text(
              isSent
                  ? 'Messages you send will appear here'
                  : 'You have no messages in your inbox',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: _fontSize(r, 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry, Responsive r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.wp(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(r.wp(4)),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: r.wp(10),
                color: AppTheme.errorRed,
              ),
            ),
            SizedBox(height: r.spacingL),
            Text(
              'Something went wrong',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: _fontSize(r, 18),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.spacingS),
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: _fontSize(r, 13),
              ),
            ),
            SizedBox(height: r.spacingL),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.wp(6),
                  vertical: r.hp(1.2),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Retry',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: _fontSize(r, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.hp(2)),
      child: Center(
        child: SizedBox(
          width: r.wp(5),
          height: r.wp(5),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildComposeTab(Responsive r) {
    return _ComposeForm(r: r);
  }

  void _navigateToDetail(FacultyMessage message, bool isSent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MessageDetailScreen(message: message, isSent: isSent),
      ),
    );
    if (!isSent && !message.isRead) {
      context.read<MessagingController>().markAsRead(message.id);
    }
  }

  void _showMessageOptions(FacultyMessage message, bool isSent, Responsive r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.all(r.wp(4)),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: r.hp(1.5)),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.hp(1)),
            _buildOptionTile(
              context: context,
              icon: Icons.visibility_rounded,
              label: 'View Details',
              onTap: () {
                Navigator.pop(context);
                _navigateToDetail(message, isSent);
              },
              r: r,
            ),
            if (!isSent && !message.isRead)
              _buildOptionTile(
                context: context,
                icon: Icons.mark_email_read_rounded,
                label: 'Mark as Read',
                onTap: () {
                  Navigator.pop(context);
                  context.read<MessagingController>().markAsRead(message.id);
                },
                r: r,
              ),
            _buildOptionTile(
              context: context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppTheme.errorRed,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(message, r);
              },
              r: r,
            ),
            SizedBox(height: r.hp(1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Responsive r,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.text(context), size: 22),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: color ?? AppTheme.text(context),
          fontSize: _fontSize(r, 14),
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(FacultyMessage message, Responsive r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Message?',
          style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This message will be permanently deleted.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: _fontSize(r, 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MessagingController>().deleteMessage(message.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message deleted', style: GoogleFonts.inter(fontSize: 13)),
                  backgroundColor: AppTheme.errorRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }

  Color _getTypeColor(MessageType type) => switch (type) {
        MessageType.announcement => const Color(0xFF3B82F6),
        MessageType.classMessage => const Color(0xFF22C55E),
        MessageType.individual => AppTheme.accentTeal,
        MessageType.parent => AppTheme.accentPurple,
      };
}

class _ComposeForm extends StatefulWidget {
  final Responsive r;

  const _ComposeForm({required this.r});

  @override
  State<_ComposeForm> createState() => _ComposeFormState();
}

class _ComposeFormState extends State<_ComposeForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _recipientSearchController = TextEditingController();

  String? _selectedRecipientId;
  String? _selectedRecipientName;
  final List<String> _selectedRecipientIds = [];
  final List<String> _selectedRecipientNames = [];
  bool _selectAllStudents = false;
  final Set<String> _expandedSections = {};
  final Set<String> _sectionSelectAll = {};
  MessageType _selectedType = MessageType.individual;
  MessagePriority _selectedPriority = MessagePriority.normal;
  MessageCategory _selectedCategory = MessageCategory.text;
  bool _showRecipientDropdown = false;
  bool _showSchedulePicker = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  List<PlatformFile> _attachments = [];
  int _bodyCharCount = 0;
  String _recipientSearchQuery = '';

  static final List<Map<String, String>> _staticRecipients = [
    {'id': 'STU001', 'name': 'Aarav Sharma', 'section': 'A'},
    {'id': 'STU003', 'name': 'Rohan Gupta', 'section': 'A'},
    {'id': 'STU007', 'name': 'Arjun Mehta', 'section': 'B'},
    {'id': 'STU012', 'name': 'Sneha Patel', 'section': 'B'},
    {'id': 'STU015', 'name': 'Vikram Singh', 'section': 'A'},
    {'id': 'STU020', 'name': 'Meera Nair', 'section': 'B'},
    {'id': 'PRN001', 'name': 'Mr. Rajesh Sharma (Parent)', 'section': 'General'},
    {'id': 'PRN003', 'name': 'Mrs. Sunita Gupta (Parent)', 'section': 'General'},
    {'id': 'PRN007', 'name': 'Mr. Vikram Mehta (Parent)', 'section': 'General'},
  ];

  List<Map<String, String>> get _allRecipients {
    final base = List<Map<String, String>>.from(_staticRecipients);
    final students = DummyDataGenerator.generateStudents();
    for (final s in students) {
      final id = 'stu_${s.id.split('_').last}';
      final name = s.name;
      if (!base.any((r) => r['id'] == id)) {
        base.add({'id': id, 'name': name, 'section': s.section ?? 'General'});
      }
    }
    for (final r in base) {
      r.putIfAbsent('section', () => 'General');
    }
    return base;
  }

  List<Map<String, String>> get _filteredRecipients {
    if (_recipientSearchQuery.isEmpty) return _allRecipients;
    final q = _recipientSearchQuery.toLowerCase();
    return _allRecipients
        .where((r) => r['name']!.toLowerCase().contains(q) || r['id']!.toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<Map<String, String>>> get _recipientsBySection {
    final map = <String, List<Map<String, String>>>{};
    for (final r in _filteredRecipients) {
      final section = r['section'] ?? 'General';
      map.putIfAbsent(section, () => []).add(r);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(() {
      final len = _bodyController.text.length;
      if (len != _bodyCharCount) {
        setState(() => _bodyCharCount = len);
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _recipientSearchController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      (_selectedRecipientId != null || _selectedRecipientIds.isNotEmpty || _selectAllStudents) &&
      _subjectController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;

    final confirmed = await _showSendConfirmation();
    if (!confirmed || !mounted) return;

    final controller = context.read<MessagingController>();

    DateTime? scheduledAt;
    if (_showSchedulePicker && _scheduledDate != null && _scheduledTime != null) {
      scheduledAt = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    final bool isBroadcast = _selectAllStudents || _selectedRecipientIds.length > 1;
    final String recipientId = _selectedRecipientId ?? (_selectedRecipientIds.isNotEmpty ? _selectedRecipientIds.first : 'all');

    final success = await controller.sendMessage(
      recipientId: recipientId,
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
      type: _selectedType,
      priority: _selectedPriority,
      category: _selectedCategory,
      scheduledAt: scheduledAt,
      attachments: _attachments.map((f) => f.name).toList(),
      recipientGroup: isBroadcast ? RecipientGroup.entireClass : RecipientGroup.individual,
      recipientIds: isBroadcast && _selectedRecipientIds.isNotEmpty ? _selectedRecipientIds : null,
    );

    if (!mounted) return;

    if (success) {
      _showSuccessAnimation();
      _formKey.currentState?.reset();
      _subjectController.clear();
      _bodyController.clear();
      setState(() {
        _selectedRecipientId = null;
        _selectedRecipientName = null;
        _selectedRecipientIds.clear();
        _selectedRecipientNames.clear();
        _selectAllStudents = false;
        _expandedSections.clear();
        _sectionSelectAll.clear();
        _selectedType = MessageType.individual;
        _selectedPriority = MessagePriority.normal;
        _selectedCategory = MessageCategory.text;
        _showSchedulePicker = false;
        _scheduledDate = null;
        _scheduledTime = null;
        _attachments = [];
        _bodyCharCount = 0;
        _recipientSearchQuery = '';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.error ?? 'Failed to send message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _showSendConfirmation() async {
    final r = widget.r;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Send',
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: _fontSize(r, 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send "${_subjectController.text.trim()}" to ${_selectedRecipientName ?? 'recipient'}?',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: _fontSize(r, 13),
              ),
            ),
            if (_showSchedulePicker && _scheduledDate != null) ...[
              SizedBox(height: r.spacingS),
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.8)),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 16, color: AppTheme.accentTeal),
                    SizedBox(width: r.spacingXS),
                    Text(
                      'Scheduled for ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} ${_scheduledTime != null ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}' : ''}',
                      style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: _fontSize(r, 11), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            if (_attachments.isNotEmpty) ...[
              SizedBox(height: r.spacingS),
              Text(
                '${_attachments.length} attachment(s)',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: _fontSize(r, 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _showSchedulePicker ? 'Schedule' : 'Send',
              style: GoogleFonts.inter(color: AppTheme.accentTeal, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessAnimation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Message sent successfully',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to pick file: $e',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _pickScheduleDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.accentTeal),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.accentTeal),
          ),
          child: child!,
        ),
      );
      setState(() {
        _scheduledDate = date;
        _scheduledTime = time ?? const TimeOfDay(hour: 9, minute: 0);
      });
    }
  }

  void _applyTemplate(MessageTemplate template) {
    setState(() {
      _subjectController.text = template.subject;
      _bodyController.text = template.body;
      _bodyCharCount = template.body.length;
      _selectedCategory = template.category;
      _selectedPriority = template.priority;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(4),
          vertical: r.hp(1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateSelector(r),
            SizedBox(height: r.spacingM),
            _buildRecipientSelector(r),
            SizedBox(height: r.spacingM),
            _buildTypeSelector(r),
            SizedBox(height: r.spacingM),
            _buildPrioritySelector(r),
            SizedBox(height: r.spacingM),
            _buildSubjectField(r),
            SizedBox(height: r.spacingM),
            _buildBodyField(r),
            SizedBox(height: r.spacingM),
            _buildAttachmentSection(r),
            SizedBox(height: r.spacingM),
            _buildScheduleSection(r),
            SizedBox(height: r.spacingL),
            _buildSendButton(r),
            SizedBox(height: r.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector(Responsive r) {
    final templates = context.read<MessagingController>().templates;
    if (templates.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Templates',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingXS),
        SizedBox(
          height: r.hp(4.5),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => SizedBox(width: r.spacingS),
            itemBuilder: (context, index) {
              final tpl = templates[index];
              return GestureDetector(
                onTap: () => _applyTemplate(tpl),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.6)),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 14, color: AppTheme.accentTeal),
                      SizedBox(width: r.spacingXS),
                      Text(
                        tpl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: _fontSize(r, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _toggleSelectAllStudents() {
    setState(() {
      _selectAllStudents = !_selectAllStudents;
      _sectionSelectAll.clear();
      if (_selectAllStudents) {
        _selectedRecipientIds.clear();
        _selectedRecipientNames.clear();
        for (final r in _filteredRecipients) {
          _selectedRecipientIds.add(r['id']!);
          _selectedRecipientNames.add(r['name']!);
        }
        _selectedRecipientId = null;
        _selectedRecipientName = null;
      } else {
        _selectedRecipientIds.clear();
        _selectedRecipientNames.clear();
      }
    });
  }

  void _toggleSectionSelectAll(String section) {
    setState(() {
      final isCurrentlySelected = _sectionSelectAll.contains(section);
      final sectionRecipients = _recipientsBySection[section] ?? [];

      if (isCurrentlySelected) {
        _sectionSelectAll.remove(section);
        for (final r in sectionRecipients) {
          _selectedRecipientIds.remove(r['id']);
          _selectedRecipientNames.remove(r['name']);
        }
      } else {
        _sectionSelectAll.add(section);
        for (final r in sectionRecipients) {
          if (!_selectedRecipientIds.contains(r['id'])) {
            _selectedRecipientIds.add(r['id']!);
            _selectedRecipientNames.add(r['name']!);
          }
        }
      }

      _selectAllStudents = _sectionSelectAll.length == _recipientsBySection.length;
      _selectedRecipientId = null;
      _selectedRecipientName = null;
    });
  }

  void _toggleIndividualRecipient(Map<String, String> recipient) {
    setState(() {
      final id = recipient['id']!;
      final name = recipient['name']!;
      if (_selectedRecipientIds.contains(id)) {
        _selectedRecipientIds.remove(id);
        _selectedRecipientNames.remove(name);
      } else {
        _selectedRecipientIds.add(id);
        _selectedRecipientNames.add(name);
      }
      _selectAllStudents = false;
      _sectionSelectAll.clear();
      _selectedRecipientId = null;
      _selectedRecipientName = null;
    });
  }

  Widget _buildRecipientSelector(Responsive r) {
    final sections = _recipientsBySection;
    final sortedSections = sections.keys.toList()..sort();
    final hasAnySelected = _selectedRecipientIds.isNotEmpty || _selectAllStudents;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingXS),
        GestureDetector(
          onTap: () => setState(() => _showRecipientDropdown = !_showRecipientDropdown),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(1.3)),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showRecipientDropdown ? AppTheme.accentTeal : AppTheme.border(context),
                width: _showRecipientDropdown ? 2 : 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(Icons.person_outline_rounded, size: 20, color: AppTheme.textSecondary(context)),
                ),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: hasAnySelected
                      ? Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (_selectAllStudents)
                              _buildSelectedChip('All Students', r),
                            ..._selectedRecipientNames.take(3).map(
                              (name) => _buildSelectedChip(name, r),
                            ),
                            if (_selectedRecipientNames.length > 3)
                              _buildSelectedChip('+${_selectedRecipientNames.length - 3} more', r),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Select recipients',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context),
                              fontSize: _fontSize(r, 14),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    _showRecipientDropdown ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showRecipientDropdown) ...[
          SizedBox(height: r.spacingXS),
          Container(
            constraints: BoxConstraints(maxHeight: r.hp(50)),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentTeal, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(r.wp(3), r.spacingXS, r.wp(3), r.spacingXS),
                  child: TextField(
                    controller: _recipientSearchController,
                    onChanged: (v) => setState(() => _recipientSearchQuery = v),
                    style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: _fontSize(r, 14)),
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID...',
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                        fontSize: _fontSize(r, 14),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary(context), size: 20),
                      suffixIcon: _recipientSearchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _recipientSearchController.clear();
                                setState(() => _recipientSearchQuery = '');
                              },
                              child: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.surface(context),
                      contentPadding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppTheme.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                      ),
                    ),
                  ),
                ),
                // Select All Students option
                Container(
                  margin: EdgeInsets.symmetric(horizontal: r.wp(3)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleSelectAllStudents,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(1)),
                        decoration: BoxDecoration(
                          color: _selectAllStudents
                              ? AppTheme.accentTeal.withValues(alpha: 0.1)
                              : AppTheme.surface(context).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectAllStudents
                                ? AppTheme.accentTeal.withValues(alpha: 0.3)
                                : AppTheme.border(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _selectAllStudents ? AppTheme.accentTeal : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _selectAllStudents ? AppTheme.accentTeal : AppTheme.textSecondary(context).withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: _selectAllStudents
                                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: r.spacingS),
                            Icon(Icons.group_rounded, size: 18, color: _selectAllStudents ? AppTheme.accentTeal : AppTheme.textSecondary(context)),
                            SizedBox(width: r.spacingS),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select All Students',
                                    style: GoogleFonts.inter(
                                      color: _selectAllStudents ? AppTheme.accentTeal : AppTheme.text(context),
                                      fontSize: _fontSize(r, 13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_filteredRecipients.length} students',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary(context),
                                      fontSize: _fontSize(r, 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectAllStudents)
                              const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.accentTeal),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: r.spacingXS),
                // Sections
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: sortedSections.length,
                    separatorBuilder: (_, __) => SizedBox(height: r.spacingXS),
                    itemBuilder: (context, index) {
                      final section = sortedSections[index];
                      final sectionRecipients = sections[section]!;
                      final isExpanded = _expandedSections.contains(section);
                      final isSectionAllSelected = _sectionSelectAll.contains(section);
                      final selectedCount = sectionRecipients
                          .where((r) => _selectedRecipientIds.contains(r['id']))
                          .length;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Section header
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: r.wp(3)),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() {
                                  if (isExpanded) {
                                    _expandedSections.remove(section);
                                  } else {
                                    _expandedSections.add(section);
                                  }
                                }),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.9)),
                                  decoration: BoxDecoration(
                                    color: isExpanded
                                        ? AppTheme.accentTeal.withValues(alpha: 0.06)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isExpanded
                                          ? AppTheme.accentTeal.withValues(alpha: 0.2)
                                          : AppTheme.border(context).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedRotation(
                                        turns: isExpanded ? 0.25 : 0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: AppTheme.textSecondary(context),
                                        ),
                                      ),
                                      SizedBox(width: r.spacingS),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentTeal.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Section $section',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.accentTeal,
                                            fontSize: _fontSize(r, 11),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: r.spacingS),
                                      Expanded(
                                        child: Text(
                                          '${sectionRecipients.length} students${selectedCount > 0 ? ' • $selectedCount selected' : ''}',
                                          style: GoogleFonts.inter(
                                            color: AppTheme.textSecondary(context),
                                            fontSize: _fontSize(r, 11),
                                          ),
                                        ),
                                      ),
                                      if (isSectionAllSelected)
                                        Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentTeal),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Expanded section content
                          if (isExpanded) ...[
                            SizedBox(height: r.spacingXS),
                            // Section Select All
                            Container(
                              margin: EdgeInsets.fromLTRB(r.wp(6), 0, r.wp(3), 0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleSectionSelectAll(section),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: r.wp(2), vertical: r.hp(0.6)),
                                    decoration: BoxDecoration(
                                      color: isSectionAllSelected
                                          ? AppTheme.accentTeal.withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isSectionAllSelected ? AppTheme.accentTeal : Colors.transparent,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: isSectionAllSelected
                                                  ? AppTheme.accentTeal
                                                  : AppTheme.textSecondary(context).withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSectionAllSelected
                                              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                              : null,
                                        ),
                                        SizedBox(width: r.spacingS),
                                        Icon(Icons.select_all_rounded, size: 16, color: AppTheme.accentTeal),
                                        SizedBox(width: r.spacingS),
                                        Expanded(
                                          child: Text(
                                            'Select All',
                                            style: GoogleFonts.inter(
                                              color: AppTheme.accentTeal,
                                              fontSize: _fontSize(r, 12),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: r.spacingXS),
                            // Individual students
                            ...sectionRecipients.map((recipient) {
                              final isSelected = _selectedRecipientIds.contains(recipient['id']);
                              final initials = recipient['name']!.isNotEmpty
                                  ? recipient['name']![0].toUpperCase()
                                  : '?';

                              return Container(
                                margin: EdgeInsets.fromLTRB(r.wp(6), 0, r.wp(3), 0),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _toggleIndividualRecipient(recipient),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: r.wp(2), vertical: r.hp(0.6)),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.accentTeal.withValues(alpha: 0.08)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppTheme.accentTeal : Colors.transparent,
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppTheme.accentTeal
                                                    : AppTheme.textSecondary(context).withValues(alpha: 0.4),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                                : null,
                                          ),
                                          SizedBox(width: r.spacingS),
                                          Container(
                                            width: r.wp(6),
                                            height: r.wp(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentTeal.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: GoogleFonts.inter(
                                                  color: AppTheme.accentTeal,
                                                  fontSize: _fontSize(r, 10),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: r.spacingS),
                                          Expanded(
                                            child: Text(
                                              recipient['name']!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: isSelected ? AppTheme.accentTeal : AppTheme.text(context),
                                                fontSize: _fontSize(r, 12),
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentTeal),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedChip(String label, Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.wp(2), vertical: r.hp(0.3)),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: AppTheme.accentTeal,
          fontSize: _fontSize(r, 10),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Responsive r) {
    final types = [
      (MessageType.individual, 'Individual', Icons.person_outline_rounded),
      (MessageType.classMessage, 'Class Message', Icons.class_outlined),
      (MessageType.announcement, 'Announcement', Icons.campaign_outlined),
      (MessageType.parent, 'Parent', Icons.family_restroom_outlined),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message Type',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingXS),
        Wrap(
          spacing: r.spacingS,
          runSpacing: r.spacingS,
          children: types.map((entry) {
            final type = entry.$1;
            final label = entry.$2;
            final icon = entry.$3;
            final isSelected = _selectedType == type;
            final color = _typeColor(type);

            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.8)),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.border(context),
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: isSelected ? color : AppTheme.textSecondary(context)),
                    SizedBox(width: r.spacingXS),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isSelected ? color : AppTheme.textSecondary(context),
                        fontSize: _fontSize(r, 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector(Responsive r) {
    final priorities = [
      (MessagePriority.normal, 'Normal', AppTheme.textSecondary(context)),
      (MessagePriority.important, 'Important', const Color(0xFFFBBF24)),
      (MessagePriority.urgent, 'Urgent', const Color(0xFFF97316)),
      (MessagePriority.emergency, 'Emergency', AppTheme.errorRed),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingXS),
        Wrap(
          spacing: r.spacingS,
          runSpacing: r.spacingS,
          children: priorities.map((entry) {
            final priority = entry.$1;
            final label = entry.$2;
            final color = entry.$3;
            final isSelected = _selectedPriority == priority;

            return GestureDetector(
              onTap: () => setState(() => _selectedPriority = priority),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.6)),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.border(context),
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSelected ? color : AppTheme.textSecondary(context),
                    fontSize: _fontSize(r, 11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubjectField(Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingXS),
        TextFormField(
          controller: _subjectController,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: _fontSize(r, 14)),
          maxLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Enter message subject',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontSize: _fontSize(r, 14),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Subject is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBodyField(Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Message',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: _fontSize(r, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$_bodyCharCount / 2000',
              style: GoogleFonts.inter(
                color: _bodyCharCount > 2000
                    ? AppTheme.errorRed
                    : _bodyCharCount > 1800
                        ? const Color(0xFFFBBF24)
                        : AppTheme.textSecondary(context),
                fontSize: _fontSize(r, 11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingXS),
        TextFormField(
          controller: _bodyController,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: _fontSize(r, 14)),
          minLines: 6,
          maxLines: 12,
          maxLength: 2000,
          onChanged: (_) => setState(() {}),
          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
          decoration: InputDecoration(
            hintText: 'Write your message here...',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
              fontSize: _fontSize(r, 14),
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Message body is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAttachmentSection(Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickAttachment,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(1.2)),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attach_file_rounded, size: 20, color: AppTheme.textSecondary(context)),
                SizedBox(width: r.spacingS),
                Text(
                  'Add Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: _fontSize(r, 13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          SizedBox(height: r.spacingS),
          ...List.generate(_attachments.length, (index) {
            final file = _attachments[index];
            return Container(
              margin: EdgeInsets.only(bottom: r.spacingXS),
              padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.6)),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_rounded, size: 16, color: AppTheme.accentTeal),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: _fontSize(r, 12),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeAttachment(index),
                    child: Icon(Icons.close_rounded, size: 16, color: AppTheme.errorRed),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildScheduleSection(Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showSchedulePicker = !_showSchedulePicker),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(1)),
            decoration: BoxDecoration(
              color: _showSchedulePicker
                  ? AppTheme.accentPurple.withValues(alpha: 0.08)
                  : AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showSchedulePicker ? AppTheme.accentPurple.withValues(alpha: 0.3) : AppTheme.border(context),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: _showSchedulePicker ? AppTheme.accentPurple : AppTheme.textSecondary(context),
                ),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Text(
                    _showSchedulePicker
                        ? (_scheduledDate != null
                            ? 'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} ${_scheduledTime != null ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}' : ''}'
                            : 'Pick date & time')
                        : 'Schedule Later',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _showSchedulePicker ? AppTheme.accentPurple : AppTheme.textSecondary(context),
                      fontSize: _fontSize(r, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_showSchedulePicker && _scheduledDate != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _scheduledDate = null;
                      _scheduledTime = null;
                    }),
                    child: Icon(Icons.close_rounded, size: 16, color: AppTheme.errorRed),
                  )
                else if (_showSchedulePicker)
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.accentPurple),
              ],
            ),
          ),
        ),
        if (_showSchedulePicker && _scheduledDate == null) ...[
          SizedBox(height: r.spacingS),
          GestureDetector(
            onTap: _pickScheduleDate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.wp(3), vertical: r.hp(0.8)),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  'Pick Date & Time',
                  style: GoogleFonts.inter(
                    color: AppTheme.accentPurple,
                    fontSize: _fontSize(r, 13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSendButton(Responsive r) {
    return Consumer<MessagingController>(
      builder: (context, controller, _) {
        return GestureDetector(
          onTap: _canSend && !controller.isSending ? _send : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: r.hp(1.6)),
            decoration: BoxDecoration(
              color: _canSend && !controller.isSending
                  ? AppTheme.accentTeal
                  : AppTheme.accentTeal.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _canSend && !controller.isSending
                  ? [
                      BoxShadow(
                        color: AppTheme.accentTeal.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: controller.isSending
                  ? SizedBox(
                      width: r.wp(5),
                      height: r.wp(5),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                        SizedBox(width: r.spacingS),
                        Text(
                          _showSchedulePicker ? 'Schedule Message' : 'Send Message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: _fontSize(r, 15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Color _typeColor(MessageType type) => switch (type) {
        MessageType.announcement => const Color(0xFF3B82F6),
        MessageType.classMessage => const Color(0xFF22C55E),
        MessageType.individual => AppTheme.accentTeal,
        MessageType.parent => AppTheme.accentPurple,
      };
}

class _MessageDetailScreen extends StatelessWidget {
  final FacultyMessage message;
  final bool isSent;

  const _MessageDetailScreen({required this.message, required this.isSent});

  String _formatFullDate(DateTime dateTime) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final hourDisplay = hour == 0 ? 12 : hour;
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}, $hourDisplay:$minute $ampm';
  }

  Color _typeColor(MessageType type) => switch (type) {
        MessageType.announcement => const Color(0xFF3B82F6),
        MessageType.classMessage => const Color(0xFF22C55E),
        MessageType.individual => AppTheme.accentTeal,
        MessageType.parent => AppTheme.accentPurple,
      };

  Widget _buildDetailStatusIcon(
      BuildContext context, MessageStatus status, Responsive r) {
    final (icon, color) = switch (status) {
      MessageStatus.sending => (
          Icons.access_time_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.sent => (
          Icons.check_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.delivered => (
          Icons.done_all_rounded,
          AppTheme.textSecondary(context),
        ),
      MessageStatus.read => (
          Icons.done_all_rounded,
          AppTheme.accentTeal,
        ),
      MessageStatus.failed => (
          Icons.error_outline_rounded,
          AppTheme.errorRed,
        ),
    };
    return Icon(icon, size: r.wp(3.2), color: color);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailHeader(context, r),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: r.wp(4),
                  vertical: r.hp(1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailTypeBadge(context, r),
                    SizedBox(height: r.spacingM),
                    _buildDetailSubject(context, r),
                    SizedBox(height: r.spacingS),
                    _buildDetailMeta(context, r),
                    SizedBox(height: r.spacingL),
                    _buildDetailBody(context, r),
                    if (message.attachments.isNotEmpty) ...[
                      SizedBox(height: r.spacingL),
                      _buildAttachments(context, r),
                    ],
                    if (message.recipientCount > 1) ...[
                      SizedBox(height: r.spacingL),
                      _buildRecipientsList(context, r),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader(BuildContext context, Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(4),
        vertical: r.hp(1),
      ),
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
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent
                      ? (message.recipientName ?? 'Recipient')
                      : message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: _fontSize(r, 16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isSent ? 'Sent message' : 'Received message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: _fontSize(r, 12),
                  ),
                ),
              ],
            ),
          ),
          _buildDetailStatusBadge(context, r),
        ],
      ),
    );
  }

  Widget _buildDetailStatusBadge(BuildContext context, Responsive r) {
    final (label, color, icon) = switch (message.status) {
      MessageStatus.sending => (
          'Sending',
          AppTheme.textSecondary(context),
          Icons.access_time_rounded,
        ),
      MessageStatus.sent => (
          'Sent',
          AppTheme.textSecondary(context),
          Icons.check_rounded,
        ),
      MessageStatus.delivered => (
          'Delivered',
          const Color(0xFF3B82F6),
          Icons.done_all_rounded,
        ),
      MessageStatus.read => (
          'Read',
          AppTheme.accentTeal,
          Icons.done_all_rounded,
        ),
      MessageStatus.failed => (
          'Failed',
          AppTheme.errorRed,
          Icons.error_outline_rounded,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(2),
        vertical: r.hp(0.4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: r.spacingXS),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: color,
              fontSize: _fontSize(r, 10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTypeBadge(BuildContext context, Responsive r) {
    final (label, color) = switch (message.type) {
      MessageType.announcement => ('Announcement', const Color(0xFF3B82F6)),
      MessageType.classMessage => ('Class Message', const Color(0xFF22C55E)),
      MessageType.individual => ('Individual Message', AppTheme.accentTeal),
      MessageType.parent => ('Parent Communication', AppTheme.accentPurple),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.wp(3),
        vertical: r.hp(0.6),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: _fontSize(r, 12),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDetailSubject(BuildContext context, Responsive r) {
    return Text(
      message.subject,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: AppTheme.text(context),
        fontSize: _fontSize(r, 20),
        fontWeight: FontWeight.w800,
        height: 1.3,
      ),
    );
  }

  Widget _buildDetailMeta(BuildContext context, Responsive r) {
    return Row(
      children: [
        Icon(Icons.access_time_rounded,
            size: 14, color: AppTheme.textSecondary(context)),
        SizedBox(width: r.spacingXS),
        Expanded(
          child: Text(
            _formatFullDate(message.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: _fontSize(r, 12),
            ),
          ),
        ),
        if (message.courseCode != null) ...[
          SizedBox(width: r.spacingM),
          Icon(Icons.book_outlined,
              size: 14, color: AppTheme.textSecondary(context)),
          SizedBox(width: r.spacingXS),
          Text(
            message.courseCode!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: _fontSize(r, 12),
            ),
          ),
        ],
        if (message.section != null) ...[
          SizedBox(width: r.spacingS),
          Text(
            'Sec ${message.section}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: _fontSize(r, 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailBody(BuildContext context, Responsive r) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.wp(4)),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.border(context),
          width: 0.5,
        ),
      ),
      child: Text(
        message.body,
        style: GoogleFonts.inter(
          color: AppTheme.text(context),
          fontSize: _fontSize(r, 14),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context, Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingS),
        ...message.attachments.map((attachment) {
          return Container(
            margin: EdgeInsets.only(bottom: r.spacingXS),
            padding: EdgeInsets.symmetric(
              horizontal: r.wp(3),
              vertical: r.hp(1),
            ),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file_rounded,
                    size: 20, color: AppTheme.accentTeal),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Text(
                    attachment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: _fontSize(r, 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecipientsList(BuildContext context, Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipients',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: _fontSize(r, 13),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.spacingS),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.wp(3)),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.border(context),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRecipientRow(
                context: context,
                name: 'Total Recipients',
                value: '${message.recipientCount}',
                color: AppTheme.textSecondary(context),
                r: r,
              ),
              Divider(
                height: r.hp(2),
                color: AppTheme.border(context),
              ),
              _buildRecipientRow(
                context: context,
                name: 'Read',
                value: '${message.readCount}',
                color: AppTheme.accentTeal,
                r: r,
              ),
              Divider(
                height: r.hp(2),
                color: AppTheme.border(context),
              ),
              _buildRecipientRow(
                context: context,
                name: 'Unread',
                value: '${message.recipientCount - message.readCount}',
                color: AppTheme.accentGold,
                r: r,
              ),
            ],
          ),
        ),
        SizedBox(height: r.spacingS),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.wp(3),
            vertical: r.hp(1),
          ),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: r.wp(40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: message.recipientCount > 0
                        ? message.readCount / message.recipientCount
                        : 0,
                    backgroundColor: AppTheme.surface(context),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                    minHeight: 6,
                  ),
                ),
              ),
              SizedBox(width: r.spacingM),
              Expanded(
                child: Text(
                  '${message.recipientCount > 0 ? ((message.readCount / message.recipientCount) * 100).round() : 0}% read',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.accentTeal,
                    fontSize: _fontSize(r, 11),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientRow({
    required BuildContext context,
    required String name,
    required String value,
    required Color color,
    required Responsive r,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: _fontSize(r, 13),
            ),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: color,
            fontSize: _fontSize(r, 14),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
