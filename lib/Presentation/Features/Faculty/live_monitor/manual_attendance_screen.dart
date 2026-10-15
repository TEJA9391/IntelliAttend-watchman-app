import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'live_monitor_controller.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final LiveMonitorController controller;

  const ManualAttendanceScreen({Key? key, required this.controller}) : super(key: key);

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Manual Override", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchField(),
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search by name or email...",
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary(context)),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    final allStudents = widget.controller.mergedStudents;
    final filtered = allStudents.where((s) => 
      s.name.toLowerCase().contains(_searchQuery) || 
      s.id.toLowerCase().contains(_searchQuery)
    ).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text("No students found.", style: TextStyle(color: Colors.white38))
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final student = filtered[index];
        final bool isPresent = student.status == StudentStatus.present;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPresent ? AppTheme.primary(context).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.white10,
              backgroundImage: student.image != null ? NetworkImage(student.image!) : null,
              child: student.image == null ? const Icon(Icons.person, color: Colors.white38) : null,
            ),
            title: Text(student.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(student.id, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: isPresent 
              ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
              : ElevatedButton(
                  onPressed: () => _showMarkPresentDialog(context, student),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary(context).withValues(alpha: 0.1),
                    foregroundColor: AppTheme.primary(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Mark Present", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
          ),
        );
      },
    );
  }

  void _showMarkPresentDialog(BuildContext context, StudentAttendance student) {
    final TextEditingController notesController = TextEditingController();
    final bool hasEmail = student.email != null && student.email!.isNotEmpty;
    final bool isWsConnected = widget.controller.wsConnectionState == 'connected';

    String selectedReason = isWsConnected ? 'live_tap' : 'late_arrival';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.id, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 14)),
                  const SizedBox(height: 16),
                  const Text("Status: Absent", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  if (!hasEmail) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        "Manual marking disabled: Student email missing. SmartBoard sync requires an email identifier.",
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text("Marking Path:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      dropdownColor: AppTheme.surface(context),
                      value: selectedReason,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.bg(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: [
                        if (isWsConnected)
                          const DropdownMenuItem(
                            value: 'live_tap',
                            child: Text("Live Tap (WebSocket)", style: TextStyle(color: Colors.white)),
                          ),
                        const DropdownMenuItem(
                          value: 'late_arrival',
                          child: Text("Retrospective: Late Arrival", style: TextStyle(color: Colors.white)),
                        ),
                        const DropdownMenuItem(
                          value: 'missed_scan',
                          child: Text("Retrospective: Missed Scan", style: TextStyle(color: Colors.white)),
                        ),
                        const DropdownMenuItem(
                          value: 'system_error',
                          child: Text("Retrospective: System Error", style: TextStyle(color: Colors.white)),
                        ),
                        const DropdownMenuItem(
                          value: 'other',
                          child: Text("Retrospective: Other", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedReason = val;
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Notes (optional)",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppTheme.bg(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  onPressed: !hasEmail ? null : () {
                    Navigator.pop(context);
                    _markPresent(student, reason: selectedReason, notes: notesController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary(context),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("MARK PRESENT"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markPresent(StudentAttendance student, {required String reason, String? notes}) async {
    try {
      final success = await widget.controller.markStudentPresent(student.id, reason: reason, notes: notes);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${student.name} marked as present."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          )
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to mark attendance. Check GPS and try again."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = "Failed to mark attendance.";
        if (e.toString().contains("ALREADY_MARKED")) {
          final source = e.toString().split(":").last;
          msg = "Already marked by $source";
        } else if (e.toString().contains("MISSING_EMAIL")) {
          msg = "Cannot mark: Student email missing.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }
}
