import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class LiveSupportChatPage extends StatefulWidget {
  const LiveSupportChatPage({Key? key}) : super(key: key);

  @override
  State<LiveSupportChatPage> createState() => _LiveSupportChatPageState();
}

class _LiveSupportChatPageState extends State<LiveSupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! I'm your IntelliAttend AI Assistant. How can I help you today?",
      "isBot": true,
      "time": DateTime.now(),
    },
  ];
  bool _isTyping = false;

  void _handleSendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    setState(() {
      _messages.add({
        "text": userMessage,
        "isBot": false,
        "time": DateTime.now(),
      });
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulated Bot Response
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            "text": _getBotResponse(userMessage),
            "isBot": true,
            "time": DateTime.now(),
          });
        });
        _scrollToBottom();
      }
    });
  }

  String _getBotResponse(String message) {
    message = message.toLowerCase();
    if (message.contains("attendance")) {
      return "To take attendance, go to the Dashboard, select your class, and click 'Go Live'. If you need to edit records, check the Reports section.";
    } else if (message.contains("report") || message.contains("analytics")) {
      return "The Reports Center provides real-time analytics for all your courses. You can export them as PDF or CSV from the top-right menu.";
    } else if (message.contains("sync") || message.contains("offline")) {
      return "The app syncs automatically. You can check your sync status in Profile > Sync Settings.";
    } else if (message.contains("hello") || message.contains("hi")) {
      return "Hi there! I'm here to help with any questions about the IntelliAttend app.";
    } else {
      return "I'm not sure about that, but I'm learning! You can also check the Help Center for more detailed tutorials.";
    }
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_rounded, color: AppTheme.primary(context), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "IntelliBot",
                  style: TextStyle(
                    color: AppTheme.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _isTyping ? "Typing..." : "Online Assistant",
                  style: TextStyle(
                    color: _isTyping ? AppTheme.primary(context) : AppTheme.greenOnline,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isBot = msg["isBot"];
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBot ? AppTheme.surface(context) : AppTheme.primary(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isBot ? 4 : 20),
            bottomRight: Radius.circular(isBot ? 20 : 4),
          ),
          border: isBot ? Border.all(color: AppTheme.border(context)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg["text"],
              maxLines: 50,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isBot ? AppTheme.text(context) : Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              TimeOfDay.fromDateTime(msg["time"]).format(context),
              style: TextStyle(
                color: isBot ? AppTheme.slate500(context) : Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: CircleAvatar(radius: 3, backgroundColor: AppTheme.primary(context).withValues(alpha: 0.5)),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border(top: BorderSide(color: AppTheme.border(context))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bg(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: AppTheme.primary(context),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _handleSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
