import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'registration/registration_screen.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Core/error/error_handler.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginScreen extends StatefulWidget {
  final String? initialError;
  const LoginScreen({Key? key, this.initialError}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  String? _authError;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _authError = widget.initialError;
    _loadVersion();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('last_login_email');
    if (savedEmail != null && mounted) {
      _emailController.text = savedEmail;
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  void _navigateToDashboard() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('⚠️ Token refresh failed (non-critical): $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _DashboardGate()),
      (route) => false,
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _authError = "Enter your email first, then tap Forgot Password.");
      return;
    }
    if (!email.endsWith('@mrcet.ac.in')) {
      setState(() => _authError = "Enter your full university email (e.g. fac01@mrcet.ac.in).");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email.")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _authError = e.message ?? "Failed to send reset email.");
    }
  }

  Future<void> _handleLogin() async {
    String email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _authError = "Faculty ID / Email is required.");
      return;
    }

    if (!email.endsWith('@mrcet.ac.in')) {
      setState(() => _authError = "Please enter your full university email (e.g. fac01@mrcet.ac.in).");
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      setState(() => _authError = "Email and password are required.");
      return;
    }

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.signIn(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_email', email);

      // ── Auth Decision Tree (matches Student app) ──────────────────────
      // Step 1: POST /auth/status + POST /auth/verify-session
      final String? flowError = await FacultyService.executeAuthFlow(authRepo);

      if (!mounted) return;

      if (flowError != null) {
        await authRepo.signOut();
        setState(() {
          _isLoading = false;
          _authError = flowError;
        });
        return;
      }

      // Step 2: Route based on registration status
      setState(() => _isLoading = false);

      if (FacultyService.isRegistered.value) {
        _navigateToDashboard();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(
              preloadedEmail: email,
              fromLogin: true,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHandler.showVisualError(context, e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHandler.showVisualError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Theme(
      data: AppTheme.getAuthTheme(context),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // High-Fidelity Branding Integration
                  Image.asset(
                    'assets/images/logo.png',
                    width: 240,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  Text(
                    "IntelliAttend",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 32,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Smart. Secure. Seamless Faculty Portal.",
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: theme.brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B),
                      letterSpacing: 0,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  if (_authError != null) ...[
                    Card(
                      color: colorScheme.errorContainer.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.error.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _authError!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: "Faculty ID / Email",
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          hintText: "user@mrcet.ac.in",
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          hintText: "Enter your password",
                          suffixIcon: IconButton(
                            icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword, 
                      child: const Text("Forgot Password?"),
                    ),
                  ),

                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                      : const Text("SIGN IN"),
                  ),

                  const SizedBox(height: 48),
                  Text(
                    "v$_appVersion • SECURE FACULTY SYSTEM",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      letterSpacing: 1.5,
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
}

class _DashboardGate extends StatefulWidget {
  const _DashboardGate({Key? key}) : super(key: key);

  @override
  State<_DashboardGate> createState() => _DashboardGateState();
}

class _DashboardGateState extends State<_DashboardGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FacultyService.isRegistered.value) {
        _goToDashboard();
      } else {
        _goToLogin();
      }
    });
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
