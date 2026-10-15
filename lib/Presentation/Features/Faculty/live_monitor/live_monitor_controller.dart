import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/registration_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';
import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class LiveMonitorController extends ChangeNotifier {
  final AttendanceRepository _repository;
  final String sessionId;
  final String? courseId;
  final String? sectionId;
  final VoidCallback? onSessionEnded;

  LiveMonitorController(
    this._repository,
    this.sessionId, {
    this.courseId,
    this.sectionId,
    this.onSessionEnded,
  }) {
    _init();
  }

  bool _disposed = false;

  final WebSocketService _wsService = WebSocketService();

  StreamSubscription? _wsEventSub;
  StreamSubscription? _wsConnSub;

  SessionInfo? _sessionInfo;
  SessionInfo? get sessionInfo => _sessionInfo;

  List<StudentAttendance> _attendance = [];
  List<StudentAttendance> get attendance => _attendance;

  List<StudentAttendance> _mergedStudents = [];
  List<StudentAttendance> get mergedStudents => _mergedStudents;

  final Set<String> _selectedStudentIds = {};
  Set<String> get selectedStudentIds => _selectedStudentIds;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _hasTimedOut = false;
  bool get hasTimedOut => _hasTimedOut;

  bool _isMarkingSelected = false;
  bool get isMarkingSelected => _isMarkingSelected;

  Timer? _loadingTimer;

  bool _isBoardConnected = false;
  bool get isBoardConnected => _isBoardConnected;

  bool _isSessionActivated = false;
  bool get isSessionActivated => _isSessionActivated;

  int _otpFailedCount = 0;
  int get otpFailedCount => _otpFailedCount;

  String _wsConnectionState = 'connecting';
  String get wsConnectionState => _wsConnectionState;

  final Set<String> _pendingMarkIds = {};

  void _init() {
    _loadingTimer = Timer(const Duration(seconds: 12), () {
      if (_isLoading && !_disposed) {
        _hasTimedOut = true;
        _isLoading = false;
        _safeNotify();
      }
    });

    _loadRosterFromHive();
    _tryFetchEnrollment();

    _wsService.connectAndJoinRoom(sessionId: sessionId);

    _wsConnSub = _wsService.connectionState.listen((state) {
      if (_disposed) return;
      switch (state) {
        case WsConnectionState.connected:
          _wsConnectionState = 'connected';
        case WsConnectionState.connecting:
          _wsConnectionState = 'connecting';
        case WsConnectionState.reconnecting:
          _wsConnectionState = 'reconnecting';
        case WsConnectionState.disconnected:
          _wsConnectionState = 'disconnected';
      }
      _safeNotify();
    });

    _wsEventSub = _wsService.events.listen((event) {
      if (_disposed) return;
      _handleWsEvent(event);
    }, onError: (error) {
      debugPrint("❌ LIVER MONITOR: WS event stream error: $error");
    });
  }

  void _handleWsEvent(WebSocketEvent event) {
    switch (event.type) {
      case WsEventType.fullStateSync:
        _handleFullStateSync(event);
      case WsEventType.facultySync:
        _handleFacultySync(event);
      case WsEventType.boardConnected:
        _isBoardConnected = true;
        _safeNotify();
      case WsEventType.attendanceOpen:
      case WsEventType.sessionActivated:
        _isSessionActivated = true;
        _safeNotify();
      case WsEventType.otpFailed:
        _otpFailedCount = event.get<int>('attempt_count') ?? 1;
        _safeNotify();
      case WsEventType.studentVerified:
      case WsEventType.attendanceUpdate:
        _handleStudentVerified(event);
      case WsEventType.attendanceUpdated:
      case WsEventType.markAttendanceAck:
      case WsEventType.studentMarked:
        _handleMarkAttendanceAck(event);
      case WsEventType.sessionPreparing:
      case WsEventType.sessionIgniting:
      case WsEventType.studentRejected:
      case WsEventType.attendanceMarkedManual:
      case WsEventType.attendanceClosed:
      case WsEventType.sessionArchived:
      case WsEventType.otpVerified:
      case WsEventType.heartbeat:
      case WsEventType.messageNew:
      case WsEventType.messageAck:
      case WsEventType.messageRead:
      case WsEventType.messageDelivered:
      case WsEventType.messageEdited:
      case WsEventType.messageDeleted:
      case WsEventType.messagePinned:
      case WsEventType.typing:
      case WsEventType.presenceUpdate:
      case WsEventType.callEvent:
      case WsEventType.conversationSync:
      case WsEventType.unknown:
        break;
    }
  }

  void _loadRosterFromHive() {
    try {
      final effectiveSectionId = sectionId ?? courseId;
      if (effectiveSectionId == null) {
        debugPrint("⚠️ LIVE MONITOR: No sectionId/courseId to load roster");
        return;
      }

      List<Map<String, dynamic>> rosterList = [];

      final keys = PersistenceService.academicBox.get('roster_keys') as List?;
      if (keys != null && keys.isNotEmpty) {
        debugPrint("📦 LIVE MONITOR: Hive roster_keys=$keys, section=$effectiveSectionId");
        for (final key in keys) {
          final keyStr = key.toString();
          if (!keyStr.startsWith("${effectiveSectionId}_")) continue;
          final lowerKey = keyStr.toLowerCase();
          if (lowerKey.contains('tutorial') || lowerKey.contains('library')) continue;
          final raw = PersistenceService.academicBox.get('roster_$key');
          if (raw is List) {
            for (final entry in raw) {
              if (entry is Map) {
                final student = Map<String, dynamic>.from(entry);
                student['section'] = keyStr;
                rosterList.add(student);
              }
            }
          }
        }
        debugPrint("📦 LIVE MONITOR: After section filter: ${rosterList.length} students");
      }

      if (rosterList.isEmpty) {
        final rawRoster = PersistenceService.academicBox.get('student_rosters');
        if (rawRoster is Map) {
          for (final entry in rawRoster.entries) {
            if (!entry.key.startsWith("${effectiveSectionId}_")) continue;
            final lowerKey = entry.key.toLowerCase();
            if (lowerKey.contains('tutorial') || lowerKey.contains('library')) continue;
            if (entry.value is List) {
              for (final item in entry.value) {
                if (item is Map) {
                  final student = Map<String, dynamic>.from(item);
                  student['section'] = entry.key;
                  rosterList.add(student);
                }
              }
            }
          }
        } else if (rawRoster is List) {
          for (final item in rawRoster) {
            if (item is Map) {
              rosterList.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      if (rosterList.isEmpty) {
        debugPrint("⚠️ LIVE MONITOR: No roster data in Hive for $effectiveSectionId");
        _fetchRosterFromServer(courseId, sectionId);
        return;
      }

      debugPrint("📦 LIVE MONITOR: Loaded ${rosterList.length} students from Hive for $effectiveSectionId");

      final seenIds = <String>{};
      _mergedStudents = rosterList.map((data) {
        final id = data['roll_number']?.toString() ?? data['id']?.toString() ?? data['student_id']?.toString() ?? '';
        final name = data['name']?.toString() ?? data['student_name']?.toString() ?? '';
        final email = data['email']?.toString() ?? data['student_email']?.toString() ?? '';
        return StudentAttendance(
          id: id,
          name: name,
          email: email.isNotEmpty ? email : null,
          status: StudentStatus.absent,
        );
      }).where((s) {
        if (s.id.isEmpty || s.name.isEmpty) return false;
        if (seenIds.contains(s.id)) return false;
        seenIds.add(s.id);
        return true;
      }).toList();

      _mergedStudents.sort((a, b) => a.name.compareTo(b.name));
      _attendance = [];
      _isLoading = false;
      _hasTimedOut = false;
      _loadingTimer?.cancel();
      _safeNotify();
      debugPrint("✅ LIVE MONITOR: Roster loaded from Hive (${_mergedStudents.length} students for $effectiveSectionId)");
    } catch (e) {
      debugPrint("❌ LIVE MONITOR: Error loading roster from Hive: $e");
    }
  }

  void _handleFullStateSync(WebSocketEvent event) {
    final syncData = FullStateSyncData.fromEvent(event);
    final allRoster = syncData.roster
        .map((e) => StudentAttendance.fromJson(e))
        .toList();

    final List<StudentAttendance> roster;
    if (_enrolledIds.isNotEmpty) {
      roster = allRoster.where((s) => _enrolledIds.contains(s.id) || (s.email != null && _enrolledEmails.values.contains(s.email))).toList();
      debugPrint("🔍 LIVE MONITOR: WS roster filtered from ${allRoster.length} to ${roster.length} (enrolled only)");
    } else {
      roster = allRoster;
    }

    final wsPresent = roster.where((s) => s.status == StudentStatus.present).toList();

    debugPrint("✅ LIVE MONITOR: WS FullStateSync received (${roster.length} students, ${wsPresent.length} present)");

    if (_mergedStudents.isEmpty) {
      _attendance = wsPresent;
      _mergedStudents = roster;
    } else {
      final wsById = <String, StudentAttendance>{};
      final wsByEmail = <String, StudentAttendance>{};
      for (final s in roster) {
        wsById[s.id] = s;
        if (s.email != null && s.email!.isNotEmpty) wsByEmail[s.email!] = s;
      }

      for (int i = 0; i < _mergedStudents.length; i++) {
        final hive = _mergedStudents[i];
        final wsMatch = wsById[hive.id] ?? (hive.email != null ? wsByEmail[hive.email!] : null);
        if (wsMatch != null) {
          final displayName = (wsMatch.name.isEmpty || wsMatch.name == 'Unknown Student') ? hive.name : wsMatch.name;
          _mergedStudents[i] = StudentAttendance(
            id: wsMatch.id.isNotEmpty ? wsMatch.id : hive.id,
            name: displayName.isNotEmpty ? displayName : hive.name,
            email: wsMatch.email ?? hive.email,
            image: wsMatch.image ?? hive.image,
            status: wsMatch.status,
            checkInTime: wsMatch.checkInTime,
            deviceFingerprint: wsMatch.deviceFingerprint,
            isVerified: wsMatch.isVerified,
            markedBy: wsMatch.markedBy,
          );
        }
      }

      for (final ws in roster) {
        final existsInHive = _mergedStudents.any((s) => s.id == ws.id || (s.email != null && s.email == ws.email));
        if (!existsInHive) {
          final duplicate = _mergedStudents.any((s) => s.id == ws.id);
          if (!duplicate) {
            _mergedStudents.add(ws);
          }
        }
      }

      _attendance = _mergedStudents.where((s) => s.status == StudentStatus.present).toList();
    }

    _isLoading = false;
    _hasTimedOut = false;
    _loadingTimer?.cancel();
    _tryFetchEnrollment();
    _safeNotify();
    debugPrint("✅ LIVE MONITOR: Roster merged (${_mergedStudents.length} total, ${_attendance.length} present)");
  }

  void _handleFacultySync(WebSocketEvent event) {
    final syncData = FacultySyncData.fromEvent(event);
    final presentStudents = syncData.presentStudents
        .map((e) => StudentAttendance.fromJson(e))
        .toList();
    _attendance = presentStudents;

    final presentIds = presentStudents.map((s) => s.id).toSet();
    final presentEmails = presentStudents.map((s) => s.email).whereType<String>().toSet();

    if (_mergedStudents.isEmpty) {
      debugPrint("⚠️ FacultySync skipped: no roster yet");
      return;
    }
    for (int i = 0; i < _mergedStudents.length; i++) {
      final s = _mergedStudents[i];
      final isPresent = presentIds.contains(s.id) || (s.email != null && presentEmails.contains(s.email));
      if (isPresent) {
        final matched = presentStudents.firstWhere((p) => p.id == s.id || (s.email != null && p.email == s.email));
        _mergedStudents[i] = StudentAttendance(
          id: matched.id,
          name: matched.name.isNotEmpty && matched.name != 'Unknown Student' ? matched.name : s.name,
          email: matched.email ?? s.email,
          image: matched.image ?? s.image,
          status: matched.status,
          checkInTime: matched.checkInTime,
          deviceFingerprint: matched.deviceFingerprint,
          isVerified: matched.isVerified,
          markedBy: matched.markedBy,
        );
      } else {
        _mergedStudents[i] = StudentAttendance(
          id: s.id,
          name: s.name,
          email: s.email,
          image: s.image,
          status: StudentStatus.absent,
          markedBy: null,
        );
      }
    }
    _safeNotify();
    debugPrint("✅ LIVER MONITOR: Roster synced via Faculty Sync (${presentStudents.length} present)");
  }

  void _handleStudentVerified(WebSocketEvent event) {
    final newStudent = StudentAttendance.fromJson(event.data);

    final isEcho = _pendingMarkIds.contains(newStudent.id) || (newStudent.email != null && _pendingMarkIds.contains(newStudent.email));
    if (isEcho) {
      _pendingMarkIds.remove(newStudent.id);
      if (newStudent.email != null) _pendingMarkIds.remove(newStudent.email);
      debugPrint("🔇 Echo suppressed for ${newStudent.id}");
      return;
    }

    int attIndex = _attendance.indexWhere((s) {
      final emailMatch = s.email != null && newStudent.email != null && s.email == newStudent.email;
      final idMatch = s.id == newStudent.id;
      return emailMatch || idMatch;
    });
    if (attIndex != -1) {
      _attendance[attIndex] = newStudent;
    } else {
      _attendance.add(newStudent);
    }

    int index = _mergedStudents.indexWhere((s) {
      final emailMatch = s.email != null && newStudent.email != null && s.email == newStudent.email;
      final idMatch = s.id == newStudent.id;
      return emailMatch || idMatch;
    });

    if (index != -1) {
      final rosterName = _mergedStudents[index].name;
      final displayName = (newStudent.name.isEmpty || newStudent.name == 'Unknown Student')
          ? rosterName
          : newStudent.name;

      _mergedStudents[index] = StudentAttendance(
        id: newStudent.id,
        name: displayName,
        email: newStudent.email ?? _mergedStudents[index].email,
        image: newStudent.image ?? _mergedStudents[index].image,
        status: newStudent.status,
        checkInTime: newStudent.checkInTime,
        deviceFingerprint: newStudent.deviceFingerprint,
        isVerified: newStudent.isVerified,
        markedBy: newStudent.markedBy,
      );
      _safeNotify();
    } else {
      debugPrint("⚠️ SEAT-MAP MISS: Student email ${newStudent.email} or ID ${newStudent.id} not in roster");
    }
  }

  void _handleMarkAttendanceAck(WebSocketEvent event) {
    final ack = AttendanceMarkAckData.fromEvent(event);
    final studentId = ack.studentId;
    if (studentId == null) return;

    if (ack.success) {
      _pendingMarkIds.add(studentId);
      final data = ack.data;
      final updatedStudent = data != null ? StudentAttendance.fromJson(data) : null;

      int index = _mergedStudents.indexWhere((s) => s.id == studentId || s.email == studentId);
      if (index != -1) {
        final s = _mergedStudents[index];
        _mergedStudents[index] = StudentAttendance(
          id: updatedStudent?.id ?? s.id,
          name: updatedStudent?.name.isNotEmpty == true ? updatedStudent!.name : s.name,
          email: updatedStudent?.email ?? s.email,
          image: updatedStudent?.image ?? s.image,
          status: StudentStatus.present,
          checkInTime: updatedStudent?.checkInTime ?? DateTime.now(),
          deviceFingerprint: updatedStudent?.deviceFingerprint ?? s.deviceFingerprint,
          isVerified: updatedStudent?.isVerified ?? s.isVerified,
          markedBy: updatedStudent?.markedBy ?? 'manual_faculty',
        );

        int attIndex = _attendance.indexWhere((att) => att.id == s.id || att.email == s.email);
        if (attIndex != -1) {
          _attendance[attIndex] = _mergedStudents[index];
        } else {
          _attendance.add(_mergedStudents[index]);
        }
      }
    } else {
      debugPrint("❌ WS Mark failed for $studentId: ${ack.error}");
    }
    _safeNotify();
  }

  void retry() {
    _hasTimedOut = false;
    _isLoading = true;
    _sessionInfo = null;
    _mergedStudents = [];
    _selectedStudentIds.clear();
    notifyListeners();
    _loadingTimer?.cancel();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    _wsService.disconnect();
    _init();
  }

  Future<void> refreshRoster() async {
    _loadRosterFromHive();
    await _tryFetchEnrollment();
    _safeNotify();
  }

  Future<void> _tryFetchEnrollment() async {
    final effectiveCourseId = _sessionInfo?.courseId ?? courseId;
    final effectiveSectionId = _sessionInfo?.sectionId ?? sectionId;

    await _fetchRosterFromServer(effectiveCourseId, effectiveSectionId);
  }

  Future<void> _fetchRosterFromServer(String? courseId, String? sectionId) async {
    if (courseId == null || sectionId == null) return;

    try {
      final syncData = await _repository.getSyncData();
      if (syncData != null && syncData['student_rosters'] != null) {
        final rosterMap = syncData['student_rosters'];
        final enrolledIds = <String>{};
        final enrolledNames = <String, String>{};
        final enrolledEmails = <String, String>{};

        if (rosterMap is Map) {
          for (final entry in rosterMap.entries) {
            final keyStr = entry.key.toString();
            if (!keyStr.startsWith("${sectionId}_")) continue;
            final lowerKey = keyStr.toLowerCase();
            if (lowerKey.contains('tutorial') || lowerKey.contains('library')) continue;
            if (entry.value is List) {
              for (final item in entry.value) {
                final id = item['roll_number']?.toString() ?? item['id']?.toString() ?? '';
                final name = item['name']?.toString() ?? '';
                final email = item['email']?.toString() ?? '';
                if (id.isNotEmpty) {
                  enrolledIds.add(id);
                  enrolledNames[id] = name;
                  enrolledEmails[id] = email;
                }
              }
            }
          }
        }

        if (enrolledIds.isNotEmpty) {
          _enrolledIds = enrolledIds;
          _enrolledNames = enrolledNames;
          _enrolledEmails = enrolledEmails;
          _mergeEnrollmentWithAttendance();
          _safeNotify();
          debugPrint("✅ LIVE MONITOR: Roster loaded from Server Sync (${enrolledIds.length} enrolled)");
        }
      }
    } catch (e) {
      debugPrint("⚠️ LIVER MONITOR: Server roster fetch error: $e");
    }
  }

  Set<String> _enrolledIds = {};
  Map<String, String> _enrolledNames = {};
  Map<String, String> _enrolledEmails = {};

  void _mergeEnrollmentWithAttendance() {
    if (_enrolledIds.isEmpty) {
      debugPrint("⚠️ Enrollment unavailable, keeping server roster (${_mergedStudents.length} students)");
      return;
    }

    final checkedInByEmail = <String, StudentAttendance>{};
    final checkedInById = <String, StudentAttendance>{};
    for (final s in _attendance) {
      if (s.email != null && s.email!.isNotEmpty) {
        checkedInByEmail[s.email!] = s;
      }
      checkedInById[s.id] = s;
    }

    final merged = <StudentAttendance>[];
    final sortedEnrolledIds = _enrolledIds.toList()..sort();

    for (final id in sortedEnrolledIds) {
      final email = _enrolledEmails[id];
      final rosterName = _enrolledNames[id] ?? id;
      StudentAttendance? s;

      if (email != null && email.isNotEmpty && checkedInByEmail.containsKey(email)) {
        s = checkedInByEmail[email];
      } else if (checkedInById.containsKey(id)) {
        s = checkedInById[id];
      }

      if (s != null) {
        final displayName = (s.name.isEmpty || s.name == 'Unknown Student' || s.name == 'Unknown')
            ? rosterName
            : s.name;

        merged.add(StudentAttendance(
          id: s.id,
          name: displayName,
          email: s.email ?? email,
          image: s.image,
          status: s.status,
          checkInTime: s.checkInTime,
          deviceFingerprint: s.deviceFingerprint,
          isVerified: s.isVerified,
        ));
      } else {
        merged.add(StudentAttendance(
          id: id,
          name: rosterName,
          email: email,
          status: StudentStatus.absent,
        ));
      }
    }

    for (final s in _attendance) {
      final email = s.email;
      bool alreadyMerged = false;

      if (email != null && email.isNotEmpty) {
        if (_enrolledEmails.values.contains(email)) alreadyMerged = true;
      }
      if (!alreadyMerged && _enrolledIds.contains(s.id)) alreadyMerged = true;

      if (!alreadyMerged) {
        merged.add(s);
      }
    }
    final seenIds = <String>{};
    final deduped = <StudentAttendance>[];
    for (final s in merged) {
      if (seenIds.add(s.id)) {
        deduped.add(s);
      }
    }
    _mergedStudents = deduped;
  }

  void toggleSelection(String studentId) {
    if (_selectedStudentIds.contains(studentId)) {
      _selectedStudentIds.remove(studentId);
    } else {
      final student = _mergedStudents.firstWhere((s) => s.id == studentId,
          orElse: () => StudentAttendance(id: studentId, name: '', status: StudentStatus.absent));
      if (student.status != StudentStatus.present) {
        _selectedStudentIds.add(studentId);
      }
    }
    _safeNotify();
  }

  Future<void> markSelectedPresent() async {
    if (_selectedStudentIds.isEmpty) return;

    _isMarkingSelected = true;
    _safeNotify();

    final idsToMark = _selectedStudentIds.toList();
    int successCount = 0;

    for (final id in idsToMark) {
      try {
        final success = await markStudentPresent(id);
        if (success) {
          successCount++;
          _selectedStudentIds.remove(id);
        }
      } catch (e) {
        if (e.toString().contains("ALREADY_MARKED")) {
          _selectedStudentIds.remove(id);
        }
        debugPrint("Bulk Mark Error for $id: $e");
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isMarkingSelected = false;
    _safeNotify();
  }

  bool _isReconciling = false;
  bool get isReconciling => _isReconciling;
  String? _reconcileMessage;
  String? get reconcileMessage => _reconcileMessage;

  Future<void> reconcileCount() async {
    _isReconciling = true;
    _reconcileMessage = null;
    _safeNotify();
    try {
      final result = await _repository.reconcileSession(sessionId);
      if (result != null) {
        final corrected = result['corrected'] as bool? ?? false;
        final actual = result['actual_count'] ?? 0;
        final stored = result['stored_count'] ?? 0;
        _reconcileMessage = corrected
            ? "Count corrected: $stored → $actual"
            : "Count already accurate ($actual)";
        _safeNotify();
      }
    } catch (e) {
      _reconcileMessage = "Reconcile failed: $e";
      _safeNotify();
    } finally {
      _isReconciling = false;
      _safeNotify();
    }
  }

  int get presentCount => _mergedStudents.where((s) => s.status == StudentStatus.present).length;
  int get absentCount => totalCount - presentCount;
  int get totalCount => _mergedStudents.length;
  double get attendanceRate => _mergedStudents.isNotEmpty
      ? (presentCount / _mergedStudents.length) * 100
      : 0;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generateRescueSeed() async {
    final seed = _generateRandomSeed(8);
    final hardware = await HardwareService.getDeviceSnapshot();
    final deviceInfo = DeviceInfoPayload(
      deviceId: hardware.deviceId,
      deviceFingerprint: hardware.fingerprint,
      brand: hardware.manufacturer,
      model: hardware.model,
      manufacturer: hardware.manufacturer,
      osVersion: hardware.osVersion,
      biometricsEnabled: true,
      isRooted: hardware.isRooted,
    );
    await _repository.generateRescueSeed(sessionId, seed, deviceInfo);
  }

  String _generateRandomSeed(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> terminateSession() async {
    await _repository.terminateSession(sessionId);
    _wsService.disconnect();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    _loadingTimer?.cancel();
    onSessionEnded?.call();
  }

  Future<bool> markStudentPresent(String studentId, {String? reason, String? notes}) async {
    try {
      final student = _mergedStudents.firstWhere((s) => s.id == studentId);
      final studentEmail = student.email;

      if (studentEmail == null || studentEmail.isEmpty || studentEmail == 'null') {
        debugPrint("❌ Cannot mark attendance: Student email missing for $studentId. SmartBoard sync requires email.");
        throw Exception("MISSING_EMAIL");
      }

      final bool isWsConnected = _wsConnectionState == 'connected';
      final bool hasReason = reason != null && reason.isNotEmpty && reason != 'live_tap';

      if (!isWsConnected || hasReason) {
        final effectiveReason = hasReason ? reason : 'late_arrival';
        final success = await _repository.markAttendanceCorrection(
          sessionId: sessionId,
          studentId: studentEmail,
          reason: effectiveReason,
          notes: notes,
        );

        if (success) {
          int index = _mergedStudents.indexWhere((s) => s.id == studentId);
          if (index != -1) {
            final s = _mergedStudents[index];
            _mergedStudents[index] = StudentAttendance(
              id: s.id,
              name: s.name,
              email: s.email,
              image: s.image,
              status: StudentStatus.present,
              checkInTime: DateTime.now(),
              deviceFingerprint: s.deviceFingerprint,
              isVerified: s.isVerified,
              markedBy: 'faculty_correction',
            );

            int attIndex = _attendance.indexWhere((att) => att.id == s.id);
            if (attIndex != -1) {
              _attendance[attIndex] = _mergedStudents[index];
            } else {
              _attendance.add(_mergedStudents[index]);
            }
            _safeNotify();
          }
        }
        return success;
      } else {
        _wsService.sendMarkAttendance(
          sessionId: sessionId,
          studentId: studentEmail,
        );
        return true;
      }
    } catch (e) {
      if (e.toString().contains("MISSING_EMAIL")) rethrow;
      if (e.toString().contains("SERVER_ERROR")) rethrow;
      if (e.toString().contains("ALREADY_MARKED")) rethrow;
      debugPrint("Manual Attendance Error: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _wsService.disconnect();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    _loadingTimer?.cancel();
    super.dispose();
  }
}
