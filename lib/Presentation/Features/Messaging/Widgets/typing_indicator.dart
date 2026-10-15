import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Animated three-dot typing indicator shown in chat and in the list.
class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingIndicator({super.key, this.color, this.dotSize = 8});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primary(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value + i * 0.33) % 1.0;
            final scale = t < 0.5 ? 0.6 + (t * 0.8) : 1.4 - (t * 0.8);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.22),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Pinned "is typing…" caption used under a peer's name.
class TypingLabel extends StatelessWidget {
  final String name;
  final Color? color;

  const TypingLabel({super.key, required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary(context);
    return Text(
      '$name is typing…',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: c,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Pinned "Recording audio…" caption with a live mic pulse, used in the list.
class RecordingLabel extends StatefulWidget {
  final String name;
  final Color? color;

  const RecordingLabel({super.key, required this.name, this.color});

  @override
  State<RecordingLabel> createState() => _RecordingLabelState();
}

class _RecordingLabelState extends State<RecordingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppTheme.errorRed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
          child: Icon(Icons.mic_rounded, size: 13, color: c),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${widget.name} is recording audio…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
