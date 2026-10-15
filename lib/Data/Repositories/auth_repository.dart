import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/registration_models.dart';

abstract class IAuthRepository {
  Future<AuthStatusResponse> checkAuthStatus();
  Future<void> sendOtp();
  Future<RegistrationCompleteResponse> completeRegistration(RegistrationCompleteRequest request);
  Future<VerifySessionResponse> verifySession(DeviceInfoPayload deviceInfo);
  Future<UserCredential?> signIn(String email, String password);
  Future<void> changePassword(String oldPassword, String newPassword);
  Future<void> signOut();
  User? getCurrentUser();
}

class AuthRepository implements IAuthRepository {
  final ApiClient _apiClient;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthRepository(this._apiClient);

  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Failed to get ID token');
    return token;
  }

  @override
  Future<AuthStatusResponse> checkAuthStatus() async {
    try {
      final token = await _getIdToken();
      final response = await _apiClient.dio.post(
        '/api/v1/auth/status',
        data: {'token': token},
      );
      return AuthStatusResponse.fromJson(response.data);
    } on DioException catch (e) {
      debugPrint('❌ checkAuthStatus error: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> sendOtp() async {
    final response = await _apiClient.dio.post('/api/v1/auth/register/send-otp');
    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP: ${response.statusCode}');
    }
  }

  @override
  Future<RegistrationCompleteResponse> completeRegistration(
      RegistrationCompleteRequest request) async {
    try {
      debugPrint('AuthRepository: Completing registration for ${request.userId}');
      final response = await _apiClient.dio.post(
        '/api/v1/auth/register/complete',
        data: request.toJson(),
      );
      if (response.statusCode == 200) {
        return RegistrationCompleteResponse.fromJson(response.data);
      }
      return RegistrationCompleteResponse(
        status: 'error',
        error: 'Server error: ${response.statusCode}',
      );
    } on DioException catch (e) {
      debugPrint('❌ Registration Complete DioException: ${e.message}');
      if (e.response?.data != null) {
        return RegistrationCompleteResponse.fromJson(e.response!.data);
      }
      return RegistrationCompleteResponse(
        status: 'error',
        error: 'Network error: ${e.message}',
      );
    } catch (e) {
      debugPrint('Complete Registration Error: $e');
      return RegistrationCompleteResponse(status: 'error', error: 'Unknown error: $e');
    }
  }

  @override
  Future<VerifySessionResponse> verifySession(DeviceInfoPayload deviceInfo) async {
    try {
      final token = await _getIdToken();
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');

      final response = await _apiClient.dio.post(
        '/api/v1/auth/verify-session',
        data: {
          'token': token,
          'role': 'faculty',
          'device_info': deviceInfo.toJson(),
          if (fcmToken != null) 'fcm_token': fcmToken,
        },
      );
      return VerifySessionResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.data != null && e.response!.data is Map) {
        return VerifySessionResponse.fromJson(e.response!.data);
      }
      return VerifySessionResponse(
        status: 'error',
        message: e.message ?? 'Server unavailable. Please try again.',
      );
    }
  }

  @override
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        debugPrint('🔥 Firebase Sign-In Successful. ID Token will be used for API Authorization.');
      }

      return credential;
    } catch (e) {
      debugPrint('Sign In Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'User not found');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  @override
  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }
}
