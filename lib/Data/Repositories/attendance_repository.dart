import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/registration_models.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class SessionStartResponse {
  final String sessionId;
  final String otp;
  final int secondsRemaining;
  final String? expiresAt;
  final String? currentTime;
  final String? websocketUrl;
  final String state;
  final int version;

  SessionStartResponse({
    required this.sessionId,
    required this.otp,
    required this.secondsRemaining,
    this.expiresAt,
    this.currentTime,
    this.websocketUrl,
    this.state = 'IGNITING',
    this.version = 1,
  });

  factory SessionStartResponse.fromJson(Map<String, dynamic> json) {
    return SessionStartResponse(
      sessionId: json['session_id']?.toString() ?? '',
      otp: json['otp']?.toString() ?? '000000',
      secondsRemaining: (json['seconds_remaining'] as int? ?? 30).clamp(10, 30),
      expiresAt: json['expires_at']?.toString(),
      currentTime: json['current_time']?.toString(),
      websocketUrl: json['websocket_url']?.toString() ?? json['ws_token']?.toString(),
      state: json['state']?.toString() ?? 'IGNITING',
      version: (json['version'] as int? ?? 1),
    );
  }
}

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository(this._apiClient);

  /// COMMAND: Start a new session (V2 Zero-Trust)
  /// Endpoint: POST /api/v1/faculty/start_session
  /// Faculty identity is read from Firebase JWT (Authorization header).
  Future<SessionStartResponse?> startSession(ScheduledClass scheduledClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("❌ ERROR: Attempted to start session without authentication.");
      throw Exception("Authentication required to start session");
    }

    debugPrint("🚀 API CALL: Starting Session...");
    debugPrint("📍 URL: ${_apiClient.baseUrl}/api/v1/faculty/start_session");

    try {
      final body = {
        'slot_id': scheduledClass.id,
      };
      debugPrint("📦 Request Body: $body");
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/start_session',
        data: body,
      );

      debugPrint("✅ API SUCCESS: HTTP ${response.statusCode}");
      debugPrint("🔑 OTP FROM SERVER: ${response.data['otp']}");
      debugPrint("📦 FULL RESPONSE: ${response.data}");
      return SessionStartResponse.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint("❌ API ERROR: ${e.response?.statusCode} - ${e.response?.data}");
      final data = e.response?.data;
      final errorCode = data?['error_code']?.toString();
      final message = data?['message']?.toString() ??
                      data?['error']?.toString() ??
                      data?['detail']?['message']?.toString() ??
                      data?['detail']?.toString() ??
                      e.message ?? 'Unknown server error';
      if (errorCode != null) {
        throw Exception("$errorCode: $message");
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  /// COMMAND: Refresh/Rotate OTP (Every 30 seconds)
  /// Endpoint: /api/v1/faculty/refresh_otp
  Future<SessionStartResponse?> refreshOtp(String sessionId) async {
    debugPrint("🔄 API CALL: Refreshing OTP for session: $sessionId");
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/refresh_otp',
        data: {'session_id': sessionId},
      );
      if (response.statusCode == 200) {
        debugPrint("🔑 NEW OTP FROM SERVER: ${response.data['otp']}");
        debugPrint("📦 REFRESH RESPONSE: ${response.data}");
        return SessionStartResponse.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      final message = e.response?.data?['error']?.toString() ??
                      e.response?.data?['detail']?['message'] ?? 
                      e.response?.data?['detail'] ?? 
                      e.message ?? 'Refresh failed';
      throw Exception(message);
    } catch (e) {
      throw Exception('Refresh connection failed: $e');
    }
  }

  /// COMMAND: Generate QR token for student scanning
  /// Endpoint: POST /api/v1/faculty/generate_qr
  /// Requires a valid OTP to authorize QR generation.
  Future<bool> generateQr(String sessionId, String otp) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/generate_qr',
        data: {
          'session_id': sessionId,
          'otp': otp,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('Generate QR API Error: ${e.response?.statusCode} - ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('Generate QR connection failed: $e');
      return false;
    }
  }

  /// COMMAND: Mark attendance via Custom Server API (Manual Faculty Override)
  /// Endpoint: POST /api/v1/faculty/attendance/manual
  Future<bool> markAttendance(AttendanceMarkRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/attendance/manual',
        data: request.toJson(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final detail = e.response?.data['detail'];
        final source = detail is Map ? detail['existing_marked_by'] : 'unknown';
        throw Exception("ALREADY_MARKED:$source");
      }
      debugPrint('Mark Attendance API Error: ${e.response?.statusCode} - ${e.response?.data}');
      return false;
    } catch (e) {
      debugPrint('Mark Attendance connection failed: $e');
      return false;
    }
  }

  /// COMMAND: Retrospective Correction via Custom Server API
  /// Endpoint: POST /api/v1/faculty/attendance/correction
  Future<bool> markAttendanceCorrection({
    required String sessionId,
    required String studentId,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/attendance/correction',
        data: {
          'session_id': sessionId,
          'student_id': studentId,
          'reason': reason,
          if (notes != null) 'notes': notes,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final detail = e.response?.data['detail'];
        final source = detail is Map ? detail['existing_marked_by'] : 'unknown';
        throw Exception("ALREADY_MARKED:$source");
      }
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data['message']?.toString();
      debugPrint('Mark Attendance Correction API Error: $statusCode - ${e.response?.data}');
      if (statusCode != null && statusCode >= 500) {
        throw Exception("SERVER_ERROR:${serverMsg ?? 'Server error. Please try again.'}");
      }
      return false;
    } catch (e) {
      debugPrint('Mark Attendance Correction connection failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSyncData() async {
    try {
      final response = await _apiClient.dio.get('/api/v1/faculty/sync');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('student_rosters')) {
          await PersistenceService.academicBox.put('student_rosters', data['student_rosters']);
          debugPrint("📦 SYNC: Student rosters saved to academicBox cache.");
        }
        return data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint("❌ Sync API Error: ${e.response?.statusCode} - ${e.response?.data}");
      final cached = PersistenceService.academicBox.get('student_rosters');
      if (cached != null) {
        debugPrint("📦 SYNC: Returning cached student rosters from local memory due to DioException");
        return {'student_rosters': cached};
      }
      return null;
    } catch (e) {
      debugPrint("❌ Sync Connection Error: $e");
      final cached = PersistenceService.academicBox.get('student_rosters');
      if (cached != null) {
        debugPrint("📦 SYNC: Returning cached student rosters from local memory due to exception");
        return {'student_rosters': cached};
      }
      return null;
    }
  }

  /// COMMAND: Terminate a session (V2 Zero-Trust Teardown)
  /// Endpoint: POST /api/v1/session/terminate
  Future<bool> terminateSession(String sessionId) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/session/terminate',
        data: {
          'session_id': sessionId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Terminate Session API Error: $e');
      return false;
    }
  }

  /// COMMAND: Generate rescue seed via Custom Server API (Validation Part)
  Future<bool> generateRescueSeed(String sessionId, String seed, DeviceInfoPayload deviceInfo) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/session/$sessionId/rescue-seed',
        data: {
          'seed': seed,
          'device_info': deviceInfo.toJson(),
          'generated_at': DateTime.now().toIso8601String(),
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Generate Rescue Seed API Error: $e');
      return false;
    }
  }

  /// COMMAND: Reconcile present_count for a session.
  /// Hits the backend to re-count actual PRESENT records from the attendance
  /// sub-collection and corrects the counter if it drifted.
  Future<Map<String, dynamic>?> reconcileSession(String sessionId) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/faculty/sessions/$sessionId/reconcile',
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      final message = e.response?.data?['detail'] ?? e.message ?? 'Reconcile failed';
      debugPrint('Reconcile API Error: $message');
      throw Exception(message);
    } catch (e) {
      debugPrint('Reconcile connection failed: $e');
      rethrow;
    }
  }

  /// Recovery API: fetch authoritative session state
  /// Endpoint: GET /api/v1/session/current-state
  Future<Map<String, dynamic>?> fetchCurrentState() async {
    try {
      final response = await _apiClient.dio.get(
        '/api/v1/session/current-state',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[Recovery] current-state fetch error: $e');
      return null;
    }
  }

  /// COMMAND: Start an existing session (PREPARING → IGNITING)
  /// Endpoint: POST /api/v1/start-session
  Future<SessionStartResponse?> startExistingSession(String sessionId) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/start-session',
        data: {'session_id': sessionId},
      );
      if (response.statusCode == 200) {
        return SessionStartResponse.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      final message = e.response?.data?['error']?.toString() ??
                      e.response?.data?['detail']?['message'] ??
                      e.message ?? 'Start session failed';
      throw Exception(message);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  /// Fetch session details from REST API (replaces Firestore listener).
  Future<Map<String, dynamic>?> fetchSessionStatus(String sessionId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/v1/session/$sessionId',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Session status fetch error: $e');
      return null;
    }
  }
}
