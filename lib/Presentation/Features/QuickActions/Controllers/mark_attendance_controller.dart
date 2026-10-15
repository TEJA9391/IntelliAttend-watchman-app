import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/mark_attendance_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/draft_attendance_service.dart';
import 'package:intelli_attend_faculty/Data/Services/offline_sync_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

enum AttendanceMode { manual, qr, face, nfc, bluetooth, hybrid }
enum SortMode { alphabetical, nameDesc, rollNumber, attendancePercent, recentlyUpdated, newest, oldest }
enum FilterMode { all, present, absent, late, leave, notMarked, below75, eligible, above90 }

enum QuickActionResult { success, skipped, offline, failed }

class StudentNote {
  final String reason;
  final String remark;
  final String? medical;
  final String? lateReason;
  final String? privateNotes;
  final DateTime timestamp;

  StudentNote({
    required this.reason,
    required this.remark,
    this.medical,
    this.lateReason,
    this.privateNotes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'reason': reason,
    'remark': remark,
    if (medical != null) 'medical': medical,
    if (lateReason != null) 'lateReason': lateReason,
    if (privateNotes != null) 'privateNotes': privateNotes,
    'timestamp': timestamp.toIso8601String(),
  };
}

class EditEntry {
  final String studentId;
  final AttendanceStatus oldStatus;
  final AttendanceStatus newStatus;
  final DateTime editedAt;
  final String editedBy;

  EditEntry({
    required this.studentId,
    required this.oldStatus,
    required this.newStatus,
    DateTime? editedAt,
    this.editedBy = 'Faculty',
  }) : editedAt = editedAt ?? DateTime.now();
}

class _UndoEntry {
  final String studentId;
  final AttendanceStatus previousStatus;
  final StudentNote? previousNote;
  _UndoEntry(this.studentId, this.previousStatus, [this.previousNote]);
}

class MarkAttendanceController extends ChangeNotifier {
  final MarkAttendanceRepository _repository;
  final List<_UndoEntry> _undoStack = [];

  List<ClassStudent> _roster = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  Map<String, StudentNote> _studentNotes = {};
  Map<String, List<Map<String, dynamic>>> _attendanceHistory = {};
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isSyncing = false;
  String? _error;
  String _searchQuery = '';
  FilterMode _filterMode = FilterMode.all;
  SortMode _sortMode = SortMode.alphabetical;
  String? _genderFilter;
  String? _sectionFilter;
  Set<String> _selectedStudentIds = {};
  bool _isSelectionMode = false;
  AttendanceMode _sessionMode = AttendanceMode.manual;
  String _sessionStatus = 'not_started';
  String _sessionId = '';
  DateTime? _sessionStartTime;
  bool _isEditMode = false;
  String _editedBy = 'Faculty';
  DateTime? _editedAt;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSubmitTime;

  String _qrCodeData = '';
  int _qrCountdownSeconds = 120;
  Timer? _qrTimer;
  List<String> _qrScannedStudentIds = [];

  List<String> _recognizedStudentIds = [];
  List<String> _unknownFaceIds = [];
  bool _isCameraActive = false;

  List<String> _nfcVerifiedIds = [];
  String _lastNfcTag = '';

  List<String> _bluetoothDetectedIds = [];
  Map<String, double> _bluetoothSignalStrengths = {};

  final String? _courseCode;
  bool _isProcessingQuickAction = false;
  Map<String, AttendanceStatus> _quickActionSnapshot = {};
  bool _hasQuickActionSnapshot = false;

  String _draftSection = '';
  Timer? _draftTimer;
  String? _submitReferenceId;
  bool _wasSubmittedOffline = false;
  String _submittedFingerprint = '';
  final Random _random = Random();

  MarkAttendanceController(this._repository, {String? courseCode}) : _courseCode = courseCode;

  List<ClassStudent> get roster => _roster;
  Map<String, AttendanceStatus> get attendanceMap => _attendanceMap;
  Map<String, StudentNote> get studentNotes => _studentNotes;
  Map<String, List<Map<String, dynamic>>> get attendanceHistory => _attendanceHistory;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  FilterMode get filterMode => _filterMode;
  SortMode get sortMode => _sortMode;
  String? get genderFilter => _genderFilter;
  String? get sectionFilter => _sectionFilter;
  Set<String> get selectedStudentIds => _selectedStudentIds;
  bool get isSelectionMode => _isSelectionMode;
  AttendanceMode get sessionMode => _sessionMode;
  String get sessionStatus => _sessionStatus;
  String get sessionId => _sessionId;
  DateTime? get sessionStartTime => _sessionStartTime;
  bool get isEditMode => _isEditMode;
  String get editedBy => _editedBy;
  DateTime? get editedAt => _editedAt;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  DateTime? get lastSubmitTime => _lastSubmitTime;
  bool get canUndo => _undoStack.isNotEmpty;
  List<_UndoEntry> get undoStack => _undoStack;
  bool get hasChanges => _attendanceMap.isNotEmpty;
  String get draftKey => '${_courseCode ?? 'default'}|$_draftSection';
  String? get submitReferenceId => _submitReferenceId;
  bool get wasSubmittedOffline => _wasSubmittedOffline;
  bool get hasDraft => DraftAttendanceService.instance.isDraftPresent(draftKey);
  String get qrCodeData => _qrCodeData;
  int get qrCountdownSeconds => _qrCountdownSeconds;
  List<String> get qrScannedStudentIds => _qrScannedStudentIds;
  List<String> get recognizedStudentIds => _recognizedStudentIds;
  List<String> get unknownFaceIds => _unknownFaceIds;
  bool get isCameraActive => _isCameraActive;
  List<String> get nfcVerifiedIds => _nfcVerifiedIds;
  String get lastNfcTag => _lastNfcTag;
  List<String> get bluetoothDetectedIds => _bluetoothDetectedIds;
  Map<String, double> get bluetoothSignalStrengths => _bluetoothSignalStrengths;
  String? get courseCode => _courseCode;
  bool get isProcessingQuickAction => _isProcessingQuickAction;
  bool get hasQuickActionSnapshot => _hasQuickActionSnapshot;
  bool get canPerformBulkActions {
    final assigned = FacultyService.courses.value;
    final code = _courseCode?.trim().toUpperCase();
    if (assigned.isEmpty || code == null || code.isEmpty) return true;
    return assigned.any((course) {
      final value = (course['code'] ?? course['course_code'] ?? course['subject_code'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return value.isNotEmpty && value == code;
    });
  }

  List<String> get availableSections {
    final sections = _roster.map((s) => s.section ?? '').where((s) => s.isNotEmpty).toSet().toList();
    sections.sort();
    return sections;
  }

  List<ClassStudent> get filteredRoster {
    var list = _roster.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.rollNumber.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q) ||
            (s.department?.toLowerCase().contains(q) ?? false) ||
            (s.email.toLowerCase().contains(q));
      }).toList();
    }
    if (_genderFilter != null) {
      list = list.where((s) => s.gender == _genderFilter).toList();
    }
    if (_sectionFilter != null) {
      list = list.where((s) => s.section == _sectionFilter).toList();
    }
    switch (_filterMode) {
      case FilterMode.present:
        list = list.where((s) => _attendanceMap[s.id] == AttendanceStatus.present).toList();
        break;
      case FilterMode.absent:
        list = list.where((s) => _attendanceMap[s.id] == AttendanceStatus.absent).toList();
        break;
      case FilterMode.late:
        list = list.where((s) => _attendanceMap[s.id] == AttendanceStatus.late).toList();
        break;
      case FilterMode.leave:
        list = list.where((s) => _attendanceMap[s.id] == AttendanceStatus.leave).toList();
        break;
      case FilterMode.notMarked:
        list = list.where((s) => !_attendanceMap.containsKey(s.id)).toList();
        break;
      case FilterMode.below75:
        list = list.where((s) => s.attendancePercentage < 75).toList();
        break;
      case FilterMode.eligible:
        list = list.where((s) => s.attendancePercentage >= 75).toList();
        break;
      case FilterMode.above90:
        list = list.where((s) => s.attendancePercentage > 90).toList();
        break;
      case FilterMode.all:
        break;
    }
    switch (_sortMode) {
      case SortMode.alphabetical:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortMode.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortMode.rollNumber:
        list.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
        break;
      case SortMode.attendancePercent:
        list.sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage));
        break;
      case SortMode.recentlyUpdated:
        list.sort((a, b) {
          final aTime = a.lastSeen ?? DateTime(2000);
          final bTime = b.lastSeen ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        break;
      case SortMode.newest:
        list.sort((a, b) {
          final aTime = a.lastSeen ?? DateTime(2000);
          final bTime = b.lastSeen ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
        break;
      case SortMode.oldest:
        list.sort((a, b) {
          final aTime = a.lastSeen ?? DateTime(2100);
          final bTime = b.lastSeen ?? DateTime(2100);
          return aTime.compareTo(bTime);
        });
        break;
    }
    return list;
  }

  int get totalCount => _roster.length;
  int get markedCount => _attendanceMap.length;
  int get unmarkedCount => _roster.length - _attendanceMap.length;
  int get presentCount => _attendanceMap.values.where((s) => s == AttendanceStatus.present).length;
  int get absentCount => _attendanceMap.values.where((s) => s == AttendanceStatus.absent).length;
  int get lateCount => _attendanceMap.values.where((s) => s == AttendanceStatus.late).length;
  int get leaveCount => _attendanceMap.values.where((s) => s == AttendanceStatus.leave).length;
  double get attendancePercent => markedCount > 0 ? (presentCount + lateCount) / totalCount * 100 : 0;
  bool get allMarked => _attendanceMap.length == _roster.length;
  bool get canSubmit => allMarked && _sessionStatus != 'not_started';
  int get editedStudentCount => _editHistory.length;
  final Map<String, EditEntry> _editHistory = {};
  Map<String, EditEntry> get editHistory => _editHistory;

  // === SESSION MANAGEMENT ===

  Future<void> loadRoster(
    String courseCode, {
    AttendanceMode mode = AttendanceMode.manual,
    String section = '',
    String? sectionId,
  }) async {
    _isLoading = true;
    _error = null;
    _attendanceMap.clear();
    _studentNotes.clear();
    _attendanceHistory.clear();
    _undoStack.clear();
    _selectedStudentIds.clear();
    _editHistory.clear();
    _sessionMode = mode;
    _sessionStatus = 'loading';
    _hasUnsavedChanges = false;
    _isEditMode = false;
    _editedAt = null;
    _draftSection = section;
    notifyListeners();

    try {
      _roster = await _repository.fetchRoster(courseCode, sectionId: sectionId);
      _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}';
      _sessionStartTime = DateTime.now();
      _sessionStatus = 'active';
      _loadAttendanceHistories();
    } catch (e) {
      _error = 'Failed to load roster: $e';
      _sessionStatus = 'error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadAttendanceHistories() {
    for (final student in _roster) {
      _attendanceHistory[student.id] = DummyDataGeneratorForHistory._generate(student.id);
    }
  }

  void cancelSession() {
    _sessionStatus = 'cancelled';
    _qrTimer?.cancel();
    notifyListeners();
  }

  // === DRAFT AUTOSAVE ===

  void _scheduleDraftSave() {
    if (_sessionStatus == 'submitted' || _sessionStatus == 'submitted_offline') return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _persistDraft);
  }

  Future<void> _persistDraft() async {
    if (_roster.isEmpty || _attendanceMap.isEmpty) return;
    if (_sessionStatus == 'submitted' || _sessionStatus == 'submitted_offline') return;
    await DraftAttendanceService.instance.saveDraft(
      DraftAttendance(
        key: draftKey,
        attendanceMap: Map.from(_attendanceMap),
        studentNotes: _studentNotes.map((k, v) => MapEntry(k, v.toMap())),
        savedAt: DateTime.now(),
      ),
    );
  }

  Future<void> saveDraftNow() async {
    _draftTimer?.cancel();
    await _persistDraft();
  }

  void _clearDraftNow() {
    _draftTimer?.cancel();
    unawaited(DraftAttendanceService.instance.clearDraft(draftKey));
  }

  Future<void> clearDraft() async {
    _draftTimer?.cancel();
    await DraftAttendanceService.instance.clearDraft(draftKey);
  }

  Future<bool> restoreDraft() async {
    final draft = await DraftAttendanceService.instance.loadDraft(draftKey);
    if (draft == null) return false;

    var restored = 0;
    final rosterIds = _roster.map((s) => s.id).toSet();
    draft.attendanceMap.forEach((id, status) {
      if (rosterIds.contains(id)) {
        _attendanceMap[id] = status;
        restored++;
      }
    });
    draft.studentNotes.forEach((id, note) {
      if (rosterIds.contains(id)) {
        _studentNotes[id] = StudentNote(
          reason: note['reason']?.toString() ?? 'General',
          remark: note['remark']?.toString() ?? '',
          medical: note['medical']?.toString(),
          lateReason: note['lateReason']?.toString(),
          privateNotes: note['privateNotes']?.toString(),
        );
      }
    });

    if (restored > 0) {
      _hasUnsavedChanges = true;
      notifyListeners();
    }
    return restored > 0;
  }

  String _fingerprintFor(Map<String, AttendanceStatus> map) {
    final keys = map.keys.toList()..sort();
    return keys.map((k) => '$k=${map[k]!.name}').join('|');
  }

  String _generateReferenceId() {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final rand = _random.nextInt(900000) + 100000;
    return 'ATT-$date-$rand';
  }

  // === ATTENDANCE MARKING ===

  void markStudent(String studentId, AttendanceStatus status) {
    final previous = _attendanceMap[studentId];
    if (previous != null && previous != status) {
      _undoStack.add(_UndoEntry(studentId, previous, _studentNotes[studentId]));
      _editHistory[studentId] = EditEntry(
        studentId: studentId,
        oldStatus: previous,
        newStatus: status,
        editedAt: DateTime.now(),
        editedBy: _editedBy,
      );
      _isEditMode = true;
      _editedAt = DateTime.now();
    }
    _attendanceMap[studentId] = status;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void markStudentWithNote(String studentId, AttendanceStatus status, {String? reason, String? remark, String? medical, String? lateReason, String? privateNotes}) {
    markStudent(studentId, status);
    if (reason != null || remark != null) {
      _studentNotes[studentId] = StudentNote(
        reason: reason ?? 'General',
        remark: remark ?? '',
        medical: medical,
        lateReason: lateReason,
        privateNotes: privateNotes,
      );
    }
  }

  void undoLast() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    _attendanceMap[entry.studentId] = entry.previousStatus;
    if (entry.previousNote != null) {
      _studentNotes[entry.studentId] = entry.previousNote!;
    } else {
      _studentNotes.remove(entry.studentId);
    }
    _editHistory.remove(entry.studentId);
    _hasUnsavedChanges = _undoStack.isNotEmpty || _attendanceMap.isNotEmpty;
    if (_undoStack.isEmpty) {
      _isEditMode = false;
    }
    _scheduleDraftSave();
    notifyListeners();
  }

  // === BULK ACTIONS ===

  void markAllPresent() {
    for (final s in _roster) {
      _attendanceMap[s.id] = AttendanceStatus.present;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void markAllAbsent() {
    for (final s in _roster) {
      _attendanceMap[s.id] = AttendanceStatus.absent;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void resetAll() {
    _attendanceMap.clear();
    _studentNotes.clear();
    _undoStack.clear();
    _editHistory.clear();
    _isEditMode = false;
    _hasUnsavedChanges = false;
    _submittedFingerprint = '';
    _submitReferenceId = null;
    _wasSubmittedOffline = false;
    _clearDraftNow();
    notifyListeners();
  }

  void markSelectedPresent() {
    for (final id in _selectedStudentIds) {
      _attendanceMap[id] = AttendanceStatus.present;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void markSelectedAbsent() {
    for (final id in _selectedStudentIds) {
      _attendanceMap[id] = AttendanceStatus.absent;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void markSelectedLate() {
    for (final id in _selectedStudentIds) {
      _attendanceMap[id] = AttendanceStatus.late;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void markSelectedLeave() {
    for (final id in _selectedStudentIds) {
      _attendanceMap[id] = AttendanceStatus.leave;
    }
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void selectAllStudents() {
    _selectedStudentIds = _roster.map((s) => s.id).toSet();
    notifyListeners();
  }

  void selectRemaining() {
    _selectedStudentIds = _roster.where((s) => !_attendanceMap.containsKey(s.id)).map((s) => s.id).toSet();
    notifyListeners();
  }

  void selectPresent() {
    _selectedStudentIds = _roster.where((s) => _attendanceMap[s.id] == AttendanceStatus.present).map((s) => s.id).toSet();
    notifyListeners();
  }

  void selectAbsent() {
    _selectedStudentIds = _roster.where((s) => _attendanceMap[s.id] == AttendanceStatus.absent).map((s) => s.id).toSet();
    notifyListeners();
  }

  void selectLate() {
    _selectedStudentIds = _roster.where((s) => _attendanceMap[s.id] == AttendanceStatus.late).map((s) => s.id).toSet();
    notifyListeners();
  }

  void selectLeave() {
    _selectedStudentIds = _roster.where((s) => _attendanceMap[s.id] == AttendanceStatus.leave).map((s) => s.id).toSet();
    notifyListeners();
  }

  void invertSelection() {
    final allIds = _roster.map((s) => s.id).toSet();
    _selectedStudentIds = allIds.difference(_selectedStudentIds);
    notifyListeners();
  }

  void clearSelection() {
    _selectedStudentIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) _selectedStudentIds.clear();
    notifyListeners();
  }

  void toggleStudentSelection(String studentId) {
    if (_selectedStudentIds.contains(studentId)) {
      _selectedStudentIds.remove(studentId);
    } else {
      _selectedStudentIds.add(studentId);
    }
    notifyListeners();
  }

  // === QUICK ACTIONS ===

  Future<QuickActionResult> _runQuickAction({
    required void Function() apply,
    required bool Function() hasTargets,
  }) async {
    if (_isProcessingQuickAction) return QuickActionResult.failed;
    if (!hasTargets()) return QuickActionResult.skipped;

    _isProcessingQuickAction = true;
    _quickActionSnapshot = Map.of(_attendanceMap);
    _hasQuickActionSnapshot = true;
    notifyListeners();

    try {
      apply();
      _scheduleDraftSave();
      await _repository.bulkUpdateAttendance(
        sessionId: _sessionId,
        courseCode: _courseCode ?? '',
        attendanceMap: Map.of(_attendanceMap),
      );
      _hasUnsavedChanges = true;
      return QuickActionResult.success;
    } on OfflineMarkAttendanceException {
      _hasUnsavedChanges = true;
      await OfflineSyncService.instance.saveOffline(
        OfflineAttendanceEntry(
          sessionId: _sessionId,
          attendanceMap: Map.of(_attendanceMap),
          timestamp: DateTime.now(),
        ),
      );
      return QuickActionResult.offline;
    } on MarkAttendanceServerException {
      _attendanceMap = Map.of(_quickActionSnapshot);
      return QuickActionResult.failed;
    } catch (_) {
      _attendanceMap = Map.of(_quickActionSnapshot);
      return QuickActionResult.failed;
    } finally {
      _isProcessingQuickAction = false;
      notifyListeners();
    }
  }

  Future<QuickActionResult> quickMarkAll(AttendanceStatus status) {
    return _runQuickAction(
      apply: () {
        for (final s in _roster) {
          _attendanceMap[s.id] = status;
        }
      },
      hasTargets: () =>
          _roster.isNotEmpty &&
          _roster.any((s) => _attendanceMap[s.id] != status),
    );
  }

  Future<QuickActionResult> quickDeselectAll() {
    return _runQuickAction(
      apply: () => _attendanceMap.clear(),
      hasTargets: () => _attendanceMap.isNotEmpty,
    );
  }

  Future<QuickActionResult> quickInvert() {
    return _runQuickAction(
      apply: () {
        for (final s in _roster) {
          final current = _attendanceMap[s.id];
          if (current == null) continue;
          _attendanceMap[s.id] = switch (current) {
            AttendanceStatus.present => AttendanceStatus.absent,
            AttendanceStatus.absent => AttendanceStatus.present,
            AttendanceStatus.late => AttendanceStatus.absent,
            AttendanceStatus.leave => AttendanceStatus.absent,
            AttendanceStatus.holiday => AttendanceStatus.holiday,
          };
        }
      },
      hasTargets: () => _attendanceMap.isNotEmpty,
    );
  }

  Future<QuickActionResult> quickMarkStudents(
    List<ClassStudent> targets,
    AttendanceStatus status,
  ) {
    return _runQuickAction(
      apply: () {
        for (final s in targets) {
          _attendanceMap[s.id] = status;
        }
      },
      hasTargets: () =>
          targets.isNotEmpty &&
          targets.any((s) => _attendanceMap[s.id] != status),
    );
  }

  Future<QuickActionResult> quickResetFiltered(List<ClassStudent> targets) {
    return _runQuickAction(
      apply: () {
        for (final s in targets) {
          _attendanceMap.remove(s.id);
        }
      },
      hasTargets: () => targets.any((s) => _attendanceMap.containsKey(s.id)),
    );
  }

  void quickUndo() {
    if (!_hasQuickActionSnapshot) return;
    _attendanceMap = Map.of(_quickActionSnapshot);
    _quickActionSnapshot = {};
    _hasQuickActionSnapshot = false;
    _hasUnsavedChanges = _attendanceMap.isNotEmpty;
    _scheduleDraftSave();
    notifyListeners();
  }

  void quickFilterDefaulters() {
    _filterMode = FilterMode.below75;
    notifyListeners();
  }

  void quickFilterEligible() {
    _filterMode = FilterMode.eligible;
    notifyListeners();
  }

  void quickClearFilters() {
    _filterMode = FilterMode.all;
    notifyListeners();
  }

  // === SEARCH / FILTER / SORT ===

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void setFilter(FilterMode mode) {
    _filterMode = mode;
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void setGenderFilter(String? gender) {
    _genderFilter = gender;
    notifyListeners();
  }

  void setSectionFilter(String? section) {
    _sectionFilter = section;
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _filterMode = FilterMode.all;
    _genderFilter = null;
    _sectionFilter = null;
    _sortMode = SortMode.alphabetical;
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _filterMode != FilterMode.all ||
      _genderFilter != null ||
      _sectionFilter != null ||
      _sortMode != SortMode.alphabetical;

  // === QR MODE ===

  void generateQRCode() {
    final random = Random();
    final code = '${_sessionId}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999999)}';
    _qrCodeData = code;
    _qrCountdownSeconds = 120;
    _qrScannedStudentIds.clear();
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _qrCountdownSeconds--;
      if (_qrCountdownSeconds <= 0) {
        timer.cancel();
        _qrCodeData = '';
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void refreshQR() {
    _qrTimer?.cancel();
    generateQRCode();
  }

  void expireQR() {
    _qrTimer?.cancel();
    _qrCodeData = '';
    notifyListeners();
  }

  void simulateQRScan(String studentId) {
    if (!_qrScannedStudentIds.contains(studentId)) {
      _qrScannedStudentIds.add(studentId);
      _attendanceMap[studentId] = AttendanceStatus.present;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void approveQRScan(String studentId) {
    _attendanceMap[studentId] = AttendanceStatus.present;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void rejectQRScan(String studentId) {
    _attendanceMap[studentId] = AttendanceStatus.absent;
    _qrScannedStudentIds.remove(studentId);
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  // === FACE RECOGNITION MODE ===

  void startCamera() {
    _isCameraActive = true;
    _recognizedStudentIds.clear();
    _unknownFaceIds.clear();
    notifyListeners();
  }

  void stopCamera() {
    _isCameraActive = false;
    notifyListeners();
  }

  void simulateFaceDetection() {
    final random = Random();
    final unmarked = _roster.where((s) => !_recognizedStudentIds.contains(s.id) && !_unknownFaceIds.contains(s.id)).toList();
    if (unmarked.isEmpty) return;

    final student = unmarked[random.nextInt(unmarked.length)];
    final confidence = 75.0 + random.nextDouble() * 25.0;

    if (confidence > 85) {
      _recognizedStudentIds.add(student.id);
      _attendanceMap[student.id] = AttendanceStatus.present;
      _hasUnsavedChanges = true;
      _scheduleDraftSave();
    } else {
      _unknownFaceIds.add(student.id);
    }
    notifyListeners();
  }

  void confirmFaceRecognition(String studentId) {
    _recognizedStudentIds.add(studentId);
    _unknownFaceIds.remove(studentId);
    _attendanceMap[studentId] = AttendanceStatus.present;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void rejectFaceRecognition(String studentId) {
    _unknownFaceIds.remove(studentId);
    _attendanceMap[studentId] = AttendanceStatus.absent;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  // === NFC MODE ===

  void simulateNFCTap(String studentId) {
    if (_nfcVerifiedIds.contains(studentId)) return;
    _nfcVerifiedIds.add(studentId);
    _lastNfcTag = 'NFC_${studentId}_${DateTime.now().millisecondsSinceEpoch}';
    _attendanceMap[studentId] = AttendanceStatus.present;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  // === BLUETOOTH MODE ===

  void startBluetoothScan() {
    _bluetoothDetectedIds.clear();
    _bluetoothSignalStrengths.clear();
    notifyListeners();
  }

  void simulateBluetoothDetection(String studentId) {
    if (_bluetoothDetectedIds.contains(studentId)) return;
    final random = Random();
    final signal = -30.0 - random.nextDouble() * 60.0;
    _bluetoothDetectedIds.add(studentId);
    _bluetoothSignalStrengths[studentId] = signal;
    _attendanceMap[studentId] = AttendanceStatus.present;
    _hasUnsavedChanges = true;
    _scheduleDraftSave();
    notifyListeners();
  }

  void stopBluetoothScan() {
    notifyListeners();
  }

  // === SUBMISSION ===

  Future<bool> submitAttendance({String? notes}) async {
    if (_attendanceMap.isEmpty) {
      _error = 'No attendance data to submit';
      notifyListeners();
      return false;
    }
    if (_isSubmitting) {
      _error = 'Attendance submission is already in progress.';
      notifyListeners();
      return false;
    }
    if (_sessionStatus == 'submitted' || _sessionStatus == 'submitted_offline') {
      _error = 'This attendance session has already been submitted.';
      notifyListeners();
      return false;
    }

    final fingerprint = _fingerprintFor(_attendanceMap);
    if (_submittedFingerprint.isNotEmpty && fingerprint == _submittedFingerprint) {
      _error = 'This attendance has already been submitted.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.submitAttendance(
        sessionId: _sessionId,
        attendanceMap: Map.from(_attendanceMap),
        notes: notes,
      );
      _submittedFingerprint = fingerprint;
      _submitReferenceId = _generateReferenceId();
      _wasSubmittedOffline = false;
      _sessionStatus = 'submitted';
      _isSubmitting = false;
      _lastSubmitTime = DateTime.now();
      _hasUnsavedChanges = false;
      _qrTimer?.cancel();
      _draftTimer?.cancel();
      await DraftAttendanceService.instance.clearDraft(draftKey);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MarkAttendance] Submit failed: $e');
      final offlineEntry = OfflineAttendanceEntry(
        sessionId: _sessionId,
        attendanceMap: Map.from(_attendanceMap),
        timestamp: DateTime.now(),
        notes: notes,
      );
      try {
        await OfflineSyncService.instance.saveOffline(offlineEntry);
        _submittedFingerprint = fingerprint;
        _submitReferenceId = _generateReferenceId();
        _wasSubmittedOffline = true;
        _sessionStatus = 'submitted_offline';
        _isSubmitting = false;
        _lastSubmitTime = DateTime.now();
        _hasUnsavedChanges = false;
        _qrTimer?.cancel();
        _draftTimer?.cancel();
        await DraftAttendanceService.instance.clearDraft(draftKey);
        notifyListeners();
        return true;
      } catch (saveError) {
        debugPrint('[MarkAttendance] Offline save failed: $saveError');
        _error = 'Unable to submit attendance. Your changes are saved as a draft.';
        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    }
  }

  Future<void> syncOfflineAttendance() async {
    _isSyncing = true;
    notifyListeners();
    await OfflineSyncService.instance.syncAll();
    _isSyncing = false;
    notifyListeners();
  }

  int get offlinePendingCount => OfflineSyncService.instance.pendingCount;

  // === HISTORY ===

  List<Map<String, dynamic>> getStudentHistory(String studentId) {
    return _attendanceHistory[studentId] ?? [];
  }

  // === CLEANUP ===

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _qrTimer?.cancel();
    _draftTimer?.cancel();
    _roster = [];
    _attendanceMap.clear();
    _studentNotes.clear();
    _attendanceHistory.clear();
    _undoStack.clear();
    _selectedStudentIds.clear();
    _editHistory.clear();
    _isLoading = false;
    _isSubmitting = false;
    _isSyncing = false;
    _error = null;
    _searchQuery = '';
    _filterMode = FilterMode.all;
    _sortMode = SortMode.alphabetical;
    _genderFilter = null;
    _sectionFilter = null;
    _isSelectionMode = false;
    _isEditMode = false;
    _editedBy = 'Faculty';
    _editedAt = null;
    _hasUnsavedChanges = false;
    _lastSubmitTime = null;
    _sessionStatus = 'not_started';
    _sessionId = '';
    _sessionStartTime = null;
    _qrCodeData = '';
    _qrCountdownSeconds = 120;
    _qrScannedStudentIds.clear();
    _recognizedStudentIds.clear();
    _unknownFaceIds.clear();
    _isCameraActive = false;
    _nfcVerifiedIds.clear();
    _lastNfcTag = '';
    _bluetoothDetectedIds.clear();
    _bluetoothSignalStrengths.clear();
    _isProcessingQuickAction = false;
    _quickActionSnapshot = {};
    _hasQuickActionSnapshot = false;
    _draftSection = '';
    _submitReferenceId = null;
    _wasSubmittedOffline = false;
    _submittedFingerprint = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    _draftTimer?.cancel();
    super.dispose();
  }
}

class DummyDataGeneratorForHistory {
  static final Random _random = Random(42);

  static List<Map<String, dynamic>> _generate(String studentId) {
    final history = <Map<String, dynamic>>[];
    final now = DateTime.now();

    int attended = 0;
    int total = 0;
    try {
      final keys = PersistenceService.academicBox.get('roster_keys');
      if (keys is List) {
        for (final key in keys) {
          final raw = PersistenceService.academicBox.get('roster_$key');
          if (raw is List) {
            for (final entry in raw) {
              if (entry is Map) {
                final id = (entry['id'] ?? entry['student_id'] ?? '').toString();
                if (id == studentId) {
                  attended = entry['attended'] is num ? (entry['attended'] as num).toInt() : 0;
                  total = entry['total'] is num ? (entry['total'] as num).toInt() : 30;
                  break;
                }
              }
            }
          }
          if (total > 0) break;
        }
      }
    } catch (_) {}

    if (total == 0) total = 30;
    final rate = total > 0 ? attended / total : 0.75;
    final daysToGenerate = total.clamp(1, 30);

    for (int i = daysToGenerate; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) continue;

      final roll = _random.nextDouble();
      final adjustedRoll = (roll + studentId.hashCode / 100000) % 1.0;
      AttendanceStatus status;
      DateTime? checkIn;
      if (adjustedRoll < rate) {
        status = AttendanceStatus.present;
        checkIn = DateTime(date.year, date.month, date.day, 9 + _random.nextInt(2), _random.nextInt(60));
      } else if (adjustedRoll < rate + 0.1) {
        status = AttendanceStatus.late;
        checkIn = DateTime(date.year, date.month, date.day, 9, 15 + _random.nextInt(45));
      } else if (adjustedRoll < rate + 0.18) {
        status = AttendanceStatus.leave;
      } else {
        status = AttendanceStatus.absent;
      }
      history.add({
        'date': date,
        'status': status,
        'checkInTime': checkIn,
      });
    }
    return history;
  }
}
