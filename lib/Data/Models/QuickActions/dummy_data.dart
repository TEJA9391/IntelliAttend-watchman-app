import 'dart:math';

import 'class_student.dart';
import 'attendance_record.dart';
import 'faculty_message.dart';
import 'export_report.dart';

class DummyDataGenerator {
  DummyDataGenerator._();

  static final Random _random = Random(42);

  static const List<String> _firstNames = [
    'Aarav', 'Vivaan', 'Aditya', 'Vihaan', 'Arjun',
    'Sai', 'Reyansh', 'Krishna', 'Ishaan', 'Shaurya',
    'Atharv', 'Advik', 'Pranav', 'Advaith', 'Aarush',
    'Ananya', 'Diya', 'Myra', 'Sara', 'Aanya',
    'Aadhya', 'Aarohi', 'Anvi', 'Prisha', 'Kavya',
    'Rohan', 'Arnav', 'Dhruv', 'Kabir', 'Veer',
    'Meera', 'Nisha', 'Pooja', 'Riya', 'Simran',
    'Harsh', 'Nikhil', 'Siddharth', 'Tanvi', 'Priya',
    'Gaurav', 'Manish', 'Sakshi', 'Deepika', 'Neha',
    'Raj', 'Pankaj', 'Shruti', 'Divya', 'Karan',
    'Karthik', 'Lakshman', 'Ojas', 'Rahul', 'Vikram',
    'Sneha', 'Pavitra', 'Ritika', 'Tanisha', 'Urmila', 'Tanya', 'Amit',
  ];

  static const List<String> _lastNames = [
    'Sharma', 'Verma', 'Gupta', 'Singh', 'Kumar',
    'Patel', 'Reddy', 'Nair', 'Iyer', 'Mishra',
    'Joshi', 'Rao', 'Choudhary', 'Tiwari', 'Chauhan',
    'Mehta', 'Desai', 'Kapoor', 'Malhotra', 'Chopra',
    'Bhat', 'Pandey', 'Saxena', 'Bhatt', 'Kulkarni',
    'Thakur', 'Pillai', 'Menon', 'Shetty', 'Hegde',
    'Yadav', 'Pandit', 'Mishra', 'Dubey', 'Srivastava',
    'Agarwal', 'Sinha', 'Rastogi', 'Khanna', 'Sethi',
    'Bansal', 'Goyal', 'Jain', 'Ahuja', 'Suri',
    'Nagpal', 'Tandon', 'Khurana', 'Berry', 'Sehgal',
    'Iyengar', 'Prasad', 'Naidu',
    'Bose', 'Dutta', 'Banerjee', 'Mukherjee', 'Sen',
    'Chatterjee', 'Ghosh', 'Das', 'Lahiri', 'Roy',
  ];

  static const List<String> _departments = [
    'CSE', 'AIML', 'ECE', 'EEE', 'MECH', 'CIVIL',
  ];

  static const List<String> _sections = ['A', 'B', 'C', 'D', 'E'];

  static const List<String> _semesters = [
    '1-1', '1-2', '2-1', '2-2', '3-1', '3-2', '4-1', '4-2',
  ];

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
  ];

  static const Map<String, String> _courseMap = {
    'CSE': 'CS101',
    'AIML': 'AL201',
    'ECE': 'EC301',
    'EEE': 'EE401',
    'MECH': 'ME501',
    'CIVIL': 'CV601',
  };

  static const Map<String, String> _courseNameMap = {
    'CSE': 'Computer Science & Engineering',
    'AIML': 'Artificial Intelligence & Machine Learning',
    'ECE': 'Electronics & Communication Engineering',
    'EEE': 'Electrical & Electronics Engineering',
    'MECH': 'Mechanical Engineering',
    'CIVIL': 'Civil Engineering',
  };

  static List<ClassStudent> generateStudents({
    String? section,
    String? courseCode,
  }) {
    final students = <ClassStudent>[];

    for (int i = 0; i < 62; i++) {
      final dept = _departments[i % _departments.length];
      final sec = section ?? _sections[i % 2];
      final firstName = _firstNames[i];
      final lastName = _lastNames[i];
      final name = '$firstName $lastName';
      final email =
          '${firstName.toLowerCase()}.${lastName.toLowerCase()}@student.mrcet.ac.in';
      final phone = '+91${7000000000 + _random.nextInt(2999999999)}';
      final rollPrefix = '21${dept.substring(0, 2)}';
      final rollNum = '${i + 1}'.padLeft(3, '0');
      final totalClasses = 30 + _random.nextInt(20);
      final attendancePct = 45.0 + _random.nextDouble() * 53.0;
      final attendedClasses = (totalClasses * attendancePct / 100).round();
      final isDefaulter = attendancePct < 65.0;
      final isEligible = !isDefaulter && attendancePct >= 65.0;

      final lastSeenDaysAgo = _random.nextInt(5);
      final lastSeenHour = 8 + _random.nextInt(10);
      final lastSeenMinute = _random.nextInt(60);

      students.add(ClassStudent(
        id: 'stu_${(i + 1).toString().padLeft(4, '0')}',
        name: name,
        rollNumber: '$rollPrefix$rollNum',
        email: email,
        phone: phone,
        department: dept,
        section: sec,
        courseCode: courseCode ?? _courseMap[dept],
        courseName: _courseNameMap[dept],
        semester: _semesters[6],
        image: null,
        attendancePercentage: double.parse(attendancePct.toStringAsFixed(1)),
        totalClasses: totalClasses,
        attendedClasses: attendedClasses,
        isEligible: isEligible,
        isDefaulter: isDefaulter,
        gender: i % 2 == 0 ? 'Male' : 'Female',
        lastSeen: DateTime.now().subtract(
          Duration(days: lastSeenDaysAgo, hours: lastSeenHour, minutes: lastSeenMinute),
        ),
        guardianName: '${_lastNames[50 + _random.nextInt(_lastNames.length - 50)]} (${i % 2 == 0 ? 'Father' : 'Mother'})',
        guardianPhone: '+91${8000000000 + _random.nextInt(1999999999)}',
        address: '${_random.nextInt(500) + 1}, Main Road, Hyderabad, Telangana 50000${_random.nextInt(9)}',
        bloodGroup: _bloodGroups[_random.nextInt(_bloodGroups.length)],
      ));
    }

    return students;
  }

  static List<Map<String, dynamic>> generateAttendanceHistory(String studentId) {
    final history = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = 30; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final statusRoll = _random.nextDouble();
      final studentHash = studentId.hashCode;
      final adjustedRoll = (statusRoll + studentHash / 100000) % 1.0;
      AttendanceStatus status;
      DateTime? checkIn;
      if (adjustedRoll < 0.75) {
        status = AttendanceStatus.present;
        checkIn = DateTime(date.year, date.month, date.day, 9 + _random.nextInt(2), _random.nextInt(60));
      } else if (adjustedRoll < 0.85) {
        status = AttendanceStatus.late;
        checkIn = DateTime(date.year, date.month, date.day, 9, 15 + _random.nextInt(45));
      } else if (adjustedRoll < 0.92) {
        status = AttendanceStatus.absent;
      } else if (adjustedRoll < 0.97) {
        status = AttendanceStatus.leave;
      } else {
        status = AttendanceStatus.holiday;
      }
      history.add({
        'date': date,
        'status': status,
        'checkInTime': checkIn,
      });
    }
    return history;
  }

  static List<AttendanceRecord> generateAttendanceRecords(
    List<ClassStudent> students,
  ) {
    final records = <AttendanceRecord>[];
    int recordId = 1;

    for (final student in students) {
      final sessionCount = 5 + _random.nextInt(6);
      for (int s = 0; s < sessionCount; s++) {
        final daysAgo = _random.nextInt(30);
        final date = DateTime.now().subtract(Duration(days: daysAgo));
        final hour = 9 + _random.nextInt(8);
        final minute = _random.nextInt(60);

        final statusRoll = _random.nextDouble();
        AttendanceStatus status;
        DateTime? checkIn;

        if (statusRoll < student.attendancePercentage / 100 * 0.9) {
          status = AttendanceStatus.present;
          checkIn = DateTime(date.year, date.month, date.day, hour, minute);
        } else if (statusRoll < student.attendancePercentage / 100) {
          status = AttendanceStatus.late;
          checkIn = DateTime(date.year, date.month, date.day, hour, minute + 15);
        } else if (statusRoll < 0.95) {
          status = AttendanceStatus.absent;
        } else if (statusRoll < 0.98) {
          status = AttendanceStatus.leave;
        } else {
          status = AttendanceStatus.holiday;
        }

        final dept = student.department ?? 'CSE';
        final courseCode = student.courseCode ?? _courseMap[dept]!;

        records.add(AttendanceRecord(
          id: 'att_${recordId.toString().padLeft(5, '0')}',
          studentId: student.id,
          studentName: student.name,
          rollNumber: student.rollNumber,
          sessionId: 'sess_${(daysAgo + 1).toString().padLeft(3, '0')}',
          courseCode: courseCode,
          courseName: _courseNameMap[dept] ?? 'Unknown Course',
          section: student.section ?? 'A',
          date: date,
          status: status,
          checkInTime: checkIn,
          notes: status == AttendanceStatus.leave ? 'Approved leave' : null,
          markedBy: _random.nextBool() ? 'faculty_auto' : 'manual',
          sessionType: _random.nextBool() ? 'lecture' : 'lab',
        ));

        recordId++;
      }
    }

    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  static List<AttendanceSession> generateSessions({int count = 20}) {
    final sessions = <AttendanceSession>[];

    for (int i = 0; i < count; i++) {
      final daysAgo = _random.nextInt(30);
      final date = DateTime.now().subtract(Duration(days: daysAgo));
      final dept = _departments[_random.nextInt(_departments.length)];
      final sec = _sections[_random.nextInt(2)];
      final totalStudents = 25 + _random.nextInt(26);
      final presentCount = (totalStudents * (0.6 + _random.nextDouble() * 0.35)).round();
      final lateCount = _random.nextInt(4);
      final leaveCount = _random.nextInt(3);
      final absentCount = totalStudents - presentCount - lateCount - leaveCount;

      sessions.add(AttendanceSession(
        sessionId: 'sess_${(i + 1).toString().padLeft(3, '0')}',
        courseCode: _courseMap[dept]!,
        courseName: _courseNameMap[dept]!,
        section: sec,
        date: date,
        totalStudents: totalStudents,
        presentCount: presentCount,
        absentCount: absentCount.clamp(0, totalStudents),
        lateCount: lateCount,
        leaveCount: leaveCount,
        status: i < 2 ? 'active' : 'completed',
        duration: Duration(minutes: 45 + _random.nextInt(46)),
      ));
    }

    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }

  static List<FacultyMessage> generateMessages({int count = 30}) {
    final messageTemplates = <Map<String, String>>[
      {
        'subject': 'Assignment Deadline Extended',
        'body': 'The deadline for Unit-3 assignment has been extended to next Friday. Please submit on time.',
      },
      {
        'subject': 'Lab Session Rescheduled',
        'body': 'Tomorrow\'s lab session is rescheduled to Thursday 2:00 PM. Bring your laptops.',
      },
      {
        'subject': 'Mid-Exam Schedule Released',
        'body': 'Mid-semester examination schedule has been published. Check the notice board for details.',
      },
      {
        'subject': 'Project Submission Reminder',
        'body': 'Final year project reports are due by end of this week. Ensure proper formatting.',
      },
      {
        'subject': 'Guest Lecture on AI',
        'body': 'A guest lecture on "Recent Trends in AI" will be held on Saturday at 10:00 AM in Seminar Hall.',
      },
      {
        'subject': 'Class Cancelled Today',
        'body': 'Today\'s class is cancelled due to unavoidable circumstances. Self-study the assigned chapter.',
      },
      {
        'subject': 'Attendance Shortage Warning',
        'body': 'Students below 65% attendance are advised to improve immediately. Next parent meeting is scheduled.',
      },
      {
        'subject': 'Workshop Registration Open',
        'body': 'Registration for the "Cloud Computing Workshop" is now open. Limited seats available.',
      },
      {
        'subject': 'Marks Updated on Portal',
        'body': 'Internal assessment marks for Mid-1 have been updated. Check the student portal.',
      },
      {
        'subject': 'New Study Material Shared',
        'body': 'Important reference material for the upcoming unit test has been uploaded to LMS.',
      },
      {
        'subject': 'Parent Meeting Scheduled',
        'body': 'Parent-teacher meeting is scheduled for next Saturday. Parents of defaulter students must attend.',
      },
      {
        'subject': 'Lab Report Submission',
        'body': 'All pending lab reports must be submitted by Wednesday. No extensions will be granted.',
      },
      {
        'subject': 'Industrial Visit Announcement',
        'body': 'An industrial visit to BHEL has been organized for next month. Interested students register now.',
      },
      {
        'subject': 'Revised Timetable',
        'body': 'The timetable for this week has been revised due to the college function. Check the updated schedule.',
      },
      {
        'subject': 'Code Review Session',
        'body': 'A code review session for the mini-project will be conducted during tomorrow\'s lab hour.',
      },
    ];

    final messages = <FacultyMessage>[];
    final now = DateTime.now();
    const senderId = 'fac_001';
    const senderName = 'Dr. Rajesh Kumar';

    for (int i = 0; i < count; i++) {
      final template = messageTemplates[i % messageTemplates.length];
      final typeIndex = _random.nextInt(MessageType.values.length);
      final type = MessageType.values[typeIndex];
      final statusIndex = _random.nextInt(MessageStatus.values.length);
      final status = MessageStatus.values[statusIndex];
      final createdAt = now.subtract(Duration(
        days: _random.nextInt(14),
        hours: _random.nextInt(24),
        minutes: _random.nextInt(60),
      ));

      final dept = _departments[_random.nextInt(_departments.length)];
      final recipientCount = type == MessageType.individual
          ? 1
          : type == MessageType.parent
              ? 10 + _random.nextInt(30)
              : 30 + _random.nextInt(70);

      final readCount = status == MessageStatus.read
          ? recipientCount
          : status == MessageStatus.delivered
              ? (recipientCount * _random.nextDouble()).round()
              : 0;

      messages.add(FacultyMessage(
        id: 'msg_${(i + 1).toString().padLeft(4, '0')}',
        senderId: senderId,
        senderName: senderName,
        recipientId: type == MessageType.individual
            ? 'stu_${(_random.nextInt(50) + 1).toString().padLeft(4, '0')}'
            : null,
        recipientName: type == MessageType.individual
            ? '${_firstNames[_random.nextInt(50)]} ${_lastNames[_random.nextInt(50)]}'
            : null,
        subject: template['subject']!,
        body: template['body']!,
        type: type,
        status: status,
        createdAt: createdAt,
        readAt: status == MessageStatus.read
            ? createdAt.add(Duration(hours: _random.nextInt(48)))
            : null,
        attachments: _random.nextBool()
            ? ['attachment_${i + 1}.pdf']
            : [],
        courseCode: _courseMap[dept],
        section: _sections[_random.nextInt(2)],
        recipientCount: recipientCount,
        readCount: readCount,
      ));
    }

    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  static List<MessageThread> generateThreads() {
    final threads = <MessageThread>[];
    final messages = generateMessages(count: 30);

    final participantMap = <String, FacultyMessage>{};
    for (final msg in messages) {
      final key = msg.recipientId ?? msg.senderId;
      if (!participantMap.containsKey(key)) {
        participantMap[key] = msg;
      }
    }

    final entries = participantMap.entries.toList();
    for (int i = 0; i < entries.length && i < 10; i++) {
      final entry = entries[i];
      threads.add(MessageThread(
        threadId: 'thread_${(i + 1).toString().padLeft(3, '0')}',
        participantName: entry.value.recipientName ?? entry.value.senderName,
        participantId: entry.key,
        lastMessage: entry.value,
        unreadCount: _random.nextInt(5),
        isOnline: _random.nextBool(),
      ));
    }

    threads.sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
    return threads;
  }

  static List<ExportReport> generateReports({int count = 15}) {
    final reports = <ExportReport>[];

    final reportTitles = <Map<String, String>>[
      {'title': 'Monthly Attendance Report - CSE', 'type': 'monthly'},
      {'title': 'Daily Summary - Section A', 'type': 'daily'},
      {'title': 'Weekly Report - All Departments', 'type': 'weekly'},
      {'title': 'Student Attendance List - AIML', 'type': 'studentList'},
      {'title': 'Session Summary - ECE 3rd Year', 'type': 'sessionSummary'},
      {'title': 'Defaulter List - CSE Dept', 'type': 'attendance'},
      {'title': 'Subject-wise Report - CS101', 'type': 'subject'},
      {'title': 'Department Overview - EEE', 'type': 'department'},
      {'title': 'Monthly Report - MECH Section B', 'type': 'monthly'},
      {'title': 'Daily Attendance - CIVIL', 'type': 'daily'},
      {'title': 'Session Report - Lab Sessions', 'type': 'sessionSummary'},
      {'title': 'Student List - ECE Section A', 'type': 'studentList'},
      {'title': 'Weekly Summary - CSE Section B', 'type': 'weekly'},
      {'title': 'Subject Report - AL201', 'type': 'subject'},
      {'title': 'Department Report - All Depts', 'type': 'department'},
    ];

    const formats = ExportFormat.values;

    for (int i = 0; i < count; i++) {
      final template = reportTitles[i % reportTitles.length];
      final reportType = _parseReportTypeFromString(template['type']!);
      final format = formats[i % formats.length];
      final generatedAt = DateTime.now().subtract(Duration(
        days: _random.nextInt(30),
        hours: _random.nextInt(24),
      ));
      final dateFrom = generatedAt.subtract(const Duration(days: 30));
      final fileSize = format == ExportFormat.pdf
          ? 50.0 + _random.nextDouble() * 200
          : format == ExportFormat.excel
              ? 30.0 + _random.nextDouble() * 100
              : 10.0 + _random.nextDouble() * 50;

      final dept = _departments[_random.nextInt(_departments.length)];

      reports.add(ExportReport(
        id: 'rpt_${(i + 1).toString().padLeft(4, '0')}',
        title: template['title']!,
        type: reportType,
        format: format,
        generatedAt: generatedAt,
        dateFrom: dateFrom,
        dateTo: generatedAt,
        courseCode: _courseMap[dept],
        section: _sections[_random.nextInt(2)],
        semester: _semesters[_random.nextInt(_semesters.length)],
        recordCount: 50 + _random.nextInt(500),
        filePath: '/exports/${template['title']!.toLowerCase().replaceAll(' ', '_')}.${format.name}',
        fileSizeKB: double.parse(fileSize.toStringAsFixed(1)),
        status: _random.nextBool() ? 'completed' : 'completed',
      ));
    }

    reports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return reports;
  }

  static ReportType _parseReportTypeFromString(String value) {
    switch (value) {
      case 'studentList':
        return ReportType.studentList;
      case 'sessionSummary':
        return ReportType.sessionSummary;
      case 'daily':
        return ReportType.daily;
      case 'weekly':
        return ReportType.weekly;
      case 'monthly':
        return ReportType.monthly;
      case 'subject':
        return ReportType.subject;
      case 'department':
        return ReportType.department;
      default:
        return ReportType.attendance;
    }
  }
}
