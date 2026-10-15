import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_input_bar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_bubble.dart';

/// Thread view: shows the original (root) message and every reply that
/// references it, with a composer that always replies into the thread.
class ThreadScreen extends StatefulWidget {
  final ChatConversation conversation;
  final ChatScreenController controller;
  final ChatMessage root;
  final Color? accent;
  final bool dark;

  const ThreadScreen({
    super.key,
    required this.conversation,
    required this.controller,
    required this.root,
    this.accent,
    this.dark = false,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> get _threadMessages => widget.controller.messages
      .where((m) =>
          m.replyTo?.messageId == widget.root.id && !m.isSystem)
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
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

  Future<void> _onSend(String text) async {
    await widget.controller.sendText(text, replyTo: widget.root);
    _scrollToBottom();
  }

  void _onSendVoice(String path, {int? durationMs}) {
    widget.controller.sendVoiceNote(path, durationMs: durationMs);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return ChatThemeScope(
      accent: widget.accent ?? ChatThemeScope.accentOf(context),
      isDark: widget.dark,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.card(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thread',
                  style: GoogleFonts.inter(
                      color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                '${_threadMessages.length} reply${_threadMessages.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final thread = _threadMessages;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: MessageBubble(
                          message: widget.root,
                          isOutgoing: widget.root.direction == MessageDirection.outgoing,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.border(context).withValues(alpha: 0.5),
                      ),
                      if (thread.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Text('No replies yet',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary(context), fontSize: 13)),
                          ),
                        )
                      else
                        for (final m in thread)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: MessageBubble(
                              message: m,
                              isOutgoing: m.direction == MessageDirection.outgoing,
                            ),
                          ),
                    ],
                  ),
                ),
                ChatInputBar(
                  controller: _inputController,
                  onSend: _onSend,
                  onSendAttachment: (att) {
                    widget.controller.sendAttachment(att, replyTo: widget.root);
                    _scrollToBottom();
                  },
                  onSendVoice: _onSendVoice,
                  onTextChanged: (_) {},
                  replyTarget: widget.root,
                  onClearReply: () {},
                  blocked: widget.conversation.isBlocked,
                  mentionSuggestions: [
                    widget.root.senderName,
                    for (final m in _threadMessages) m.senderName,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
