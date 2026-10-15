class AuthSession {
  final String sessionId;
  final String deviceModel;
  final String osVersion;
  final String deviceType;
  final DateTime lastActive;
  final bool isCurrentDevice;
  final String ipAddress;
  final String manufacturer;
  final String deviceName;
  final String location;
  final DateTime? loginTime;
  final String sessionStatus;
  final String browserName;
  final String browserVersion;

  AuthSession({
    required this.sessionId,
    required this.deviceModel,
    required this.osVersion,
    required this.deviceType,
    required this.lastActive,
    this.isCurrentDevice = false,
    this.ipAddress = '',
    this.manufacturer = '',
    this.deviceName = '',
    this.location = '',
    this.loginTime,
    this.sessionStatus = 'active',
    this.browserName = '',
    this.browserVersion = '',
  });

  String get displayName {
    if (manufacturer.isNotEmpty && deviceModel.isNotEmpty) {
      return '$manufacturer $deviceModel';
    }
    if (deviceModel.isNotEmpty && deviceModel != 'Unknown') return deviceModel;
    if (deviceName.isNotEmpty) return deviceName;
    return _platformDisplayName;
  }

  String get _platformDisplayName {
    switch (deviceType) {
      case 'android': return 'Android Device';
      case 'ios': return 'iOS Device';
      case 'desktop': return 'Desktop';
      case 'web': return 'Web Browser';
      default: return 'Unknown Device';
    }
  }

  String get osDisplay {
    if (deviceType == 'web' && browserName.isNotEmpty) {
      return browserVersion.isNotEmpty ? '$browserName $browserVersion' : browserName;
    }
    return osVersion;
  }

  bool get isActive => sessionStatus == 'active';
  bool get isExpired => sessionStatus == 'expired';

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      sessionId: json['session_id'] ?? json['jti'] ?? '',
      deviceModel: json['device_model'] ?? json['model'] ?? 'Unknown',
      osVersion: json['os_version'] ?? json['os_version_name'] ?? '',
      deviceType: json['device_type'] ?? 'unknown',
      lastActive: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isCurrentDevice: json['is_current_device'] ?? json['is_current'] ?? false,
      ipAddress: json['ip_address'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      deviceName: json['device_name'] ?? '',
      location: json['location'] ?? json['city'] ?? '',
      loginTime: json['login_time'] != null
          ? DateTime.tryParse(json['login_time'].toString())
          : null,
      sessionStatus: json['session_status'] ?? json['status'] ?? 'active',
      browserName: json['browser_name'] ?? '',
      browserVersion: json['browser_version'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'device_model': deviceModel,
    'os_version': osVersion,
    'device_type': deviceType,
    'last_active': lastActive.toIso8601String(),
    'is_current_device': isCurrentDevice,
    'ip_address': ipAddress,
    'manufacturer': manufacturer,
    'device_name': deviceName,
    'location': location,
    'login_time': loginTime?.toIso8601String(),
    'session_status': sessionStatus,
    'browser_name': browserName,
    'browser_version': browserVersion,
  };
}
