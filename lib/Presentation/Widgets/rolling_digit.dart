import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RollingDigitGroup extends StatelessWidget {
  final String? code;
  final TextStyle? style;

  const RollingDigitGroup({
    Key? key,
    this.code,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final characters = code?.split('') ?? [];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBlock(characters.take(2).toList(), startIndex: 0),
        _buildDash(context),
        _buildBlock(characters.skip(2).toList(), startIndex: 2),
      ],
    );
  }

  Widget _buildBlock(List<String> digits, {required int startIndex}) {
    final delays = startIndex == 0
        ? [0, 100]
        : [200, 300];

    return Row(
      children: List.generate(2, (index) {
        final String? char = index < digits.length ? digits[index] : null;
        final asInt = (char != null) ? int.tryParse(char) : null;
        return RollingDigit(
          // Stable key per slot so the widget keeps its random seed across rebuilds
          key: ValueKey('rolling_digit_${startIndex + index}'),
          slotIndex: startIndex + index,
          digit: asInt,
          // Non-numeric chars (e.g. "!") render statically without animation
          staticChar: (char != null && asInt == null) ? char : null,
          style: style,
          lockDelay: Duration(milliseconds: delays[index]),
        );
      }),
    );
  }

  Widget _buildDash(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        "-",
        style: GoogleFonts.jetBrainsMono(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
          fontSize: 48,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RollingDigit extends StatefulWidget {
  final int? digit;
  final String? staticChar;
  final TextStyle? style;
  final Duration lockDelay;
  final int slotIndex;

  const RollingDigit({
    Key? key,
    this.digit,
    this.staticChar,
    this.style,
    this.lockDelay = Duration.zero,
    this.slotIndex = 0,
  }) : super(key: key);

  @override
  State<RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<RollingDigit>
    with TickerProviderStateMixin {
  static const int _stripDigits = 10;

  late final double _digitHeight;
  late final double _digitWidth;
  late final double _stripHeight;

  late AnimationController _spinController;
  late AnimationController _lockController;
  late Animation<double> _lockAnimation;

  // Per-slot randomized characteristics
  late int _direction;       // +1 = downward visual roll, -1 = upward
  late double _phaseOffset;  // initial offset within strip
  late int _spinDurationMs;  // per-cycle duration (controls speed)

  double _currentOffset = 0.0;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();

    // Slot dimensions derived from font size — generous padding so glyph
    // ascenders/descenders never overflow the clip box.
    final fontSize = widget.style?.fontSize ?? 60.0;
    _digitHeight = fontSize * 1.4;
    _digitWidth = fontSize * 0.85;
    _stripHeight = _digitHeight * _stripDigits;

    // Deterministic per-slot randomness so direction/speed don't reshuffle on rebuild
    final rng = Random(widget.slotIndex * 8675309 + 17);
    _direction = rng.nextBool() ? 1 : -1;
    _phaseOffset = rng.nextDouble() * _stripHeight;
    // Tight speed band — coherent group motion, not chaotic.
    // Full 0..9 cycle takes 3200-3800ms.
    _spinDurationMs = 3200 + rng.nextInt(600);

    _spinController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _spinDurationMs),
    );

    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _lockAnimation = CurvedAnimation(
      parent: _lockController,
      curve: Curves.easeOutCubic,
    );

    if (widget.staticChar != null) {
      // No animation — render static char.
    } else if (widget.digit == null) {
      _spinController.repeat();
    } else {
      _isLocked = true;
      _currentOffset = widget.digit! * _digitHeight;
    }
  }

  @override
  void didUpdateWidget(RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSpinning = oldWidget.digit == null && oldWidget.staticChar == null;
    if (wasSpinning && widget.digit != null) {
      _lockIntoDigit(widget.digit!);
    } else if (wasSpinning && widget.staticChar != null) {
      _spinController.stop();
    } else if (!wasSpinning && widget.digit == null && widget.staticChar == null) {
      _isLocked = false;
      _spinController.repeat();
    }
  }

  double _currentSpinOffset() {
    final base = _phaseOffset + _direction * _spinController.value * _stripHeight;
    return ((base % _stripHeight) + _stripHeight) % _stripHeight;
  }

  void _lockIntoDigit(int digit) {
    if (_isLocked) return;

    final double startVal = _currentSpinOffset();
    final double endVal = digit * _digitHeight;

    if (widget.lockDelay == Duration.zero) {
      _animateLock(startVal, endVal);
    } else {
      Future.delayed(widget.lockDelay, () {
        if (mounted && !_isLocked) {
          _animateLock(_currentSpinOffset(), endVal);
        }
      });
    }
  }

  void _animateLock(double startVal, double endVal) {
    _spinController.stop();

    // Continue in the current direction so the lock feels like a smooth
    // deceleration rather than a snap. Add at least one extra full revolution
    // so the eye sees a clear "slowing" rather than an instant stop.
    double adjustedEnd = endVal;
    if (_direction > 0) {
      while (adjustedEnd < startVal) adjustedEnd += _stripHeight;
      adjustedEnd += _stripHeight; // one extra cycle of glide
    } else {
      while (adjustedEnd > startVal) adjustedEnd -= _stripHeight;
      adjustedEnd -= _stripHeight; // one extra cycle of glide
    }

    _lockAnimation = Tween<double>(
      begin: startVal,
      end: adjustedEnd,
    ).animate(CurvedAnimation(
      parent: _lockController,
      curve: Curves.easeOutCubic,
    ));

    _lockController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _currentOffset = endVal;
        });
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _lockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ??
        GoogleFonts.jetBrainsMono(
          fontSize: 48,
          fontWeight: FontWeight.w800,
        );

    final innerStyle = textStyle.copyWith(height: 1.0, letterSpacing: 0);

    // Static-char mode (e.g. "!") renders without any animation/clip overhead.
    if (widget.staticChar != null) {
      return SizedBox(
        height: _digitHeight,
        width: _digitWidth,
        child: Center(
          child: Text(
            widget.staticChar!,
            textAlign: TextAlign.center,
            style: innerStyle,
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: ClipRect(
        child: SizedBox(
          height: _digitHeight,
          width: _digitWidth,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spinController, _lockController]),
              builder: (context, child) {
                double offset;
                if (_isLocked) {
                  offset = _currentOffset;
                } else if (_lockController.isAnimating) {
                  offset = _lockAnimation.value;
                } else {
                  offset = _currentSpinOffset();
                }

                final wrapped = ((offset % _stripHeight) + _stripHeight) % _stripHeight;

                return Transform.translate(
                  offset: Offset(0, -wrapped),
                  child: child!,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_stripDigits * 2, (index) {
                  return SizedBox(
                    height: _digitHeight,
                    width: _digitWidth,
                    child: Center(
                      child: Text(
                        "${index % 10}",
                        textAlign: TextAlign.center,
                        style: innerStyle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
