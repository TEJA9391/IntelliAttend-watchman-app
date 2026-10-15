class AuthStatusResponse {
  final String authStatus;
  final String? name;
  final String? role;
  final String? userId;

  AuthStatusResponse({
    required this.authStatus,
    this.name,
    this.role,
    this.userId,
  });

  bool get isActive => authStatus == 'active';
  bool get isPending => authStatus == 'pending';
  bool get isNotFound => authStatus == 'not_found';

  factory AuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return AuthStatusResponse(
      authStatus: json['auth_status'] as String? ?? 'not_found',
      name: json['name'] as String?,
      role: json['role'] as String?,
      userId: json['user_id'] as String?,
    );
  }
}

class VerifySessionResponse {
  final String status;
  final String? authStatus;
  final String? errorCode;
  final String? message;

  VerifySessionResponse({
    required this.status,
    this.authStatus,
    this.errorCode,
    this.message,
  });

  bool get isAuthenticated => status == 'authenticated';
  bool get isDeviceMismatch => status == 'device_mismatch';
  bool get isDeviceMissing => status == 'device_missing';
  bool get isRegistrationRequired => status == 'registration_required';

  factory VerifySessionResponse.fromJson(Map<String, dynamic> json) {
    return VerifySessionResponse(
      status: json['status'] as String? ?? 'error',
      authStatus: json['auth_status'] as String?,
      errorCode: json['error_code']?.toString(),
      message: json['message'] as String?,
    );
  }
}

class RegistrationCompleteRequest {
  final String userId;
  final String otp;
  final String password;
  final Map<String, dynamic> deviceInfo;

  RegistrationCompleteRequest({
    required this.userId,
    required this.otp,
    required this.password,
    required this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'otp': otp,
    'password': password,
    'device_info': deviceInfo,
  };
}

class RegistrationCompleteResponse {
  final String status;
  final Map<String, dynamic>? profile;
  final String? error;
  final String? errorCode;

  RegistrationCompleteResponse({
    required this.status,
    this.profile,
    this.error,
    this.errorCode,
  });

  factory RegistrationCompleteResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('detail')) {
      final detail = json['detail'];
      if (detail is Map) {
        return RegistrationCompleteResponse(
          status: 'error',
          error: detail['message']?.toString(),
          errorCode: detail['error_code']?.toString(),
        );
      }
    }

    return RegistrationCompleteResponse(
      status: json['status'] ?? (json.containsKey('profile') ? 'success' : 'unknown'),
      profile: json['profile'] as Map<String, dynamic>?,
      error: json['error'] ?? json['message'],
      errorCode: json['error_code'],
    );
  }
}

class DeviceInfoPayload {
  final String deviceId;
  final String deviceFingerprint;
  final String brand;
  final String model;
  final String manufacturer;
  final String osVersion;
  final bool biometricsEnabled;
  final bool isRooted;

  DeviceInfoPayload({
    required this.deviceId,
    required this.deviceFingerprint,
    required this.brand,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.biometricsEnabled,
    this.isRooted = false,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_fingerprint': deviceFingerprint,
    'brand': brand,
    'model': model,
    'manufacturer': manufacturer,
    'os_version': osVersion,
    'biometrics_enabled': biometricsEnabled,
    'is_rooted': isRooted,
  };
}
