import 'chat_enums.dart';
import 'student_contact.dart';

/// A phone / video call record between the faculty and a peer.
class ChatCall {
  final String id;
  final StudentContact peer;
  final CallType type;
  final CallDirection direction;
  final CallState state;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const ChatCall({
    required this.id,
    required this.peer,
    required this.type,
    required this.direction,
    required this.state,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  factory ChatCall.fromJson(Map<String, dynamic> json) {
    return ChatCall(
      id: json['id']?.toString() ?? '',
      peer: StudentContact.fromJson(
        Map<String, dynamic>.from(json['peer'] as Map? ?? const {}),
      ),
      type: CallType.fromJson(json['type']?.toString()),
      direction: CallDirection.fromJson(json['direction']?.toString()),
      state: CallState.fromJson(json['state']?.toString()),
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peer': peer.toJson(),
      'type': type.name,
      'direction': direction.name,
      'state': state.name,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  ChatCall copyWith({
    CallState? state,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return ChatCall(
      id: id,
      peer: peer,
      type: type,
      direction: direction,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
