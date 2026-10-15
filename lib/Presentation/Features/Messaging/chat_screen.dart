import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/forward_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/thread_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/message_search_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/message_info_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/call_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/view_profile_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_input_bar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_appearance_sheet.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_wallpapers.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_action_sheet.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_bubble.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_context_bar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/typing_indicator.dart';

/// The 1:1 chat screen: header with presence + call buttons, the message
/// list with date separators and tails, and the composer.
class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatScreenController _controller;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _draftTimer;
  bool _isMuted = false;
  int? _wallpaper;
  bool _darkChat = false;
  int _accentIndex = 0;
  String _wallpaperId = ChatWallpaper.defaultId;
  String? _customWallpaperPath;
  String _themeMode = 'auto';
  bool _glassEnabled = false;
  bool _soundsEnabled = true;
  String? _scrollTargetId;
  String? _highlightId;
  List<String>? _searchNavIds;
  int _searchNavIndex = 0;
  ChatMessage? _contextMessage;
  bool _contextBarVisible = false;
  bool _showScrollFab = false;
  bool _bannerDismissed = false;
  bool _elevated = false;
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void initState() {
    super.initState();
    NotificationService.setActiveConversation(widget.conversation.id);
    _controller = ChatScreenController(
      repository: MessagingRepository(),
      conversation: widget.conversation,
    );
    _controller.onIncomingMessage = () {
      if (_soundsEnabled) {
        HapticService.selection();
        SystemSound.play(SystemSoundType.click);
      }
    };
    _isMuted = MessageCacheService.instance.isMuted(widget.conversation.id);
    _wallpaper = MessageCacheService.instance.getWallpaper(widget.conversation.id);
    _accentIndex = MessageCacheService.instance.getChatAccent(widget.conversation.id) ?? 0;
    _wallpaperId = MessageCacheService.instance.getWallpaperId(widget.conversation.id) ??
        ChatWallpaper.defaultId;
    _customWallpaperPath =
        MessageCacheService.instance.getCustomWallpaperPath(widget.conversation.id);
    _themeMode = MessageCacheService.instance.getChatThemeMode(widget.conversation.id);
    _glassEnabled = MessageCacheService.instance.getGlassEnabled(widget.conversation.id);
    _soundsEnabled = MessageCacheService.instance.getSoundsEnabled();
    _resolveDarkChat();

    // Restore the saved draft.
    final draft = MessageCacheService.instance.getDraft(widget.conversation.id);
    if (draft != null && draft.isNotEmpty) {
      _inputController.text = draft;
    }

    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.markRead();
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
    NotificationService.setActiveConversation(null);
    _draftTimer?.cancel();
    _controller.markRead();
    _inputController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 200;
    if (atBottom) {
      _controller.loadOlder();
    }
    final elevated = pos.pixels > 4;
    if (mounted && elevated != _elevated) {
      setState(() => _elevated = elevated);
    }
    if (mounted && atBottom == _showScrollFab) {
      setState(() => _showScrollFab = !atBottom);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (mounted && _showScrollFab) {
      setState(() => _showScrollFab = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(target,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _onTextChanged(String text) {
    _controller.notifyTyping(text.trim().isNotEmpty);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      MessageCacheService.instance.saveDraft(widget.conversation.id, text);
    });
  }

  List<String> _mentionSuggestions(ChatScreenController controller) {
    final names = <String>{
      widget.conversation.peer.name,
      for (final m in controller.messages) m.senderName,
    };
    names.removeWhere((n) => n.isEmpty);
    return names.toList();
  }

  void _onSend(String text) async {
    await _controller.sendText(text);
    _playSendSound();
    _scrollToBottom();
  }

  void _onSendAttachment(ChatAttachment attachment) async {
    await _controller.sendAttachment(attachment);
    _playSendSound();
    _scrollToBottom();
  }

  void _onSendVoice(String path, {int? durationMs}) async {
    await _controller.sendVoiceNote(path, durationMs: durationMs);
    _playSendSound();
    _scrollToBottom();
  }

  /// Broadcasts local voice-recording state so the peer sees the realtime
  /// "Recording audio…" presence in their header.
  void _broadcastVoiceRecording(ChatScreenController controller, bool recording) {
    final peer = widget.conversation.peer;
    ChatRealtimeService.instance.sendRecording(peerId: peer.id, isRecording: recording);
  }

  void _playSendSound() {
    if (!_soundsEnabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  /// Resolves the effective dark flag from the per-chat theme mode.
  void _resolveDarkChat() {
    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _darkChat = switch (_themeMode) {
      'light' => false,
      'dark' => true,
      _ => systemDark,
    };
  }

  /// Re-reads the appearance prefs (used after returning from the profile
  /// screen or the appearance picker, where changes are persisted directly).
  void _reloadAppearance() {
    final id = widget.conversation.id;
    final cache = MessageCacheService.instance;
    _wallpaper = cache.getWallpaper(id);
    _accentIndex = cache.getChatAccent(id) ?? 0;
    _wallpaperId = cache.getWallpaperId(id) ?? ChatWallpaper.defaultId;
    _customWallpaperPath = cache.getCustomWallpaperPath(id);
    _themeMode = cache.getChatThemeMode(id);
    _glassEnabled = cache.getGlassEnabled(id);
    _resolveDarkChat();
  }

  /// Paints the chat surface behind the message list: custom gallery image,
  /// premium preset, legacy flat color, or the default dotted gradient.
  Widget _buildChatBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ChatAccents.resolve(_accentIndex);

    if (_customWallpaperPath != null && _customWallpaperPath!.isNotEmpty) {
      final file = File(_customWallpaperPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    final wallpaper = ChatWallpaper.byId(_wallpaperId);
    if (wallpaper != null) {
      return CustomPaint(
        painter: ChatWallpaperPainter(wallpaper: wallpaper),
        size: Size.infinite,
      );
    }

    return ColoredBox(
      color: isDark ? const Color(0xFF0D1117) : Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatAppearanceScope(
      accent: ChatAccents.resolve(_accentIndex),
      isDark: _darkChat,
      wallpaper: ChatWallpaper.byId(_wallpaperId),
      wallpaperPath: _customWallpaperPath,
      glass: _glassEnabled,
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: Consumer<ChatScreenController>(
          builder: (context, controller, _) {
            return Scaffold(
              backgroundColor: AppTheme.bg(context),
              appBar: _buildAppBar(context, controller),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _buildChatBackground(context),
                ),
                Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildSearchNavBar(context, controller),
                    ),
                    if (!_bannerDismissed && controller.pinnedMessages.isNotEmpty)
                      _buildPinnedBanner(context, controller),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildMessageList(context, controller),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 8,
                            child: AnimatedScale(
                              scale: _showScrollFab ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: FloatingActionButton(
                                heroTag: null,
                                mini: true,
                                backgroundColor: AppTheme.card(context),
                                foregroundColor: AppTheme.primary(context),
                                elevation: 3,
                                onPressed: () => _scrollToBottom(),
                                child: const Icon(Icons.arrow_downward_rounded),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: !_contextBarVisible,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedOpacity(
                                  opacity: _contextBarVisible ? 1 : 0,
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOut,
                                  child: _contextMessage == null
                                      ? const SizedBox.shrink()
                                      : MessageContextBar(
                                          key: ValueKey(_contextMessage!.id),
                                          message: _contextMessage!,
                                          isOutgoing: _contextMessage!.direction ==
                                              MessageDirection.outgoing,
                                          onAction: (a) => _handleContextAction(
                                              context, controller, _contextMessage!, a),
                                          onClose: _closeContextBar,
                                          onMore: () {
                                            final msg = _contextMessage;
                                            _closeContextBar();
                                            if (msg == null) return;
                                            final isOutgoing =
                                                msg.direction == MessageDirection.outgoing;
                                            MessageActionSheet.show(context, msg,
                                                    isOutgoing: isOutgoing)
                                                .then((action) {
                                              if (action != null && mounted) {
                                                _dispatchMessageAction(
                                                    context, controller, msg, action);
                                              }
                                            });
                                          },
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildTypingIndicator(context, controller),
                    ChatInputBar(
                      controller: _inputController,
                      onSend: _onSend,
                      onSendAttachment: _onSendAttachment,
                      onSendVoice: _onSendVoice,
                      onTextChanged: _onTextChanged,
                      replyTarget: controller.replyTarget,
                      onClearReply: controller.clearReply,
                      blocked: _controller.conversation.isBlocked,
                      mentionSuggestions: _mentionSuggestions(controller),
                      onVoiceRecording: (recording) =>
                          _broadcastVoiceRecording(controller, recording),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  bool _isPeerOnline() {
    final peer = widget.conversation.peer;
    return ChatRealtimeService.instance.presenceFor(peer.id)?.isOnline ?? peer.isOnline;
  }

  /// Stable key per presence state so [AnimatedSwitcher] cross-fades between
  /// Online / Offline / Last seen / Typing… / Recording audio…
  String _presenceKey() {
    final peer = widget.conversation.peer;
    if (ChatRealtimeService.instance.isTypingIn(widget.conversation.id)) return 'typing';
    if (ChatRealtimeService.instance.isRecording(peer.id)) return 'recording';
    final snap = ChatRealtimeService.instance.presenceFor(peer.id);
    if ((snap?.isOnline ?? peer.isOnline)) return 'online';
    final lastSeen = snap?.lastSeen ?? peer.lastSeen;
    return lastSeen?.toIso8601String() ?? 'offline';
  }

  Widget _buildPresenceLine(Color defaultColor, Color accent) {
    final peer = widget.conversation.peer;
    if (ChatRealtimeService.instance.isTypingIn(widget.conversation.id)) {
      return _PresenceLine(
        icon: Icons.more_horiz_rounded,
        iconSize: 13,
        color: accent,
        text: 'Typing…',
      );
    }
    if (ChatRealtimeService.instance.isRecording(peer.id)) {
      return _PresenceLine(
        icon: Icons.mic_rounded,
        iconSize: 11,
        color: AppTheme.errorRed,
        text: 'Recording audio…',
      );
    }
    final snap = ChatRealtimeService.instance.presenceFor(peer.id);
    if ((snap?.isOnline ?? peer.isOnline)) {
      return _PresenceLine(
        icon: Icons.circle,
        iconSize: 7,
        color: AppTheme.greenOnline,
        text: 'Online',
      );
    }
    final lastSeen = snap?.lastSeen ?? peer.lastSeen;
    if (lastSeen == null) {
      return _PresenceLine(color: defaultColor, text: 'Offline');
    }
    return _PresenceLine(color: defaultColor, text: ChatTimeFormat.lastSeen(lastSeen));
  }

  PreferredSizeWidget _buildHeader(BuildContext context, ChatScreenController controller) {
    final accent = ChatThemeScope.accentOf(context);
    final dark = ChatThemeScope.isDarkOf(context);
    final glass = ChatThemeScope.glassOf(context);
    final headerBg = AppTheme.card(context);
    final headerText = AppTheme.text(context);
    final headerSub = AppTheme.textSecondary(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 400;
    final avatarRadius = compact ? 21.0 : 23.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(compact ? 62 : 68),
      child: AnimatedBuilder(
        animation: ChatRealtimeService.instance,
        builder: (context, _) => AnimatedPhysicalModel(
          elevation: _elevated ? 6 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          color: glass
              ? headerBg.withValues(alpha: dark ? 0.60 : 0.66)
              : headerBg,
          shadowColor: Colors.black45,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.zero,
          child: glass
              ? ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: _buildHeaderAppBar(context, controller, headerBg, headerText, headerSub,
                        accent, dark, compact, avatarRadius),
                  ),
                )
              : _buildHeaderAppBar(context, controller, headerBg, headerText, headerSub,
                    accent, dark, compact, avatarRadius),
        ),
      ),
    );
  }

  AppBar _buildHeaderAppBar(
      BuildContext context,
      ChatScreenController controller,
      Color headerBg,
      Color headerText,
      Color headerSub,
      Color accent,
      bool dark,
      bool compact,
      double avatarRadius) {
    final peer = widget.conversation.peer;
    return AppBar(
            key: const ValueKey('chat-header-appbar'),
            toolbarHeight: compact ? 62 : 68,
            backgroundColor: headerBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: headerText),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openProfile(context),
              child: Row(
                children: [
                  PeerAvatar(
                    name: peer.name,
                    imageUrl: peer.avatarUrl,
                    radius: avatarRadius,
                    isOnline: _isPeerOnline(),
                    showOnlineDot: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: headerText,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1)),
                        if (peer.rollNumber != null && peer.rollNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(peer.rollNumber!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: headerSub,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                        begin: const Offset(0, 0.4), end: Offset.zero)
                                    .animate(anim),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(_presenceKey()),
                              child: _buildPresenceLine(headerSub, accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                color: AppTheme.card(context),
                surfaceTintColor: Colors.transparent,
                icon: Icon(Icons.more_vert_rounded, color: headerText),
                onSelected: (value) => _onMenuAction(context, controller, value),
                itemBuilder: (_) => [
                   PopupMenuItem(value: 'profile', child: Text('View Profile', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'search', child: Text('Search', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'appearance', child: Text('Wallpaper & Theme', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'media', child: Text('Media', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'documents', child: Text('Documents', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'links', child: Text('Links', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'export', child: Text('Export Chat', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'mute', child: Text('Mute', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'clear', child: Text('Clear Chat', style: TextStyle(color: AppTheme.text(context)))),
                   PopupMenuItem(value: 'delete', child: const Text('Delete Conversation', style: TextStyle(color: Color(0xFFEF4444)))),
                   PopupMenuItem(value: 'block', child: const Text('Block Student', style: TextStyle(color: Color(0xFFEF4444)))),
                   PopupMenuItem(value: 'report', child: const Text('Report', style: TextStyle(color: Color(0xFFEF4444)))),
                ],
              ),
            ],
    );
  }

  Future<void> _startCall(BuildContext context, CallType type) async {
    if (type == CallType.video) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required for video calls')),
          );
        }
        return;
      }
    }
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for calls')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    HapticService.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: widget.conversation.peer,
          type: type,
          direction: CallDirection.outgoing,
          repository: _controller.repository,
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ViewProfileScreen(
              peer: widget.conversation.peer,
              conversationId: widget.conversation.id,
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            setState(_reloadAppearance);
          }
        });
  }

  Future<void> _openAppearance(BuildContext context) async {
    HapticService.selection();
    await showChatAppearanceSheet(
      context,
      conversationId: widget.conversation.id,
    );
    if (mounted) {
      setState(_reloadAppearance);
    }
  }

  Future<void> _onMenuAction(
      BuildContext context, ChatScreenController controller, String value) async {
    switch (value) {
      case 'profile':
        _openProfile(context);
      case 'search':
        final jump = await Navigator.of(context).push<ChatSearchJump>(
          MaterialPageRoute(
            builder: (_) => MessageSearchScreen(controller: controller),
          ),
        );
        if (jump != null && jump.messageIds.isNotEmpty) {
          _startSearchNav(jump);
        } else if (jump != null) {
          controller.clearSearch();
        }
      case 'mute':
        final muted = !_isMuted;
        await controller.cache.setMuted(widget.conversation.id, muted);
        controller.repository.setMuted(widget.conversation.id, muted);
        setState(() => _isMuted = muted);
      case 'appearance':
        await _openAppearance(context);
      case 'media':
        _showMediaAndLinks(context, controller, initialIndex: 0);
      case 'documents':
        _showMediaAndLinks(context, controller, initialIndex: 1);
      case 'links':
        _showMediaAndLinks(context, controller, initialIndex: 2);
      case 'clear':
        await _confirmClear(context, controller);
      case 'export':
        await _exportChat(context, controller);
      case 'block':
        await _toggleBlock(context, controller);
      case 'report':
        await _reportChat(context, controller);
      case 'delete':
        await _deleteChat(context, controller);
    }
  }

  void _showPinned(BuildContext context, ChatScreenController controller) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.bg(context),
          appBar: AppBar(
            backgroundColor: AppTheme.bg(context),
            elevation: 0,
            title: Text('Pinned messages',
                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final pinned = controller.pinnedMessages;
              if (pinned.isEmpty) {
                return Center(
                  child: Text('No pinned messages',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
                );
              }
              return ListView.builder(
                itemCount: pinned.length,
                itemBuilder: (context, i) {
                  final m = pinned[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToMessage(m.id);
                      },
                      child: MessageBubble(
                        message: m,
                        isOutgoing: m.direction == MessageDirection.outgoing,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showMediaAndLinks(
      BuildContext context, ChatScreenController controller,
      {int initialIndex = 0}) async {
    final media = await controller.fetchMedia('media');
    final documents = await controller.fetchMedia('documents');
    final links = await controller.fetchMedia('links');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.bg(context),
          appBar: AppBar(
            backgroundColor: AppTheme.bg(context),
            elevation: 0,
            title: Text('Media, links and docs',
                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          body: DefaultTabController(
            initialIndex: initialIndex,
            length: 3,
            child: Column(
              children: [
                TabBar(
                  indicatorColor: AppTheme.primary(context),
                  labelColor: AppTheme.primary(context),
                  unselectedLabelColor: AppTheme.textSecondary(context),
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Media'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Links'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MediaGrid(messages: media),
                      _DocumentList(messages: documents),
                      _LinkList(messages: links),
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

  Future<void> _confirmClear(BuildContext context, ChatScreenController controller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Clear chat?',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'This will delete all messages in this chat from your device.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
    if (ok == true) await controller.clearChat();
  }

  Future<void> _exportChat(BuildContext context, ChatScreenController controller) async {
    final text = await controller.exportChat('text');
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export yet')),
      );
      return;
    }
    await Share.share(text);
  }

  Future<void> _toggleBlock(BuildContext context, ChatScreenController controller) async {
    final currentlyBlocked = controller.conversation.isBlocked ||
        controller.cache.isBlocked(widget.conversation.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text(currentlyBlocked ? 'Unblock?' : 'Block ${widget.conversation.title}?',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          currentlyBlocked
              ? 'They will be able to message you again.'
              : 'They won\'t be able to message or call you.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentlyBlocked ? 'Unblock' : 'Block',
                style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final blocked = !currentlyBlocked;
    await controller.cache.setBlocked(widget.conversation.id, blocked);
    controller.repository.setBlocked(widget.conversation.id, blocked);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked ? 'Contact blocked' : 'Contact unblocked')),
      );
    }
  }

  Future<void> _reportChat(BuildContext context, ChatScreenController controller) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Report contact',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Tell us what happened…',
            hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
          ),
          style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'reported'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    controller.repository.reportConversation(widget.conversation.id, reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you, your report was submitted')),
      );
    }
  }

  Future<void> _deleteChat(BuildContext context, ChatScreenController controller) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Delete chat?',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently delete the chat on your device.',
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
    if (confirm != true) return;
    await controller.cache.removeConversation(widget.conversation.id);
    controller.repository.deleteConversation(widget.conversation.id);
    if (mounted) Navigator.pop(context);
  }

  // ── Selection mode ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatScreenController controller) {
    final compact = MediaQuery.sizeOf(context).width < 400;
    final height = compact ? 62.0 : 68.0;
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: controller.selectionMode
            ? _buildSelectionAppBar(context, controller, height)
            : _buildHeader(context, controller),
      ),
    );
  }

  AppBar _buildSelectionAppBar(BuildContext context, ChatScreenController controller,
      double toolbarHeight) {
    final count = controller.selectedIds.length;
    return AppBar(
      key: const ValueKey('selection-appbar'),
      toolbarHeight: toolbarHeight,
      backgroundColor: AppTheme.card(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: AppTheme.text(context)),
        onPressed: controller.exitSelection,
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text('$count selected',
            key: ValueKey(count),
            style: GoogleFonts.inter(
                color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      actions: [
        IconButton(
          tooltip: 'Copy',
          icon: Icon(Icons.copy_rounded, color: AppTheme.text(context)),
          onPressed: () => _copySelected(context, controller),
        ),
        IconButton(
          tooltip: 'Star',
          icon: Icon(Icons.star_border_rounded, color: AppTheme.text(context)),
          onPressed: () => _starSelected(controller),
        ),
        IconButton(
          tooltip: 'Forward',
          icon: Icon(Icons.forward_rounded, color: AppTheme.text(context)),
          onPressed: () => _forwardSelected(context, controller),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
          onPressed: () => _deleteSelected(context, controller),
        ),
      ],
    );
  }

  Future<void> _copySelected(BuildContext context, ChatScreenController controller) async {
    final text = controller.selectedMessages.map((m) => m.contentSummary).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    controller.exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _starSelected(ChatScreenController controller) {
    for (final m in controller.selectedMessages) {
      controller.starMessage(m, star: !m.isStarred);
    }
    controller.exitSelection();
  }

  void _forwardSelected(BuildContext context, ChatScreenController controller) {
    final messages = controller.selectedMessages;
    controller.exitSelection();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForwardScreen(messages: messages),
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context, ChatScreenController controller) async {
    final forEveryone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Delete messages',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'Delete for everyone, or just for you?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('For me', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('For everyone', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
    if (forEveryone == null) return;
    final first = controller.selectedMessages.firstOrNull;
    if (first != null) {
      await controller.deleteMessage(first, forEveryone: forEveryone);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Messages deleted'),
            action: SnackBarAction(label: 'UNDO', onPressed: controller.undoDelete),
          ),
        );
    }
  }

  // ── Message list ──────────────────────────────────────────────────────

  Widget _buildPinnedBanner(BuildContext context, ChatScreenController controller) {
    final pinned = controller.pinnedMessages.first;
    final preview = pinned.attachments.isNotEmpty
        ? (pinned.attachments.first.type == MessageContentType.image
            ? '📷 Photo'
            : pinned.attachments.first.name.isNotEmpty
                ? pinned.attachments.first.name
                : 'Attachment')
        : pinned.text;
    return Material(
      color: AppTheme.card(context),
      child: InkWell(
        onTap: () => _showPinned(context, controller),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.push_pin_rounded,
                  size: 16, color: AppTheme.primary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pinned message',
                        style: GoogleFonts.inter(
                            color: AppTheme.primary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.textSecondary(context)),
                onPressed: () => setState(() => _bannerDismissed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ChatScreenController controller) {
    if (controller.isLoading && controller.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.messages.isEmpty) {
      return const _EmptyChat();
    }

    final rows = _buildRows(controller.messages);
    final reversed = rows.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final row = reversed[index];
        if (row.isSeparator) {
          return _DateSeparator(date: row.date!);
        }
        final message = row.message!;
        final bubble = _buildBubble(context, controller, message, row);
        Widget entry;
        if (message.id == _scrollTargetId) {
          final key = _messageKeys.putIfAbsent(message.id, GlobalKey.new);
          entry = KeyedSubtree(key: key, child: bubble);
        } else {
          entry = bubble;
        }
        if (message.id == _highlightId) {
          entry = _MessageHighlight(child: entry);
        }
        return RepaintBoundary(
          child: _MessageAppear(key: ValueKey(message.id), child: entry),
        );
      },
    );
  }

  void _scrollToMessage(String messageId) {
    setState(() => _scrollTargetId = messageId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[messageId];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
      }
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _scrollTargetId = null;
            _messageKeys.clear();
          });
        }
      });
    });
  }

  /// Jumps to a referenced message (reply/mention/search) with a glow highlight.
  /// Paginates older messages first when the target lives outside the loaded window.
  Future<void> _jumpToMessage(String messageId) async {
    HapticService.light();
    if (!_controller.messages.any((m) => m.id == messageId)) {
      final loaded = await _controller.ensureMessageLoaded(messageId);
      if (!mounted) return;
      if (!loaded) return;
    }
    setState(() {
      _scrollTargetId = messageId;
      _highlightId = messageId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[messageId];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
      }
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _scrollTargetId = null;
            _highlightId = null;
            _messageKeys.clear();
          });
        }
      });
    });
  }

  // ── Search result navigation ─────────────────────────────────────────

  void _startSearchNav(ChatSearchJump jump) {
    setState(() {
      _searchNavIds = List.of(jump.messageIds);
      _searchNavIndex = jump.index.clamp(0, jump.messageIds.length - 1);
    });
    _jumpToSearchIndex();
  }

  void _closeSearchNav() {
    setState(() {
      _searchNavIds = null;
      _searchNavIndex = 0;
    });
  }

  void _stepSearchNav(int delta) {
    final ids = _searchNavIds;
    if (ids == null || ids.isEmpty) return;
    final next =
        (_searchNavIndex + delta + ids.length) % ids.length;
    setState(() => _searchNavIndex = next);
    _jumpToSearchIndex();
  }

  void _jumpToSearchIndex() {
    final ids = _searchNavIds;
    if (ids == null || ids.isEmpty) return;
    _jumpToMessage(ids[_searchNavIndex]);
  }

  Widget _buildSearchNavBar(BuildContext context, ChatScreenController controller) {
    final ids = _searchNavIds;
    if (ids == null || ids.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('search-nav-off'));
    }
    final accent = ChatThemeScope.accentOf(context);
    return KeyedSubtree(
      key: const ValueKey('search-nav-on'),
      child: Material(
        color: AppTheme.surface(context),
        elevation: 4,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.border(context)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                color: AppTheme.text(context),
                tooltip: 'Close search',
                onPressed: _closeSearchNav,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Search results',
                        style: GoogleFonts.inter(
                            color: AppTheme.text(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    Text(
                      '${_searchNavIndex + 1} of ${ids.length}',
                      style: GoogleFonts.inter(
                          color: accent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                color: AppTheme.text(context),
                tooltip: 'Previous result',
                onPressed: () => _stepSearchNav(-1),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: AppTheme.text(context),
                tooltip: 'Next result',
                onPressed: () => _stepSearchNav(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ChatRow> _buildRows(List<ChatMessage> messages) {
    final rows = <_ChatRow>[];
    DateTime? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (!m.isSystem &&
          (lastDay == null || !ChatTimeFormat.isSameDay(m.timestamp, lastDay))) {
        rows.add(_ChatRow.separator(m.timestamp));
        lastDay = m.timestamp;
      }
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;
      final groupStart = prev == null ||
          prev.senderId != m.senderId ||
          prev.isSystem ||
          !ChatTimeFormat.isSameDay(prev.timestamp, m.timestamp);
      final groupEnd = next == null ||
          next.senderId != m.senderId ||
          next.isSystem ||
          !ChatTimeFormat.isSameDay(next.timestamp, m.timestamp);
      rows.add(_ChatRow.message(m, showTail: groupEnd, showAvatar: groupStart && !m.isSystem));
    }
    return rows;
  }

  Widget _buildBubble(BuildContext context, ChatScreenController controller,
      ChatMessage message, _ChatRow row) {
    final isOutgoing = message.direction == MessageDirection.outgoing;
    final bubble = GestureDetector(
      onTap: () {
        if (controller.selectionMode) {
          controller.toggleSelect(message.id);
        }
      },
      child: MessageBubble(
        message: message,
        isOutgoing: isOutgoing,
        showTail: row.showTail,
        showAvatar: row.showAvatar,
        onLongPress: () => _onMessageLongPress(context, controller, message),
        onTap: controller.selectionMode ? () => controller.toggleSelect(message.id) : null,
        onDoubleTap: controller.selectionMode ? null : () => controller.toggleReaction(message, '👍'),
        onCancelUpload: message.isUploading
            ? () => controller.cancelUpload(message.id)
            : null,
        onRetry: !message.isUploading && message.status == MessageStatus.failed
            ? () => controller.retryMessage(message)
            : null,
        onReact: controller.selectionMode
            ? null
            : (emoji) => controller.toggleReaction(message, emoji),
        onReactMore: controller.selectionMode ? null : () => _showReactionPicker(context, message),
        onReplyTap: message.replyTo == null
            ? null
            : () => _jumpToMessage(message.replyTo!.messageId),
        onThreadTap: message.threadCount > 0
            ? () => _openThread(context, controller, message)
            : null,
      ),
    );
    return _SwipeReply(
      fromRight: isOutgoing,
      onReply: () {
        if (controller.selectionMode) return;
        HapticService.light();
        controller.setReplyTarget(message);
      },
      child: bubble,
    );
  }

  void _openThread(BuildContext context, ChatScreenController controller, ChatMessage root) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadScreen(
          conversation: widget.conversation,
          controller: controller,
          root: root,
          accent: ChatAccents.resolve(_accentIndex),
          dark: _darkChat,
        ),
      ),
    );
  }

  Future<void> _onMessageLongPress(
      BuildContext context, ChatScreenController controller, ChatMessage message) async {
    HapticService.medium();
    if (controller.selectionMode) {
      controller.toggleSelect(message.id);
      return;
    }

    if (_contextBarVisible) _closeContextBar();
    setState(() {
      _contextMessage = message;
      _contextBarVisible = true;
    });
  }

  void _closeContextBar() {
    setState(() {
      _contextBarVisible = false;
      _contextMessage = null;
    });
  }

  Future<void> _handleContextAction(
      BuildContext context, ChatScreenController controller, ChatMessage message, String action) async {
    if (action == MessageActions.select) {
      _closeContextBar();
      controller.enterSelection(message);
      return;
    }
    await _dispatchMessageAction(context, controller, message, action);
  }

  Future<void> _dispatchMessageAction(
      BuildContext context, ChatScreenController controller, ChatMessage message, String action) async {
    if (MessageActions.isReactionResult(action)) {
      await controller.toggleReaction(message, MessageActions.reactionEmojiFrom(action)!);
      return;
    }

    switch (action) {
      case MessageActions.reply:
        _closeContextBar();
        controller.setReplyTarget(message);
      case MessageActions.copy:
        await MessageActionSheet.copyToClipboard(message);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied')),
        );
      case MessageActions.forward:
        _closeContextBar();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ForwardScreen(messages: [message])),
        );
      case MessageActions.info:
        _closeContextBar();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MessageInfoScreen(message: message)),
        );
      case MessageActions.star:
        await controller.starMessage(message, star: true);
      case MessageActions.unstar:
        await controller.starMessage(message, star: false);
      case MessageActions.pin:
        await controller.pinMessage(message, pin: true);
      case MessageActions.unpin:
        await controller.pinMessage(message, pin: false);
      case MessageActions.edit:
        await _editMessage(context, controller, message);
      case MessageActions.delete:
        await _deleteOneMessage(context, controller, message);
      case MessageActions.translate:
        final translated = await controller.translateMessage(message);
        if (!mounted) return;
        if (translated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Translated: $translated')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Translation is not available right now')),
          );
        }
      case MessageActions.select:
        controller.enterSelection(message);
      case MessageActions.share:
        await Share.share(message.contentSummary);
      case MessageActions.save:
        if (message.attachments.isNotEmpty) {
          await _saveAttachment(context, message.attachments.first);
        }
      case MessageActions.open:
        break;
      case MessageActions.react:
        await _showReactionPicker(context, message);
    }
  }

  Future<void> _showReactionPicker(BuildContext context, ChatMessage message) async {
    HapticService.light();
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '👏', '💯', '🔥',
      '😍', '🤝', '🥳', '🙌', '😅', '🤔', '😭', '😡', '🫡', '⭐', '✅', '❌'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('React to message',
                  style: GoogleFonts.inter(
                      color: AppTheme.text(ctx), fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis
                    .map((e) => GestureDetector(
                          onTap: () => Navigator.pop(ctx, e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: message.reactions.contains(e)
                                  ? AppTheme.primary(ctx).withValues(alpha: 0.14)
                                  : AppTheme.surface(ctx),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 26)),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _controller.toggleReaction(message, selected);
    }
  }

  Future<void> _editMessage(
      BuildContext context, ChatScreenController controller, ChatMessage message) async {
    final textController = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Edit message',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: textController,
          maxLines: 3,
          style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'New message…',
            hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary(context)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (newText != null) {
      await controller.editMessage(message, newText);
    }
  }

  Future<void> _deleteOneMessage(
      BuildContext context, ChatScreenController controller, ChatMessage message) async {
    final isOutgoing = message.direction == MessageDirection.outgoing;
    final forEveryone = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Delete message',
            style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          isOutgoing ? 'Delete for everyone, or just for you?' : 'Delete this message?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isOutgoing ? 'For me' : 'Cancel',
                style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          if (isOutgoing)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('For everyone', style: TextStyle(color: AppTheme.errorRed)),
            ),
        ],
      ),
    );
    if (forEveryone == null) return;
    await controller.deleteMessage(message, forEveryone: forEveryone);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Message deleted'),
          action: SnackBarAction(label: 'UNDO', onPressed: controller.undoDelete),
        ),
      );
  }

  Future<void> _saveAttachment(BuildContext context, ChatAttachment attachment) async {
    final remote = attachment.remoteUrl;
    final local = attachment.localPath;
    String? path = local;
    if (path == null || !File(path).existsSync()) {
      if (remote == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading attachment…')),
      );
      try {
        final dir = await getTemporaryDirectory();
        var name = attachment.name.isNotEmpty
            ? attachment.name.replaceAll(RegExp(r'[\\/:*?"<>|\x00]'), '_').trim()
            : 'attachment_${attachment.id}';
        if (name.isEmpty) name = 'attachment_${attachment.id}';
        if (name.length > 80) name = name.substring(0, 80);
        final ext = remote!.contains('.') ? remote.substring(remote.lastIndexOf('.')) : '';
        final file = File('${dir.path}/$name$ext');
        await ApiClient().dio.download(remote, file.path);
        path = file.path;
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
        return;
      }
    }
    if (path == null || !File(path).existsSync()) return;
    await Share.shareXFiles([XFile(path)], text: attachment.name);
  }

  Widget _buildTypingIndicator(BuildContext context, ChatScreenController controller) {
    return AnimatedBuilder(
      animation: ChatRealtimeService.instance,
      builder: (context, _) {
        final typing = ChatRealtimeService.instance.isTypingIn(widget.conversation.id);
        if (!typing) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const TypingIndicator(),
          ),
        );
      },
    );
  }
}

// ── Row helpers ─────────────────────────────────────────────────────────

class _ChatRow {
  final DateTime? date;
  final ChatMessage? message;
  final bool showTail;
  final bool showAvatar;

  const _ChatRow._({this.date, this.message, this.showTail = false, this.showAvatar = false});

  factory _ChatRow.separator(DateTime date) => _ChatRow._(date: date);

  factory _ChatRow.message(ChatMessage message, {required bool showTail, required bool showAvatar}) =>
      _ChatRow._(message: message, showTail: showTail, showAvatar: showAvatar);

  bool get isSeparator => date != null;
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          ChatTimeFormat.dateSeparator(date),
          style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Pulses a primary-tinted glow behind a message when jumping to it.
class _MessageHighlight extends StatefulWidget {
  final Widget child;

  const _MessageHighlight({required this.child});

  @override
  State<_MessageHighlight> createState() => _MessageHighlightState();
}

class _MessageHighlightState extends State<_MessageHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primary(context)
              .withValues(alpha: 0.16 + _controller.value * 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Fades + slides a message in on mount (new incoming/outgoing messages).
class _MessageAppear extends StatefulWidget {
  final Widget child;

  const _MessageAppear({super.key, required this.child});

  @override
  State<_MessageAppear> createState() => _MessageAppearState();
}

class _MessageAppearState extends State<_MessageAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..forward();
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _EmptyChat extends StatefulWidget {
  const _EmptyChat();

  @override
  State<_EmptyChat> createState() => _EmptyChatState();
}

class _EmptyChatState extends State<_EmptyChat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween(begin: 0.8, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ChatThemeScope.accentOf(context);
    final dark = ChatThemeScope.isDarkOf(context);
    return FadeTransition(
      opacity: _fade,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.92),
                        accent.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.forum_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 22),
              Text('No messages yet',
                  style: GoogleFonts.inter(
                      color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Say hello to start the conversation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : AppTheme.text(context)).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text('Messages are securely transmitted',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swipe-to-reply gesture wrapper. Swiping a bubble outward (left for
/// outgoing, right for incoming) reveals a reply chip; releasing past the
/// threshold triggers [onReply] and the bubble springs back.
class _SwipeReply extends StatefulWidget {
  final Widget child;
  final bool fromRight;
  final VoidCallback onReply;

  const _SwipeReply({
    required this.child,
    required this.fromRight,
    required this.onReply,
  });

  @override
  State<_SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<_SwipeReply> {
  double _dx = 0;
  bool _armed = false;

  static const double _threshold = 90;

  void _onUpdate(DragUpdateDetails d) {
    final raw = _dx + d.delta.dx;
    final next = raw.clamp(-120.0, 120.0).toDouble();
    final active = widget.fromRight ? next < 0 : next > 0;
    setState(() {
      _dx = active ? next : next * 0.12;
      _armed = active && _dx.abs() >= _threshold;
    });
  }

  void _onEnd(DragEndDetails d) {
    if (_armed) {
      widget.onReply();
      HapticService.selection();
    }
    setState(() {
      _dx = 0;
      _armed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = ChatThemeScope.accentOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_dx.abs() > 8)
            Positioned(
              left: widget.fromRight ? null : 12,
              right: widget.fromRight ? 12 : null,
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(Icons.reply_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// Soft diagonal gradient (tinted with the chat accent) plus a faint grid of
/// chat-bubble watermarks, giving the conversation area a premium feel while
/// keeping message text readable.
class _ChatBackgroundPainter extends CustomPainter {
  final bool dark;
  final Color accent;

  _ChatBackgroundPainter({required this.dark, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [
              Color(0xFF0C1218),
              Color(0xFF142028),
              Color(0xFF10161C),
            ]
          : [
              const Color(0xFFF4FCF9),
              accent.withValues(alpha: 0.05),
              const Color(0xFFEAF8F3),
            ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final cell = 92.0;
    final w = 24.0;
    final paint = Paint()
      ..color = (dark ? Colors.white : accent).withValues(alpha: dark ? 0.035 : 0.05);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var i = 0; i <= cols; i++) {
      for (var j = 0; j <= rows; j++) {
        final cx = i * cell + cell / 2;
        final cy = j * cell + cell / 2;
        canvas.save();
        canvas.translate(cx, cy);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.72),
            const Radius.circular(6),
          ),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(-2, 0),
              width: w * 0.24,
              height: w * 0.18),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ChatBackgroundPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.accent != accent;
}

class _MediaGrid extends StatelessWidget {
  final List<ChatMessage> messages;

  const _MediaGrid({required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _EmptyTab(icon: Icons.photo_outlined, label: 'No media shared yet');
    }
    final media = messages.expand((m) => m.attachments).where((a) => a.type == MessageContentType.image).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: media.length,
      itemBuilder: (context, i) {
        final a = media[i];
        final local = a.localPath;
        final remote = a.remoteUrl;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: local != null && File(local).existsSync()
              ? Image.file(File(local), fit: BoxFit.cover)
              : remote != null
                  ? CachedNetworkImage(
                      imageUrl: remote,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surface(context),
                        child: Icon(Icons.broken_image_outlined, color: AppTheme.textSecondary(context)),
                      ),
                    )
                  : Container(color: AppTheme.surface(context)),
        );
      },
    );
  }
}

class _DocumentList extends StatelessWidget {
  final List<ChatMessage> messages;

  const _DocumentList({required this.messages});

  @override
  Widget build(BuildContext context) {
    final docs = messages.where((m) => m.type.isFile).toList();
    if (docs.isEmpty) {
      return _EmptyTab(icon: Icons.description_outlined, label: 'No documents shared yet');
    }
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final m = docs[i];
        final a = m.attachments.isNotEmpty ? m.attachments.first : null;
        return ListTile(
          leading: Icon(Icons.insert_drive_file_rounded, color: AppTheme.primary(context)),
          title: Text(a?.name ?? m.contentSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(ChatTimeFormat.full(m.timestamp),
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
          onTap: () {
            final att = a;
            if (att != null) _openAttachment(context, att);
          },
        );
      },
    );
  }

  Future<void> _openAttachment(BuildContext context, ChatAttachment a) async {
    try {
      final local = a.localPath;
      if (local != null && File(local).existsSync()) {
        await OpenFilex.open(local);
        return;
      }
      final remote = a.remoteUrl;
      if (remote == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${a.name}');
      if (!file.existsSync()) {
        await ApiClient().dio.download(remote, file.path);
      }
      await OpenFilex.open(file.path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file')),
        );
      }
    }
  }
}

class _LinkList extends StatelessWidget {
  final List<ChatMessage> messages;

  const _LinkList({required this.messages});

  @override
  Widget build(BuildContext context) {
    final links = messages.where((m) => m.text.contains(RegExp(r'https?://', caseSensitive: false))).toList();
    if (links.isEmpty) {
      return _EmptyTab(icon: Icons.link_rounded, label: 'No links shared yet');
    }
    return ListView.builder(
      itemCount: links.length,
      itemBuilder: (context, i) {
        final m = links[i];
        final url = RegExp(r'(https?://[^\s]+)').firstMatch(m.text)?.group(1) ?? '';
        return ListTile(
          leading: Icon(Icons.link_rounded, color: AppTheme.primary(context)),
          title: Text(url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppTheme.primary(context), fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary(context)),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
        ],
      ),
    );
  }
}

/// Single-line presence label used in the chat header (online / typing /
/// last-seen / recording) with an optional leading indicator icon.
class _PresenceLine extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final double iconSize;

  const _PresenceLine({
    required this.text,
    required this.color,
    this.icon,
    this.iconSize = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
