import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';

class SmartBoardController extends ChangeNotifier {
  final String sessionId;
  final AttendanceRepository _repository;

  String _otp = '';
  int _secondsLeft = 0;
  Timer? _timer;
  bool _isRotating = false;

  int _initialDuration = 30;

  String get otp => _otp;
  int get secondsLeft => _secondsLeft;
  int get initialDuration => _initialDuration;
  bool get isRotating => _isRotating;

  SmartBoardController({
    required this.sessionId, 
    required String initialOtp, 
    required int initialSeconds,
    required AttendanceRepository repository,
  }) : _repository = repository {
    _otp = initialOtp;
    _secondsLeft = initialSeconds;
    _initialDuration = initialSeconds > 0 ? initialSeconds : 30;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      } else {
        _timer?.cancel();
        debugPrint("⏳ SMARTBOARD: OTP expired. Manual refresh required.");
      }
    });
  }

  Future<void> rotateCodeManually() async {
    if (_isRotating) return;
    _isRotating = true;
    notifyListeners();
    
    try {
      final response = await _repository.refreshOtp(sessionId);
      if (response != null) {
        _otp = response.otp;
        _secondsLeft = response.secondsRemaining;
        _initialDuration = response.secondsRemaining; // Update for full circle
        _startTimer();
      }
    } catch (e) {
      debugPrint("❌ SMARTBOARD: Failed to refresh OTP: $e");
    } finally {
      _isRotating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
