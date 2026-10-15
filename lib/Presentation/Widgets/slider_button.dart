import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class SliderButton extends StatefulWidget {
  final String label;
  final VoidCallback onSlideCompleted;
  final Color? backgroundColor;
  final Color? sliderColor;
  final Color? labelColor;
  final IconData? icon;

  const SliderButton({
    Key? key,
    required this.label,
    required this.onSlideCompleted,
    this.backgroundColor,
    this.sliderColor,
    this.labelColor,
    this.icon,
  }) : super(key: key);

  @override
  State<SliderButton> createState() => SliderButtonState();
}

class SliderButtonState extends State<SliderButton> with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _isCompleted = false;

  void reset() {
    if (mounted) {
      setState(() {
        _dragValue = 0.0;
        _isCompleted = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double sliderSize = 56.0;
        final double dragLimit = maxWidth - sliderSize;

        return Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppTheme.primary(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.primary(context).withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Background Text
              Center(
                child: Opacity(
                  opacity: (1.0 - (_dragValue / dragLimit)).clamp(0.2, 1.0),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.labelColor ?? AppTheme.primary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // The Slider Handle
              Positioned(
                left: _dragValue,
                top: 4,
                bottom: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragValue += details.delta.dx;
                      _dragValue = _dragValue.clamp(0.0, dragLimit);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCompleted) return;
                    if (_dragValue >= dragLimit * 0.9) {
                      // Success
                      setState(() {
                        _dragValue = dragLimit;
                        _isCompleted = true;
                      });
                      HapticService.heavy();
                      widget.onSlideCompleted();
                      
                      // Reset after a delay if needed, but usually we navigate away
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          setState(() {
                            _dragValue = 0.0;
                            _isCompleted = false;
                          });
                        }
                      });
                    } else {
                      // Reset
                      setState(() {
                        _dragValue = 0.0;
                      });
                      HapticService.light();
                    }
                  },
                  child: Container(
                    width: sliderSize,
                    decoration: BoxDecoration(
                      color: widget.sliderColor ?? AppTheme.primary(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary(context).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      widget.icon ?? Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
