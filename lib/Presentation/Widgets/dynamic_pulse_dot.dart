import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

enum HeartbeatState {
  idle,
  initiating,
  pending,
  success,
  error,
}

class DynamicPulseDot extends StatefulWidget {
  final HeartbeatState state;
  final double size;

  const DynamicPulseDot({
    Key? key,
    required this.state,
    this.size = 8.0,
  }) : super(key: key);

  @override
  State<DynamicPulseDot> createState() => _DynamicPulseDotState();
}

class _DynamicPulseDotState extends State<DynamicPulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  @override
  void didUpdateWidget(covariant DynamicPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: _getDurationForState(widget.state),
    );
    _animation = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.state != HeartbeatState.idle) {
      _controller.repeat();
    }
  }

  void _updateAnimation() {
    _controller.duration = _getDurationForState(widget.state);
    if (widget.state == HeartbeatState.idle) {
      _controller.stop();
      _controller.value = 0.0;
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  Duration _getDurationForState(HeartbeatState state) {
    switch (state) {
      case HeartbeatState.initiating:
        return const Duration(milliseconds: 1000); // Medium
      case HeartbeatState.pending:
        return const Duration(milliseconds: 1500); // Slow
      case HeartbeatState.error:
        return const Duration(milliseconds: 500); // Fast
      case HeartbeatState.success:
        return const Duration(milliseconds: 2000); // Very slow glow
      case HeartbeatState.idle:
      default:
        return const Duration(milliseconds: 1000);
    }
  }

  Color _getColorForState(HeartbeatState state, bool isDark) {
    switch (state) {
      case HeartbeatState.initiating:
        return Colors.amber;
      case HeartbeatState.pending:
        return AppTheme.accentTeal;
      case HeartbeatState.success:
        return AppTheme.highlightLime;
      case HeartbeatState.error:
        return AppTheme.errorRed;
      case HeartbeatState.idle:
      default:
        return isDark ? Colors.white24 : Colors.black26;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor = _getColorForState(widget.state, isDark);

    return Container(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.state != HeartbeatState.idle)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: widget.size * _animation.value,
                  height: widget.size * _animation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: baseColor.withOpacity(0.6 * (2.5 - _animation.value) / 1.5),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor,
            ),
          ),
        ],
      ),
    );
  }
}
