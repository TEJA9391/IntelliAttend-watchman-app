import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/auth_session_model.dart';

class SessionManagementService {
  final Dio _dio;

  SessionManagementService() : _dio = ApiClient().dio;

  Future<List<AuthSession>> getActiveSessions() async {
    try {
      final response = await _dio.get('/api/v1/auth/sessions');
      final List<dynamic> sessionsJson = response.data['sessions'] ?? [];
      return sessionsJson.map((s) => AuthSession.fromJson(s as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[SessionMgmt] Failed to fetch sessions: $e');
      return [];
    }
  }

  Future<bool> revokeSession(String sessionId) async {
    try {
      final response = await _dio.delete('/api/v1/auth/sessions/$sessionId');
      return response.data['success'] == true;
    } catch (e) {
      debugPrint('[SessionMgmt] Failed to revoke session: $e');
      return false;
    }
  }

  Future<int> revokeAllOtherSessions({String? currentSessionId}) async {
    try {
      final sessions = await getActiveSessions();
      final others = sessions.where((s) => !s.isCurrentDevice && s.sessionId != currentSessionId).toList();
      int revoked = 0;
      for (final session in others) {
        final success = await revokeSession(session.sessionId);
        if (success) revoked++;
      }
      return revoked;
    } catch (e) {
      debugPrint('[SessionMgmt] Failed to revoke all other sessions: $e');
      return 0;
    }
  }
}
