import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Only notification permission is required for faculty app
  Future<bool> hasAllPermissions() async {
    return await Permission.notification.isGranted;
  }

  bool _isRequesting = false;

  /// Requests notification permission only
  Future<Map<Permission, PermissionStatus>> requestAll() async {
    if (_isRequesting) return {};
    _isRequesting = true;
    try {
      return await {Permission.notification: await Permission.notification.request()};
    } finally {
      _isRequesting = false;
    }
  }

  Future<bool> isNotificationGranted() async => await Permission.notification.isGranted;
}
