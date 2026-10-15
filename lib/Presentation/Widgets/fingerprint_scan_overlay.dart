import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class FingerprintScanOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const FingerprintScanOverlay({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<FingerprintScanOverlay> createState() => _FingerprintScanOverlayState();
}

class _FingerprintScanOverlayState extends State<FingerprintScanOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // v13.0 SECURITY PATCH: Simulation backdoor removed.
    // The overlay now only serves as a visual indicator.
    // Logic moved to SecurityController for native hardware enforcement.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: Colors.black.withValues(alpha: 0.7)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    _isSuccess ? "Identity Verified" : "Touch ID Required", 
                    key: ValueKey(_isSuccess),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSuccess ? "Access Granted" : "Hold finger on sensor to login",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis, 
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)
                ),
                const SizedBox(height: 60),
                
                ScaleTransition(
                  scale: _isSuccess ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: _isSuccess ? AppTheme.greenOnline.withValues(alpha: 0.2) : AppTheme.primary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSuccess ? AppTheme.greenOnline : AppTheme.primary(context).withValues(alpha: 0.5),
                        width: 4
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isSuccess ? AppTheme.greenOnline : AppTheme.primary(context)).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10
                        )
                      ]
                    ),
                    child: Center(
                      child: Icon(
                        _isSuccess ? Icons.check : Icons.fingerprint,
                        color: _isSuccess ? AppTheme.greenOnline : AppTheme.primary(context),
                        size: 80,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 80),
                if (!_isSuccess)
                  Text(
                    "REAL-TIME SCANNING",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white60),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
