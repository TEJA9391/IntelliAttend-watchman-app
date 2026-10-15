import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class StudentDirectoryScreen extends StatelessWidget {
  const StudentDirectoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> students = [
      {
        'name': 'Aditya Kumar',
        'id': '2024CS001',
        'attendance': '98%',
        'status': 'Present',
        'img': 'https://i.pravatar.cc/150?u=1'
      },
      {
        'name': 'Sneha Sharma',
        'id': '2024CS002',
        'attendance': '92%',
        'status': 'Present',
        'img': 'https://i.pravatar.cc/150?u=2'
      },
      {
        'name': 'Rohan Das',
        'id': '2024CS003',
        'attendance': '85%',
        'status': 'Absent',
        'img': 'https://i.pravatar.cc/150?u=3'
      },
      {
        'name': 'Priya Singh',
        'id': '2024CS004',
        'attendance': '75%',
        'status': 'Present',
        'img': 'https://i.pravatar.cc/150?u=4'
      },
      {
        'name': 'Vikram Mehra',
        'id': '2024CS005',
        'attendance': '88%',
        'status': 'Present',
        'img': 'https://i.pravatar.cc/150?u=5'
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text("Student Directory",
            style: TextStyle(
                color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppTheme.text(context)),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search student name or ID...",
                prefixIcon:
                    Icon(Icons.search, color: AppTheme.slate500(context)),
                fillColor: AppTheme.surface(context),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01), blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundImage: NetworkImage(student['img']),
                          radius: 26),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppTheme.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text(student['id'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(student['attendance'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.primary(context),
                                  fontWeight: FontWeight.bold)),
                          Text(student['status'],
                              style: TextStyle(
                                  color: student['status'] == 'Present'
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
