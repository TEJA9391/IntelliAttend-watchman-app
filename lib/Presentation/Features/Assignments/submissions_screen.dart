import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({Key? key}) : super(key: key);

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  final List<Map<String, dynamic>> _assignments = [
    {
      'title': 'Backpropagation Lab',
      'course': 'CSE-402',
      'submitted': 42,
      'total': 55,
      'dueDate': '28 Mar 2024',
      'status': 'Active',
    },
    {
      'title': 'Ethics Case Study',
      'course': 'HUM-101',
      'submitted': 55,
      'total': 55,
      'dueDate': '22 Mar 2024',
      'status': 'Completed',
    },
    {
      'title': 'ML Model Optimization',
      'course': 'AI-301',
      'submitted': 12,
      'total': 55,
      'dueDate': '02 Apr 2024',
      'status': 'Active',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text("Submissions",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.text(context),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final a = _assignments[index];
          final double progress = a['submitted'] / a['total'];
          final bool isCompleted = a['submitted'] == a['total'];

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.border(context).withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.text(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text("${a['course']} • Due: ${a['dueDate']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    _buildStatusBadge(a['status']),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text("Completion Rate",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textSecondary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Flexible(
                      child: Text("${a['submitted']}/${a['total']} Students",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.primary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.primary(context).withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted ? Colors.green : AppTheme.primary(context)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showSubmissionDetails(a),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side:
                          BorderSide(color: AppTheme.primary(context).withValues(alpha: 0.3)),
                    ),
                    child: Text("View Breakdown",
                        style: TextStyle(
                            color: AppTheme.primary(context),
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSubmissionDetails(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${a['title']} - Submissions",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 24),
              _buildSubmissionTile("John Doe", "submitted", "10:30 AM Today"),
              _buildSubmissionTile(
                  "Jane Smith", "submitted", "09:15 AM Yesterday"),
              _buildSubmissionTile("Mark Wilson", "absent", "Not Submitted"),
              _buildSubmissionTile(
                  "Emma Brown", "submitted", "02:45 PM Yesterday"),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary(context),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Close",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmissionTile(String name, String status, String time) {
    final bool isDone = status == "submitted";
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDone
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            radius: 18,
            child: Icon(isDone ? Icons.check : Icons.close,
                size: 16, color: isDone ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.text(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
          if (isDone)
            Text("VIEW",
                style: TextStyle(
                    color: AppTheme.primary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final bool isDone = status == "Completed";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withValues(alpha: 0.1)
            : AppTheme.primary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: isDone ? Colors.green : AppTheme.primary(context),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }
}
