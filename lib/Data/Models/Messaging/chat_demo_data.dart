import 'dart:math';

import 'chat_conversation.dart';
import 'chat_enums.dart';
import 'chat_message.dart';
import 'student_contact.dart';

/// Demo catalog of 5 students used to hydrate the Chat list when the backend
/// is unreachable (offline first-run).
///
/// These are the "5 dummy students" requested for local development. When the
/// backend is available the [MessagingRepository] returns real conversations
/// and this file is only used as a contact fallback.
class ChatDemoData {
  ChatDemoData._();

  static const List<Map<String, dynamic>> _students = [
    {
      'id': 'stu_001',
      'name': 'Aarav Sharma',
      'roll_number': '21CS001',
      'email': 'aarav.sharma@student.intelliattend.app',
      'phone': '+91 98765 43210',
      'department': 'Computer Science',
      'section': 'IV CSE-A',
      'course_code': 'CS501',
      'course_name': 'Operating Systems',
      'initials': 'AS',
      'avatar_color': 0xFF2DD4BF,
      'is_online': true,
      'custom_status': 'Working on OS lab assignment',
    },
    {
      'id': 'stu_002',
      'name': 'Priya Patel',
      'roll_number': '21CS002',
      'email': 'priya.patel@student.intelliattend.app',
      'phone': '+91 91234 56780',
      'department': 'Computer Science',
      'section': 'IV CSE-A',
      'course_code': 'CS501',
      'course_name': 'Operating Systems',
      'initials': 'PP',
      'avatar_color': 0xFFA3E635,
      'is_online': false,
      'custom_status': 'In the library 📚',
    },
    {
      'id': 'stu_003',
      'name': 'Rohan Verma',
      'roll_number': '21CS003',
      'email': 'rohan.verma@student.intelliattend.app',
      'phone': '+91 87654 32109',
      'department': 'Computer Science',
      'section': 'IV CSE-A',
      'course_code': 'CS502',
      'course_name': 'DBMS',
      'initials': 'RV',
      'avatar_color': 0xFF6B4EFF,
      'is_online': false,
      'custom_status': '',
    },
    {
      'id': 'stu_004',
      'name': 'Sneha Reddy',
      'roll_number': '21CS004',
      'email': 'sneha.reddy@student.intelliattend.app',
      'phone': '+91 76543 21098',
      'department': 'Computer Science',
      'section': 'IV CSE-B',
      'course_code': 'CS502',
      'course_name': 'DBMS',
      'initials': 'SR',
      'avatar_color': 0xFFF472B6,
      'is_online': true,
      'custom_status': 'Coding 💻',
    },
    {
      'id': 'stu_005',
      'name': 'Karthik Nair',
      'roll_number': '21CS005',
      'email': 'karthik.nair@student.intelliattend.app',
      'phone': '+91 65432 10987',
      'department': 'Computer Science',
      'section': 'IV CSE-B',
      'course_code': 'CS503',
      'course_name': 'Software Engineering',
      'initials': 'KN',
      'avatar_color': 0xFFFACC15,
      'is_online': false,
      'custom_status': 'Busy in internship',
    },
  ];

  /// The 5 demo students.
  static List<StudentContact> get students => _students
      .map((s) => StudentContact.fromJson(Map<String, dynamic>.from(s)))
      .toList();

  /// Look up a demo student by id/roll number. Returns null if unknown.
  static StudentContact? byId(String id) {
    for (final s in students) {
      if (s.id == id || s.rollNumber == id) return s;
    }
    return null;
  }

  /// Builds a full set of seed conversations (5 chats) plus their messages.
  ///
  /// Returns a map of conversationId -> ordered messages. Each thread contains
  /// messages spread over several days so pagination, date separators and
  /// read-receipt states are demonstrable.
  static Map<String, List<ChatMessage>> seedConversations({
    required String facultyName,
    required String facultyId,
  }) {
    final now = DateTime.now();
    final result = <String, List<ChatMessage>>{};
    var seed = 42;

    for (final student in students) {
      final convId = 'demo_${student.id}';
      final messages = <ChatMessage>[];
      final rnd = Random(seed++);
      final days = rnd.nextInt(3) + 1; // 1-3 days of history
      final numberOfMessages = rnd.nextInt(6) + 8; // 8-13 messages

      for (var i = 0; i < numberOfMessages; i++) {
        final outgoing = rnd.nextBool();
        final minutesAgo = rnd.nextInt(200) + (i * 37) + (days * 24 * 60);
        final ts = now.subtract(Duration(minutes: minutesAgo));
        final incoming = _incomingPool[rnd.nextInt(_incomingPool.length)];
        final out = _outgoingPool[rnd.nextInt(_outgoingPool.length)];

        final isRead = outgoing ? rnd.nextBool() : rnd.nextBool();
        final status = outgoing
            ? (isRead ? MessageStatus.read : MessageStatus.delivered)
            : MessageStatus.read;

        messages.add(ChatMessage(
          id: '${convId}_msg_$i',
          conversationId: convId,
          direction: outgoing ? MessageDirection.outgoing : MessageDirection.incoming,
          type: MessageContentType.text,
          text: outgoing ? out : incoming,
          senderId: outgoing ? facultyId : student.id,
          senderName: outgoing ? facultyName : student.name,
          timestamp: ts,
          status: status,
          deliveredAt: outgoing ? ts.add(const Duration(minutes: 1)) : ts,
          readAt: status == MessageStatus.read ? ts.add(const Duration(minutes: 3)) : null,
        ));
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Decorate for a richer demo: reply threads, a pin, stars, reactions.
      for (var i = 1; i < messages.length && i < 6; i++) {
        final target = messages[i - 1];
        messages[i] = messages[i].copyWith(
          replyTo: ReplyPreview(
            messageId: target.id,
            senderName: target.senderName,
            text: target.contentSummary,
            type: target.type,
          ),
        );
        messages[i - 1] = target.copyWith(threadCount: target.threadCount + 1);
      }

      final outgoing =
          messages.where((m) => m.direction == MessageDirection.outgoing).toList();
      if (outgoing.isNotEmpty) outgoing.last.isPinned = true;

      if (messages.length > 4) {
        messages[2] = messages[2].copyWith(isStarred: true);
        messages[messages.length - 2] =
            messages[messages.length - 2].copyWith(isStarred: true);
      }
      if (messages.length > 5) {
        messages[1] = messages[1].copyWith(reactions: const ['👍']);
        messages[4] = messages[4].copyWith(reactions: const ['❤️']);
      }

      result[convId] = messages;
    }
    return result;
  }

  static const List<String> _incomingPool = [
    'Good morning ma\'am/sir. I had a question about the assignment.',
    'Thank you for the clarification, that makes sense now.',
    'Sir, I have submitted my lab file. Please review when you get a chance.',
    'Is the class test rescheduled? I saw an update on the portal.',
    'I will complete the remaining exercises by tonight.',
    'Received. I will share my doubt in the next class.',
    'Could you please share the reference material again?',
    'Noted. I have updated my attendance records.',
    'The team has finalized the project proposal. Sharing the summary.',
    'Understood. I will inform the rest of the group.',
  ];

  static const List<String> _outgoingPool = [
    'Sure, please share your doubt clearly so I can help you better.',
    'I have checked your submission. One more section needs attention.',
    'Please go through chapter 4 before the next class.',
    'The test is confirmed for Friday, 10 AM, in the seminar hall.',
    'Great work! Keep it up.',
    'I have uploaded the reference material to the Resources section.',
    'Attendance has been updated. Let me know if you notice any issue.',
    'Please make sure your project is ready for review by Monday.',
    'I will share the corrected marks after the moderation is done.',
    'Kindly submit the assignment before the deadline to avoid penalty.',
  ];
}
