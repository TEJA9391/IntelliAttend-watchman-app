import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/attendance_records_repository.dart';

enum AttendanceFilter { none, date, subject, section, status, student, session }
enum RecordSortField { date, name, rollNumber, attendancePercent, time }
enum SortDirection { ascending, descending }

class AttendanceRecordsController extends ChangeNotifier {
  final AttendanceRecordsRepository _repository;

  List<AttendanceSession> _sessions = [];
  List<AttendanceRecord> _currentSessionRecords = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  String _selectedCourseCode = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  AttendanceFilter _currentFilter = AttendanceFilter.none;
  String _searchQuery = '';

  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;

  RecordSortField _sortField = RecordSortField.date;
  SortDirection _sortDirection = SortDirection.descending;

  AttendanceRecordsController(this._repository);

  List<AttendanceSession> get sessions => _sessions;
  List<AttendanceRecord> get currentSessionRecords => _currentSessionRecords;
  Map<String, dynamic> get summary => _summary;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get currentPage => _currentPage;
  String get selectedCourseCode => _selectedCourseCode;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  AttendanceFilter get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  RecordSortField get sortField => _sortField;
  SortDirection get sortDirection => _sortDirection;

  Future<void> loadSessions({
    String? courseCode,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    if (courseCode != null) _selectedCourseCode = courseCode;
    if (dateFrom != null) _dateFrom = dateFrom;
    if (dateTo != null) _dateTo = dateTo;
    notifyListeners();

    try {
      _sessions = await _repository.fetchSessions(
        courseCode:
            _selectedCourseCode.isNotEmpty ? _selectedCourseCode : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: 1,
        pageSize: _pageSize,
      );
      _hasMore = _sessions.length >= _pageSize;
    } catch (e) {
      _error = 'Failed to load sessions: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final moreSessions = await _repository.fetchSessions(
        courseCode:
            _selectedCourseCode.isNotEmpty ? _selectedCourseCode : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (moreSessions.isEmpty) {
        _hasMore = false;
      } else {
        _sessions.addAll(moreSessions);
        _hasMore = moreSessions.length >= _pageSize;
      }
    } catch (e) {
      _currentPage--;
      _error = 'Failed to load more sessions: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadSessionRecords(String sessionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentSessionRecords =
          await _repository.fetchSessionRecords(sessionId);
    } catch (e) {
      _error = 'Failed to load session records: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSummary({
    String? courseCode,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _repository.fetchSummary(
        courseCode: courseCode,
        dateFrom: dateFrom ?? _dateFrom,
        dateTo: dateTo ?? _dateTo,
      );
    } catch (e) {
      _error = 'Failed to load summary: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void setCourseCode(String courseCode) {
    _selectedCourseCode = courseCode;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void setFilter(AttendanceFilter filter) {
    if (_currentFilter == filter) {
      _currentFilter = AttendanceFilter.none;
    } else {
      _currentFilter = filter;
    }
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortField(RecordSortField field) {
    if (_sortField == field) {
      _sortDirection = _sortDirection == SortDirection.ascending
          ? SortDirection.descending
          : SortDirection.ascending;
    } else {
      _sortField = field;
      _sortDirection = field == RecordSortField.name
          ? SortDirection.ascending
          : SortDirection.descending;
    }
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortDirection = _sortDirection == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
    notifyListeners();
  }

  List<AttendanceRecord> sortRecords(List<AttendanceRecord> records) {
    final sorted = List<AttendanceRecord>.from(records);
    final dir = _sortDirection == SortDirection.ascending ? 1 : -1;

    switch (_sortField) {
      case RecordSortField.date:
        sorted.sort((a, b) => dir * a.date.compareTo(b.date));
      case RecordSortField.name:
        sorted.sort((a, b) => dir * a.studentName.compareTo(b.studentName));
      case RecordSortField.rollNumber:
        sorted.sort((a, b) => dir * a.rollNumber.compareTo(b.rollNumber));
      case RecordSortField.attendancePercent:
        sorted.sort((a, b) => dir * (a.attendancePercentage ?? 0).compareTo(b.attendancePercentage ?? 0));
      case RecordSortField.time:
        sorted.sort((a, b) {
          final aTime = a.checkInTime ?? DateTime(2000);
          final bTime = b.checkInTime ?? DateTime(2000);
          return dir * aTime.compareTo(bTime);
        });
    }
    return sorted;
  }

  void clearFilters() {
    _selectedCourseCode = '';
    _dateFrom = null;
    _dateTo = null;
    _currentFilter = AttendanceFilter.none;
    _searchQuery = '';
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void clearSessionRecords() {
    _currentSessionRecords = [];
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadSessions();
    await loadSummary();
  }
}
