import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Core/Services/security_controller.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _timedOut = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    security.isAuthenticating
                        ? 'Authenticating...'
                        : _timedOut
                            ? 'Timed out. Tap to retry.'
                            : _errorMessage != null
                                ? _errorMessage!
                                : 'Tap to unlock',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (!mounted) return;
    final security = context.read<SecurityController>();
    if (security.isCompromised || security.isAuthenticating) return;
    if (!security.isLocked) return;

    setState(() {
      _timedOut = false;
      _errorMessage = null;
    });

    try {
      final result = await security.authenticate();
      if (!mounted) return;
      if (!result && security.isLocked) {
        setState(() => _timedOut = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Authentication failed. Tap to retry.';
      });
    }
  }
}
