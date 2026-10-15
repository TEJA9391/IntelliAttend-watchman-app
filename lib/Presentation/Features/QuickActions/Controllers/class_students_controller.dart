import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/students_repository.dart';

enum StudentsFilter {
  none,
  rollNumber,
  name,
  department,
  section,
  attendance,
  eligible,
  defaulter,
  gender,
}

enum SortOrder { ascending, descending }

class ClassStudentsController extends ChangeNotifier {
  final StudentsRepository _repository;

  List<ClassStudent> _allStudents = [];
  List<ClassStudent> _filteredStudents = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  StudentsFilter _currentFilter = StudentsFilter.none;
  SortOrder _sortOrder = SortOrder.ascending;
  String _selectedSection = '';
  String _selectedCourseCode = '';

  ClassStudentsController(this._repository);

  List<ClassStudent> get students => _filteredStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _filteredStudents.isEmpty && !_isLoading;
  int get totalCount => _allStudents.length;
  String get searchQuery => _searchQuery;
  StudentsFilter get currentFilter => _currentFilter;
  SortOrder get sortOrder => _sortOrder;
  String get selectedSection => _selectedSection;
  String get selectedCourseCode => _selectedCourseCode;

  Future<void> loadStudents({
    String? section,
    String? courseCode,
  }) async {
    _isLoading = true;
    _error = null;
    if (section != null) _selectedSection = section;
    if (courseCode != null) _selectedCourseCode = courseCode;
    notifyListeners();

    try {
      _allStudents = await _repository.fetchStudents(
        section: _selectedSection.isNotEmpty ? _selectedSection : null,
        courseCode:
            _selectedCourseCode.isNotEmpty ? _selectedCourseCode : null,
      );
      _applyFiltersAndSort();
    } catch (e) {
      _error = 'Failed to load students: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setFilter(StudentsFilter filter) {
    if (_currentFilter == filter) {
      _currentFilter = StudentsFilter.none;
    } else {
      _currentFilter = filter;
    }
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _currentFilter = StudentsFilter.none;
    _sortOrder = SortOrder.ascending;
    _selectedSection = '';
    _selectedCourseCode = '';
    _applyFiltersAndSort();
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadStudents();
  }

  void _applyFiltersAndSort() {
    List<ClassStudent> result = List.from(_allStudents);

    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      result = result.where((s) {
        return s.name.toLowerCase().contains(lowerQuery) ||
            s.rollNumber.toLowerCase().contains(lowerQuery) ||
            s.email.toLowerCase().contains(lowerQuery);
      }).toList();
    }

    switch (_currentFilter) {
      case StudentsFilter.none:
        break;
      case StudentsFilter.eligible:
        result = result.where((s) => s.isEligible).toList();
        break;
      case StudentsFilter.defaulter:
        result = result.where((s) => s.isDefaulter).toList();
        break;
      case StudentsFilter.attendance:
        result = result.where((s) => s.attendancePercentage < 75).toList();
        break;
      case StudentsFilter.gender:
        break;
      case StudentsFilter.department:
        break;
      case StudentsFilter.section:
        break;
      case StudentsFilter.rollNumber:
        break;
      case StudentsFilter.name:
        break;
    }

    result.sort((a, b) {
      int comparison;
      switch (_currentFilter) {
        case StudentsFilter.rollNumber:
          comparison = a.rollNumber.compareTo(b.rollNumber);
          break;
        case StudentsFilter.name:
          comparison = a.name.compareTo(b.name);
          break;
        case StudentsFilter.department:
          comparison =
              (a.department ?? '').compareTo(b.department ?? '');
          break;
        case StudentsFilter.section:
          comparison =
              (a.section ?? '').compareTo(b.section ?? '');
          break;
        case StudentsFilter.attendance:
          comparison = a.attendancePercentage
              .compareTo(b.attendancePercentage);
          break;
        case StudentsFilter.eligible:
          comparison = a.isEligible == b.isEligible
              ? 0
              : a.isEligible
                  ? -1
                  : 1;
          break;
        case StudentsFilter.defaulter:
          comparison = a.isDefaulter == b.isDefaulter
              ? 0
              : a.isDefaulter
                  ? 1
                  : -1;
          break;
        case StudentsFilter.gender:
          comparison =
              (a.gender ?? '').compareTo(b.gender ?? '');
          break;
        case StudentsFilter.none:
          comparison = a.name.compareTo(b.name);
          break;
      }
      return _sortOrder == SortOrder.ascending
          ? comparison
          : -comparison;
    });

    _filteredStudents = result;
  }
}
