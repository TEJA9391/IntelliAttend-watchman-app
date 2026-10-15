import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String? preloadedEmail;
  final bool fromLogin;
  const RegistrationScreen({Key? key, this.preloadedEmail, this.fromLogin = false}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedEmail != null) {
      _emailController.text = widget.preloadedEmail!;
    }
  }

  Future<void> _handleInitiate() async {
    String email = _emailController.text.trim().toLowerCase();
    
    if (email.isEmpty || !email.endsWith('@mrcet.ac.in')) {
      setState(() => _error = "Please enter your full university email (e.g. fac01@mrcet.ac.in).");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.sendOtp();

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email),
        ),
      );
    } catch (e) {
      setState(() {
        _error = "An error occurred. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getAuthTheme(context),
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Faculty Registration", 
            style: GoogleFonts.inter(
              color: AppTheme.text(context), 
              fontWeight: FontWeight.bold,
              fontSize: 18,
            )
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) _buildError(context, _error!),
              
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text("Identify Yourself", style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text("Confirm your university ID to receive a secure verification code.", maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                readOnly: widget.fromLogin,
                decoration: InputDecoration(
                  labelText: "University ID",
                  hintText: "fac01@mrcet.ac.in",
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  filled: widget.fromLogin,
                  fillColor: widget.fromLogin ? AppTheme.accentTeal.withOpacity(0.05) : null,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _isLoading ? null : _handleInitiate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Send Verification Code"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13))),
        ],
      ),
    );
  }
}
