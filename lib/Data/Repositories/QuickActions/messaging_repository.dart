import 'dart:math';

import 'package:intelli_attend_faculty/Data/Models/QuickActions/faculty_message.dart';

class MessagingRepository {
  final List<FacultyMessage> _messages = [];
  final List<MessageThread> _threads = [];
  int _nextId = 1;

  MessagingRepository() {
    _generateMessages(200);
    _generateThreads();
  }

  void _generateMessages(int count) {
    final random = Random(42);

    const firstNames = [
      'Aarav', 'Vivaan', 'Aditya', 'Vihaan', 'Arjun', 'Sai', 'Reyansh',
      'Krishna', 'Ishaan', 'Shaurya', 'Ananya', 'Diya', 'Myra', 'Sara',
      'Aanya', 'Rohan', 'Arnav', 'Dhruv', 'Kabir', 'Veer', 'Meera',
      'Nisha', 'Pooja', 'Riya', 'Simran', 'Harsh', 'Nikhil', 'Siddharth',
      'Tanvi', 'Priya', 'Gaurav', 'Manish', 'Sakshi', 'Deepika', 'Neha',
      'Raj', 'Pankaj', 'Shruti', 'Divya', 'Karan', 'Karthik', 'Rahul',
      'Vikram', 'Sneha', 'Ritika', 'Amit',
    ];
    const lastNames = [
      'Sharma', 'Verma', 'Gupta', 'Singh', 'Kumar', 'Patel', 'Reddy',
      'Nair', 'Iyer', 'Mishra', 'Joshi', 'Rao', 'Mehta', 'Desai',
      'Kapoor', 'Malhotra', 'Chopra', 'Bhat', 'Pandey', 'Saxena',
    ];
    const departments = ['CSE', 'AIML', 'ECE', 'EEE', 'MECH', 'CIVIL'];
    const sections = ['A', 'B', 'C', 'D', 'E'];
    const courseMap = {
      'CSE': 'CS101', 'AIML': 'AL201', 'ECE': 'EC301',
      'EEE': 'EE401', 'MECH': 'ME501', 'CIVIL': 'CV601',
    };
    const parents = [
      'Mr. Rajesh Sharma', 'Mrs. Sunita Gupta', 'Mr. Vikram Mehta',
      'Mrs. Priyanka Patel', 'Mr. Anil Kumar', 'Mrs. Suman Reddy',
      'Mr. Deepak Nair', 'Mrs. Kavita Iyer', 'Mr. Ramesh Mishra',
      'Mrs. Geeta Joshi',
    ];

    final subjectTemplates = [
      'Assignment Deadline Extension', 'Lab Session Rescheduled',
      'Mid-Exam Schedule Released', 'Project Submission Reminder',
      'Guest Lecture on AI', 'Class Cancelled Today',
      'Attendance Shortage Warning', 'Workshop Registration Open',
      'Marks Updated on Portal', 'New Study Material Shared',
      'Parent Meeting Scheduled', 'Lab Report Submission',
      'Industrial Visit Announcement', 'Revised Timetable',
      'Code Review Session', 'Holiday Notice - Republic Day',
      'Emergency: Campus Closure', 'Exam Hall Allotment',
      'Sports Day Practice', 'Cultural Fest Registration',
    ];

    final bodyTemplates = [
      'The deadline for this assignment has been extended. Please ensure timely submission.',
      'The lab session has been rescheduled. Check the updated timetable.',
      'The examination schedule has been published. Please check the notice board.',
      'This is a reminder for the upcoming project submission deadline.',
      'A guest lecture has been organized. Attendance is mandatory.',
      'Today\'s class has been cancelled due to unforeseen circumstances.',
      'Students below the required attendance threshold must improve immediately.',
      'Registration for the workshop is now open. Limited seats available.',
      'Internal assessment marks have been updated on the portal.',
      'Reference material for the upcoming test has been uploaded to LMS.',
      'The parent-teacher meeting is scheduled for next week.',
      'All pending lab reports must be submitted by Wednesday.',
      'An industrial visit has been organized for next month.',
      'The timetable has been revised for this week.',
      'A code review session will be conducted during tomorrow\'s lab.',
      'The college will remain closed for the national holiday.',
      'Due to emergency, campus is closed today. Stay safe.',
      'Exam hall allotment list has been posted on the notice board.',
      'Sports day practice starts from tomorrow. Be punctual.',
      'Register for the cultural fest before the deadline.',
    ];

    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      final typeIdx = random.nextInt(MessageType.values.length);
      final type = MessageType.values[typeIdx];
      final statusIdx = random.nextInt(MessageStatus.values.length);
      final status = MessageStatus.values[statusIdx];
      final priorityIdx = random.nextInt(MessagePriority.values.length);
      final priority = MessagePriority.values[priorityIdx];
      final categoryIdx = random.nextInt(MessageCategory.values.length);
      final category = MessageCategory.values[categoryIdx];
      final daysAgo = random.nextInt(30);
      final hoursAgo = random.nextInt(24);
      final createdAt = now.subtract(Duration(days: daysAgo, hours: hoursAgo, minutes: random.nextInt(60)));

      final dept = departments[random.nextInt(departments.length)];
      final sec = sections[random.nextInt(2)];
      final firstName = firstNames[random.nextInt(firstNames.length)];
      final lastName = lastNames[random.nextInt(lastNames.length)];
      final studentName = '$firstName $lastName';
      final parentName = '${parents[random.nextInt(parents.length)]} (Parent)';

      final isParent = type == MessageType.parent;
      final recipientCount = type == MessageType.individual
          ? 1
          : isParent
              ? 10 + random.nextInt(30)
              : 30 + random.nextInt(70);
      final readCount = status == MessageStatus.read
          ? recipientCount
          : status == MessageStatus.delivered
              ? (recipientCount * random.nextDouble()).round()
              : 0;

      final hasAttachment = random.nextDouble() < 0.3;
      final attachments = hasAttachment
          ? ['document_${(i + 1).toString().padLeft(3, '0')}.pdf']
          : <String>[];

      final isScheduled = random.nextDouble() < 0.08;
      final scheduledAt = isScheduled
          ? now.add(Duration(days: random.nextInt(7) + 1, hours: random.nextInt(12)))
          : null;

      _messages.add(FacultyMessage(
        id: 'msg_${(i + 1).toString().padLeft(4, '0')}',
        senderId: 'fac_001',
        senderName: 'Dr. Rajesh Kumar',
        recipientId: type == MessageType.individual
            ? 'stu_${(random.nextInt(50) + 1).toString().padLeft(4, '0')}'
            : isParent
                ? 'prn_${(random.nextInt(10) + 1).toString().padLeft(4, '0')}'
                : null,
        recipientName: type == MessageType.individual
            ? studentName
            : isParent
                ? parentName
                : null,
        subject: subjectTemplates[i % subjectTemplates.length],
        body: bodyTemplates[i % bodyTemplates.length],
        type: type,
        status: isScheduled ? MessageStatus.sent : status,
        priority: priority,
        category: category,
        createdAt: createdAt,
        readAt: status == MessageStatus.read
            ? createdAt.add(Duration(hours: random.nextInt(48)))
            : null,
        scheduledAt: scheduledAt,
        attachments: attachments,
        courseCode: courseMap[dept],
        section: sec,
        recipientCount: recipientCount,
        readCount: readCount,
        recipientGroup: type == MessageType.individual
            ? RecipientGroup.individual
            : isParent
                ? RecipientGroup.parents
                : RecipientGroup.entireClass,
        recipientIds: List.generate(
          recipientCount,
          (idx) => 'stu_${(random.nextInt(50) + 1).toString().padLeft(4, '0')}',
        ),
      ));
    }

    _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _nextId = count + 1;
  }

  void _generateThreads() {
    final participantMap = <String, FacultyMessage>{};
    for (final msg in _messages) {
      final key = msg.recipientId ?? 'broadcast_${msg.courseCode}_${msg.section}';
      if (!participantMap.containsKey(key)) {
        participantMap[key] = msg;
      }
    }

    final random = Random(42);
    final entries = participantMap.entries.toList()..shuffle(random);

    for (int i = 0; i < entries.length && i < 20; i++) {
      final entry = entries[i];
      _threads.add(MessageThread(
        threadId: 'thread_${(i + 1).toString().padLeft(3, '0')}',
        participantName: entry.value.recipientName ?? 'Class ${entry.value.courseCode ?? ''} ${entry.value.section ?? ''}',
        participantId: entry.key,
        lastMessage: entry.value,
        unreadCount: random.nextInt(5),
        isOnline: random.nextBool(),
      ));
    }

    _threads.sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
  }

  List<MessageTemplate> getTemplates() {
    return const [
      MessageTemplate(
        id: 'tpl_001',
        name: 'Attendance Reminder',
        subject: 'Attendance Shortage Warning',
        body: 'Your attendance has fallen below the required threshold. Please ensure regular attendance to maintain course eligibility.',
        category: MessageCategory.reminder,
        priority: MessagePriority.important,
      ),
      MessageTemplate(
        id: 'tpl_002',
        name: 'Assignment Submission',
        subject: 'Assignment Submission Reminder',
        body: 'This is a reminder that the assignment is due soon. Please submit your work on time to avoid penalties.',
        category: MessageCategory.assignment,
        priority: MessagePriority.normal,
      ),
      MessageTemplate(
        id: 'tpl_003',
        name: 'Exam Tomorrow',
        subject: 'Exam Tomorrow - Be Prepared',
        body: 'There is an examination scheduled for tomorrow. Please revise all topics and carry your ID card.',
        category: MessageCategory.examNotification,
        priority: MessagePriority.urgent,
      ),
      MessageTemplate(
        id: 'tpl_004',
        name: 'Holiday Notice',
        subject: 'Holiday Notice',
        body: 'The institution will remain closed on the mentioned date. Regular classes will resume the following day.',
        category: MessageCategory.holidayNotice,
        priority: MessagePriority.normal,
      ),
      MessageTemplate(
        id: 'tpl_005',
        name: 'Bring Lab Record',
        subject: 'Bring Lab Record to Class',
        body: 'All students must bring their completed lab records to the next session. Records will be evaluated.',
        category: MessageCategory.reminder,
        priority: MessagePriority.normal,
      ),
      MessageTemplate(
        id: 'tpl_006',
        name: 'Parents Meeting',
        subject: 'Parent-Teacher Meeting Scheduled',
        body: 'A parent-teacher meeting is scheduled. Parents of students with attendance or academic concerns must attend.',
        category: MessageCategory.eventNotification,
        priority: MessagePriority.important,
      ),
      MessageTemplate(
        id: 'tpl_007',
        name: 'Low Attendance Warning',
        subject: 'Critical: Low Attendance Alert',
        body: 'Your attendance is critically low. Immediate improvement is required. Meet the faculty during office hours.',
        category: MessageCategory.importantNotice,
        priority: MessagePriority.urgent,
      ),
      MessageTemplate(
        id: 'tpl_008',
        name: 'Fee Reminder',
        subject: 'Fee Payment Reminder',
        body: 'This is a reminder to pay the pending semester fees. Late payments may attract additional charges.',
        category: MessageCategory.reminder,
        priority: MessagePriority.normal,
      ),
    ];
  }

  Future<List<FacultyMessage>> fetchMessages({
    MessageType? type,
    String? query,
    MessageFilter? filter,
    int page = 1,
    int pageSize = 20,
    bool sentOnly = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    List<FacultyMessage> results = List.from(_messages);

    if (sentOnly) {
      results = results.where((m) => m.senderId == 'fac_001').toList();
    }

    if (type != null) {
      results = results.where((m) => m.type == type).toList();
    }

    if (filter != null) {
      if (filter.status != null) {
        results = results.where((m) => m.status == filter.status).toList();
      }
      if (filter.priority != null) {
        results = results.where((m) => m.priority == filter.priority).toList();
      }
      if (filter.category != null) {
        results = results.where((m) => m.category == filter.category).toList();
      }
      if (filter.courseCode != null) {
        results = results.where((m) => m.courseCode == filter.courseCode).toList();
      }
      if (filter.section != null) {
        results = results.where((m) => m.section == filter.section).toList();
      }
      if (filter.dateFrom != null) {
        results = results.where((m) => m.createdAt.isAfter(filter.dateFrom!)).toList();
      }
      if (filter.dateTo != null) {
        results = results.where((m) => m.createdAt.isBefore(filter.dateTo!.add(const Duration(days: 1)))).toList();
      }
    }

    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results.where((m) {
        return m.subject.toLowerCase().contains(lowerQuery) ||
            m.body.toLowerCase().contains(lowerQuery) ||
            m.senderName.toLowerCase().contains(lowerQuery) ||
            (m.recipientName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (m.courseCode?.toLowerCase().contains(lowerQuery) ?? false) ||
            (m.notes?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final startIndex = (page - 1) * pageSize;
    if (startIndex >= results.length) return [];

    final endIndex = (startIndex + pageSize).clamp(0, results.length);
    return results.sublist(startIndex, endIndex);
  }

  Future<int> fetchMessageCount({
    MessageType? type,
    MessageFilter? filter,
    String? query,
  }) async {
    List<FacultyMessage> results = List.from(_messages);
    if (type != null) results = results.where((m) => m.type == type).toList();
    if (filter != null) {
      if (filter.status != null) results = results.where((m) => m.status == filter.status).toList();
      if (filter.priority != null) results = results.where((m) => m.priority == filter.priority).toList();
      if (filter.category != null) results = results.where((m) => m.category == filter.category).toList();
    }
    if (query != null && query.isNotEmpty) {
      final lq = query.toLowerCase();
      results = results.where((m) =>
        m.subject.toLowerCase().contains(lq) ||
        m.body.toLowerCase().contains(lq) ||
        m.senderName.toLowerCase().contains(lq) ||
        (m.recipientName?.toLowerCase().contains(lq) ?? false)
      ).toList();
    }
    return results.length;
  }

  Future<List<MessageThread>> fetchThreads() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final threads = List<MessageThread>.from(_threads);
    threads.sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
    return threads;
  }

  Future<FacultyMessage> sendMessage({
    required String recipientId,
    required String subject,
    required String body,
    MessageType type = MessageType.individual,
    MessagePriority priority = MessagePriority.normal,
    MessageCategory category = MessageCategory.text,
    List<String>? attachments,
    DateTime? scheduledAt,
    String? courseCode,
    String? section,
    RecipientGroup recipientGroup = RecipientGroup.individual,
    List<String>? recipientIds,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final newMessage = FacultyMessage(
      id: 'msg_${_nextId.toString().padLeft(4, '0')}',
      senderId: 'fac_001',
      senderName: 'Dr. Rajesh Kumar',
      recipientId: recipientId,
      subject: subject,
      body: body,
      type: type,
      status: scheduledAt != null ? MessageStatus.sent : MessageStatus.sending,
      priority: priority,
      category: category,
      createdAt: DateTime.now(),
      scheduledAt: scheduledAt,
      attachments: attachments ?? [],
      courseCode: courseCode,
      section: section,
      recipientCount: recipientIds?.length ?? (type == MessageType.individual ? 1 : 62),
      readCount: 0,
      recipientGroup: recipientGroup,
      recipientIds: recipientIds ?? [],
      notes: notes,
    );

    _nextId++;
    _messages.insert(0, newMessage);

    if (scheduledAt == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _messages.indexWhere((m) => m.id == newMessage.id);
      if (index != -1) {
        final updated = _messages[index].copyWith(status: MessageStatus.sent);
        _messages[index] = updated;
        await Future.delayed(const Duration(milliseconds: 500));
        final index2 = _messages.indexWhere((m) => m.id == newMessage.id);
        if (index2 != -1) {
          _messages[index2] = _messages[index2].copyWith(status: MessageStatus.delivered);
        }
      }
    }

    return newMessage;
  }

  Future<void> markAsRead(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final old = _messages[index];
      _messages[index] = old.copyWith(
        status: MessageStatus.read,
        readAt: DateTime.now(),
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _messages.removeWhere((m) => m.id == messageId);
  }

  Future<void> updateMessage(String messageId, {
    String? subject,
    String? body,
    MessagePriority? priority,
    List<String>? attachments,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        subject: subject,
        body: body,
        priority: priority,
        attachments: attachments,
      );
    }
  }

  Future<List<FacultyMessage>> fetchScheduledMessages() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _messages.where((m) => m.isScheduled).toList();
  }

  Future<void> cancelScheduledMessage(String messageId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _messages.removeWhere((m) => m.id == messageId);
  }

  Future<List<Map<String, dynamic>>> exportMessages({
    String format = 'csv',
    MessageFilter? filter,
    MessageType? type,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    List<FacultyMessage> results = List.from(_messages);
    if (type != null) results = results.where((m) => m.type == type).toList();
    if (filter != null) {
      if (filter.status != null) results = results.where((m) => m.status == filter.status).toList();
      if (filter.priority != null) results = results.where((m) => m.priority == filter.priority).toList();
    }

    return results.map((m) => m.toJson()).toList();
  }
}
