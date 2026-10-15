import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_action_sheet.dart';

/// Premium animated context toolbar shown when a message is long-pressed.
///
/// Slides/scales in with a quick-reaction strip and a 3×3 action grid
/// (Reply · Copy · Forward · Star · Pin · Delete · Info · Share · Multi
/// select). A trailing overflow button exposes the remaining actions via
/// [MessageActionSheet].
class MessageContextBar extends StatefulWidget {
  final ChatMessage message;
  final bool isOutgoing;
  final ValueChanged<String> onAction;
  final VoidCallback onClose;
  final VoidCallback onMore;

  const MessageContextBar({
    super.key,
    required this.message,
    required this.isOutgoing,
    required this.onAction,
    required this.onClose,
    required this.onMore,
  });

  @override
  State<MessageContextBar> createState() => _MessageContextBarState();
}

class _MessageContextBarState extends State<MessageContextBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            color: AppTheme.card(context),
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Divider(height: 1, color: AppTheme.border(context)),
                _buildReactions(context),
                Divider(height: 1, color: AppTheme.border(context)),
                _buildGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final message = widget.message;
    final isOutgoing = widget.isOutgoing;
    final excerpt = message.text.isNotEmpty ? message.text : message.contentSummary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutgoing ? 'You' : message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppTheme.primary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  excerpt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: 12,
                      height: 1.2),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More actions',
            icon: Icon(Icons.more_horiz_rounded,
                color: AppTheme.textSecondary(context), size: 22),
            onPressed: widget.onMore,
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 22),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final selected = widget.message.reactions.isEmpty ? null : widget.message.reactions.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final e in emojis)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onAction('${MessageActions.reactPrefix}$e'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected == e
                      ? AppTheme.primary(context).withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(e, style: const TextStyle(fontSize: 22)),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onAction(MessageActions.react),
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

  Widget _buildGrid(BuildContext context) {
    final message = widget.message;
    final isDeletable = !message.isDeletedForEveryone && !message.isSystem;

    final items = [
      const _BarItem(Icons.reply_rounded, 'Reply', MessageActions.reply),
      const _BarItem(Icons.copy_rounded, 'Copy', MessageActions.copy),
      const _BarItem(Icons.forward_rounded, 'Forward', MessageActions.forward),
      _BarItem(message.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
          message.isStarred ? 'Unstar' : 'Star',
          message.isStarred ? MessageActions.unstar : MessageActions.star),
      _BarItem(message.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          message.isPinned ? 'Unpin' : 'Pin',
          message.isPinned ? MessageActions.unpin : MessageActions.pin),
      _BarItem(Icons.delete_outline_rounded, 'Delete', MessageActions.delete,
          color: isDeletable ? AppTheme.errorRed : AppTheme.textSecondary(context).withValues(alpha: 0.3)),
      const _BarItem(Icons.info_outline_rounded, 'Info', MessageActions.info),
      const _BarItem(Icons.share_rounded, 'Share', MessageActions.share),
      const _BarItem(Icons.checklist_rounded, 'Multi select', MessageActions.select,
          highlight: true),
    ];

    final rows = <Widget>[];
    for (var r = 0; r < 3; r++) {
      final rowItems = items.sublist(r * 3, r * 3 + 3);
      rows.add(Row(
        children: rowItems
            .map((item) => Expanded(
                  child: _GridItem(
                    item: item,
                    accent: AppTheme.primary(context),
                    onTap: () => widget.onAction(item.action),
                  ),
                ))
            .toList(),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(children: rows),
    );
  }
}

class _BarItem {
  final IconData icon;
  final String label;
  final String action;
  final Color? color;
  final bool highlight;

  const _BarItem(this.icon, this.label, this.action,
      {this.color, this.highlight = false});
}

class _GridItem extends StatelessWidget {
  final _BarItem item;
  final Color accent;
  final VoidCallback onTap;

  const _GridItem({required this.item, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = item.highlight
        ? accent
        : (item.color ?? AppTheme.textSecondary(context));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.highlight
                    ? accent.withValues(alpha: 0.12)
                    : color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 5),
            Text(item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: item.highlight ? accent : AppTheme.text(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
