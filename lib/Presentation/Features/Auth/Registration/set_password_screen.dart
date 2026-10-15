import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/registration_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/permission_service.dart';
import 'package:google_fonts/google_fonts.dart';


class SetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const SetPasswordScreen({Key? key, required this.email, required this.otp}) : super(key: key);

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleComplete() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = "Password must be at least 6 characters.");
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _error = "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      final snapshot = await HardwareService.getDeviceSnapshot();

      // Step 1: Get auth status to retrieve user_id
      final authStatus = await authRepo.checkAuthStatus();
      final userId = authStatus.userId;
      if (userId == null) {
        setState(() {
          _error = "Could not verify your identity. Please restart registration.";
          _isLoading = false;
        });
        return;
      }

      final deviceInfoPayload = DeviceInfoPayload(
        deviceId: snapshot.deviceId,
        deviceFingerprint: snapshot.fingerprint,
        brand: snapshot.manufacturer,
        model: snapshot.model,
        manufacturer: snapshot.manufacturer,
        osVersion: snapshot.osVersion,
        biometricsEnabled: true,
      );

      // Step 2: Complete registration (verify OTP, set password, bind device)
      final request = RegistrationCompleteRequest(
        userId: userId,
        otp: widget.otp,
        password: password,
        deviceInfo: deviceInfoPayload.toJson(),
      );

      final response = await authRepo.completeRegistration(request);

      if (response.status == 'success') {
        // Step 3: Bind device via session verification
        try {
          await authRepo.verifySession(deviceInfoPayload);
        } catch (_) {
          debugPrint('⚠️ verifySession failed post-registration — non-blocking');
        }

        // Step 4: Request Permissions
        await PermissionService().requestAll();

        // Step 5: Fetch faculty profile
        await FacultyService.loadBaseProfile();

        // Step 6: Set persistence flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } else {
        setState(() {
          _error = response.error ?? "Failed to complete registration. Please check your connection.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred during completion. Please try again.";
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
            "Secure Faculty Account", 
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
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: AppTheme.accentTeal, size: 40),
              ),
              const SizedBox(height: 32),
              Text("Set Password", maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text("Create a strong password and secure your device binding.", maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Create Password",
                  prefixIcon: Icon(Icons.password_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: Icon(Icons.password_rounded),
                ),
              ),
              const SizedBox(height: 32),
              _buildSecurityBadge(context),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _isLoading ? null : _handleComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Complete Registration"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentTeal.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phonelink_lock_rounded, color: AppTheme.accentTeal, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hardware Binding", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text("This phone will be linked to your Faculty ID", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("TRUSTED", style: TextStyle(color: AppTheme.accentTeal, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        ],
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
