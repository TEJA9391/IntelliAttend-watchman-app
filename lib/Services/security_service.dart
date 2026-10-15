import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';

class DeviceInfo {
  final String id;
  final String deviceName;
  final String location;
  final String lastActive;
  final bool isCurrent;
  final String os;
  final String ip;
  final bool isRooted;

  DeviceInfo({
    required this.id,
    required this.deviceName,
    required this.location,
    required this.lastActive,
    this.isCurrent = false,
    required this.os,
    required this.ip,
    this.isRooted = false,
  });
}

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  
  static Future<Map<String, String>> getDeviceIdentity() async {
    final hardware = await HardwareService.getDeviceSnapshot();
    return {
      'id': hardware.deviceId,
      'fingerprint': hardware.fingerprint,
      'model': hardware.model,
      'os': hardware.osVersion,
    };
  }

  SecurityService._internal() {
    initRealDeviceInfo();
  }

  final ValueNotifier<List<DeviceInfo>> activeDevices = ValueNotifier([
    DeviceInfo(
        id: "loading",
        deviceName: "Authenticating Device...",
        location: "Checking...",
        lastActive: "Now",
        isCurrent: true,
        os: "Detecting OS...",
        ip: "Fetching IP...",
        isRooted: false),
  ]);

  Future<void> initRealDeviceInfo() async {
    try {
      // Use the newly implemented HardwareService (Native Bridge)
      final hardwareData = await HardwareService.getDeviceSnapshot();

      activeDevices.value = [
        DeviceInfo(
          id: "current",
          deviceName: "${hardwareData.manufacturer} ${hardwareData.model}",
          location: "Syncing from Native...",
          lastActive: "Active Now",
          isCurrent: true,
          os: hardwareData.osVersion,
          ip: hardwareData.localIpAddress.isNotEmpty ? hardwareData.localIpAddress : "N/A",
          isRooted: hardwareData.isRooted,
        ),
      ];
    } catch (e) {
      activeDevices.value = [
        DeviceInfo(
          id: "error",
          deviceName: "Hardware Sync Error",
          location: "Manual verification needed",
          lastActive: "Now",
          isCurrent: true,
          os: "Unknown",
          ip: "0.0.0.0",
          isRooted: false,
        ),
      ];
    }
  }

  void logoutDevice(String id) {
    activeDevices.value = activeDevices.value.where((d) => d.id != id).toList();
  }
}
