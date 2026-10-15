class DeviceData {
  final String deviceId;
  final String fingerprint;
  final String? integrityToken;
  final String model;
  final String manufacturer;
  final String brand;
  final String osVersion;
  final String sdkVersion;
  final String deviceName;
  final String cpuArchitecture;
  final String screenResolution;
  final String localIpAddress;
  final String networkType;
  final bool hasScreenLock;
  final bool isRooted;
  final String appVersion;

  DeviceData({
    required this.deviceId,
    required this.fingerprint,
    this.integrityToken,
    required this.model,
    required this.manufacturer,
    this.brand = '',
    required this.osVersion,
    this.sdkVersion = '',
    this.deviceName = '',
    this.cpuArchitecture = '',
    this.screenResolution = '',
    this.localIpAddress = '',
    this.networkType = '',
    this.hasScreenLock = false,
    required this.isRooted,
    required this.appVersion,
  });

  String get displayName {
    if (manufacturer.isNotEmpty && model.isNotEmpty) {
      return '$manufacturer $model';
    }
    if (model.isNotEmpty) return model;
    if (deviceName.isNotEmpty) return deviceName;
    return 'Android Device';
  }

  String get osDisplay => 'Android $osVersion';

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_fingerprint': fingerprint,
    'integrity_token': integrityToken,
    'model': model,
    'manufacturer': manufacturer,
    'brand': brand,
    'os_version': osVersion,
    'sdk_version': sdkVersion,
    'device_name': deviceName,
    'cpu_architecture': cpuArchitecture,
    'screen_resolution': screenResolution,
    'local_ip_address': localIpAddress,
    'network_type': networkType,
    'has_screen_lock': hasScreenLock,
    'is_rooted': isRooted,
    'app_version': appVersion,
  };
}
