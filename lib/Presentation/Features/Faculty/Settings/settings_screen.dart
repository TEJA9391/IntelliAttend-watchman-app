import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Core/Services/security_controller.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBackPressed;
  const SettingsScreen({Key? key, required this.onBackPressed}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _showSaveButton = false;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _urlController = TextEditingController(text: apiClient.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Mirrored from Kotlin
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBackPressed,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildServerSection(),
            const SizedBox(height: 24),
            _buildSecuritySection(),
            const SizedBox(height: 24),
            _buildHelpSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSection() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("🌐 Backend Server Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            const Text("Server URL", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              onChanged: (v) {
                setState(() => _showSaveButton = v != context.read<ApiClient>().baseUrl);
              },
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: "http://192.168.0.1:8000",
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF475569)), borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF3B82F6)), borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            const Text("⚠️ IP address and port (default: 8000)", style: TextStyle(fontSize: 11, color: Color(0xFFFBBF24))),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_showSaveButton)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<ApiClient>().updateBaseUrl(_urlController.text);
                        setState(() => _showSaveButton = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server URL Updated")));
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    ),
                  ),
                if (_showSaveButton) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _urlController.text = context.read<ApiClient>().baseUrl;
                      setState(() => _showSaveButton = _urlController.text != context.read<ApiClient>().baseUrl);
                    },                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("RESET", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF475569))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📖 Connectivity Help", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildHelpStep("1", "Ensure your phone has a stable internet connection."),
            _buildHelpStep("2", "Find PC IP (ifconfig / ipconfig)."),
            _buildHelpStep("3", "Use format http://<IP>:8000"),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Consumer<SecurityController>(
      builder: (context, security, _) {
        return Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("🔒 Security", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Lock app on background", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Require fingerprint when you return to the app", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: security.biometricLockEnabled,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (value) async {
                    if (value) {
                      security.lock();
                      final didAuth = await security.authenticate();
                      if (!didAuth) {
                        security.unlock();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Biometric verification failed. Cannot enable lock."),
                              backgroundColor: Color(0xFFEF4444),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (context.mounted) {
                      security.setBiometricLockEnabled(value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? "App lock enabled" : "App lock disabled"),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(4)),
            child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
