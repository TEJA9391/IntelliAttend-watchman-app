import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_list_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_status_ticks.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/typing_indicator.dart';

/// The conversation list — the entry screen of the Messaging feature.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatListController(repository: MessagingRepository());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openConversation(ChatConversation conversation) {
    final controller = context.read<ChatListController>();
    controller.markConversationRead(conversation.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Builder(
        builder: (context) {
          final controller = context.watch<ChatListController>();
          final conversations = controller.conversations;

          return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          'Chats',
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search chats',
            icon: Icon(Icons.search_rounded, color: AppTheme.text(context)),
            onPressed: () {
              HapticService.selection();
              showSearch(
                context: context,
                delegate: _ChatSearchDelegate(conversations: conversations),
              );
            },
          ),
          IconButton(
            tooltip: 'New chat',
            icon: Icon(Icons.edit_rounded, color: AppTheme.primary(context)),
            onPressed: () => _showNewChatSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!controller.isBackendAvailable && controller.allConversations.isNotEmpty)
            _OfflineBanner(onRefresh: controller.refresh),
          if (conversations.isEmpty && !controller.isLoading)
            _EmptyState(onNewChat: () => _showNewChatSheet(context))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 78,
                    color: AppTheme.border(context),
                  ),
                  itemBuilder: (context, index) =>
                      _ConversationTile(conversation: conversations[index]),
                ),
              ),
            ),
        ],
      ),
    );
    },
  ),
);
  }

  Future<void> _showNewChatSheet(BuildContext context) async {
    HapticService.medium();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => NewChatSheet(controller: context.read<ChatListController>()),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _OfflineBanner({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.accentGold.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppTheme.accentGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline — showing cached chats',
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRefresh,
            child: Text(
              'Retry',
              style: GoogleFonts.inter(
                color: AppTheme.primary(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewChat;

  const _EmptyState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary(context).withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppTheme.primary(context),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No chats yet',
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a conversation with a student or colleague.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNewChat,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add_comment_rounded, size: 18),
              label: const Text('New chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatListController>();
    final peer = conversation.peer;
    final snapshot = controller.presenceFor(peer.id);
    final isOnline = snapshot?.isOnline ?? peer.isOnline;
    final typing = controller.isTypingIn(conversation.id);
    final recording = controller.isRecording(peer.id);
    final offlineLastSeen = (!isOnline && snapshot?.lastSeen != null)
        ? ChatTimeFormat.lastSeen(snapshot!.lastSeen!)
        : null;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.errorRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.card(ctx),
            title: Text('Delete chat',
                style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 18, fontWeight: FontWeight.w800)),
            content: Text(
              'Delete this chat with ${conversation.title}? Messages will be removed from your device.',
              style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => controller.deleteConversation(conversation),
      child: ListTile(
        onTap: () => _open(context, controller),
        onLongPress: () => _showActions(context, controller),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            PeerAvatar(name: peer.name, radius: 26, isOnline: isOnline, showOnlineDot: true),
            if (conversation.isMuted)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.card(context),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Icon(Icons.notifications_off_rounded,
                      size: 12, color: AppTheme.textSecondary(context)),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 15,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ChatTimeFormat.listTime(conversation.lastMessageTime),
              style: GoogleFonts.inter(
                color: conversation.unreadCount > 0
                    ? AppTheme.primary(context)
                    : AppTheme.textSecondary(context),
                fontSize: 11,
                fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (conversation.unreadCount > 0 && conversation.lastMessageStatus != null)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: MessageStatusTicks(
                    status: conversation.lastMessageStatus!,
                    size: 14,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              if (conversation.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.push_pin_rounded, size: 13, color: AppTheme.primary(context)),
                ),
              Expanded(
                child: recording
                    ? RecordingLabel(
                        name: conversation.title, color: AppTheme.errorRed)
                    : typing
                        ? TypingLabel(
                            name: conversation.title,
                            color: AppTheme.primary(context))
                        : Text(
                            conversation.lastMessage?.isNotEmpty == true
                                ? conversation.lastMessage!
                                : 'Tap to start a conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: conversation.unreadCount > 0
                                  ? AppTheme.text(context)
                                  : AppTheme.textSecondary(context),
                              fontSize: 13,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${conversation.unreadCount}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (offlineLastSeen != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'last seen $offlineLastSeen',
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
        ),
    );
  }

  void _open(BuildContext context, ChatListController controller) {
    controller.markConversationRead(conversation.id);
    HapticService.selection();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)),
    );
  }

  Future<void> _showActions(BuildContext context, ChatListController controller) async {
    HapticService.medium();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.push_pin_rounded, color: AppTheme.primary(ctx)),
              title: Text(conversation.isPinned ? 'Unpin chat' : 'Pin chat',
                  style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: AppTheme.textSecondary(ctx)),
              title: Text(conversation.isMuted ? 'Unmute notifications' : 'Mute notifications',
                  style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'mute'),
            ),
            ListTile(
              leading: Icon(Icons.archive_outlined, color: AppTheme.textSecondary(ctx)),
              title: Text('Archive chat',
                  style: TextStyle(color: AppTheme.textSecondary(ctx))),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppTheme.errorRed),
              title: Text(conversation.isBlocked ? 'Unblock' : 'Block',
                  style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
              title: const Text('Delete chat',
                  style: TextStyle(color: AppTheme.errorRed)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;
    switch (action) {
      case 'pin':
        await controller.togglePin(conversation);
      case 'mute':
        await controller.toggleMute(conversation);
      case 'archive':
        await controller.setArchived(conversation, true);
      case 'block':
        await controller.toggleBlock(conversation);
      case 'delete':
        await controller.deleteConversation(conversation);
    }
  }
}

class _ChatSearchDelegate extends SearchDelegate<String?> {
  final List<ChatConversation> conversations;

  _ChatSearchDelegate({required this.conversations});

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = conversations
        .where((c) =>
            c.title.toLowerCase().contains(query.toLowerCase()) ||
            (c.peer.rollNumber?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (c.peer.section?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
    return _resultsList(context, results);
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = conversations
        .where((c) =>
            c.title.toLowerCase().contains(query.toLowerCase()) ||
            (c.peer.rollNumber?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
    return _resultsList(context, results);
  }

  Widget _resultsList(BuildContext context, List<ChatConversation> results) {
    if (results.isEmpty) {
      return Center(
        child: Text('No chats found',
            style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 78, color: AppTheme.border(context)),
      itemBuilder: (context, i) {
        final c = results[i];
        return ListTile(
          leading: PeerAvatar(name: c.peer.name, radius: 24),
          title: Text(c.title,
              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${c.peer.rollNumber ?? ''}${c.peer.section != null ? ' • ${c.peer.section}' : ''}',
            style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
          ),
          onTap: () {
            final convId = c.id;
            close(context, convId);
          },
        );
      },
    );
  }
}

/// Bottom sheet listing known contacts to start a new chat.
class NewChatSheet extends StatefulWidget {
  final ChatListController controller;

  const NewChatSheet({super.key, required this.controller});

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  final TextEditingController _search = TextEditingController();
  List<StudentContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final List<StudentContact> all = [];
    try {
      final keys = PersistenceService.academicBox.get('roster_keys');
      if (keys is List) {
        for (final key in keys) {
          final raw = PersistenceService.academicBox.get('roster_$key');
          if (raw is List) {
            for (final item in raw) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                all.add(StudentContact(
                  id: (m['id'] ?? m['student_id'] ?? m['roll_number'] ?? '').toString(),
                  name: (m['name'] ?? m['student_name'] ?? '').toString(),
                  rollNumber: m['roll_number']?.toString(),
                  email: m['email']?.toString(),
                  phone: m['phone']?.toString(),
                  department: m['department']?.toString(),
                  section: m['section']?.toString(),
                  courseCode: m['course_code']?.toString(),
                  avatarUrl: m['avatar_url']?.toString() ?? m['profile_image']?.toString() ?? m['photo_url']?.toString(),
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NewChatSheet: Error loading roster: $e');
    }
    if (mounted) {
      setState(() => _contacts = all);
    }
  }

  void _startChat(StudentContact contact) {
    final existing = widget.controller.allConversations
        .where((c) => c.peer.id == contact.id && !c.isGroup)
        .firstOrNull;
    final conversation = existing ??
        ChatConversation(
          id: 'direct_${contact.id}',
          peer: contact,
          createdAt: DateTime.now(),
        );
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _contacts
        : _contacts
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                (c.rollNumber?.toLowerCase().contains(query) ?? false) ||
                (c.section?.toLowerCase().contains(query) ?? false) ||
                (c.courseCode?.toLowerCase().contains(query) ?? false))
            .toList();

    final Map<String, List<StudentContact>> grouped = {};
    for (final c in filtered) {
      final section = (c.section ?? 'Other').toString().isEmpty ? 'Other' : (c.section ?? 'Other');
      grouped.putIfAbsent(section, () => []).add(c);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search students',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary(context)),
                  filled: true,
                  fillColor: AppTheme.surface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final section = sortedKeys[index];
                  final students = grouped[section]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...students.map((contact) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          onTap: () => _startChat(contact),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: PeerAvatar(
                            name: contact.name,
                            imageUrl: contact.avatarUrl,
                            radius: 22,
                          ),
                          title: Text(contact.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      )),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
