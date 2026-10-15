import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/resource_model.dart';
import 'package:intelli_attend_faculty/Data/Repositories/resource_repository.dart';

class ResourcesController extends ChangeNotifier {
  final ResourceRepository _repository;

  List<ResourceItem> _myResources = [];
  List<ResourceItem> _collegeResources = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  List<ResourceItem> get myResources => _myResources;
  List<ResourceItem> get collegeResources => _collegeResources;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;

  ResourcesController(this._repository);

  Future<void> loadResources() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final results = await Future.wait([
      _repository.getMyResources(),
      _repository.getCollegeResources(),
    ]);

    _myResources = results[0];
    _collegeResources = results[1];
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> uploadResource({
    required String filePath,
    required String fileName,
    required String facultyId,
    String? courseId,
    String? subjectId,
    required String category,
    String? description,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    final result = await _repository.uploadResource(
      filePath: filePath,
      fileName: fileName,
      facultyId: facultyId,
      courseId: courseId,
      subjectId: subjectId,
      category: category,
      description: description,
      onProgress: (progress) {
        _uploadProgress = progress;
        notifyListeners();
      },
    );

    _isUploading = false;
    if (result['success'] == true) {
      _uploadProgress = 1.0;
      notifyListeners();
      await loadResources();
      return true;
    } else {
      _error = result['error']?.toString() ?? 'Upload failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteResource(String resourceId) async {
    final result = await _repository.deleteResource(resourceId);
    if (result['success'] == true) {
      _myResources.removeWhere((r) => r.id == resourceId);
      _collegeResources.removeWhere((r) => r.id == resourceId);
      notifyListeners();
      return true;
    }
    _error = result['error']?.toString() ?? 'Delete failed';
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>> getPresignedUrl(String resourceId) async {
    return await _repository.getPresignedUrl(resourceId);
  }

  Future<bool> pushToSession(String resourceId, String sessionId) async {
    final result = await _repository.pushToSession(resourceId, sessionId);
    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Push failed';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> pushToSection(String resourceId, String sectionId) async {
    final result = await _repository.pushToSection(resourceId, sectionId);
    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Push failed';
      notifyListeners();
      return false;
    }
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
