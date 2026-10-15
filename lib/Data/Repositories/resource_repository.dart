import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/resource_model.dart';

class ResourceRepository {
  final ApiClient _apiClient;

  ResourceRepository(this._apiClient);

  Future<List<ResourceItem>> getMyResources({String scope = 'faculty_private', String? subjectCode}) async {
    try {
      final queryParams = <String, dynamic>{'scope': scope};
      if (subjectCode != null) queryParams['subject_code'] = subjectCode;
      
      final response = await _apiClient.dio.get(
        '/api/v1/faculty/resources',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ResourceItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ Get resources error: ${e.response?.statusCode} - ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ Get resources error: $e');
      return [];
    }
  }

  Future<List<ResourceItem>> getCollegeResources({String? subjectCode}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (subjectCode != null) queryParams['subject_code'] = subjectCode;
      
      final response = await _apiClient.dio.get(
        '/api/v1/faculty/college-resources',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ResourceItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('❌ Get college resources error: ${e.response?.statusCode} - ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('❌ Get college resources error: $e');
      return [];
    }
  }

  String _detectMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':  return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':  return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':  return 'text/plain';
      case 'csv':  return 'text/csv';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'zip':  return 'application/zip';
      default:     return 'application/octet-stream';
    }
  }

  bool isSupportedFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv', 'jpg', 'jpeg', 'png', 'zip'].contains(ext);
  }

  Future<Map<String, dynamic>> uploadResource({
    required String filePath,
    required String fileName,
    required String facultyId,
    String? courseId,
    String? subjectId,
    required String category,
    String? description,
    void Function(double)? onProgress,
  }) async {
    try {
      if (!isSupportedFile(fileName)) {
        return {'success': false, 'error': 'Unsupported file type'};
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        return {'success': false, 'error': 'File not found'};
      }

      final fileSize = file.lengthSync();
      if (fileSize > 50 * 1024 * 1024) {
        return {'success': false, 'error': 'File too large. Maximum size is 50 MB.'};
      }

      String resolvedFacultyId = facultyId.trim();
      if (resolvedFacultyId.isEmpty) {
        resolvedFacultyId = FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';
      }
      if (resolvedFacultyId.isEmpty) {
        return {'success': false, 'error': 'Missing authentication'};
      }

      if (category.isEmpty) {
        return {'success': false, 'error': 'Missing category'};
      }

      final mimeType = _detectMimeType(fileName);

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📤 RESOURCE UPLOAD REQUEST');
      debugPrint('URL: ${_apiClient.dio.options.baseUrl}/api/v1/faculty/resources/upload');
      debugPrint('Method: POST');
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('Multipart fields:');
      debugPrint('  facultyId: $facultyId');
      debugPrint('  courseId: $courseId');
      debugPrint('  subjectId: $subjectId');
      debugPrint('  category: $category');
      debugPrint('  description: $description');
      debugPrint('  filename: $fileName');
      debugPrint('  mimeType: $mimeType');
      debugPrint('  file size: $fileSize bytes');
      debugPrint('═══════════════════════════════════════════════');

      final formData = FormData.fromMap({
        'faculty_id': facultyId,
        if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
        if (subjectId != null && subjectId.isNotEmpty) 'subject_id': subjectId,
        'category': category,
        if (description != null && description.isNotEmpty) 'description': description,
        'filename': fileName,
        'mime_type': mimeType,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _apiClient.dio.post(
        '/api/v1/faculty/resources/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📥 UPLOAD RESPONSE');
      debugPrint('HTTP ${response.statusCode}');
      debugPrint('Body: ${response.data}');
      debugPrint('═══════════════════════════════════════════════');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          return {'success': true, ...Map<String, dynamic>.from(response.data)};
        }
        return {'success': true, 'data': response.data};
      }

      final errorBody = response.data is Map ? response.data as Map : <String, dynamic>{'error': 'Unexpected response: ${response.statusCode}'};
      debugPrint('❌ Upload failed with HTTP ${response.statusCode}: $errorBody');
      return {'success': false, 'error': errorBody['message']?.toString() ?? errorBody['detail']?.toString() ?? errorBody['error']?.toString() ?? 'Upload failed (HTTP ${response.statusCode})'};
    } on DioException catch (e) {
      debugPrint('❌ DIO EXCEPTION: ${e.message}');
      debugPrint('   HTTP ${e.response?.statusCode}');
      debugPrint('   Body: ${e.response?.data}');

      if (e.response?.statusCode == 400) {
        final data = e.response?.data;
        if (data is Map) {
          final errors = <String>[];
          data.forEach((key, value) {
            errors.add('$key: $value');
          });
          debugPrint('   Validation errors: $errors');
          final msg = data['message']?.toString() ?? data['detail']?.toString() ?? data['error']?.toString() ?? errors.join('; ');
          return {'success': false, 'error': msg, 'validation_errors': errors};
        }
        return {'success': false, 'error': 'Bad request. Check all required fields.'};
      }

      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return {'success': false, 'error': 'Server unavailable. Please try again.'};
      }

      if (e.type == DioExceptionType.connectionError) {
        return {'success': false, 'error': 'Server unavailable. Check your internet connection.'};
      }

      final message = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ??
             e.response!.data['detail']?.toString() ??
             e.response!.data['error']?.toString() ??
             'Upload failed')
          : e.message ?? 'Upload failed';
      return {'success': false, 'error': message};
    } catch (e) {
      debugPrint('❌ UNEXPECTED ERROR: $e');
      return {'success': false, 'error': 'Upload failed: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteResource(String resourceId) async {
    try {
      final response = await _apiClient.dio.delete('/api/v1/faculty/resources/$resourceId');
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': false, 'error': 'Delete failed'};
    } on DioException catch (e) {
      final message = e.response?.data?['detail']?.toString() ??
          e.response?.data?['error']?.toString() ??
          e.message ??
          'Delete failed';
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPresignedUrl(String resourceId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/v1/faculty/resources/$resourceId/presigned-url',
      );
      if (response.statusCode == 200 && response.data is Map) {
        return {'success': true, ...Map<String, dynamic>.from(response.data)};
      }
      return {'success': false, 'error': 'Failed to get URL'};
    } on DioException catch (e) {
      final message = e.response?.data?['detail']?.toString() ??
          e.response?.data?['error']?.toString() ??
          e.message ??
          'URL generation failed';
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> pushToSession(String resourceId, String sessionId) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/resources/$resourceId/push-to-session',
        data: {'session_id': sessionId},
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': false, 'error': 'Push failed'};
    } on DioException catch (e) {
      final message = e.response?.data?['detail']?.toString() ??
          e.response?.data?['error']?.toString() ??
          e.message ??
          'Push failed';
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> pushToSection(String resourceId, String sectionId) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/resources/$resourceId/push-to-section',
        data: {'section_id': sectionId},
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': false, 'error': 'Push failed'};
    } on DioException catch (e) {
      final message = e.response?.data?['detail']?.toString() ??
          e.response?.data?['error']?.toString() ??
          e.message ??
          'Push failed';
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
