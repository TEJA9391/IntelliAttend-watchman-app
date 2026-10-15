import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Result action keys returned from [MessageActionSheet.show].
class MessageActions {
  static const reply = 'reply';
  static const copy = 'copy';
  static const forward = 'forward';
  static const info = 'info';
  static const star = 'star';
  static const unstar = 'unstar';
  static const pin = 'pin';
  static const unpin = 'unpin';
  static const edit = 'edit';
  static const delete = 'delete';
  static const translate = 'translate';
  static const select = 'select';
  static const share = 'share';
  static const save = 'save';
  static const open = 'open';
  static const react = 'react';

  /// Quick reactions returned as `react:<emoji>` so the caller can toggle
  /// in one tap. Use [isReactionResult] / [reactionEmojiFrom] to decode.
  static const reactPrefix = 'react:';

  static bool isReactionResult(String action) =>
      action.startsWith(reactPrefix) && action.length > reactPrefix.length;

  static String? reactionEmojiFrom(String action) =>
      action.startsWith(reactPrefix) ? action.substring(reactPrefix.length) : null;
}

/// WhatsApp-style long-press action sheet for a single message.
class MessageActionSheet {
  MessageActionSheet._();

  static Future<String?> show(
    BuildContext context,
    ChatMessage message, {
    bool isOutgoing = true,
  }) {
    final isAttachment = message.hasAttachment;
    final isDeletable = !message.isDeletedForEveryone && !message.isSystem;
    final canEdit = isOutgoing && !isAttachment && message.type == MessageContentType.text;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(message: message),
              _ReactionRow(
                selectedEmoji: message.reactions.isEmpty ? null : message.reactions.first,
                onTap: (emoji) => Navigator.pop(ctx, '${MessageActions.reactPrefix}$emoji'),
                onMore: () => Navigator.pop(ctx, MessageActions.react),
              ),
              _ActionRow(items: [
                _Item(Icons.reply_rounded, 'Reply', MessageActions.reply),
                _Item(Icons.copy_rounded, 'Copy', MessageActions.copy),
                _Item(Icons.share_rounded, 'Share', MessageActions.share),
                if (isAttachment)
                  _Item(Icons.download_rounded, 'Save', MessageActions.save),
              ]),
              _ActionRow(items: [
                _Item(Icons.forward_rounded, 'Forward', MessageActions.forward),
                _Item(message.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                    message.isStarred ? 'Unstar' : 'Star', message.isStarred ? MessageActions.unstar : MessageActions.star),
                _Item(message.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    message.isPinned ? 'Unpin' : 'Pin', message.isPinned ? MessageActions.unpin : MessageActions.pin),
                _Item(Icons.info_outline_rounded, 'Info', MessageActions.info),
              ]),
              Divider(height: 1, color: AppTheme.border(context)),
              if (canEdit)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_rounded, color: AppTheme.textSecondary(context)),
                  title: _label(ctx, 'Edit'),
                  onTap: () => Navigator.pop(ctx, MessageActions.edit),
                ),
              if (isDeletable)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed),
                  title: Text('Delete',
                      style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 15, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, MessageActions.delete),
                ),
              ListTile(
                dense: true,
                leading: Icon(Icons.translate_rounded, color: AppTheme.textSecondary(context)),
                title: _label(ctx, 'Translate'),
                onTap: () => Navigator.pop(ctx, MessageActions.translate),
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.checklist_rounded, color: AppTheme.textSecondary(context)),
                title: _label(ctx, 'Select'),
                onTap: () => Navigator.pop(ctx, MessageActions.select),
              ),
            ],
          ),
        );
      },
    );
  }

  static Text _label(BuildContext ctx, String text) => Text(text,
      style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 15, fontWeight: FontWeight.w600));

  /// Copies the message text to the clipboard. Returns the copied text.
  static Future<void> copyToClipboard(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.contentSummary));
  }
}

class _Header extends StatelessWidget {
  final ChatMessage message;

  const _Header({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: AppTheme.primary(context), fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  message.text.isNotEmpty
                      ? message.text
                      : message.contentSummary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context), fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (message.hasAttachment)
            Icon(message.type == MessageContentType.image
                ? Icons.image_rounded
                : message.type.isFile
                    ? Icons.insert_drive_file_rounded
                    : Icons.attach_file_rounded,
                color: AppTheme.textSecondary(context), size: 22),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  final String action;

  const _Item(this.icon, this.label, this.action);
}

/// Quick-reaction strip (👍 ❤️ 😂 😮 😢 🙏) plus an overflow "+" button.
class _ReactionRow extends StatelessWidget {
  static const List<String> _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  final String? selectedEmoji;
  final ValueChanged<String> onTap;
  final VoidCallback onMore;

  const _ReactionRow({
    required this.selectedEmoji,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ..._emojis.map((e) {
            final selected = selectedEmoji == e;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onTap(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary(context).withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            );
          }),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onMore,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_reaction_rounded,
                  color: AppTheme.primary(context), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final List<_Item> items;

  const _ActionRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items
          .map((item) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, item.action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: AppTheme.primary(context), size: 24),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: GoogleFonts.inter(
                                color: AppTheme.text(context), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
