import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intelli_attend_shared/engine/time_source.dart' as shared;
import 'package:intelli_attend_faculty/engine/engine.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/override_slot.dart';
import 'package:intelli_attend_faculty/Data/Repositories/course_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/override_repository.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_hydration_service.dart';
import 'package:intelli_attend_faculty/Services/time_sync_service.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';
import 'package:intelli_attend_faculty/Services/board_readiness_notifier.dart';
import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';

class DashboardController with ChangeNotifier, WidgetsBindingObserver {
  static const String _institutionTimezone = 'Asia/Kolkata';

  final CourseRepository _courseRepository;
  final AttendanceRepository _attendanceRepository;
  final OverrideRepository _overrideRepository = OverrideRepository();
  final TimetableController timetableEngine;

  List<ScheduledClass> _schedule = [];
  List<ScheduledClass> _tomorrowSchedule = [];
  Map<String, String> _subjectsCache = {};
  bool _isLoading = true;
  bool _displayShimmer = false;
  Timer? _shimmerThresholdTimer;
  Map<String, dynamic>? _activeSessionMetadata;
  SessionStartResponse? _activeOtpResponse;
  StreamSubscription<WebSocketEvent>? _wsEventSub;
  StreamSubscription<WsConnectionState>? _wsConnSub;

  SessionState _sessionState = SessionState.idle;
  set _updateSessionState(SessionState state) {
    if (_sessionState != state) {
      debugPrint("[State] ${_sessionState.name} → ${state.name}");
    }
    _sessionState = state;
  }
  SessionStateInfo? _sessionStateInfo;
  int _presentCount = 0;
  int _absentCount = 0;
  final Set<String> _presentStudentIds = {};
  final Set<String> _absentStudentIds = {};
  final Set<String> _lateStudentIds = {};
  final Set<String> _leaveStudentIds = {};
  List<Map<String, dynamic>> _rosterStudents = [];

  bool _isRecovering = false;
  final List<WebSocketEvent> _recoveryBuffer = [];
  Timer? _notifyThrottle;
  int _pendingNotifyCount = 0;

  DashboardController(
    this._courseRepository,
    this._attendanceRepository,
  ) : timetableEngine = TimetableController(
          timeSource: _SyncedTimeSource(),
          institutionTimezone: _institutionTimezone,
        ) {
    FacultyHydrationService.onDataChanged = reloadFromCache;
    WidgetsBinding.instance.addObserver(this);
    timetableEngine.addListener(_onEngineTick);
    timetableEngine.onDayChanged = () {
      debugPrint("📅 [Dashboard] Day boundary crossed. Refreshing timetable data.");
      _init();
    };
    BoardReadinessNotifier.instance.addListener(_onBoardReadinessChanged);
    _init();
  }

  SessionState get sessionState => _sessionState;
  SessionStateInfo? get sessionStateInfo => _sessionStateInfo;
  int get presentCount => _presentCount;
  int get absentCount => _absentCount;
  Set<String> get presentStudentIds => _presentStudentIds;
  Set<String> get absentStudentIds => _absentStudentIds;
  Set<String> get lateStudentIds => _lateStudentIds;
  Set<String> get leaveStudentIds => _leaveStudentIds;
  List<Map<String, dynamic>> get rosterStudents => _rosterStudents;

  void _onEngineTick() {
    if (_activeSessionMetadata != null && !_ts.isClassActive) {
      debugPrint("⏰ DASHBOARD: Class slot ended — clearing stale session.");
      clearActiveSession();
    }
    if (hasListeners) notifyListeners();
  }

  TimetableSnapshot get _ts => timetableEngine.snapshot;

  List<ScheduledClass> get scheduledClasses => _schedule;
  List<ScheduledClass> get tomorrowSchedule => _tomorrowSchedule;

  Map<String, List<ScheduledClass>> get weeklySchedule {
    final nowMs = TimeSyncService.syncedNowMs;
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).toLocal();
    final map = <String, List<ScheduledClass>>{};
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (int i = 0; i < 7; i++) {
      final day = days[i];
      if (day == _getDayName(now)) {
        map[day] = _schedule;
      } else if (day == _getDayName(now.add(const Duration(days: 1)))) {
        map[day] = _tomorrowSchedule;
      } else {
        map[day] = _courseRepository.getCachedSchedule(day);
      }
    }
    return map;
  }
  bool get isLoading => _isLoading;
  bool get displayShimmer => _displayShimmer;
  String? get activeSessionId => _activeSessionMetadata?['id'];
  SessionStartResponse? get activeOtpResponse => _activeOtpResponse;

  void _handleLoadingState(bool isLoading) {
    if (isLoading) {
      _shimmerThresholdTimer?.cancel();
      _shimmerThresholdTimer = Timer(const Duration(milliseconds: 150), () {
        _displayShimmer = true;
        if (hasListeners) notifyListeners();
      });
    } else {
      _shimmerThresholdTimer?.cancel();
      _shimmerThresholdTimer = null;
      if (_displayShimmer) {
        _displayShimmer = false;
        if (hasListeners) notifyListeners();
      }
      _isLoading = false;
    }
  }

  void clearActiveSession() {
    _activeSessionMetadata = null;
    _activeOtpResponse = null;
    _updateSessionState = SessionState.idle;
        _sessionStateInfo = null;
        _presentCount = 0;
    _absentCount = 0;
    _presentStudentIds.clear();
    _absentStudentIds.clear();
    _lateStudentIds.clear();
    _leaveStudentIds.clear();
    _rosterStudents.clear();
    _isRecovering = false;
    _recoveryBuffer.clear();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    _wsEventSub = null;
    _wsConnSub = null;
    WebSocketService().disconnect();
    if (hasListeners) notifyListeners();
  }

  void updateOtpResponse(SessionStartResponse response) {
    _activeOtpResponse = response;
    if (hasListeners) notifyListeners();
  }

  Map<String, dynamic>? get activeSession => _activeSessionMetadata;

  /// Lightweight current-state fetch for polling (returns raw map)
  Future<Map<String, dynamic>?> fetchCurrentState() async {
    try {
      return await _attendanceRepository.fetchCurrentState();
    } catch (_) {
      return null;
    }
  }

  /// Recover state from server (recovery API)
  /// Called on startup, reconnect, and foreground resume
  Future<SessionStateInfo?> recoverState() async {
    debugPrint("[Recovery] Fetching current session state...");
    _isRecovering = true;
    try {
      final data = await _attendanceRepository.fetchCurrentState();
      if (data != null) {
        final info = SessionStateInfo.fromJson(data);
        debugPrint("Recovery response: state=${info.state}");
        if (_sessionStateInfo != null &&
            info.sessionId == _sessionStateInfo!.sessionId &&
            info.version <= _sessionStateInfo!.version) {
          debugPrint("[Recovery] Skipped stale state (v${info.version} ≤ v${_sessionStateInfo!.version})");
          _isRecovering = false;
          _flushRecoveryBuffer();
          return _sessionStateInfo;
        }
        _sessionStateInfo = info;
        _updateSessionState = info.state;
        debugPrint("Parsed state = $_sessionState");
        _presentCount = info.presentCount;
        _absentCount = info.absentCount;
        if (info.sessionId != null && info.state != SessionState.idle) {
          _restoreActiveSession(info);
        }
        if (hasListeners) notifyListeners();
        debugPrint("[Recovery] State: ${info.state}");
        _isRecovering = false;
        _flushRecoveryBuffer();
        return info;
      } else {
        _updateSessionState = SessionState.idle;
        _sessionStateInfo = null;
        if (hasListeners) notifyListeners();
        debugPrint("[Recovery] No active session");
        _isRecovering = false;
        _flushRecoveryBuffer();
        return null;
      }
    } catch (e) {
      debugPrint("[Recovery] Error: $e");
      _isRecovering = false;
      _flushRecoveryBuffer();
      return null;
    }
  }

  void _flushRecoveryBuffer() {
    if (_recoveryBuffer.isEmpty) return;
    debugPrint("[Recovery] Flushing ${_recoveryBuffer.length} buffered events");
    final buffer = List<WebSocketEvent>.from(_recoveryBuffer);
    _recoveryBuffer.clear();
    for (final event in buffer) {
      _handleWsEvent(event);
    }
  }

  void _restoreActiveSession(SessionStateInfo info) {
    _activeSessionMetadata = {
      'id': info.sessionId,
      'subject_name': info.subjectName ?? '',
      'subject_code': info.subjectCode ?? '',
      'room_number': info.roomNumber ?? '',
      'present_count': info.presentCount,
      'absent_count': info.absentCount,
    };
    if (info.sessionId != null) {
      _connectDashboardWs(info.sessionId!);
    }
  }

  String _getMainCardSubjectName() {
    return _ts.subjectName ?? 'Ongoing Session';
  }
  String _getMainCardSubjectCode() => _ts.subjectCode ?? 'LIVE';
  String _getMainCardRoomNumber() => _ts.roomNumber ?? 'Room';

  bool get isTomorrow => _ts.isAfterLastClass;

  // ── Engine bridge: ScheduledClass → TimeBlock ─────────────────────

  ScheduledClass? get mainCardClass {
    TimeBlock? block;
    if (_ts.currentBlock != null && !_ts.currentBlock!.isBreak) {
      block = _ts.currentBlock;
    } else {
      block = _ts.nextBlock;
    }
    if (block == null || block.isBreak) {
      if (_ts.isAfterLastClass || _ts.isWeekend) {
        final ahead = _findNextClassInWeek();
        if (ahead != null) return ahead;
      }
      return null;
    }
    return _resolveScheduledClass(block);
  }

  ScheduledClass? _findNextClassInWeek() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final now = DateTime.now();
    final currentDayIdx = now.weekday - 1;

    for (int offset = 1; offset <= 7; offset++) {
      final targetIdx = (currentDayIdx + offset) % 7;
      final dayName = days[targetIdx];
      final classes = _courseRepository.getCachedSchedule(dayName);
      if (classes != null && classes.isNotEmpty) {
        return classes.first;
      }
    }
    return null;
  }

  ScheduledClass? get currentSlot {
    final block = _ts.currentBlock;
    if (block == null || block.isBreak) return null;
    return _resolveScheduledClass(block);
  }

  ScheduledClass? _resolveScheduledClass(TimeBlock block) {
    try {
      return _schedule.firstWhere((c) => c.id == block.sourceSlot.id);
    } catch (_) {
      try {
        return _tomorrowSchedule.firstWhere((c) => c.id == block.sourceSlot.id);
      } catch (_) {
        return null;
      }
    }
  }

  bool isCurrentSlot(ScheduledClass c) {
    final cs = currentSlot;
    return cs != null && cs.id == c.id;
  }

  void _pushBlocksToEngine() {
    final todayBlocks = _schedule.map(_classToBlock).toList();
    final tomorrowBlocks = _tomorrowSchedule.map(_classToBlock).toList();
    timetableEngine.updateBlocks(todayBlocks, tomorrowBlocks);
  }

  TimeBlock _classToBlock(ScheduledClass c) {
    final slot = c.toTimetableSlot(institutionTimezone: _institutionTimezone);
    return TimeBlock.fromSlot(slot);
  }

  // ── End engine bridge ────────────────────────────────────────────

  /// Resolve canonical subject name from subjects cache.
  /// Falls back to the timetable's denormalized label if cache miss.
  String resolveSubjectName(ScheduledClass c) {
    if (_subjectsCache.containsKey(c.subjectCode)) {
      return _subjectsCache[c.subjectCode]!;
    }
    return c.subjectName;
  }

  Future<void> _init() async {
    debugPrint("🛠 DASHBOARD -> Initializing (High Caching Mode)");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      debugPrint("❌ DASHBOARD: No active user found — retrying in 2s (Firebase may still be initializing)...");
      _handleLoadingState(true);
      await Future.delayed(const Duration(seconds: 2));
      final retryUser = FirebaseAuth.instance.currentUser;
      if (retryUser == null || retryUser.email == null) {
        debugPrint("❌ DASHBOARD: No active user after retry. Giving up.");
        _handleLoadingState(false);
        return;
      }
      _initWithData(retryUser.email!.toLowerCase().trim());
      return;
    }

    _initWithData(user.email!.toLowerCase().trim());
  }

  void _initWithData(String email) {
    final nowMs = TimeSyncService.syncedNowMs;
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).toLocal();
    final todayName = _getDayName(now);
    final tomorrowName = _getDayName(now.add(const Duration(days: 1)));

    _subjectsCache = PersistenceService.getSubjectsCache();

    _schedule = _courseRepository.getCachedSchedule(todayName);
    _tomorrowSchedule = _courseRepository.getCachedSchedule(tomorrowName);

    final bool hasCache = _schedule.isNotEmpty || _tomorrowSchedule.isNotEmpty;
    if (hasCache) {
      _pushBlocksToEngine();
      _isLoading = false;
      if (hasListeners) notifyListeners();
      _syncOverrides(email, todayName);
      _refreshTopicsInBackground(email, todayName, tomorrowName);
      debugPrint("📦 DASHBOARD: Data served from HIGH CACHE.");
    } else {
      debugPrint("📡 DASHBOARD: Cache empty, start shimmer + fetch...");
      _handleLoadingState(true);
      _fetchFullScheduleFromFirebase(email, todayName, tomorrowName);
    }

    recoverState();
  }

  void reloadFromCache() {
    final nowMs = TimeSyncService.syncedNowMs;
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).toLocal();
    final todayName = _getDayName(now);
    final tomorrowName = _getDayName(now.add(const Duration(days: 1)));
    final fresh = _courseRepository.getCachedSchedule(todayName);
    final freshTomorrow = _courseRepository.getCachedSchedule(tomorrowName);
    if (fresh.isNotEmpty || freshTomorrow.isNotEmpty) {
      _schedule = fresh;
      _tomorrowSchedule = freshTomorrow;
      _pushBlocksToEngine();
      debugPrint("🔄 DASHBOARD: Reloaded from cache (today: ${fresh.length}, tomorrow: ${freshTomorrow.length})");
      if (hasListeners) notifyListeners();
    }
  }

  Future<void> _fetchFullScheduleFromFirebase(String email, String today, String tomorrow) async {
    try {
      final classes = await _courseRepository.watchTodaySchedule(email).first;
      _schedule = classes;

      final tomorrowClasses = await _courseRepository.watchSchedule(email, tomorrow).first;
      _tomorrowSchedule = tomorrowClasses;

      _pushBlocksToEngine();
      await _syncOverrides(email, today);
      _handleLoadingState(false);
      if (hasListeners) notifyListeners();
    } catch (e) {
      debugPrint("❌ Full Schedule Fetch Error: $e");
      _handleLoadingState(false);
      _isLoading = false;
      if (hasListeners) notifyListeners();
    }
  }

  Future<void> _syncOverrides(String email, String todayName) async {
    try {
      final overrides = await _overrideRepository.fetchTodaysOverrides(email);
      if (overrides.isNotEmpty) {
        debugPrint("🔄 DASHBOARD: Merging ${overrides.length} live overrides...");
        _mergeOverrides(overrides, todayName);
        _pushBlocksToEngine();
        if (hasListeners) notifyListeners();
      }
    } catch (e) {
      debugPrint("⚠️ Override sync error: $e");
    }
  }

  Future<void> _refreshTopicsInBackground(String email, String today, String tomorrow) async {
    try {
      final classes = await _courseRepository.watchTodaySchedule(email).first;
      if (classes.isNotEmpty) {
        bool topicsChanged = false;
        for (int i = 0; i < classes.length && i < _schedule.length; i++) {
          if (classes[i].topics.isNotEmpty && _schedule[i].topics.isEmpty) {
            topicsChanged = true;
            break;
          }
        }
        if (topicsChanged) {
          _schedule = classes;
          _pushBlocksToEngine();
          debugPrint("🔄 DASHBOARD: Topics refreshed from server.");
          if (hasListeners) notifyListeners();
        }
      }

      final tomorrowClasses = await _courseRepository.watchSchedule(email, tomorrow).first;
      if (tomorrowClasses.isNotEmpty) {
        bool topicsChanged = false;
        for (int i = 0; i < tomorrowClasses.length && i < _tomorrowSchedule.length; i++) {
          if (tomorrowClasses[i].topics.isNotEmpty && _tomorrowSchedule[i].topics.isEmpty) {
            topicsChanged = true;
            break;
          }
        }
        if (topicsChanged) {
          _tomorrowSchedule = tomorrowClasses;
          _pushBlocksToEngine();
          if (hasListeners) notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("⚠️ DASHBOARD: Background topic refresh error: $e");
    }
  }

  Future<void> refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final email = user.email!.toLowerCase().trim();
    final nowMs = TimeSyncService.syncedNowMs;
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true).toLocal();
    final todayName = _getDayName(now);
    final tomorrowName = _getDayName(now.add(const Duration(days: 1)));

    debugPrint("🔄 DASHBOARD: Manual refresh triggered...");
    await _fetchFullScheduleFromFirebase(email, todayName, tomorrowName);
  }

  void _mergeOverrides(List<OverrideSlot> overrides, String todayName) {
    final outSlotIds = <String>{};
    final inSlots = <ScheduledClass>[];

    for (final ov in overrides) {
      if (ov.originalFacultyEmail == FacultyService.canonicalId) {
        outSlotIds.add(ov.slotId);
        debugPrint("   ➖ Removed slot ${ov.slotId} (${ov.subjectName})");
      }
      if (ov.substituteFacultyEmail == FacultyService.canonicalId) {
        inSlots.add(ScheduledClass(
          id: ov.id,
          subjectName: ov.subjectName,
          subjectCode: ov.subjectCode,
          roomNumber: ov.roomNumber,
          startTime: ov.legacyStartTime ?? '$_formatMin(${ov.startMinutes})',
          endTime: ov.legacyEndTime ?? '$_formatMin(${ov.endMinutes})',
          dayOfWeek: ov.dayOfWeek,
          sectionId: ov.sectionId,
          startMinutes: ov.startMinutes,
          endMinutes: ov.endMinutes,
        ));
        debugPrint("   ➕ Added substitute slot: ${ov.subjectName} (${ov.startMinutes}-${ov.endMinutes})");
      }
    }

    if (outSlotIds.isNotEmpty) {
      _schedule.removeWhere((s) => outSlotIds.contains(s.id));
    }

    if (inSlots.isNotEmpty) {
      _schedule.addAll(inSlots);
      _schedule.sort((a, b) {
        final am = a.startMinutes ?? 0;
        final bm = b.startMinutes ?? 0;
        return am.compareTo(bm);
      });
    }
  }

  static String _formatMin(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  String _getDayName(DateTime date) {
    final List<String> weekDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return weekDays[date.weekday - 1];
  }

  bool get isWithinT3 {
    if (_ts.isClassActive) return false;
    if (_ts.phase == TimetablePhase.noSchedule) return false;
    return _ts.countdown.inSeconds <= 180 && _ts.countdown.inSeconds > 0;
  }

  static const int preClassWindowSeconds = 1800;

  bool get isWithinPreClassWindow {
    if (_ts.isClassActive) return false;
    if (_ts.phase == TimetablePhase.noSchedule) return false;
    if (_ts.phase == TimetablePhase.weekend) return false;
    if (_ts.isBreak) return false;
    return _ts.countdown.inSeconds <= preClassWindowSeconds && _ts.countdown.inSeconds > 0;
  }

  bool get isBreak {
    if (_ts.isBreak) return true;
    if (_ts.phase == TimetablePhase.weekend) return true;
    if (_ts.isBeforeFirstClass) return true;
    if (_ts.phase == TimetablePhase.noSchedule) return false;
    return !_ts.isClassActive;
  }

  String get breakLabel {
    if (_ts.breakLabel != null) return _ts.breakLabel!;
    if (_ts.phase == TimetablePhase.weekend) return 'Happy Sunday';
    if (_ts.isAfterLastClass) return 'Classes ended for today';
    if (_ts.isBeforeFirstClass) {
      final firstBlock = _ts.nextBlock;
      if (firstBlock != null) {
        return 'Classes start at ${_formatMinutes(firstBlock.startMinutes)}';
      }
      return 'Classes start soon';
    }
    return '';
  }

  String _formatMinutes(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 12;
    final m = totalMinutes % 60;
    final period = totalMinutes ~/ 60 >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : h;
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  String get timeLeft => _ts.countdownLabel;

  void _computeAbsentIds() {
    _absentStudentIds.clear();
    for (final s in _rosterStudents) {
      final id = s['id']?.toString() ?? s['roll_number']?.toString() ?? s['student_id']?.toString() ?? '';
      if (id.isNotEmpty && !_presentStudentIds.contains(id)) {
        _absentStudentIds.add(id);
      }
    }
  }

  void _onBoardReadinessChanged() {
    if (hasListeners) notifyListeners();
  }

  bool isBoardReady(String slotId) =>
      BoardReadinessNotifier.instance.isReady(slotId);

  void clearBoardReadiness(String slotId) {
    BoardReadinessNotifier.instance.clearReady(slotId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("📱 [Dashboard] App resumed. Re-evaluating timetable state.");
      timetableEngine.forceReevaluate();
      recoverState();
    }
  }

  /// Move PREPARING → IGNITING via swipe-to-start on an existing session
  Future<SessionStartResponse?> startExistingSession(String sessionId) async {
    if (_sessionState != SessionState.preparing) {
      debugPrint("[State] Cannot start session: current state ${_sessionState.name}");
      return null;
    }
    _sessionStateInfo = null;
    try {
      final response = await _attendanceRepository.startExistingSession(sessionId);
      if (response != null) {
        _activeOtpResponse = response;
        _activeSessionMetadata ??= {
          'id': sessionId,
          'present_count': 0,
          'absent_count': 0,
          'total_count': 0,
        };
        _activeSessionMetadata!['id'] = response.sessionId;
        _connectDashboardWs(response.sessionId);
      }
      return response;
    } catch (e) {
      debugPrint("[Session] startExistingSession error: $e");
      rethrow;
    }
  }

  Future<SessionStartResponse?> startSession(ScheduledClass scheduledClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    clearBoardReadiness(scheduledClass.id);
    _sessionStateInfo = null;
    try {
      final response = await _attendanceRepository.startSession(scheduledClass);
      if (response != null) {
        _activeOtpResponse = response;
        int totalCount = 0;
        try {
          final raw = PersistenceService.academicBox.get('roster_${scheduledClass.sectionId}');
          if (raw is List) totalCount = raw.length;
        } catch (_) {}
        _activeSessionMetadata = {
          'id': response.sessionId,
          'subject_name': resolveSubjectName(scheduledClass),
          'subject_code': scheduledClass.subjectCode,
          'room_number': scheduledClass.roomNumber,
          'start_time': scheduledClass.startTime,
          'end_time': scheduledClass.endTime,
          'course_id': scheduledClass.id,
          'section_id': scheduledClass.sectionId,
          'subject_code_only': scheduledClass.subjectCode,
          'present_count': 0,
          'total_count': totalCount,
        };
        _connectDashboardWs(response.sessionId);
      }
      return response;
    } catch (e) {
      debugPrint("❌ DASHBOARD: Failed to start session: $e");
      rethrow;
    }
  }

  Future<SessionStartResponse?> refreshOtp() async {
    final sessionId = activeSessionId;
    if (sessionId == null) return null;

    try {
      final response = await _attendanceRepository.refreshOtp(sessionId);
      if (response != null) {
        _activeOtpResponse = response;
        if (hasListeners) notifyListeners();
      }
      return response;
    } catch (e) {
      debugPrint("❌ DASHBOARD: Failed to refresh OTP: $e");
      rethrow;
    }
  }

  Future<SessionStartResponse?> retrySession(ScheduledClass scheduledClass) async {
    clearActiveSession();
    return startSession(scheduledClass);
  }

  void _connectDashboardWs(String sessionId) {
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();

    final wsService = WebSocketService();
    wsService.connectAndJoinRoom(sessionId: sessionId);

    _wsConnSub = wsService.connectionState.listen((state) {
      if (state == WsConnectionState.connected) {
        debugPrint("[Dashboard] WS connected — triggering state recovery");
        recoverState();
      }
    });

    _wsEventSub = wsService.events.listen((event) {
      if (_activeSessionMetadata == null) {
        debugPrint("[WS] Skipped: _activeSessionMetadata is null");
        return;
      }
      if (_isRecovering) {
        debugPrint("[WS] Buffered during recovery: ${event.type.name}");
        _recoveryBuffer.add(event);
        return;
      }
      _handleWsEvent(event);
    });
  }

  void _handleWsEvent(WebSocketEvent event) {
    final eventSessionId = event.data['session_id']?.toString();
    debugPrint("[WS] Event ${event.type.name} session=$eventSessionId _sessionStateInfo=${_sessionStateInfo?.sessionId}");
    if (_sessionStateInfo != null &&
        eventSessionId != null &&
        _sessionStateInfo!.sessionId != null &&
        eventSessionId != _sessionStateInfo!.sessionId) {
      debugPrint("[WS] ❌ BLOCKED by version guard: event session ($eventSessionId) != current (${_sessionStateInfo!.sessionId})");
      return;
    }

    final eventVersion = event.data['version'] as int?;
    if (eventVersion != null &&
        _sessionStateInfo != null &&
        eventVersion <= _sessionStateInfo!.version) {
      debugPrint("[WS] ❌ BLOCKED by version: event v$eventVersion ≤ current v${_sessionStateInfo!.version}");
      return;
    }

    switch (event.type) {
      case WsEventType.facultySync:
        final syncData = FacultySyncData.fromEvent(event);
        _activeSessionMetadata!['present_count'] = syncData.totalPresent;
        _activeSessionMetadata!['total_count'] = syncData.totalStudents;
        _presentCount = syncData.totalPresent;
        _absentCount = (syncData.totalStudents - syncData.totalPresent).clamp(0, syncData.totalStudents);
        _presentStudentIds.clear();
        for (final s in syncData.presentStudents) {
          final id = s['student_id']?.toString() ?? s['id']?.toString() ?? s['roll_number']?.toString() ?? '';
          if (id.isNotEmpty) _presentStudentIds.add(id);
        }
        _computeAbsentIds();
        _scheduleNotify();

      case WsEventType.studentVerified:
      case WsEventType.attendanceUpdate:
        final currentPresent = _activeSessionMetadata!['present_count'] as int? ?? 0;
        _activeSessionMetadata!['present_count'] = currentPresent + 1;
        _presentCount = currentPresent + 1;
        _scheduleNotify();

      case WsEventType.attendanceUpdated:
        final present = event.get<int>('present') ?? event.get<int>('present_count');
        final absent = event.get<int>('absent') ?? event.get<int>('absent_count');
        if (present != null) {
          _presentCount = present;
          _activeSessionMetadata!['present_count'] = present;
        }
        if (absent != null) {
          _absentCount = absent;
          _activeSessionMetadata!['absent_count'] = absent;
        }
        _scheduleNotify();

      case WsEventType.markAttendanceAck:
      case WsEventType.studentMarked:
        final ack = AttendanceMarkAckData.fromEvent(event);
        if (ack.success) {
          final currentPresent = _activeSessionMetadata!['present_count'] as int? ?? 0;
          _activeSessionMetadata!['present_count'] = currentPresent + 1;
          _presentCount = currentPresent + 1;
          _scheduleNotify();
        }

      case WsEventType.fullStateSync:
        final syncData = FullStateSyncData.fromEvent(event);
        _activeSessionMetadata!['present_count'] = syncData.totalPresent;
        _activeSessionMetadata!['total_count'] = syncData.totalStudents;
        _presentCount = syncData.totalPresent;
        _absentCount = (syncData.totalStudents - syncData.totalPresent).clamp(0, syncData.totalStudents);
        _presentStudentIds.clear();
        _lateStudentIds.clear();
        _leaveStudentIds.clear();
        _rosterStudents
          ..clear()
          ..addAll(syncData.roster);
        for (final s in syncData.roster) {
          final id = s['student_id']?.toString() ?? s['id']?.toString() ?? s['roll_number']?.toString() ?? '';
          final status = s['status']?.toString()?.toLowerCase() ?? '';
          if (id.isNotEmpty) {
            if (status == 'present' || status == 'late') {
              _presentStudentIds.add(id);
            }
            if (status == 'late') {
              _lateStudentIds.add(id);
            }
            if (status == 'leave') {
              _leaveStudentIds.add(id);
            }
          }
        }
        _computeAbsentIds();
        _scheduleNotify();
        _scheduleNotify();

      case WsEventType.sessionPreparing:
        _updateSessionState = SessionState.preparing;
        if (hasListeners) notifyListeners();

      case WsEventType.sessionIgniting:
        _updateSessionState = SessionState.igniting;
        if (hasListeners) notifyListeners();

      case WsEventType.attendanceOpen:
      case WsEventType.sessionActivated:
        _updateSessionState = SessionState.active;
        if (eventVersion != null && _sessionStateInfo != null) {
          _sessionStateInfo = _sessionStateInfo!.copyWith(version: eventVersion);
        }
        if (hasListeners) notifyListeners();

      case WsEventType.boardConnected:
        if (hasListeners) notifyListeners();

      case WsEventType.attendanceClosed:
      case WsEventType.sessionArchived:
        _updateSessionState = SessionState.closed;
        if (eventVersion != null && _sessionStateInfo != null) {
          _sessionStateInfo = _sessionStateInfo!.copyWith(version: eventVersion);
        }
        if (hasListeners) notifyListeners();
        clearActiveSession();

      case WsEventType.studentRejected:
      case WsEventType.attendanceMarkedManual:
      case WsEventType.otpFailed:
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

  void _scheduleNotify() {
    _notifyThrottle?.cancel();
    _pendingNotifyCount++;
    _notifyThrottle = Timer(const Duration(milliseconds: 250), () {
      _pendingNotifyCount = 0;
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void dispose() {
    _shimmerThresholdTimer?.cancel();
    _notifyThrottle?.cancel();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    WebSocketService().disconnect();
    WidgetsBinding.instance.removeObserver(this);
    BoardReadinessNotifier.instance.removeListener(_onBoardReadinessChanged);
    if (FacultyHydrationService.onDataChanged == reloadFromCache) {
      FacultyHydrationService.onDataChanged = null;
    }
    timetableEngine.removeListener(_onEngineTick);
    timetableEngine.dispose();
    super.dispose();
  }
}

class _SyncedTimeSource extends shared.SyncedClockSource {
  _SyncedTimeSource() : super(nowMsProvider: _nowMs);

  static int _nowMs() => TimeSyncService.syncedNowMs;
}
